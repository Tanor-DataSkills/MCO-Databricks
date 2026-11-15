SELECT date(period_start_time) AS jour,
       count(*) AS runs,
       sum(CASE WHEN result_state = 'SUCCEEDED' THEN 1 ELSE 0 END) / count(*) AS taux_succes
FROM system.lakeflow.job_run_timeline
WHERE period_start_time >= current_date() - 30
  AND result_state IS NOT NULL
GROUP BY 1 ORDER BY 1;
