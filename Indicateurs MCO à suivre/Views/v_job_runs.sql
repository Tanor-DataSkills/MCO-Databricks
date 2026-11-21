--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--                                                                     mco.monitoring.v_job_runs 
--Objectif:  bâtir un socle d'observabilité des jobs(la view socle des jobs et leurs executions); tout le cycle de vie du job + caracteristiques mco.La première a etre créer sur laquelle repose d'autres views et plusieurs indicateurs.
--Ordre de création: 1 ( après création de mco.ref.job_registry)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Sous requetes: runs + jobs + mco.ref.job_registry
--runs: La table system.lakeflow.job_run_timeline est une table d'événements/périodes (et non une ligne figée par run)
--jobs: avoir un nom unique j.name pour chaque job-->La table system.lakeflow.jobs est une table SCD / historique des changements de configuration d'un job(des id_job en doublon, delete_time IS NOT NULL si job supprimé)
--Select final (runs + jobs + mco.ref.job_registry(Récupération des champs métiers mco): Enrichissement MCO et calcul d'indicateurs

--Reconstruction du cycle de vie de chaque exécution(L'objectif est d'obtenir une seule ligne par exécution de job car une longue execution crée plusieurs lignes(run_id) qu'il faut consolider
CREATE OR REPLACE VIEW mco.monitoring.v_job_runs AS
WITH runs AS (
  SELECT workspace_id, job_id, run_id,
         min(period_start_time) AS start_time,
         max(period_end_time)   AS end_time,
         max_by(result_state, period_end_time)     AS result_state,      --Récupère le résultat final associé à la date de fin maximale(fin de run)
         max_by(termination_code, period_end_time) AS termination_code,  --Récupère le code de terminaison associé à la date de fin maximale(fin de run)
         max_by(trigger_type, period_end_time)     AS trigger_type       --Récupère le type de déclenchement associé à la date de fin maximale(fin de run)
  FROM system.lakeflow.job_run_timeline
  WHERE run_type = 'JOB_RUN'                  --filtre sur les exécutions de jobs principales (en écartant d'autres types de runs internes/tâches selon le modèle)
  GROUP BY workspace_id, job_id, run_id),
  
  --Récupération du dernier nom "j.name" connu associé à job_id et filtrage des jobs actifs
jobs AS (
  SELECT job_id, name FROM (
    SELECT job_id, name, delete_time,
           row_number() OVER (PARTITION BY job_id ORDER BY change_time DESC) AS rn  --classer les versions d'un même job_id de la plus récente (rn = 1) à la plus ancienne
    FROM system.lakeflow.jobs)
  WHERE rn = 1 AND delete_time IS NULL) --ne conserve que l'état courant des jobs non supprimés

  --Enrichissement MCO et calcul d'indicateurs
  SELECT r.workspace_id, r.job_id, r.run_id, j.name AS job_name,
       g.criticite, g.owner, g.sla_heure,
       r.start_time, r.end_time, r.trigger_type, r.termination_code,
       coalesce(r.result_state, 'EN_COURS') AS etat, --tant qu'un run n'a pas d'état final renseigné(si null), il est qualifié 'EN_COURS'
       unix_timestamp(r.end_time) - unix_timestamp(r.start_time) AS duree_s
FROM runs r
JOIN jobs j ON r.job_id = j.job_id  --rattache le nom lisible du job et restreint aux jobs actifs référencés dans jobs
LEFT JOIN mco.ref.job_registry g ON r.job_id = g.job_id;



                                                  /*Utilité dans l'analyse MCO ?
  
En MCO Databricks, cette vue permet de passer d'une investigation réactive (aller fouiller dans l'UI des Workflows run par run) à une analyse structurée, chiffrée et priorisée :

1- Triage des incidents par criticité et responsabilité (criticite, owner) : lors d'une astreinte ou d'un incident matin, l'équipe identifie immédiatement les échecs (FAILED) sur des jobs CRITIQUE et sait vers quel owner (équipe data/métier) router le ticket.

2- Suivi des SLA (sla_heure, end_time) : permet de repérer les jobs qui terminent après l'heure de SLA attendue, même s'ils sont en SUCCESS (dérive silencieuse avant rupture de SLA).

3- Détection des dérives de performance (duree_s) : suivre l'évolution de la durée d'exécution dans le temps aide à anticiper la volumétrie croissante, un cluster sous-dimensionné ou du data skew.

4- Repérage des runs bloqués ou anormalement longs (etat = 'EN_COURS') : permet d'alerter sur des exécutions qui restent en cours au-delà d'une durée attendue (ex. : job bloqué ou cluster en attente de ressources).

5- Audit du référentiel MCO : les lignes où criticite IS NULL ou owner IS NULL révèlent des jobs en production non documentés dans mco.ref.job_registry.


                                                     Interprétation ligne par ligne

ING_CRM_CLIENTS_DAILY (run_id = 884101) : exécuté automatiquement (PERIODIC) en 18 min 30 s (1110 s) et terminé à 04:18:42, largement avant le SLA de 06:00:00. Comportement nominal.

AGG_FINANCE_CLOTURE (run_id = 884155) : en échec (FAILED) avec termination_code = INTERNAL_ERROR après ~12 min (735 s). Comme sa criticité est CRITIQUE et que son SLA est à 06:30:00, c'est la priorité absolue pour squad-fin : vérifier s'il s'agit d'un incident plateforme/cluster transitoire (INTERNAL_ERROR) et relancer rapidement.

ML_SCORING_CHURN (run_id = 884210) : affiché en EN_COURS (end_time et duree_s à NULL). À surveiller par rapport au SLA de 07:00:00 : si la durée habituelle de ce modèle est de 20–30 minutes, il faudra vérifier l'avancement des tâches pour éviter un dépassement de SLA.

EXP_PARTENAIRE_CSV (run_id = 884244) : lancé manuellement (MANUAL) et réussi en 52 secondes, mais criticite, owner et sla_heure sont à NULL. À ajouter dans mco.ref.job_registry pour formaliser son rattachement MCO.*/
