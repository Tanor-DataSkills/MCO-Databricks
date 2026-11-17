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
