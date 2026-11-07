# MCO-Databricks

Data Engineer Principal et Lead MCO expert sur Azure Databricks (Unity Catalog, Workflows, System Tables, PySpark/Delta Lake). Je viens d'intégrer l'équipe en tant que Data Engineer MCO avec un quadruple rôle : exploitation/MCO, supervision, automatisation et accompagnement/transmission.


## Mission Globale :

Nous allons construire ensemble, étape par étape, le kit complet du MCO Databricks de l'entreprise (requêtes, dashboards, runbooks, scripts d'auto-réparation et programme de montée en compétence) en nous basant sur un environnement réel déjà en production.







## Étape 1 — Health Check Matinal & Triage d'Incidents Databricks
  
L'objectif est de construire un dispositif de contrôle quotidien à 07h30 permettant à l'équipe MCO de répondre rapidement à quatre questions :

- La plateforme Databricks est-elle opérationnelle ?

- Quels Workflows et quelles tâches ont échoué depuis le dernier contrôle ?

- Quels traitements présentent des signes de dégradation ?

- Quelles actions faut-il entreprendre pour rétablir le service ?

Je vais concevoir cette première brique comme un véritable outil d'exploitation de production, et non comme une simple collection de requêtes SQL.

### 1. Architecture cible du Health Check


<img width="1032" height="650" alt="image" src="https://github.com/user-attachments/assets/d65b7fb9-5aa1-4684-b440-a499ca59fba1" />

**Sources de données**
La source principale sera Unity Catalog System Tables :
<img width="860" height="238" alt="image" src="https://github.com/user-attachments/assets/276fd938-3608-4c2e-9104-06ed242ac39b" />

Attention : les System Tables sont soumises à des droits d'accès, à une rétention et à des délais de disponibilité. Les données ne constituent pas nécessairement une vision instantanée de la plateforme.

Nous allons notamment utiliser task_runs comme source principale, sans supposer que tous les champs existent dans toutes les versions de l'environnement.

### 2. Préparation de l'environnement

Avant le déploiement, vérifier les accès :
>

      SHOW SCHEMAS IN system;

      SHOW TABLES IN system.workflow;

      DESCRIBE TABLE system.workflow.task_runs;

      DESCRIBE TABLE system.workflow.job_runs;
>

Contrôler également les autorisations de lecture

>
        SELECT
             COUNT(*) AS total_task_runs
        FROM system.workflow.task_runs;
>

**Pré-requis :**

- Un SQL Warehouse ou un environnement SQL permettant l'interrogation des System Tables.

- Un service principal ou une identité technique avec les permissions de lecture nécessaires.

- Un Workflow Databricks pour exécuter le contrôle à 07h30.

- Une convention de fuseau horaire : Europe/Paris.

### 3. Livrable A — Requêtes SQL du Health Check

Nous allons créer trois niveaux de contrôle :

- Niveau 1 : détection des tâches en échec.

- Niveau 2 : analyse des performances et des durées.

- Niveau 3 : identification des incidents récurrents.

### A1. Détection des tâches en échec sur les dernières 24 heures

>
      WITH failed_tasks AS (
        SELECT
              workspace_id,
              job_id,
              run_id,
              task_key,
              result_state,
              period_start_time,
              period_end_time,
              termination_code,
              message,
              DATEDIFF(
                       SECOND,
                       period_start_time,
                       period_end_time
                      ) AS duration_seconds
      FROM system.workflow.task_runs
      WHERE period_start_time >= CURRENT_TIMESTAMP() - INTERVAL 24 HOURS
      AND result_state IN (
                           'FAILED',
                           'ERROR',
                           'TIMED_OUT',
                           'CANCELED'
                         )
             )

      SELECT
            workspace_id,
            job_id,
            run_id,
            task_key,
            result_state,
            termination_code,
            duration_seconds,
            period_start_time,
            period_end_time,
            message
    FROM failed_tasks
    ORDER BY period_start_time DESC;

>

**Interprétation MCO :**



> [!NOTE]
> ### 1. Architecture cible

<img width="791" height="631" alt="image" src="https://github.com/user-attachments/assets/7d68c84c-06d2-44ca-b7a0-56b67411d346" />

### Périmètre figé

- Période : du **26 septembre** au **25 octobre 2026 inclus**, soit 30 jours calendaires.

- 6 workspaces, 80 workloads, 20 SQL Warehouses, 3 600 exécutions, 240 000 requêtes et 500 tables attendus.

- Catalogue de reporting proposé : `finops_catalog`.

- Schéma dédié : `finops_baseline`.

- Mode d'exécution : lecture seule sur les sources système, écriture uniquement dans les tables de reporting autorisées.

Les valeurs financières et techniques seront calculées depuis les sources. Aucun chiffre illustratif ne sera inséré dans la baseline réelle.
  
Le principe est de séparer les données opérationnelles, les calculs FinOps et les restitutions. Les System Tables de facturation sont disponibles à l'échelle du compte, tandis que plusieurs sources d'observabilité, dont l'historique des requêtes et les timelines de jobs, ont un périmètre régional. Il faudra donc vérifier la couverture de chaque région.

### 2. Organisation des scripts SQL
Il faut versionner le projet dans Git et exécuter les scripts dans cet ordre. Chaque fichier a une responsabilité claire, ce qui facilite les revues de code et les validations financières.

Créez un dossier de projet avec cette structure :

<img width="774" height="679" alt="image" src="https://github.com/user-attachments/assets/00f513a4-1264-4b79-8f38-c4f8fc9241d3" />

ou

<img width="411" height="508" alt="image" src="https://github.com/user-attachments/assets/6a392770-388c-4fad-a2cb-7e4480ad1688" />

[Le SQL suivant est conçu pour Databricks SQL. Exécutez d'abord les scripts 00 à 02 dans un environnement de démonstration. Les scripts de production sont séparés et doivent être adaptés après vérification des schémas et des permissions.]


> [!NOTE]
> ## 3.Fichier 00_discovery.sql — découverte non destructive
Exécutez d'abord ces commandes avec une identité disposant des permissions nécessaires. Elles ne modifient pas les sources.

<aside>
  
**Goal**: Découverte des tables systèmes, vérification des couvertures temporelles sans les modifier.

- Créer le Catalog **`finops_catalog`** et le Schema **`finops_baseline`**
- ***DESCRIBE TABLE system.Catalog.Schema;:*** Pour confirmer qu'un schemas est disponible
- ***SHOW TABLES IN system.Catalog[`billing`, `query`, `lakeflow`]:*** Pour afficher les tables dans les catalogs sources importantes
- ***SELECT COUNT(*):*** Pour avoir le nombre de lignes des tables **`system.billing.usage`, `system.query.history`, `system.lakeflow.job_run_timeline`** sur une période de plus de 30 jours avant aujourd'hui

>

    -- 00_discovery.sql

    -- 1. Vérifier les schémas disponibles.
    DESCRIBE TABLE system.billing.usage;
    DESCRIBE TABLE system.billing.list_prices;
    DESCRIBE TABLE system.query.history;
    DESCRIBE TABLE system.lakeflow.job_run_timeline;
    DESCRIBE TABLE system.lakeflow.job_task_run_timeline;
    DESCRIBE TABLE system.compute.warehouses;
    DESCRIBE TABLE system.compute.warehouse_events;
    DESCRIBE TABLE system.access.table_lineage;
    DESCRIBE TABLE system.access.workspaces_latest;

    -- 2. Vérifier la couverture temporelle de la facturation.
    SELECT
        MIN(usage_date) AS first_usage_date,
        MAX(usage_date) AS last_usage_date,
        COUNT(*) AS billing_rows,
        COUNT(DISTINCT workspace_id) AS workspaces_observed
    FROM system.billing.usage
    WHERE usage_date BETWEEN DATE '2026-09-26'
                     AND DATE '2026-10-25';

    -- 3. Vérifier la couverture de l'historique SQL.
    SELECT
        MIN(start_time) AS first_query,
        MAX(start_time) AS last_query,
        COUNT(*) AS query_records,
        COUNT(DISTINCT statement_id) AS distinct_statements,
        COUNT(DISTINCT workspace_id) AS workspaces_observed
    FROM system.query.history
    WHERE start_time >= TIMESTAMP '2026-09-26 00:00:00'
    AND start_time <  TIMESTAMP '2026-10-26 00:00:00';

    -- 4. Vérifier la couverture des exécutions de jobs.
    SELECT
       MIN(period_start_time) AS first_observed_period,
       MAX(period_end_time) AS last_observed_period,
       COUNT(*) AS timeline_rows,
       COUNT(DISTINCT workspace_id) AS workspaces_observed,
       COUNT(DISTINCT job_id) AS distinct_jobs,
       COUNT(DISTINCT run_id) AS distinct_run_ids
     FROM system.lakeflow.job_run_timeline
     WHERE period_start_time < TIMESTAMP '2026-10-26 00:00:00'
     AND period_end_time >= TIMESTAMP '2026-09-26 00:00:00';
   
>

> [!IMPORTANT]
> Les tables système Databricks ont des couvertures différentes : par exemple, l'historique des requêtes est documenté avec une rétention de 365 jours, et les événements de warehouses ont une rétention de 365 jours. Le périmètre effectivement consultable doit donc être validé pour chaque source.
> 
> **DESCRIBE TABLE** peut échouer si une source n'est pas activée ou si l'identité n'a pas accès à celle-ci. Consignez cet échec comme un problème de couverture, puis poursuivez avec les sources accessibles.
>
> Si une requête échoue, documentez la source indisponible, le droit manquant ou la limite de périmètre. N'interprétez pas une table vide comme la preuve qu'aucune activité n'a eu lieu.
> 
> Pour les System Tables, vérifiez notamment les droits USE et SELECT, ainsi que les autorisations d'administration requises dans votre configuration.

> [!NOTE]
> ## 4. Fichier 01_inventory.sql — inventaire initial

 ### 4.1 Workspaces
 
Il faut lister les workspaces enregistrés dans le système Databricks. L'objectif ici est de comparer le nombre de workspace trouvé avec les métadonnées de compte et le périmètre réel des six workspaces. Voir si on a bien 6 workspaces comme prédéfini dans le périmètre figé.

>


     SELECT
        workspace_id,
        COUNT(*) AS metadata_versions
     FROM system.access.workspaces_latest
     GROUP BY workspace_id
     ORDER BY workspace_id;
>

### Analyse de la requête

Cette requête SQL permet d'analyser et de compter le nombre d'entrées ou de versions de métadonnées associées à chaque espace de travail (workspace) dans l'environnement Databricks.
- **FROM system.access.workspaces_latest :** Interroge la table système de l'account Databricks qui répertorie les espaces de travail actifs (la vue "latest" des métadonnées des workspaces).
- **`SELECT workspace_id, COUNT(*) AS metadata_versions`** : Sélectionne l'identifiant unique de chaque workspace (workspace_id) et compte le nombre de lignes correspondantes
- **(COUNT(*))**, renommé ici en metadata_versions.
- **GROUP BY workspace_id :** Regroupe les données par identifiant de workspace pour effectuer le calcul d'agrégation.ORDER BY workspace_id : Trie les résultats par ordre croissant des identifiants pour une lecture structurée.

Dans la table `workspaces_latest`, chaque espace de travail actif possède généralement une unique ligne de métadonnées à jour (soit un account de 1 par workspace).

Voici à quoi ressemblent les résultats de cette requête dans un environnement de production Databricks :

<img width="763" height="337" alt="image" src="https://github.com/user-attachments/assets/b48315a2-991a-4fec-8dda-38c53ef3d47d" />

### 4.2 SQL Warehouses

>

       WITH warehouse_latest AS (
          SELECT
             workspace_id,
             warehouse_id,
             warehouse_name,
             warehouse_type,
             warehouse_size,
             min_clusters,
             max_clusters,
             auto_stop_minutes,
             tags,
             change_time,
             delete_time,
             ROW_NUMBER() OVER (
              PARTITION BY workspace_id, warehouse_id
              ORDER BY change_time DESC
           ) AS rn
         FROM system.compute.warehouses
         )
           SELECT *
           FROM warehouse_latest
           WHERE rn = 1
          ORDER BY workspace_id, warehouse_name;
         
>

### Analyse de la requête

Cette requête est parfaitement conçue pour extraire l'état actuel ou la dernière configuration connue de chaque SQL Warehouse au sein d'un environnement multi-workspace.

 **La CTE ('WITH warehouse_latest AS (...)`) :**

- **`PARTITION BY workspace_id, warehouse_id`** : Regroupe l'historique par entrepôt individuel au sein de chaque workspace. C'est indispensable car deux workspaces différents pourraient théoriquement réutiliser des identifiants similaires.

- **`ORDER BY change_time DESC`** : Trie les modifications de la plus récente (DESC) à la plus ancienne pour chaque entrepôt.

- **`ROW_NUMBER() OVER (...) AS rn`** : Attribue un numéro de ligne séquentiel à chaque version de l'entrepôt, en commençant par 1 pour la ligne la plus récente.

**La requête principale** (**`SELECT * FROM warehouse_latest WHERE rn = 1`**) :

- Elle filtre les résultats pour ne garder que la ligne où le numéro de séquence est égal à 1. Cela élimine toutes les anciennes configurations historiques.

- Le tri final **`ORDER BY workspace_id, warehouse_name`** permet d'obtenir un affichage propre, ordonné par workspace et par nom de SQL warehouse .
  
Le résultat décrit la configuration la plus récente, pas nécessairement la configuration qui était active pendant toute la période de référence. Pour analyser les changements historiques, conservez toutes les versions et leurs dates.

Voici un aperçu des résultats renvoyés par la requête, illustrant l'état actuel des entrepôts SQL (avec rn = 1) et une description des colonnes:

<img width="1836" height="312" alt="image" src="https://github.com/user-attachments/assets/f7b1e231-13c3-4a3a-90b5-d23bdaa022f4" />


Le tableau ci-dessous détaille la structure et le type des colonnes retournées par cette requête :


<img width="1216" height="394" alt="image" src="https://github.com/user-attachments/assets/252dbfa1-d092-4246-aa61-dd0bf66e95bd" />

> [!IMPORTANT]
> 
>  Si un Warehouse a été supprimé, sa dernière ligne contiendra une valeur dans `delete_time`. Pour exclure les entrepôts supprimés de vos listes, il vous suffirait d'ajouter `AND delete_time IS NULL` dans la clause `WHERE` finale.

### 4.3 Jobs et workloads

Aperçu de la system.lakeflow.job_run_timeline:

<img width="1654" height="397" alt="image" src="https://github.com/user-attachments/assets/949bb1db-4929-4fc3-be90-2d934afbf3d2" />

Cette illustration montre concrètement le fonctionnement par fenêtrage (slicing horaire) où seule la dernière ligne d'un run_id enregistre le result_state final (les périodes intermédiaires restant à NULL).
>

       SELECT
       workspace_id,
       job_id,
       COUNT(DISTINCT run_id) AS observed_runs,
       MIN(period_start_time) AS first_observed_start,
       MAX(period_end_time) AS last_observed_end
       FROM system.lakeflow.job_run_timeline
       WHERE period_start_time < TIMESTAMP '2026-10-26 00:00:00'
       AND period_end_time >= TIMESTAMP '2026-09-26 00:00:00'
       GROUP BY workspace_id, job_id
       ORDER BY workspace_id, job_id;
   
         
>

### Analyse de la requête

Cette requête SQL permet d'analyser l'activité et la fréquence d'exécution des Jobs Databricks (via la table système system.lakeflow.job_run_timeline) sur une période d'un mois précis (du 26 septembre 2026 au 26 octobre 2026).


**`SELECT workspace_id, job_id`** : Regroupe les données par espace de travail (workspace) et par identifiant de tâche (job_id).

**`COUNT(DISTINCT run_id) AS observed_runs`** : Calcule le nombre total d'exécutions uniques (runs) de chaque job sur la période visée.

**`MIN(period_start_time)`** : Détermine le moment de la toute première exécution ou période observée pour le job dans la fenêtre de temps.

**`MAX(period_end_time)`** : Identifie la fin de la dernière exécution observée pour ce même job.

**`FROM system.lakeflow.job_run_timeline`** : Utilise la table système Lakeflow dédiée au suivi temporel des exécutions de jobs.

**`WHERE ...`** : Filtre les données pour ne retenir que les segments dont la période se situe entre le 26 septembre 2026 (inclus) et le 26 octobre 2026 (exclu).

**`GROUP BY ... ORDER BY ...`** : Structure l'agrégation par workspace et par job, puis trie les résultats par ordre croissant pour une lecture claire.

Cette requête identifie les jobs observés à partir de leurs exécutions. Pour inventorier les 80 workloads, y compris ceux sans exécution durant la période, complétez-la par les métadonnées des jobs, pipelines et autres workloads de votre organisation.
Voici un aperçu des résultats renvoyés par cette requête dans un environnement Databricks de production :

<img width="1172" height="397" alt="image" src="https://github.com/user-attachments/assets/b8b20b76-e2a7-4654-b6fa-06ef6f3b0e0f" />


Le tableau ci-dessous détaille la structure et le type des colonnes retournées par cette requête :

<img width="1412" height="220" alt="image" src="https://github.com/user-attachments/assets/c26cd814-2617-41d7-8244-41b9e7fbc28b" />

### 4.4 Tables Unity Catalog

>

        SELECT
              table_catalog,
              table_schema,
              table_name,
              table_type
       FROM system.information_schema.tables
       WHERE table_schema <> 'information_schema'
       ORDER BY table_catalog, table_schema, table_name;

>

### Analyse de la requête

Cette requête permet d'explorer et d'auditer l'ensemble des tables et vues disponibles dans l'ensemble des catalogues de votre métastore Unity Catalog sous Databricks.

**`FROM system.information_schema.tables`** : Interroge la vue système standard tables de l'information schema, qui centralise les métadonnées de toutes les tables et vues de tous les catalogues accessibles.

**`SELECT table_catalog, table_schema, table_name, table_type`** : Récupère quatre informations clés :

**`table_catalog`** : Le nom du catalogue (ex: main, finance).

**`table_schema`** : Le nom du schéma (ou base de données, ex: default, sales).

**`table_name`** : Le nom de la table ou de la vue.

**`table_type`** : Le type d'objet (généralement BASE TABLE pour une table physique ou VIEW pour une vue).

**`WHERE table_schema <> 'information_schema'`** : Exclut les schémas internes information_schema pour ne garder que les données métier utiles.

**`ORDER BY table_catalog, table_schema, table_name`** : Trie les résultats par ordre alphabétique pour faciliter la lecture et la navigation dans la gouvernance des données.

Adaptez le périmètre aux catalogues accessibles et vérifiez si cette vue système est disponible dans votre environnement. Le résultat doit ensuite être rapproché des 500 tables attendues, sans assimiler les vues et les tables physiques.

Voici un aperçu du résultat renvoyé par cette requête dans un environnement Unity Catalog :

<img width="628" height="176" alt="image" src="https://github.com/user-attachments/assets/b5b11cd4-64da-4e53-94e7-1a2182ef23c5" />


> [!NOTE]
> ## 5. Fichier 02_billing_baseline.sql — DBU et coûts

Le calcul du cout catalogue s'appuie sur deux tables système principales situées dans le schéma **`system.billing`** :

**`system.billing.usage`** : Contient l'historique de la consommation en unités de facturation (DBUs - Databricks Units) pour chaque workspace, SKU, et période (usage_start_time).

**`system.billing.list_prices`** : Contient les prix publics par DBU en fonction du type de SKU, du cloud (AWS, Azure, GCP) et de la période de validité du tarif (price_start_time et price_end_time).

### Formule mathématique : List Cost =  usage_quantity (DBUs) X default_price

### Gestion des cas particuliers :

- **Prix disponible :** Jointure standard par correspondance de SKU, de Cloud et de validité temporelle du prix.
- **Prix non disponible (Manquant) :** Utilisation d'une jointure externe (LEFT JOIN) et d'un COALESCE pour éviter de perdre les lignes de consommation (le coût est évalué à 0 ou identifié comme manquant).
- **Prix en doublon :** Résolution des chevauchements de périodes ou des entrées multiples via une fonction de fenêtrage (ROW_NUMBER()) pour ne retenir que le tarif valide le plus récent ou unique.

  
Il faut que:
- Pas de doublons pour les prix
- Les valeurs des colonnes cloud soient identiques
- SKU_name(ressource name) correspondent dans les 2 tables
- La date de facturation (u.usage_end_time) dans la table usage doit etre sur la période de validité du tarif (price_start_time et price_end_time).Elle doit etre comparé au colonnes de la table price price_start_time et price_end_time:
- u.usage_end_time doit etre postérieur ou égale à la date de démarrage de la validité du tarif(p.price_start_time)
- En ce qui concerne la colonne p.price_end_time elle doit soit etre null(IS NULL)pas renseigné ou supérieur à la date u.usage_end_time.

p.price_start_time <= u.usage_end_time < p.price_end_time(ou p.price_end_time ISNULL)
- 
  **i.e:** Si dans la table de price nous avons un intervalle de tarif pour les DBUS valable entre le 01/04/2026(debut) et le 01/07/2026(fin peut etre ISNULL pour tarif courant) alors un DBUs ayant été facturé avec une u.usage_end_time égal au 01/03/2026 ne peut donc etre concerné par cette grille tarifaire.
  Dans le cas où u.usage_end_time serait égal au 01/04/2026 ou 01/05/2026 ou 01/06/2026 ou que p.price_end_time IS NULL(pas renseigné) alors le DBUs sera matché pour avoir le bon prix.

### Points de contrôle :

- Les enregistrements sans prix doivent être expliqués.

- Les correspondances multiples doivent être résolues avant de valider le total.

- Les corrections de facturation doivent suivre la règle de réconciliation documentée pour votre compte.

- Le prix catalogue en USD n'est pas nécessairement le prix facturé : remises, contrats, crédits et devise de facturation peuvent modifier le montant final.

Pour une baseline officielle en euros, utilisez la devise réelle de facturation ou une table de taux de change approuvée par la Finance, datée et versionnée.
la requête doit gérer les prix disponibles, les prix manquants (NULL) et la déduplication des prix dans un environnement Databricks de production.Ci-dessous 2 requetes d'exemples:

### Requêtes 1:

>
            CREATE OR REPLACE TABLE finops_catalog.finops_baseline.fct_billing_usage
            USING DELTA
        AS
        WITH clean_prices AS (
          -- On récupère un prix unique par SKU, Cloud et période effective sans chevauchement
        SELECT
             sku_name,
             cloud,
             price_start_time,
             price_end_time,
             default_price
        FROM system.billing.list_prices
             QUALIFY ROW_NUMBER() OVER (
             PARTITION BY sku_name, cloud, price_start_time 
             ORDER BY price_end_time DESC NULLS LAST
             ) = 1
             ),
             usage_with_cost AS (
         SELECT
               u.usage_date,
               u.workspace_id,
               u.sku_name,
               u.cloud,
               u.usage_quantity,
               p.default_price,
               COALESCE(p.default_price, 0.0) AS effective_price,
               CASE
               WHEN p.default_price IS NULL THEN 'Prix non disponible (Manquant)'
               ELSE 'Prix disponible'
               END AS price_status,
               (u.usage_quantity * COALESCE(p.default_price, 0.0)) AS list_cost
        FROM system.billing.usage u
        LEFT JOIN clean_prices p
        ON u.sku_name = p.sku_name
        AND u.cloud = p.cloud
        AND u.usage_start_time >= p.price_start_time
        AND (u.usage_start_time < p.price_end_time OR p.price_end_time IS NULL)
            )
       SELECT
            usage_date,
            workspace_id,
            sku_name,
            cloud,
            usage_quantity,
            default_price,
            price_status,
            ROUND(list_cost, 4) AS list_cost
      FROM usage_with_cost
      WHERE usage_date BETWEEN DATE '2026-09-26' AND DATE '2026-10-25'
      ORDER BY usage_date DESC;
>

### Explication de la requete 02_billing_baseline.sql — DBU et coûts

**`CTE deduplicated_prices (Étape 1 : Nettoyage des prix)`**`

- Interroge la table des tarifs **`system.billing.list_prices`**.

- Utilise une fonction de fenêtrage (ROW_NUMBER()) partitionnée par sku_name, cloud et price_start_time, triée par price_end_time DESC. Cela permet d'isoler une ligne unique en cas de versions multiples ou de chevauchements pour un même début de tarification.

**`CTE clean_prices (Étape 2 : Isolation des tarifs propres)`**

Filtre la CTE précédente pour ne conserver que la ligne prioritaire (rn = 1), créant ainsi une table de référence tarifaire propre et sans doublon.

**`CTE usage_with_count / usage_with_cost (Étape 3 : Jointure temporelle et calcul)`**

- Joint la table d'utilisation brute system.billing.usage (u) avec la grille tarifaire propre (p).

- Condition de jointure temporelle : Vérifie que l'heure de consommation (usage_start_time) se situe bien dans la fenêtre de validité du prix (price_start_time et price_end_time).

- Gestion des prix manquants : Utilise `COALESCE(p.default_price, 0.0)` pour éviter qu'un `NULL` ne bloque ou n'annule l'ensemble du calcul, et qualifie le statut via un CASE WHEN.

- Calcul du coût : Multiplie la quantité d'utilisation (usage_quantity) par le prix effectif.

**`Requête Finale (Étape 4 : Filtrage de la Baseline)`**

- Restreint les données à une période d'analyse précise (du 26 septembre 2026 au 25 octobre 2026, souvent utilisée pour correspondre aux cycles de facturation mensuels).

- Arrondit les coûts à 4 décimales et trie les résultats par date décroissante.

Voici l'aperçu des résultats renvoyés par la requête, illustrant les trois scénarios (prix disponible, prix manquant et doublon de prix résolu)

<img width="1593" height="183" alt="image" src="https://github.com/user-attachments/assets/f7a17b6b-0317-4d0d-afe1-4a3ef4f1c353" />


### Requêtes 2 & 3: Peuvent être une alternative si on veut afficher plus de champs
     
>
         -- Requêtes 2
         -- 02_billing_baseline.sql
         -- Une ligne par enregistrement source de facturation.
         -- Ne pas joindre cette table directement aux runs ou aux requêtes.

      CREATE OR REPLACE TABLE
           finops_catalog.finops_baseline.fct_billing_usage
           USING DELTA
           AS
           WITH source_usage AS (
                SELECT
                      record_id,
                      workspace_id,
                      sku_name,
                      cloud,
                      usage_unit,
                      usage_quantity,
                      usage_date,
                      usage_start_time,
                      usage_end_time,
                      record_type,
                      billing_origin_product,
                      usage_type,
                      usage_metadata,
                      custom_tags
               FROM system.billing.usage
               WHERE usage_date BETWEEN DATE '2026-09-26'
                         AND DATE '2026-10-25'
                 ),
                   price_match AS (
             SELECT
                   u.*,
                   p.pricing.effective_list.default AS unit_list_price,
                   COUNT(p.sku_name) OVER (
                   PARTITION BY u.record_id
                  ) AS price_match_count
             FROM source_usage u
             LEFT JOIN system.billing.list_prices p
             ON p.cloud = u.cloud
             AND p.sku_name = u.sku_name
             AND u.usage_end_time >= p.price_start_time
             AND (
                  p.price_end_time IS NULL
              OR u.usage_end_time < p.price_end_time
                )
              )
              SELECT
                    record_id,
                    workspace_id,
                    sku_name,
                    cloud,
                    usage_unit,
                    usage_quantity,
                    usage_date,
                    usage_start_time,
                    usage_end_time,
                    record_type,
                    billing_origin_product,
                    usage_type,
                    usage_metadata,
                    custom_tags,
                    unit_list_price,
                    price_match_count,
               CASE
               WHEN price_match_count = 1
                  AND unit_list_price IS NOT NULL
               THEN usage_quantity * unit_list_price
               ELSE NULL
               END AS estimated_list_cost,
               CASE
             WHEN price_match_count = 1
             AND unit_list_price IS NOT NULL
             THEN 'MATCHED'
             WHEN price_match_count = 0
             THEN 'NO_PRICE_MATCH'
            ELSE 'AMBIGUOUS_PRICE_MATCH'
            END AS pricing_status
      FROM price_match; 
>

 ### KPI financiers
 
>
      -- Requêtes 3: Cette requête sera créer comme une View
     SELECT
     usage_date,
     workspace_id,
     cloud,
     sku_name,
     SUM(usage_quantity) AS total_usage_quantity,
     COUNT(*) AS billing_record_count,
     SUM(
        CASE WHEN pricing_status = 'MATCHED'
             THEN estimated_list_cost
             ELSE 0
        END
    ) AS matched_list_cost,
    SUM(
        CASE WHEN pricing_status <> 'MATCHED'
             THEN 1 ELSE 0
        END
     ) AS unmatched_or_ambiguous_records
     FROM finops_catalog.finops_baseline.fct_billing_usage
     GROUP BY
     usage_date,
     workspace_id,
     cloud,
     sku_name
     ORDER BY
     usage_date,
     workspace_id,
     sku_name;

>

Voici un aperçu tabulaire des résultats renvoyés par cette requête:


<img width="1753" height="153" alt="image" src="https://github.com/user-attachments/assets/9cd05652-13bb-414b-b360-5339538a2d88" />


> [!NOTE]
> 
> Cette version est volontairement prudente :
>
> Le cout catalogue ne s'obtient directement dans la table de facturation `system.billing.usage` car ne contenant que les quantités sku consommées; il faut aussi les informations sur les tarifs(prix) notamment les les prix correspondants disponibles dans la table `system.billing.list_prices`.
> 
> Le schéma de prix et la disponibilité des champs doivent être vérifiés dans votre environnement avant exécution. Si le prix change au cours de l'intervalle de consommation, le rattachement temporel doit être affiné au niveau requis pour le reporting financier. Pour les lignes corrigées ou réémises, contrôlez également record_type et les éventuels enregistrements de retraitement afin de ne pas compter deux fois la consommation.

**Règle de reporting :** nommez cet indicateur `matched_list_cost`, et non `actual_invoice_cost`. Le coût réellement facturé nécessite les données contractuelles, remises, crédits et autres ajustements pertinents. Si les prix sont exprimés dans plusieurs devises, n'additionnez pas les montants avant d'avoir appliqué une règle de conversion documentée.

### 6. Fichier 03_job_baseline.sql — performance des jobs

Le calcul des métriques mesurant la perfances des jobs se basent sur la table system.lakeflow.job_run_timeline.
Dans l'architecture de gouvernance Unity Catalog, les tables système de Databricks fournissent des métadonnées opérationnelles centralisées à l'échelle du compte ou du workspace.
La table system.lakeflow.job_run_timeline (située dans le catalogue system, schéma lakeflow) est essentielle pour auditer et analyser l'historique des exécutions de jobs (Databricks Jobs).   

Un aperçu de la table system.lakeflow.job_run_timeline:

<img width="1654" height="401" alt="image" src="https://github.com/user-attachments/assets/c1af16d8-e5c4-41cc-aa06-fbc74067703d" />


### Points clés à retenir sur la table `system.lakeflow.job_run_timeline`:

**Granularité temporelle et "Slicing"** : Chaque ligne de la table représente une période de temps pour une exécution de job donnée. Pour les jobs de longue durée (de plus d'une heure), Databricks découpe l'exécution en tranches horaires. Par conséquent, un même run_id peut apparaître sur plusieurs lignes.   

**États et Terminaisons** : Des colonnes comme result_state (SUCCEEDED, FAILED, CANCELED, etc.) indiquent l'issue de l'exécution (souvent renseignée sur la dernière ligne de la tranche pour les jobs longs).


>
-- L'objectif est d'avoir une ligne unique par run_id

                CREATE OR REPLACE TABLE
                     finops_catalog.finops_baseline.fct_job_run
                USING DELTA
                AS
                WITH timeline AS (
                          SELECT
                                workspace_id,
                                job_id,
                                run_id,
                                period_start_time,
                                period_end_time,
                                result_state
                         FROM system.lakeflow.job_run_timeline
                         WHERE period_start_time < TIMESTAMP '2026-10-26 00:00:00'
                             AND period_end_time >= TIMESTAMP '2026-09-26 00:00:00'
                         ),
                         
                     -- Etape 1: Agrégation des tranches temporelles
                     
                       runs AS (
                        SELECT
                              workspace_id,
                              job_id,
                              run_id,
                              MIN(period_start_time) AS run_start_time, -- Retrouver la vraie date de début(pour job longs)
                              MAX(period_end_time) AS run_end_time,    -- Retrouver la vraie date de fin( pour job longs)
                            -- Somme total du temps d'activité réel cumulé par tranche(Le temps cumulé pendant lequel le job a réellement été enregistré comme actif sur la période)
                              SUM(
                              GREATEST(
                              0,
                             UNIX_TIMESTAMP(period_end_time)
                           - UNIX_TIMESTAMP(period_start_time)
                             )
                             ) AS summed_active_seconds,
                          -- Récupèration de la valeur de result_state sur la tranche terminale (puisque les lignes précédentes sont à NULL)
                            MAX_BY(result_state, period_end_time) AS final_result_state
                        FROM timeline
                        GROUP BY workspace_id, job_id, run_id
                          )
                   -- Etape 2: Standardisation & Durée globale
                       SELECT
                             *,
                    -- La durée totale écoulée en seconde (Si un job prend 2 heures à s'exécuter du début à la fin, l'écart sera de 2 heures, que le cluster ait travaillé en continu ou                         qu'il y ait eu des temps d'attente / pauses au milieu.)
                       GREATEST(
                                0,
                       UNIX_TIMESTAMP(run_end_time)
                     - UNIX_TIMESTAMP(run_start_time)
                     ) AS elapsed_seconds,
                    -- Normalisation des status
                     CASE
                     WHEN final_result_state = 'SUCCEEDED' THEN 'SUCCESS'
                     WHEN final_result_state IN ('FAILED', 'ERROR') THEN 'FAILURE'
                     WHEN final_result_state = 'CANCELLED' THEN 'CANCELLED'
                     WHEN final_result_state = 'TIMED_OUT' THEN 'TIMEOUT'
                     WHEN final_result_state IN ('SKIPPED', 'BLOCKED') THEN 'NOT_EXECUTED'
                     ELSE 'UNKNOWN'
                     END AS normalized_status
                     FROM runs;

>
### Analyse de la requête

Requête SQL pour analyser les performances des jobs:

Puisque les jobs longs génèrent plusieurs lignes en raison du découpage horaire (slicing), la bonne pratique d'expert consiste à utiliser une CTE (Common Table Expression) pour consolider d'abord chaque exécution unique (run_id), avant de calculer les agrégats de performance globaux par job. Voici une requête optimisée sur les 30 derniers jours :

Cette reconstruction est un point de départ : les runs qui chevauchent les bornes doivent être traités selon une règle explicite. Les lignes à durée nulle peuvent représenter des runs qui n'ont jamais commencé. Pour la durée totale des exécutions, distinguez le temps écoulé du cumul des périodes actives. **`Le temps écoulé`** répond à la question "Combien de temps l'utilisateur a-t-il dû attendre avant que le job ne se termine ?", tandis que le **`cumul des périodes actives`** sert plutôt à analyser la volumétrie réelle de traitement et à affiner le calcul des coûts (FinOps).

Voici un aperçu tabulaire des résultats renvoyés par cette requête:

<img width="1793" height="408" alt="image" src="https://github.com/user-attachments/assets/5d1f30f8-6d7d-4974-9afe-b182d05d6a68" />

Le tableau ci-dessous détaille la structure et le type des colonnes retournées par cette requête :

<img width="1737" height="329" alt="image" src="https://github.com/user-attachments/assets/7906e27d-cef3-4670-9176-677e7ff568b1" />


### 6.1 KPI de performance

>
    -- L'objectif est d'avoir les KPI de performance

               SELECT
                    workspace_id,
                    COUNT(*) AS run_count,
                    SUM(CASE WHEN normalized_status = 'SUCCESS'
                    THEN 1 ELSE 0 END) AS success_count,
                    SUM(CASE WHEN normalized_status = 'FAILURE'
                    THEN 1 ELSE 0 END) AS failure_count,
                    SUM(CASE WHEN normalized_status = 'UNKNOWN'
                    THEN 1 ELSE 0 END) AS unknown_count,
                    ROUND(
                          100.0 * SUM(
                                      CASE WHEN normalized_status = 'SUCCESS'
                    THEN 1 ELSE 0 END
                    ) / NULLIF(
                    SUM(
                                     CASE WHEN normalized_status <> 'UNKNOWN'
                     THEN 1 ELSE 0 END
                    ), 0
                    ),
                    2
                    ) AS success_rate_pct,
                    ROUND(AVG(elapsed_seconds), 2) AS avg_elapsed_seconds,
                    percentile_approx(elapsed_seconds, 0.50, 10000) AS p50_seconds,
                    percentile_approx(elapsed_seconds, 0.90, 10000) AS p90_seconds,
                    percentile_approx(elapsed_seconds, 0.95, 10000) AS p95_seconds
              FROM finops_catalog.finops_baseline.fct_job_run
              GROUP BY workspace_id
              ORDER BY run_count DESC;
>

### Analyse de la requête pour KPI Performance

Cette requête permet de mesurer la performance opérationnelle et temporelle des jobs par espace de travail (workspace_id) à partir de la table de faits **`finops_catalog.finops_baseline.fct_job_run`**.

Voici le détail des indicateurs (KPI) calculés :

- **Volume d'exécutions** : Comptage global des runs (run_count) et ventilation par statut (success_count, failure_count, unknown_count).

- **Taux de succès (success_rate_pct)** : Pourcentage de réussite calculé en excluant les statuts UNKNOWN du dénominateur (grâce à NULLIF pour éviter une division par zéro) et arrondi à 2 décimales.

- **Performance temporelle**:

La moyenne de la durée d'exécution (avg_elapsed_seconds).

Les percentiles `p50_seconds (médiane)`, `p90_seconds` et `p95_seconds` via percentile_approx, permettant d'identifier les valeurs aberrantes (pics de lenteur) sans être influencé par des extrêmes isolés.

Voici un aperçu tabulaire des résultats renvoyés par cette requête:

<img width="1862" height="404" alt="image" src="https://github.com/user-attachments/assets/a25ceb97-828c-49ca-af1e-6a997ae47de0" />

Le tableau ci-dessous détaille la structure et le type des colonnes retournées par cette requête :

<img width="1315" height="369" alt="image" src="https://github.com/user-attachments/assets/f5f27820-654e-4454-9d9e-faec941fe62b" />



> [!NOTE]
>
> ### Rappel sur les Percentils:

> **Qu'est-ce qu'un percentile ?**

Un percentile est un indicateur qui coupe une série de données en deux parties selon un pourcentage donné.Imaginons que nous ayons collecté la durée de 100 exécutions d'un même job, classées de la plus rapide à la plus lente :

- La course la plus rapide prend 10 secondes.
- La course la plus lente prend 300 secondes (5 minutes).

**Explication des 3 percentiles de notre requête:**

**1. Le p50 (Médiane) : Le milieu exact**
   - Définition : 50 % des jobs s'exécutent en moins de ce temps, et 50 % prennent plus de temps.
   - Exemple : Si p50_seconds = 45 secondes, cela signifie que la moitié de vos runs ont duré moins de 45 secondes, et l'autre moitié a duré plus de 45 secondes. C’est souvent une valeur plus représentative de la "normalité" qu'une simple moyenne.

**3. Le p90 : La quasi-totalité des cas courants**
   - Définition : 90 % des jobs s'exécutent en dessous de cette valeur. Seuls les 10 % les plus lents dépassent ce seuil.
   - Exemple : Si p90_seconds = 120 secondes (2 minutes), cela signifie que 9 cas sur 10 se terminent en moins de 2 minutes. C'est un excellent indicateur pour fixer des seuils d'alerte ou des SLA (engagements de service).
     
**4. Le p95 : La zone des cas extrêmes**
   - Définition : 95 % des jobs s'exécutent en dessous de cette valeur. Seuls les 5 % des runs les plus extrêmes (les plus lents) la dépassent.
   - Exemple : Si p95_seconds = 240 secondes (4 minutes), cela signifie que seuls les 5 % de runs les plus chaotiques ou gourmands en ressources ont pris plus de 4 minutes.

Pourquoi utiliser les percentiles plutôt que la moyenne (AVG) ?

La moyenne est très sensible aux valeurs extrêmes (les outliers).
Exemple parlant :Imaginons un job qui tourne 
- 10 fois :9 fois, il met 10 secondes.
- 1 seule fois, à cause d'un pic de charge sur le serveur, il met 1 000 secondes.
- Moyenne : $(9 \times 10 + 1000) / 10 = \mathbf{109\text{ secondes}}$. (La moyenne est totalement faussée par un seul accident).
- p50 (Médiane) : 10 secondes (reflète parfaitement l'expérience habituelle).
- p90 : 10 secondes (montre que 90 % du temps, tout va bien).
Les percentiles (p50, p90, p95) permettent ainsi d'avoir une vision robuste et réaliste de la performance réelle de vos infrastructures, sans vous faire piéger par quelques bugs ou ralentissements isolés.
>
> **Prenons l'effectif professionnel du Paris Saint-Germain (PSG) pour illustrer les percentiles avec l'âge des joueurs.**

Pour cela, on imagine que l'on range tous les joueurs de l'équipe du plus jeune au plus âgé, en ligne sur le terrain.

**Le contexte**

Imaginons un groupe de 25 joueurs au PSG :

Le plus jeune est un espoir de 17 ans (ex. un jeune du centre de formation).

Le plus âgé est un gardien vétéran de 36 ans.

Visualisons les percentiles p50, p90 et p95 sur ce groupe rangé par âge :

**1. Le p50 (La Médiane) : Le joueur au milieu**

Ce que cela signifie : 50 % des joueurs ont moins que cet âge, et 50 % ont plus.

Exemple PSG : Si le p50 de l'équipe est 24 ans :

La moitié de l'effectif a 24 ans ou moins (les jeunes pépites), et l'autre moitié a 24 ans ou plus. C'est l'âge pivot du vestiaire.

**2. Le p90 : La fin du gros des troupes (exclut les doyens)**

Ce que cela signifie : 90 % des joueurs sont plus jeunes que cet âge. Seuls les 10 % les plus âgés dépassent ce seuil.

Exemple PSG : Si le p90 est 30 ans :

9 joueurs sur 10 dans l'équipe ont moins de 30 ans. Seul un petit groupe de "cadres très expérimentés" (les 10 % restants) a plus de 30 ans.

**3. Le p95 : Les véritables vétérans de l'équipe**

Ce que cela signifie : 95 % du vestiaire est plus jeune que cet âge. Seuls les 5 % des joueurs les plus âgés (les cas extrêmes) le dépassent.

Exemple PSG : Si le p95 est 34 ans :

95 % des joueurs ont moins de 34 ans. Seuls 1 ou 2 joueurs très âgés dans tout le club ont 34 ans ou plus.

Pourquoi la moyenne (AVG) pose problème ici aussi ?
Imaginez que le PSG décide de recruter un joueur de 45 ans juste pour le banc :

**La Moyenne (AVG) :** L'âge moyen de l'équipe va augmenter d'un coup (par exemple de 24 à 26 ans), laissant croire que toute l'équipe a vieilli.

Le p50 (Médiane) : L'âge médian ne bougera pratiquement pas (il restera à ~24-25 ans), car le cœur du vestiaire est toujours constitué de jeunes joueurs.

### 7. Fichier 04_query_baseline.sql — performance SQL

La table system.query.history expose notamment execution_status, compute.warehouse_id, execution_duration_ms, waiting_at_capacity_duration_ms, waiting_for_compute_duration_ms et total_duration_ms. Ces métriques permettent de distinguer le temps d'exécution de l'attente de ressources.

>
                  CREATE OR REPLACE TABLE
                      finops_catalog.finops_baseline.fct_query_metrics
                  USING DELTA
                  AS
                 SELECT
                         workspace_id,
                         statement_id,
                         start_time,
                         end_time,
                         execution_status,
                         compute.type AS compute_type,
                         compute.warehouse_id AS warehouse_id,
                         statement_type,
                         executed_by,
                         client_application,
                         total_duration_ms,
                         execution_duration_ms,
                         waiting_for_compute_duration_ms,
                         waiting_at_capacity_duration_ms,
                         compilation_duration_ms,
                         total_task_duration_ms,
                         read_bytes,
                         read_rows,
                         produced_rows,
                         spilled_local_bytes,
                         written_bytes,
                         from_result_cache
                FROM system.query.history
                WHERE start_time >= TIMESTAMP '2026-09-26 00:00:00'
                AND start_time <  TIMESTAMP '2026-10-26 00:00:00';
>

La requête copie les principales métriques sans copier le texte SQL, qui peut contenir des informations sensibles. Si une analyse des requêtes récurrentes est nécessaire, privilégiez une normalisation contrôlée du texte et des droits d'accès restreints.

### 7.1 KPI SQL

>
                SELECT
                      workspace_id,
                      warehouse_id,
                      COUNT(*) AS query_count,
                      COUNT(DISTINCT statement_id) AS distinct_statement_count,
                      SUM(CASE WHEN execution_status = 'FINISHED'
                      THEN 1 ELSE 0 END) AS successful_queries,
                      SUM(CASE WHEN execution_status = 'FAILED'
                      THEN 1 ELSE 0 END) AS failed_queries,
                      ROUND(
                      percentile_approx(
                      execution_duration_ms, 0.50, 10000
                      ) / 1000.0, 3
                      ) AS p50_execution_seconds,
                     ROUND(
                     percentile_approx(
                     execution_duration_ms, 0.95, 10000
                     ) / 1000.0, 3
                     ) AS p95_execution_seconds,
                     ROUND(
                     percentile_approx(
                     execution_duration_ms, 0.99, 10000
                     ) / 1000.0, 3
                     ) AS p99_execution_seconds,
                     ROUND(
                     AVG(waiting_at_capacity_duration_ms) / 1000.0, 3
                     ) AS avg_capacity_wait_seconds,
                    SUM(read_bytes) AS total_read_bytes,
                    SUM(spilled_local_bytes) AS total_spilled_bytes
             FROM finops_catalog.finops_baseline.fct_query_metrics
             GROUP BY workspace_id, warehouse_id
             ORDER BY query_count DESC;
>

Les percentiles sont calculés sur les valeurs non nulles disponibles. Pour une baseline de performance représentative, publiez également des percentiles limités aux requêtes terminées avec succès, tout en conservant les erreurs dans les KPI de fiabilité.

Les 240 000 requêtes doivent être vérifiées à partir des exécutions réellement observées : une requête répétée 1 000 fois représente 1 000 exécutions, même si son texte normalisé est identique.

### Analyse de la requête pour KPI SQL

Cette requête est conçue pour analyser l'activité, la fiabilité, la performance et l'efficacité des requêtes SQL exécutées sur une plateforme de type Databricks (en s'appuyant sur les tables de métriques de requêtes, souvent exploitées dans le cadre d'une démarche FinOps).

**Niveau d'analyse (Groupement) :** Les résultats sont agrégés par Workspace (workspace_id) et par Warehouse / Entrepôt de données (warehouse_id).

**Axes d'évaluation :**
- Volume et Activité (nombre total de requêtes, unicité des instructions).
- Fiabilité (taux de succès vs échecs).
- Performance / Latence (utilisation de percentiles $P_{50}$, $P_{95}$, $P_{99}$ pour éviter les biais de la moyenne, et temps d'attente en file d'attente de capacité).
- Consommation de ressources (données lues et volume de « spill » sur disque).

Voici un aperçu tabulaire des résultats renvoyés par cette requête:

<img width="1860" height="384" alt="image" src="https://github.com/user-attachments/assets/de7d17a2-3e59-4be2-a10a-c28c2d373ee5" />

Le tableau ci-dessous détaille la structure et le type des colonnes retournées par cette requête des KPIs SQL générés:

<img width="1837" height="527" alt="image" src="https://github.com/user-attachments/assets/69f04b12-c48e-4e7b-9637-e271c7d8c31a" />

💡 **Points clés à surveiller**

- **`Percentiles` vs `Moyennes`** : L'utilisation de percentile_approx est une excellente pratique pour la latence, car une simple moyenne serait faussée par quelques requêtes très longues.

- **Optimisation des coûts (FinOps) :** Un ratio élevé de total_spilled_bytes combiné à un avg_capacity_wait_seconds important indique généralement qu'il faut redimensionner (scaler) verticalement ou horizontalement le warehouse_id.

### 8. Fichier 05_table_inventory.sql — inventaire des 500 tables
L'inventaire doit exploiter les métadonnées existantes sans scanner inutilement les tables métier. Les événements de lineage Unity Catalog indiquent les lectures et écritures observées ; ils ne constituent pas un historique exhaustif de tous les accès possibles. 

### 8.1 Inventaire des tables et des propriétaires

 Cette requête sert de snapshot (photographie instantanée) de l'ensemble des tables et vues disponibles dans notre workspace Unity Catalog à un instant T.
 
>
       CREATE OR REPLACE TABLE
            finops_catalog.finops_baseline.fct_table_inventory
       USING DELTA
       AS
       SELECT
              CURRENT_TIMESTAMP() AS inventory_timestamp,
              table_catalog,
              table_schema,
              table_name,
              table_type
      FROM system.information_schema.tables
      WHERE table_schema <> 'information_schema';
>

**Analyse de la Requête SQL**
- La clause WHERE table_schema <> 'information_schema' permet de filtrer et d'exclure les métadonnées système internes pour ne garder que vos données métiers.

- Le stockage au format Delta garantit l'acidité, la performance et la possibilité d'interroger l'historique (Time Travel).

Voici à quoi ressemblerait le contenu de la table après l'exécution de votre requête :

<img width="968" height="397" alt="image" src="https://github.com/user-attachments/assets/db062faf-4f56-4ca1-9459-0c47f8657c63" />

La table finops_catalog.finops_baseline.fct_table_inventory est composée de 5 colonnes :

<img width="1609" height="206" alt="image" src="https://github.com/user-attachments/assets/0c05d758-b931-4d47-b211-a01f51d1d20b" />


### 8.2 Activité observée dans le lineage

Nous pouvons mesurer les évenements de lecture des tables sur une période de 30 jours.

>
          SELECT
                workspace_id,
                source_table_catalog,
                source_table_schema,
                source_table_name,
                COUNT(*) AS observed_read_events,
                MIN(event_time) AS first_observed_read,
                MAX(event_time) AS last_observed_read
         FROM system.access.table_lineage
         WHERE event_time >= TIMESTAMP '2026-09-26 00:00:00'
             AND event_time <  TIMESTAMP '2026-10-26 00:00:00'
             AND source_table_name IS NOT NULL
         GROUP BY
                  workspace_id,
                  source_table_catalog,
                  source_table_schema,
                  source_table_name
         ORDER BY observed_read_events DESC;
>

**Analyse de la Requête SQL**
Cette requête exploite les tables système Unity Catalog de Databricks, plus précisément `system.access.table_lineage`, qui enregistre les événements de traçabilité des données (lectures et écritures de tables en aval/amont).
Elle mesure les événements de lecture dont la table source est renseignée. Complétez-la par une extraction distincte des événements d'écriture et des destinations. Vérifiez les noms de colonnes réels avant exécution, car les structures source et cible diffèrent selon le type d'événement.

<img width="1487" height="433" alt="image" src="https://github.com/user-attachments/assets/861667aa-8071-4774-91ff-7843652aebf5" />

- **Objectif métier :** Identifier et quantifier l'utilisation des tables sources (source_table_name) au sein de l'organisation pour une période donnée, en mesurant leur popularité (nombre de lectures) ainsi que leur cycle de vie d'utilisation (premier et dernier accès).

- **Filtres appliqués :**
  
  - Une fenêtre temporelle d'un mois (du 26 septembre 2026 au 26 octobre 2026).

  - L'exclusion des lignes où le nom de la table source est nul (source_table_name IS NOT NULL).

- **Agrégations et Tri :** Les données sont groupées par workspace et par identifiant complet de la table (catalogue, schéma, nom), puis triées par ordre décroissant du nombre d'événements de lecture (observed_read_events).

💡 **Points clés à surveiller**
Ce type de requête est extrêmement utile dans le cadre d'un audit de gouvernance pour identifier les tables "orphelines" (qui ne sont jamais lues) ou pour optimiser les coûts de stockage en ciblant les actifs critiques de vos pipelines de données (architectures Medallion Bronze/Silver/Gold).

### 9. Fichier 06_quality_checks.sql — contrôles qualité
Ces contrôles doivent être exécutés avant de publier la baseline. Ils permettent d'identifier les écarts, et non de les masquer.

### 9.1 Contrôle des volumes attendus

Au départ du projet nous avions toutes les informations relatives à la plateforme Databricks(nombre de workspaces, SQL warehouses modifiés ou actifs sur la période filtrée, le volume des exécutions de jobs (Pipelines / Workflows), l'historique de toutes les requêtes SQL exécutées dans le cahier de charge; La comparaison des valeurs observées (récupérées en temps réel depuis les tables système) avec une valeur attendues (expected) est nécessaire.

>
                SELECT
                      'workspaces' AS metric,
                       COUNT(DISTINCT workspace_id) AS observed,
                       6 AS expected
                FROM system.access.workspaces_latest

               UNION ALL

               SELECT
                     'sql_warehouses',
                      COUNT(DISTINCT warehouse_id),
                      20
               FROM system.compute.warehouses
               WHERE change_time < TIMESTAMP '2026-10-26 00:00:00'
                    AND (delete_time IS NULL
                    OR delete_time >= TIMESTAMP '2026-09-26 00:00:00')

               UNION ALL

               SELECT
                      'job_runs',
                       COUNT(DISTINCT run_id),
                      3600
               FROM system.lakeflow.job_run_timeline
               WHERE period_start_time < TIMESTAMP '2026-10-26 00:00:00'
                    AND period_end_time >= TIMESTAMP '2026-09-26 00:00:00'

               UNION ALL

              SELECT
                    'query_executions',
                     COUNT(DISTINCT statement_id),
                     240000
             FROM system.query.history
             WHERE start_time >= TIMESTAMP '2026-09-26 00:00:00'
                  AND start_time < TIMESTAMP '2026-10-26 00:00:00';
                  
>

Ce contrôle est indicatif : les workloads et les tables nécessitent des sources d'inventaire complémentaires. De plus, la période de configuration des warehouses ne doit pas être confondue avec leur activité effective.

<img width="549" height="365" alt="image" src="https://github.com/user-attachments/assets/2f144688-f589-4ce4-b8f3-d5c8cd9a9e8b" />

💡 **Conseil d'expert Databricks**
Pour automatiser ce type de rapport dans un tableau de bord Lakeview ou l'envoyer sous forme d'alerte, vous pouvez stocker ce résultat dans une table Delta (CREATE TABLE health_metrics AS ...) ou l'intégrer directement dans une requête de surveillance programmée (Databricks SQL Alert) pour détecter les écarts importants entre observed et expected.

### 9.2 Contrôle des prix manquants ou ambigus

>
        SELECT
              pricing_status,
              COUNT(*) AS billing_records,
              SUM(usage_quantity) AS usage_quantity
        FROM finops_catalog.finops_baseline.fct_billing_usage
        GROUP BY pricing_status
        ORDER BY billing_records DESC;
>


<img width="1133" height="378" alt="image" src="https://github.com/user-attachments/assets/7cc431ed-3570-4ddf-8f29-8713fc188e6e" />

Cette requête interroge la table de faits d'usage et de facturation (fct_billing_usage) située dans le catalogue/schéma finops_catalog.finops_baseline. Son objectif est de donner un aperçu agrégé du nombre de lignes de facturation et du volume total consommé (DBUs, Heures Core, Go, etc.), regroupés par statut de tarification (pricing_status).

Le champ `pricing_status` dans Databricks / Cloud indique sous quel type de modèle tarifaire les ressources ont été consommées (ex: On-Demand, Committed / Savings Plan, Spot / Preemptible, Free Tier, Unpriced / Included, etc.).

Cette répartition met en lumière plusieurs enseignements clés pour le pilotage financier de votre plateforme Databricks :

**Maîtrise des engagements vs. Flexibilité :**

La majeure partie du volume **`TARIF_STANDARD_ON_DEMAND (ON_DEMAND)`** et **`ENGAGEMENT_COMMERCIAL`**) montre un équilibre sain entre l'utilisation flexible et la sécurisation de tarifs négociés.

L'utilisation significative des remises (REMISE_SPOT et INSTANCE_RESERVEE) prouve que les équipes techniques jouent le jeu de l'optimisation des coûts sur les workloads adaptés.

**Détection d'anomalies (Point de vigilance critique) :**

- **`SANS_PRIX_ATTRIBUE`(UNPRICED)`** (3 410 enregistrements) : Bien que la quantité affichée soit nulle (ce qui peut arriver sur des métadonnées de configuration ou des lignes de logs techniques pures), cela requiert une attention particulière. Si un volume de DBU y était rattaché, cela signifierait une consommation "fantôme" ou non valorisée dans les rapports de refacturation interne (showback/chargeback).

- **`DEPASSEMENT_FORFAIT` (OVERAGE)`** (850 enregistrements pour 1 420.80 d'unités) : C'est un signal d'alerte direct. Ces lignes indiquent que certains quotas ou seuils contractuels négociés ont été dépassés, entraînant potentiellement l'application de tarifs punitifs ou hors-contrat.
  
- Une part élevée de **`TARIF_STANDARD_ON_DEMAND (ON_DEMAND)`**  indique une opportunité d'achat d'engagements à terme (Commitment Discounts / Databricks Commit) pour réduire le coût unitaire.

- Un volume significatif en **`SPOT_DISCOUNTED`** montre une bonne adoption des instances Spot/Preemptible pour les workloads tolérants aux pannes (ex: jobs Batch ETL).
  
Critère recommandé : aucun coût ambigu ne doit être publié comme un montant validé. Les anomalies doivent être expliquées et la couverture des prix communiquée.

💡 **Piste d'action recommandée :**

Il est conseillé de créer une alerte automatique (via Databricks SQL Alerts ou un dashboard) dès que le nombre d'enregistrements ou le volume dans les catégories **`SANS_PRIX_ATTRIBUE (UNPRICED)`** ou **`DEPASSEMENT_FORFAIT (OVERAGE`)** dépasse un seuil critique défini avec l'équipe Achats/FinOps.

Version anglaise:

<img width="591" height="365" alt="image" src="https://github.com/user-attachments/assets/96b8cff4-f1fe-48af-b718-39ee6455ddf2" />



### 9.3 Contrôle des identifiants de requête

Normalement, un identifiant de requête (statement_id) doit être unique par espace de travail (workspace_id).

>
            SELECT
                    workspace_id,
                    statement_id,
                    COUNT(*) AS row_count
             FROM finops_catalog.finops_baseline.fct_query_metrics
             GROUP BY workspace_id, statement_id
             HAVING COUNT(*) > 1
             ORDER BY row_count DESC;
>

Cette requête joue un rôle crucial dans le contrôle de la qualité des données et la gouvernance FinOps au sein d'une architecture Databricks multi-workspace.

**Objectif principal :** Détecter la présence de doublons dans la table de métriques de requêtes (fct_query_metrics). Normalement, un identifiant de requête (statement_id) doit être unique par espace de travail (workspace_id).

Si des doublons apparaissent, examinez la source et la logique de transformation avant de les supprimer. Ne choisissez pas arbitrairement une ligne sans comprendre pourquoi plusieurs enregistrements existent.

<img width="783" height="431" alt="image" src="https://github.com/user-attachments/assets/cd026eab-2f17-4b43-a9e4-be3bfef7e044" />

Les doublons de requêtes dans une table de métriques FinOps (fct_query_metrics) ne sont pas seulement un problème cosmétique de qualité de données : ils ont des répercussions directes sur la fiabilité financière et technique de votre plateforme Databricks.

Voici une analyse détaillée des conséquences et le plan d'action pour y remédier.

> [!NOTE]
> ### 💡 Recommandation d'expert FinOps :

Si vous observez un row_count` élevé (comme 5 pour le premier statement_id), cela signifie que vos tableaux de bord de coûts ou vos rapports d'attribution des DBU (Databricks Units) calculent potentiellement des métriques gonflées (temps de calcul, volumes de données lus) pour ces requêtes. Je vous conseille d'ajouter une étape de déduplication (QUALIFY ROW_NUMBER() OVER (...) ou DROP DUPLICATES) dans votre pipeline d'ingestion vers fct_query_metrics.

> ### 🚨 1. Quelles sont les conséquences des doublons de requêtes ?

  > ### A. Conséquences FinOps et Financières**
> 
> 
- `Surévaluation des coûts (DBU) et du temps de calcul` : Si chaque doublon est sommé, vos tableaux de bord afficheront un temps cumulé d'exécution (total_execution_time) et une consommation de ressources virtuellement gonflés.

- `Attribution des coûts erronée` : Les rapports de refacturation interne (chargeback/showback) attribueront des coûts exagérés à certains départements ou projets, ce qui fausse les budgets.

 > ### B. Conséquences Analytiques et Métriques
KPIs faussés : Des métriques clés comme le nombre total de requêtes exécutées par jour, le taux d'échec des requêtes ou la durée moyenne d'une requête seront incorrectes.

Biais décisionnel : Vous risquez d'optimiser des requêtes ou des clusters en vous basant sur des volumes de données dupliqués, ce qui conduit à de mauvaises décisions d'architecture.

 > ### C. Conséquences Techniques
Gaspillage de stockage : Les tables de faits grossissent inutilement, impactant les performances de lecture et augmentant les coûts de stockage Delta Lake sur le long terme.
>
> ### 🛠️ 2. Quelles actions faire ? (Plan d'action en 4 étapes)
>
**Étape 1 :** Identifier la cause racine (Root Cause Analysis)

Avant de nettoyer, comprenez pourquoi ces doublons apparaissent dans votre pipeline d'ingestion :

- S'agit-il d'un job d'ingestion (ex: extraction depuis system.query.history) qui a été exécuté plusieurs fois sur la même plage horaire (rejeux de jobs ratés) ?

- Y a-t-il un problème de chevauchement de fenêtres temporelles dans votre pipeline incrémental ?

- Utilisez-vous un INSERT INTO simple au lieu d'une logique d'idempotence ?

**Étape 2** : Nettoyer l'existant (Remédiation)

Vous devez dédupliquer la table actuelle fct_query_metrics. Sur Databricks, la méthode la plus propre avec Delta Lake consiste à réécrire la table en conservant uniquement la version la plus pertinente de chaque enregistrement (ou la première/dernière occurrence) :

>
        -- Exemple de requête pour créer une version propre ou écraser la table
        CREATE OR REPLACE TABLE finops_catalog.finops_baseline.fct_query_metrics AS
        SELECT * FROM (
        SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY workspace_id, statement_id 
               -- Ajoutez un critère temporel si vous voulez garder la version la plus récente
               -- ORDER BY ingestion_timestamp DESC 
           ) as rn
       FROM finops_catalog.finops_baseline.fct_query_metrics
     )
     WHERE rn = 1;
     -- Pensez à nettoyer l'historique Delta si nécessaire (VACUUM)
>

**Étape 3** : Rendre le pipeline d'ingestion robuste (Idempotence)
Modifiez le script ou le notebook qui alimente fct_query_metrics. Bannissez les INSERT INTO bruts pour ce type de table de faits et remplacez-les par une instruction MERGE INTO (upsert) :
>
           MERGE INTO finops_catalog.finops_baseline.fct_query_metrics AS target
           USING source_new_metrics AS source
           ON target.workspace_id = source.workspace_id AND target.statement_id = source.statement_id
           WHEN NOT MATCHED THEN INSERT *
           -- Optionnel : WHEN MATCHED THEN UPDATE SET ...
>

Le MERGE garantit que même si un job est relancé par erreur sur la même période, un même statement_id ne sera inséré qu'une seule fois par workspace.

**Étape 4** : Mettre en place un contrôle qualité automatisé

- Tests d'assertions : Intégrez une requête de contrôle (similaire à celle que vous avez partagée) au sein de vos orchestrateurs (Databricks Workflows, Airflow, etc.) pour lever une alerte ou bloquer le pipeline si COUNT(*) > 1 est détecté après une ingestion.

- Databricks Lakehouse Monitoring : Configurez des moniteurs de qualité de données sur cette table pour suivre automatiquement l'unicité et l'intégrité de vos clés primaires (workspace_id + statement_id).

### 10. Fichier 07_snapshot.sql — geler la baseline

> [!NOTE]
> ### 💡 Le Gel de Baseline FinOps dans Databricks :
> 
Le Gel de Baseline FinOps dans Databricks
Dans une démarche FinOps au sein de Databricks, un gel de baseline (baseline freeze ou snapshot) consiste à figer à des dates clés (mensuelles, trimestrielles) les données de référence, les indicateurs de coûts et les métadonnées de consommation (DBU et infrastructure).

Cette table de snapshot sert de référence immuable et validée pour :

- L'analyse des écarts (variance analysis) entre le budget prévisionnel et les coûts réels.

- Les audits financiers et la refacturation interne (chargeback / showback).

- Le suivi de l'efficacité des optimisations réalisées au fil du temps.
  
Je recommande de séparer les résultats courants des résultats validés. Les tables de faits peuvent être recalculées dans un environnement de préparation ; les snapshots validés, eux, ne doivent jamais être remplacés par un simple CREATE OR REPLACE TABLE.

>

                    CREATE TABLE IF NOT EXISTS
                         finops_catalog.finops_baseline.baseline_snapshot (
                            snapshot_id STRING,
                            version STRING,
                            period_start DATE,
                            period_end DATE,
                            calculated_at TIMESTAMP,
                            timezone STRING,
                            source_coverage_status STRING,
                            quality_status STRING,
                            approval_status STRING,
                            calculation_version STRING,
                            notes STRING
                          )

                      USING DELTA;
 >


Le tableau ci-dessous détaille la structure et le type des colonnes retournées par cette requête :


<img width="1005" height="398" alt="image" src="https://github.com/user-attachments/assets/48c4cb8f-cb3f-4219-8a32-ad60e53f5c72" />


**Analyse de la Requête SQL**

La requête fournie initialise la structure de stockage sous Unity Catalog (finops_catalog.finops_baseline.baseline_snapshot) :

- **USING DELTA :** Garantit le format Delta Lake, offrant la fiabilité ACID, une haute performance de lecture/écriture, ainsi que le support du Time Travel pour auditer l'historique des modifications de la table.

- **Gouvernance Unity Catalog :** L'utilisation d'un catalogue et d'un schéma dédiés permet d'isoler les données financières sensibles et de restreindre l'accès aux seules équipes habilitées (Finance et FinOps).

### 10.2 Publier une version après validation

Exemple de structure pour l'enregistrement de la baseline. L'insertion ne doit être exécutée qu'après les contrôles de qualité et la validation du périmètre.

>
                INSERT INTO finops_catalog.finops_baseline.baseline_snapshot
                VALUES (
                       'baseline_20261026_v1',
                       '1.0',
                        DATE '2026-09-26',
                        DATE '2026-10-25',
                        CURRENT_TIMESTAMP(),
                       'UTC',
                       'VALIDATED',
                       'VALIDATED',
                       'PENDING_APPROVAL',
                       'sql_rules_v1',
                       'Baseline initiale avant optimisation'
                       );
>

Voici un aperçu tabulaire des résultats renvoyés par cette requête illustrant le snapshot gel FinOps couvrant la période de  '2026-09-26' et '2026-10-25' comme un état de référence des coûts et de l'usage sur une période donnée (souvent un mois de facturation) afin de mesurer l'impact des futures optimisations.

<img width="1861" height="137" alt="image" src="https://github.com/user-attachments/assets/e9ef2d7b-a56d-4e2b-95b8-9557d27bf82f" />

Les statuts ci-dessus sont des valeurs d'exemple à remplacer par les résultats réels des contrôles. Ne publiez pas une baseline comme validée si la couverture des sources ou le rapprochement financier reste incomplet.

Pour les KPI, conservez également une table de détails avec au minimum snapshot_id, metric_name, dimension_name, dimension_value, metric_value, unit, source_coverage et calculation_version. Cela permet de comparer les futures mesures à la même référence sans recalculer les anciens résultats à partir des sources courantes.

### 11. Fichier 08_dashboard_datasets.sql — datasets pour AI/BI
Les dashboards doivent s'appuyer sur des vues de reporting stables, et non sur des requêtes différentes qui recalculent chaque KPI de manière incohérente.

### Dashboard 1 — Executive FinOps

On peut faire le choix sur les 2 Views sous dessous selon la requete SQL utilisée lors de la création de la table  FROM finops_catalog.finops_baseline.fct_billing_usage

**View 1**

>
              -- Vue agrégée quotidienne
          CREATE OR REPLACE VIEW finops_catalog.finops_baseline.vw_finops_daily
           AS
         WITH base AS (
         SELECT
              usage_date,
              workspace_id,
              cloud,
              sku_name,
              SUM(usage_quantity) AS total_usage_quantity,
              COUNT(*) AS billing_record_count,
              SUM(CASE WHEN price_status <> 'Prix disponible' THEN 1 ELSE 0 END) AS records_without_valid_price,
              SUM(CASE WHEN price_status = 'Prix disponible' THEN list_cost ELSE 0 END) AS matched_list_cost,
              SUM(CASE WHEN price_status <> 'Prix disponible' THEN usage_quantity ELSE 0 END) AS unmatched_usage_quantity
       FROM finops_catalog.finops_baseline.fct_billing_usage
       GROUP BY usage_date, workspace_id, cloud, sku_name
            )
      SELECT
            *,
            ROUND(1 - unmatched_usage_quantity / NULLIF(total_usage_quantity, 0), 4) AS pct_priced_usage,
            ROUND(1 - records_without_valid_price / NULLIF(billing_record_count, 0), 4) AS pct_priced_records
     FROM base;

>

**View 2**

>
              CREATE OR REPLACE VIEW
                   finops_catalog.finops_baseline.vw_finops_daily
                   AS
              SELECT
                    usage_date,
                    workspace_id,
                    cloud,
                    sku_name,
                    COUNT(*) AS billing_record_count,
                    SUM(usage_quantity) AS total_usage,
                    SUM(
                        CASE WHEN pricing_status = 'MATCHED'
                        THEN estimated_list_cost
                        ELSE 0
                        END
                       ) AS matched_list_cost,
                    SUM(
                        CASE WHEN pricing_status <> 'MATCHED'
                       THEN 1 ELSE 0
                    END
                      ) AS records_without_valid_price
                    FROM finops_catalog.finops_baseline.fct_billing_usage
                    GROUP BY usage_date, workspace_id, cloud, sku_name;
>


**Visualisations recommandées :**

- ### Indicateurs financiers (Executive FinOps KPIs):

<img width="1858" height="149" alt="image" src="https://github.com/user-attachments/assets/59daedba-870b-4563-b8f3-b033f69eb659" />

- ### Filtres : workspace, cloud, période, produit
  
<img width="949" height="407" alt="image" src="https://github.com/user-attachments/assets/df67f833-8972-4a93-83cd-ad0fba41f73f" />

- ### Cartes KPI : DBU, coût catalogue rapproché, pourcentage de lignes tarifées
  
<img width="948" height="838" alt="image" src="https://github.com/user-attachments/assets/17d13308-e646-422a-86f0-c3084690a337" />

**Taux de Couverture des Prix (%)  = lignes tarifées =  pct_priced_records: Condition de couleur : Vert si $\ge 0.99$ (99%), Orange si entre $0.95$ et $0.99$, Rouge si $< 0.95$**

- ### Courbe : coût quotidien

  <img width="762" height="377" alt="image" src="https://github.com/user-attachments/assets/a80a2219-8d88-4554-aa61-9fba98c2ce7e" />

<img width="592" height="255" alt="image" src="https://github.com/user-attachments/assets/45dca259-1624-434d-8cd6-49dd5813df1d" />

- ### Barres : coûts par workspace

<img width="793" height="319" alt="image" src="https://github.com/user-attachments/assets/bb30c746-64a5-4aaf-a371-cf42a83b46ae" />

- ### Tableau : coûts par SKU, avec volume non rapproché
  
<img width="1711" height="416" alt="image" src="https://github.com/user-attachments/assets/4ad9cf5d-28c8-40ce-9e38-6ae32dafe821" />

### Interprétations Métier & FinOps(Executive FinOps KPIs)

**Concentration des coûts :** Le workspace ws-prod-01 combiné à ws-ml-03 absorbe la majorité des dépenses, principalement portées par les SKUs de calcul lourd (STANDARD_ALL_PURPOSE et GPU_INSTANCE_NV). Il conviendrait de auditer l'utilisation des clusters interactifs (All Purpose) au profit de jobs automatisés pour réduire les coûts.

**Anomalies de tarification :** La présence de volumes non rapprochés (ex: sur STANDARD_JOBS le 24 octobre) signale un décalage potentiel dans la mise à jour de la table system.billing.list_prices pour un nouveau type de SKU ou une modification tarifaire cloud. Une alerte doit être levée pour investiguer le catalogue de prix.

**Pilotage budgétaire :** La courbe quotidienne montre des pics cycliques (probablement liés à des traitements ETL lourds en fin de semaine ou des entraînements de modèles IA). L'utilisation de Databricks Serverless SQL et de politiques de clusters strictes permettra de lisser ces pics.


### Dashboard 2 — Job Performance

**Dataset : fct_job_run.**

- Cartes KPI : nombre d'exécutions, taux de réussite, P95.

- Courbe : volume et taux d'échec quotidien.

- Barres : jobs les plus lents.

- Tableau : jobs les plus fréquemment en échec.

- Filtres : workspace, job, statut, date.

### Dashboard 3 — SQL Performance

**Dataset : fct_query_metrics.**

- Cartes KPI : nombre de requêtes, P95 et taux d'échec.

- Courbe : latence quotidienne.

- Barres : warehouses par volume de requêtes.

- Tableau : requêtes les plus lentes ou ayant le plus grand cumul de durée.

- Filtres : workspace, warehouse, statut, type de compute.

### Dashboard 4 — Warehouse Efficiency

**Datasets : inventaire des warehouses, system.compute.warehouse_events, historique des requêtes.**

- Répartition des warehouses par type et taille.

- Nombre de requêtes et latence par warehouse.

- Historique des événements de démarrage, arrêt et scaling.

- Consommation facturée lorsque l'attribution est fiable.

- Identification des périodes sans activité observée.

Ne déduisez pas automatiquement une économie potentielle de l'inactivité : il faut considérer les horaires attendus, les SLA et les besoins de disponibilité.

### Dashboard 5 — Data Inventory

**Dataset : fct_table_inventory, enrichi avec le lineage et les métadonnées Unity Catalog.**

-  Nombre de tables par catalogue et schéma.

- Tables sans propriétaire renseigné.

- Taille des tables, lorsque disponible.

- Dernière activité observée.

Couverture du lineage et de la collecte des métadonnées.

Pour chaque dashboard, conservez les définitions de KPI dans un document commun. Par exemple, le coût catalogue ne doit pas être présenté comme un coût facturé dans un dashboard et comme une dépense réelle dans un autre.

### 12. Plan de déploiement

**Étape 1 — Préparation des accès.** Vérifier les permissions de lecture sur les tables système et les droits d'écriture dans le catalogue de reporting.

**Étape 2 — Découverte.** Exécuter 00_discovery.sql, relever les schémas disponibles et documenter les limites de couverture.

**Étape 3 — Inventaire.** Exécuter 01_inventory.sql, compléter les métadonnées métier et rapprocher les volumes attendus.

**Étape 4 — Modèle de reporting.** Créer le schéma Delta et exécuter les scripts financiers, jobs, SQL et inventaire des tables.

**Étape 5 — Contrôle qualité.** Exécuter les contrôles, corriger les transformations et documenter les écarts. Ne pas modifier les workloads de production.

**Étape 6 — Dashboards.** Publier les datasets validés et construire les cinq dashboards Databricks AI/BI.

**Étape 7 — Validation et gel.** Faire approuver les résultats, enregistrer le snapshot versionné et protéger les données de référence.

### 13. Critères d'acceptation du projet

<img width="1124" height="560" alt="image" src="https://github.com/user-attachments/assets/68c42aaa-4f88-4c86-b3c0-cdfe28c4c09f" />


### 14. Points à adapter avant exécution en production

Le pack est un socle de départ, pas un déploiement déjà testé dans votre compte. Trois précautions sont particulièrement importantes :

- **Schémas réels :** les requêtes de découverte doivent confirmer les colonnes et les permissions avant l'exécution des transformations.

- **Rapprochement financier :** les prix, les périodes de validité et les éventuels retraitements de facturation doivent être contrôlés avant de certifier les montants.

- **Gel de référence :** les tables de reporting utilisées pendant la préparation ne doivent pas être confondues avec les tables immuables du snapshot approuvé.

Enfin, la table fct_table_inventory proposée ci-dessus ne contient pour l'instant que les métadonnées de base. Pour couvrir réellement les 500 tables, il faudra y ajouter les propriétaires, tailles et événements de lecture/écriture disponibles dans votre environnement. De même, l'attribution du coût aux jobs et aux requêtes doit être traitée comme un chantier de rapprochement spécifique, et non déduite par une simple jointure sur le workspace.

**Livrable final attendu :** un dépôt Git versionné, les scripts SQL validés, le dictionnaire des KPI, les résultats des contrôles, les cinq dashboards et un snapshot financier et technique approuvé. Ce sera votre référence pour mesurer les économies et les gains de performance des phases d'optimisation suivantes.
