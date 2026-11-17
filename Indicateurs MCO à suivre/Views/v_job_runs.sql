CREATE OR REPLACE VIEW mco.monitoring.v_job_runs AS
WITH runs AS (
  SELECT workspace_id, job_id, run_id,
         min(period_start_time) AS start_time,
         max(period_end_time)   AS end_time,
         max_by(result_state, period_end_time)     AS result_state,
         max_by(termination_code, period_end_time) AS termination_code,
         max_by(trigger_type, period_end_time)     AS trigger_type
  FROM system.lakeflow.job_run_timeline
  WHERE run_type = 'JOB_RUN'
  GROUP BY workspace_id, job_id, run_id),
jobs AS (
  SELECT job_id, name FROM (
    SELECT job_id, name, delete_time,
           row_number() OVER (PARTITION BY job_id ORDER BY change_time DESC) AS rn
    FROM system.lakeflow.jobs)
  WHERE rn = 1 AND delete_time IS NULL)
SELECT r.workspace_id, r.job_id, r.run_id, j.name AS job_name,
       g.criticite, g.owner, g.sla_heure,
       r.start_time, r.end_time, r.trigger_type, r.termination_code,
       coalesce(r.result_state, 'EN_COURS') AS etat,
       unix_timestamp(r.end_time) - unix_timestamp(r.start_time) AS duree_s
FROM runs r
JOIN jobs j ON r.job_id = j.job_id
LEFT JOIN mco.ref.job_registry g ON r.job_id = g.job_id;
