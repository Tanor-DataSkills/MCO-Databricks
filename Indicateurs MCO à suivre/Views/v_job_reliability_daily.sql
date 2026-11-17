CREATE OR REPLACE VIEW mco.monitoring.v_job_reliability_daily AS
SELECT date(start_time) AS jour, job_id, job_name, criticite,
       count(*) AS runs,
       sum(CASE WHEN etat = 'SUCCEEDED' THEN 1 ELSE 0 END) AS succes,
       sum(CASE WHEN etat IN ('FAILED', 'ERROR', 'TIMED_OUT') THEN 1 ELSE 0 END) AS echecs
FROM mco.monitoring.v_job_runs
WHERE etat NOT IN ('EN_COURS', 'CANCELED')
  AND start_time >= current_date() - 90
GROUP BY date(start_time), job_id, job_name, criticite;

CREATE OR REPLACE VIEW mco.monitoring.v_duration_drift AS
WITH base AS (
  SELECT job_id, job_name, criticite,
         percentile(duree_s, 0.5)  AS mediane_s,
         percentile(duree_s, 0.95) AS p95_s
  FROM mco.monitoring.v_job_runs
  WHERE etat = 'SUCCEEDED' AND start_time >= current_date() - 30
  GROUP BY job_id, job_name, criticite),
derniere AS (
  SELECT job_id,
         max_by(run_id, start_time)  AS run_id,
         max_by(duree_s, start_time) AS dernier_s,
         max(start_time)             AS dernier_debut
  FROM mco.monitoring.v_job_runs
  WHERE etat = 'SUCCEEDED'
  GROUP BY job_id)
SELECT b.job_id, b.job_name, b.criticite, b.mediane_s, b.p95_s,
       d.run_id, d.dernier_s, d.dernier_debut,
       round(d.dernier_s / b.mediane_s, 2) AS ratio
FROM base b JOIN derniere d ON b.job_id = d.job_id;
