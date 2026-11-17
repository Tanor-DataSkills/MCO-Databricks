INSERT INTO mco.ops.incidents (incident_id, job_id, run_id, criticite, echec_ts, runbook_existant)
SELECT concat('INC-', date_format(r.end_time, 'yyyyMMdd'), '-', r.run_id),
       r.job_id, r.run_id, r.criticite, r.end_time, g.runbook_url IS NOT NULL
FROM mco.monitoring.v_job_runs r
LEFT JOIN mco.ref.job_registry g ON r.job_id = g.job_id
WHERE r.etat IN ('FAILED', 'ERROR', 'TIMED_OUT')
  AND r.criticite IN ('P1', 'P2')
  AND r.run_id NOT IN (SELECT run_id FROM mco.ops.incidents);
