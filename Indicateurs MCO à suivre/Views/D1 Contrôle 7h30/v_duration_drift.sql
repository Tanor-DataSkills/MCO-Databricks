/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_duration_drift

# Objectif: La dérive de la durée permet de lister les jobs ayant réussi mais sur une durée anormalement longue.Son objectif principal est de détecter les dérives de performances 
          # et l'instabilité temporelle des jobs sur une fenêtre glissante de 30 jours, en s'appuyant sur les tables système d'Unity Catalog (system.lakeflow.job_run_timeline). 
          # Elle met en lumière les traitements dont le temps d'exécution maximal dépasse de plus de 50% ($ratio > 1.5$) leur temps médian habituel, signalant un risque potentiel sur les SLA de restitution des données
 
# Dépendances: 4 ( après création et alimentation de mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/ v_job_runs.sql )
# Ordre de création : 8 ( mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/v_job_runs.sql / v_table_freshness.sql / v_night_status / v_jobs_not_started / v_morning_status / v_duration_drift)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1   
# Indicateurs: 
# Indicateurs: 1
    # Dérives de durée ( Durée du dernier run réussi / médiane des runs réussis sur 30 jours ; alerte si > 1,5 ) ------> Carte Dérives de durée(sur databricks créer un widget : count(*))
# Table ou View appelée par :
# Sources ou Sous requetes: mco.monitoring.v_job_runs /
##############################################################################################################################################################################################################################*/

CREATE OR REPLACE VIEW mco.monitoring.v_duration_drift AS
--Profil de référence sur 30 jours glissants
WITH base AS (
  SELECT job_id, job_name, criticite,
         percentile(duree_s, 0.5)  AS mediane_s,
         percentile(duree_s, 0.95) AS p95_s
  FROM mco.monitoring.v_job_runs
  WHERE etat = 'SUCCEEDED' AND start_time >= current_date() - 30
  GROUP BY job_id, job_name, criticite),
          
--Dernière exécution réussie connue
derniere AS (
  SELECT job_id,
         max_by(run_id, start_time)  AS run_id,     --run_id associé à la dernière exécution réussie
         max_by(duree_s, start_time) AS dernier_s,   --durée en secondes associé à cette dernière exécution réussie
         max(start_time)             AS dernier_debut  --date/heure de début de cette dernière exécution réussie
  FROM mco.monitoring.v_job_runs
  WHERE etat = 'SUCCEEDED'
  GROUP BY job_id)
SELECT b.job_id, b.job_name, b.criticite, b.mediane_s, b.p95_s,
       d.run_id, d.dernier_s, d.dernier_debut,
       round(d.dernier_s / b.mediane_s, 2) AS ratio
FROM base b JOIN derniere d ON b.job_id = d.job_id;
