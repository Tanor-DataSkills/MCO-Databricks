/*La table mco.ref.table_registry associe chaque table Delta/Unity Catalog à son job_id producteur dans mco.ref.job_registry, sa criticité, sa colonne d'ingestion 
et ses seuils de surveillance (seuil_fraicheur_h, seuil_volumetrie_pct)

La table mco.ref.table_registry s’alimente en cinq(5) étapes : 

- Etape 1: Découverte et repérage les tables à surveiller par le lineage, 
- Etape 2: Detection des colonnes d'ingestion candidates
- Etape 3: Fixer les seuils avec l’owner 
- Etape 4: Chargement en masse MERGE
- Etape 5: Vérification post-chargement(controle de la cohérence entre le référentiel MCO (mco.ref.table_registry) et la réalité de la plateforme Unity Catalog)

Les résultats des étapes 1 et 2 permettent d'avoir les champs table_name, job_id et colonne_ingestion; ces informations sont complétées par les champs criticité, seuil_fraicheur_h, seuil_volumetrie_pct,
le tout à saisir en collaboration avec les owners dans le fichier tables_p1.csv avant d'etre merger dans la table finale mco.ref.table_registry.

------------------------------------------------********************************---------------------------------------------------------------------------------------------------------
                                              Étape 1 : Découverte et repérage les tables à surveiller par le lineage
  
                                                Lister les tables P1 via le lineage (30 derniers jours)
  
Cette requete croise system.access.table_lineage (entity_type = 'JOB', event_date >= current_date() - 30) avec mco.ref.job_registry filtré sur g.criticite = 'P1'. Cela restreint le périmètre 
aux tables effectivement touchées récemment par des pipelines critiques P1.*/


  SELECT DISTINCT
  l.target_table_full_name AS table_name,
  l.entity_id AS job_id,
  g.criticite
FROM system.access.table_lineage AS l
JOIN mco.ref.job_registry AS g
  ON l.entity_id = g.job_id
WHERE l.entity_type = 'JOB'
  AND g.criticite = 'P1'
  AND l.target_table_full_name IS NOT NULL
  AND l.event_date >= current_date() - 30;

-------------------------------------------------********************************------------------------------------------------------------------------------------------------------
                                            /*Etape 2: Détecter les colonnes d'ingestion candidates

Le champ colonne_ingestion de la table mco.ref.table_registry s'obtient depuis system.information_schema.columns. 
On repère les colonnes de type TIMESTAMP ou TIMESTAMP_NTZ dont le nom correspond au motif ingest|load|updated|insert|etl (utile comme suggestion/pré-remplissage, 
à valider car une table peut avoir plusieurs colonnes correspondantes).

Colonne d'ingestion candidate ?
Dans le cadre du MCO Databricks, une colonne d'ingestion candidate est une colonne de type horodatage (TIMESTAMP ou TIMESTAMP_NTZ) repérée automatiquement 
dans une table via system.information_schema.columns parce que son nom évoque un chargement ou une mise à jour technique (ex. ingestion_ts, load_date, etl_insert_ts, updated_at).

On la qualifie de « candidate » (et non pas encore « retenue ») car la requête ne peut pas deviner le sens métier réel d'une colonne uniquement à son nom. 
Une table peut avoir plusieurs colonnes correspondantes (par exemple inserted_at à la création de la ligne et updated_at lors d'une modification), 
ou n'en avoir aucune si l'horodatage est nommé autrement (ex. event_ts, business_date).*/

SELECT concat_ws('.', table_catalog, table_schema, table_name) AS table_name, column_name
FROM system.information_schema.columns
WHERE data_type IN ('TIMESTAMP', 'TIMESTAMP_NTZ')
  AND lower(column_name) RLIKE 'ingest|load|updated|insert|etl';

/*Elle interroge system.information_schema.columns sur les types TIMESTAMP / TIMESTAMP_NTZ filtrés par regex ingest|load|updated|insert|etl. Attention : si une table possède à la fois inserted_ts et updated_ts, plusieurs lignes ressortiront pour la même table ; 
le choix final doit être validé et figé dans tables_p1.csv.

L’owner regarde la sortie pour confirmer la bonne colonne
-------------------------------------------------------********************************-----------------------------------------------------------------------------------------------------
                                                   Étape 3 :  Fixer les seuils avec l’owner

Les informations obtenues des 2 premières requetes( Table_name, colonne_ingestion, job_id) sont enrichies avec les informations fournies par les métiers 
ou owner(criticite,seuil_fraicheur_h,seuil_volumetrie_pct) le tout saisi dans le fichier tables_p1.csv et déposé au volume avant d'etre merger.

Fichier de référence métier (tables_p1.csv à déposer dans un Volume Unity Catalog) : fournit les valeurs validées avec les owners (colonne_ingestion, seuil_fraicheur_h, seuil_volumetrie_pct, criticite, job_id), 
puis applique un MERGE INTO sur mco.ref.table_registry.*/


table_name,criticite,colonne_ingestion,seuil_fraicheur_h,seuil_volumetrie_pct,job_id)
silver.sales.orders,P1,ingestion_ts,24,25,1001
<catalog.schema.table>,P1,<colonne>,<heures>,<pct>,<JOB_ID>


---------------------------------------------------------------------***********************-----------------------------------------------------------------------------------------------
                                                  /*Etape 4: Chargement en masse MERGE

--Après l’atelier avec les owners, l’équipe dépose un fichier jobs_p1.csv dans un Volume (disponible dans Alim_mco_metier_job_registry.csv)
--Puis un MERGE met à jour les lignes existantes :*/


  
CREATE OR REPLACE TEMP VIEW src AS
SELECT * FROM read_files('/Volumes/<catalog>/<schema>/<volume>/tables_p1.csv',
                         format => 'csv', header => true);

MERGE INTO mco.ref.table_registry t
USING src s ON t.table_name = s.table_name
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;


-------------------------------------------------------------------********************************--------------------------------------------------------------------------------------
                            /*Etape 5: Contrôle la cohérence entre le référentiel MCO (mco.ref.table_registry) et la réalité de la plateforme Unity Catalog

Ce contrôle permet d'éviter des contrôles cassés (table introuvable) ou des angles morts de surveillance (table critique non couverte).
La table referentielle mco doit refléter exactement le contenu de unity catalog(les nom des tables dans mco.ref.table_registry doivent etre identiques aux nom des tables 
dans system.information_schema.tables et system.access.table_lineage

2 Contrôles sont necessaires:

- Contrôle 1: Les tables du referentiel qui n'existent pas (faute de frappe, table supprimée):

Ce contrôle sert à repérer les angles morts de surveillance — des tables effectivement écrites au cours des 30 derniers jours par un job classé P1, mais qui ne figurent pas encore 
dans mco.ref.table_registry (nouvelle table ajoutée à un job P1 existant, oubli dans tables_p1.csv, ou écriture secondaire non déclarée).
  
Détecte les entrées de mco.ref.table_registry qui ne correspondent à aucune table existante dans system.information_schema.tables (ex. faute de frappe dans tables_p1.csv, 
mauvais nom de catalogue/schéma, renommage ou suppression physique d'une table Delta, ou manque de privilège SELECT/BROWSE de l'utilisateur courant sur la table).

La première requete de contrôle doit afficher des lignes nulles pour le champ t.full_name

repère les angles morts de surveillance — des tables effectivement écrites au cours des 30 derniers jours par un job classé P1, mais qui ne figurent pas encore 
dans mco.ref.table_registry (nouvelle table ajoutée à un job P1 existant, oubli dans tables_p1.csv, ou écriture secondaire non déclarée).
 
Impact MCO si ignorée : les jobs de contrôle qualité, fraîcheur ou volumétrie qui interrogent la colonne r.table_name de la table mco.ref.table_registry risquent de planter 
en erreur (TABLE_OR_VIEW_NOT_FOUND) et de faire échouer le contrôle matinal de 7h30.
  
- Contrôle 2: Les tables écrites par des jobs P1 mais absentes du referentiel:

Ces deux requêtes ci-dessous doivent renvoyer zéro ligne.


-- Contrôle 1: Tables du referentiel qui n'existent pas (faute de frappe, table supprimée) 
             Une sortie avec des valeurs nulles pour t.full_name signifie soit il y'a erreur de saisi des données(en saisissant le table_name dans csv) sur fichier csv devant alimenter la table 
             de reference mco.ref.table_registry ou que la table a probablement été supprimée ou renommée dans Unity Catalog, ou l'utilisateur/service principal exécutant la requête n'a pas 
             les privilèges nécessaires(en gros le systeme databricks ne reconnait pas la ou les tables présentes dans notre reference mco.ref.table_registry.*/

SELECT r.table_name, t.full_name
FROM mco.ref.table_registry r
LEFT JOIN (SELECT concat_ws('.', table_catalog, table_schema, table_name) AS full_name
           FROM system.information_schema.tables) t ON r.table_name = t.full_name
WHERE t.full_name IS NULL;

/*-- Contrôle 2: Tables écrites par des jobs P1 mais absentes du referentiel
             (Si aucune ligne n'est retournée, cela signifie que toutes les tables écrites par des jobs P1 sur 30 jours et remontées par table_lineage sont déjà présentes dans mco.ref.table_registry.)
             si des noms de tables apparaissent dans la sortie alors des tables écrites par des jobs P1 au cours des 30 derniers jours ne figurent pas encore dans mco.ref.table_registry
             Il peut s'agir d'une table métier critique non encore déclarée dans mco.ref.table_registry → angle mort de surveillance fraîcheur/volumétrie à faire qualifier avec l'owner et ajouter à tables_p1.csv / au référentiel.*/

SELECT DISTINCT l.target_table_full_name
FROM system.access.table_lineage l
JOIN mco.ref.job_registry g ON l.entity_id = g.job_id
WHERE l.entity_type = 'JOB' AND g.criticite = 'P1'
  AND l.event_date >= current_date() - 30
  AND l.target_table_full_name NOT IN (SELECT table_name FROM mco.ref.table_registry);
