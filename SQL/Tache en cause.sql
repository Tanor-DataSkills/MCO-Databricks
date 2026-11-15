SELECT task_key, result_state, termination_code, period_start_time, period_end_time
FROM system.lakeflow.job_task_run_timeline
WHERE run_id = 983472 ORDER BY period_start_time;
