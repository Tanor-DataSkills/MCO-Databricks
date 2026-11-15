SELECT r.job_id, r.job_name, r.heure_prevue
FROM <catalog>.mco.referentiel_jobs r
LEFT JOIN system.lakeflow.job_run_timeline t
  ON r.job_id = t.job_id
 AND t.period_start_time >= date_trunc('day', current_timestamp())
WHERE t.job_id IS NULL
  AND r.heure_prevue < current_timestamp();
