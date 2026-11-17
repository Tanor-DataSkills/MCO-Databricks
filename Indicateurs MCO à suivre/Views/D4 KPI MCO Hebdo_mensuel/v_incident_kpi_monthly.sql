CREATE OR REPLACE VIEW mco.monitoring.v_incident_kpi_monthly AS
WITH i AS (
  SELECT *,
         count(*) OVER (
           PARTITION BY job_id, categorie ORDER BY echec_ts
           RANGE BETWEEN INTERVAL 30 DAYS PRECEDING AND CURRENT ROW) AS occurrences_30j
  FROM mco.ops.incidents)
SELECT date_trunc('month', echec_ts) AS mois,
       count(*) AS incidents,
       round(avg((unix_timestamp(detecte_ts) - unix_timestamp(echec_ts)) / 60), 0) AS mttd_min,
       round(avg((unix_timestamp(resolu_ts) - unix_timestamp(detecte_ts)) / 60), 0) AS mttr_min,
       sum(CASE WHEN occurrences_30j >= 2 THEN 1 ELSE 0 END) AS incidents_recurrents,
       round(100 * avg(CASE WHEN runbook_existant THEN 1 ELSE 0 END), 1) AS pct_runbook,
       round(100 * sum(CASE WHEN mode_relance = 'AUTO' THEN 1 ELSE 0 END)
             / nullif(sum(CASE WHEN mode_relance IN ('AUTO', 'MANUELLE') THEN 1 ELSE 0 END), 0), 1) AS pct_relances_auto
FROM i
GROUP BY date_trunc('month', echec_ts);
