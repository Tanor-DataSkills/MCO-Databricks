**Ordre de livraison:** Première livraison (semaine 1)

**Requêtes SQL concernées:** Inventaire des jobs P1 à 100 % renseignés/non renseignés.sql

**Critère de validation:** Jobs P1 à 100 % renseignés dans job_registry ; validé par le management

**Livrables: 3 tableaux**


- Tableau Inventaire global (avec dépendances amont/aval et tables produites via tables système)
  
- Tableau Inventaire des Jobs P1 complets à 100 %
  
- Tableau Inventaire des jobs non renseignés
  

# Livrable 1: Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites)

### C'est le premier livrable à fournir.

## 1- Inventaire global (avec dépendances amont/aval et tables produites via tables système)

>

     WITH tasks_agg AS (
       SELECT
             job_id,
             CONCAT_WS(', ', COLLECT_SET(task_key)) AS tasks_list,
             CONCAT_WS(', ', COLLECT_SET(
             CASE WHEN SIZE(depends_on) > 0 THEN CONCAT(task_key, ' <- ', ARRAY_JOIN(TRANSFORM(depends_on, x -> x.task_key), '+')) END
             )) AS dependances_amont_aval
        FROM system.lakeflow.job_tasks
        GROUP BY job_id
        ),
       tables_agg AS (
       SELECT
              entity_id AS job_id,
              CONCAT_WS(', ', COLLECT_SET(
              CONCAT_WS('.', target_table_catalog, target_table_schema, target_table_name)
              )) AS tables_produites
        FROM system.access.table_lineage
        WHERE entity_type = 'JOB'
        AND target_table_name IS NOT NULL
        GROUP BY entity_id
        )
        SELECT
               r.job_id,
               r.job_name,
               r.criticite,
               r.owner,
               r.heure_prevue AS planning_paris,
               r.sla_heure AS sla_paris,
               COALESCE(ta.dependances_amont_aval, 'Non renseigne / Aucune') AS dependances_amont_aval,
               COALESCE(tb.tables_produites, 'Non renseigne / Aucune') AS tables_produites,
               r.runbook_url,
               r.actif
               FROM mco.ref.job_registry r
               LEFT JOIN tasks_agg ta
               ON r.job_id = CAST(ta.job_id AS STRING)
               LEFT JOIN tables_agg tb
               ON r.job_id = CAST(tb.job_id AS STRING)
               WHERE r.actif = true
               ORDER BY r.criticite ASC, r.job_name ASC;
>


<img width="1846" height="177" alt="image" src="https://github.com/user-attachments/assets/1161485e-477f-49ec-b274-7bb7483303af" />



## 2- Inventaire des Jobs P1 complets à 100 %

Pour qu'un job P1 soit considéré comme 100 % renseigné sur la structure de mco.ref.job_registry, il doit :

- Être actif (actif = true),

- Avoir la criticité 'P1',

- Avoir toutes les colonnes opérationnelles renseignées (ni NULL, ni chaîne vide '', ni espaces seuls TRIM(...) = ''), y compris le format HH:mm pour heure_prevue et sla_heure.

La requete ci-dessous fourni les Jobs P1 complets à 100 %

>
     SELECT
           job_id,
           job_name,
           criticite,
           owner,
           heure_prevue,
           sla_heure,
           runbook_url,
           actif
     FROM mco.ref.job_registry
     WHERE actif = true
     AND UPPER(TRIM(criticite)) = 'P1'
     AND TRIM(COALESCE(job_id, '')) <> ''
     AND TRIM(COALESCE(job_name, '')) <> ''
     AND TRIM(COALESCE(owner, '')) <> ''
     AND TRIM(COALESCE(heure_prevue, '')) <> ''
     AND TRIM(COALESCE(sla_heure, '')) <> ''
     AND TRIM(COALESCE(runbook_url, '')) <> ''
     ORDER BY sla_heure ASC, heure_prevue ASC, job_name ASC;
>

**Points d'attention MCO sur cette requête**

Lors de la saisi il peut y'avoir des espaces ou des majuscules et muniscules combinés qu'il faut tenir en compte.

- Chaînes vides ("" / "   ") : En production, un UPDATE avec une chaîne vide passe à côté d'un simple IS NOT NULL. Le TRIM(COALESCE(..., '')) <> '' protège contre ce piège.

- Format horaire (heure_prevue, sla_heure) : Les colonnes sont en STRING (HH:mm, heure de Paris). Si tu veux filtrer sur un format horaire strict (ex. 06:30), tu peux ajouter un contrôle regex RLIKE '^([01][0-9]|2[0-3]):[0-5][0-9]$'.

- Jobs P1 incomplets (à exclure de l'inventaire 100 % prêt) : Les jobs P1 où owner, heure_prevue, sla_heure ou runbook_url sont manquants n'apparaissent pas ici ; ils doivent être traités en priorité dans la file de qualification MCO.

  Voici un exemple de résultat sur mco.ref.job_registry (les jobs **P2/P3**, les jobs **actif = false** et les **P1 incomplets** ne ressortent pas) :


  <img width="1837" height="142" alt="image" src="https://github.com/user-attachments/assets/a7c81053-c57c-4e63-945a-67d9a17b1b07" />


- Fiabilité du runbook (runbook_url) : La présence d'une URL non vide garantit qu'en cas d'incident de nuit (au contrôle de 7h30 ou en astreinte), l'exploitant dispose d'une procédure de relance/reprise documentée sans perte de temps.

- Couverture de la nuit : Sur les 3 lignes retournées, tous les sla_heure (05:30, 06:45, 07:00) se situent avant le contrôle matinal de 07:30 : tout dépassement ou échec sur ces job_id est donc détectable au point de 7h30 avec un contexte complet (owner et runbook_url connus).

  ## 3- Inventaire des Jobs incomplets


  >
               SELECT
                     job_id,
                     job_name,
                     criticite,
                     owner,
                     heure_prevue,
                     sla_heure,
                     runbook_url,
                     actif,
                     CONCAT_WS(
                                ', ',
                                CASE WHEN TRIM(COALESCE(criticite, '')) = '' THEN 'criticite' END,
                                CASE WHEN TRIM(COALESCE(owner, '')) = '' THEN 'owner' END,
                                CASE WHEN TRIM(COALESCE(heure_prevue, '')) = '' THEN 'heure_prevue' END,
                                CASE WHEN TRIM(COALESCE(sla_heure, '')) = '' THEN 'sla_heure' END,
                                CASE WHEN TRIM(COALESCE(runbook_url, '')) = '' THEN 'runbook_url' END
                              ) AS champs_manquants
                FROM mco.ref.job_registry
                WHERE actif = true
                AND (
                     TRIM(COALESCE(criticite, '')) = ''
                OR TRIM(COALESCE(owner, '')) = ''
                OR TRIM(COALESCE(heure_prevue, '')) = ''
                OR TRIM(COALESCE(sla_heure, '')) = ''
                OR TRIM(COALESCE(runbook_url, '')) = ''
                 )
                ORDER BY
               CASE UPPER(TRIM(COALESCE(criticite, '')))
               WHEN 'P1' THEN 1
               WHEN 'P2' THEN 2
               WHEN 'P3' THEN 3
               ELSE 0
               END ASC,
               job_name ASC;
  >


**Ce que fait cette requête**

- Priorité P1 en tête (ELSE 0 puis P1, P2, P3) : les nouveaux jobs sans criticité ou déjà qualifiés P1 remontent tout en haut de la file de traitement MCO.

- Colonne champs_manquants : indique exactement quelles colonnes sont NULL ou vides ("" / espaces) pour faciliter le suivi avec les owners.

- Filtre actif = true : évite de solliciter des owners sur des jobs déjà supprimés/inactifs.

Exemple de sortie simulée

<img width="1842" height="135" alt="image" src="https://github.com/user-attachments/assets/fafdb823-0f75-40e2-be7c-d013b239bec9" />
