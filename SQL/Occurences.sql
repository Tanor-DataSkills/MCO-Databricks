SELECT job_id, termination_code, count(*) AS occurrences,
       min(period_end_time) AS premiere, max(period_end_time) AS derniere
FROM system.lakeflow.job_run_timeline
WHERE result_state IN ('FAILED','ERROR')
  AND period_end_time >= current_date() - 30
GROUP BY job_id, termination_code
HAVING count(*) >= 2
ORDER BY occurrences DESC;
