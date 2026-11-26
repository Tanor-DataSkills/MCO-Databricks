
SELECT j.name, t.job_id, t.run_id, t.result_state,
       t.termination_code, t.period_start_time, t.period_end_time
FROM system.lakeflow.job_run_timeline t
JOIN (SELECT job_id, name,
             ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY change_time DESC) rn
      FROM system.lakeflow.jobs) j
  ON t.job_id = j.job_id AND j.rn = 1
WHERE t.period_end_time >= date_trunc('day', current_timestamp()) - INTERVAL 2 HOURS
  AND t.result_state IN ('FAILED','ERROR','TIMED_OUT','CANCELED')
ORDER BY t.period_end_time DESC;
