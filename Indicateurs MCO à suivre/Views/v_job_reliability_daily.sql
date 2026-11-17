CREATE OR REPLACE VIEW mco.monitoring.v_job_reliability_daily AS
SELECT date(start_time) AS jour, job_id, job_name, criticite,
       count(*) AS runs,
       sum(CASE WHEN etat = 'SUCCEEDED' THEN 1 ELSE 0 END) AS succes,
       sum(CASE WHEN etat IN ('FAILED', 'ERROR', 'TIMED_OUT') THEN 1 ELSE 0 END) AS echecs
FROM mco.monitoring.v_job_runs
WHERE etat NOT IN ('EN_COURS', 'CANCELED')
  AND start_time >= current_date() - 90
GROUP BY date(start_time), job_id, job_name, criticite;


