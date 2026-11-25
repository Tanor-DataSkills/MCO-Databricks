
/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_jobs_not_started

# Objectif: Cette view permet d'identifier les jobs planifiés qui n'ont pas encore démarré aujourd'hui alors que leur heure prévue (avec une tolérance de 15 minutes) est dépassée.

# Dépendances: 4 ( après création et alimentation de mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/ v_job_runs.sql )
# Ordre de création : 7 ( mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/v_job_runs.sql / v_table_freshness.sql / v_night_status / v_jobs_not_started)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->>D1    
# Indicateurs: Jobs non démarrés (Jobs actifs du référentiel sans run aujourd'hui, 15 min après l'heure prévue)
# Job: 
# Table ou View appelée par : mco.monitoring.v_morning_status
# Sources ou Sous requetes: mco.ref.job_registry / mco.monitoring.v_job_runs
##############################################################################################################################################################################################################################*/

CREATE OR REPLACE VIEW mco.monitoring.v_jobs_not_started AS
SELECT g.job_id, g.job_name, g.criticite, g.heure_prevue
FROM mco.ref.job_registry g
LEFT JOIN mco.monitoring.v_job_runs r
  ON r.job_id = g.job_id
 AND from_utc_timestamp(r.start_time, 'Europe/Paris')
     >= date_trunc('day', from_utc_timestamp(current_timestamp(), 'Europe/Paris'))
WHERE g.actif
  AND r.job_id IS NULL
  AND from_utc_timestamp(current_timestamp(), 'Europe/Paris')
      > to_timestamp(concat(date_format(from_utc_timestamp(current_timestamp(), 'Europe/Paris'), 'yyyy-MM-dd'),
                            ' ', g.heure_prevue)) + INTERVAL 15 MINUTES;
