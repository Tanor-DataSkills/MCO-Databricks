SELECT
  count(DISTINCT run_id) AS runs_total,
  count(DISTINCT CASE WHEN result_state = 'SUCCEEDED' THEN run_id END) AS reussis,
  count(DISTINCT CASE WHEN result_state IN ('FAILED','ERROR','TIMED_OUT') THEN run_id END) AS echecs
FROM system.lakeflow.job_run_timeline
WHERE period_end_time >= date_trunc('day', current_timestamp()) - INTERVAL 2 HOURS
  AND result_state IS NOT NULL;
