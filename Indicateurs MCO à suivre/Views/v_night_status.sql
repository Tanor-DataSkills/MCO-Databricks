CREATE OR REPLACE VIEW mco.monitoring.v_night_status AS
SELECT job_id, job_name, criticite, run_id, etat, termination_code,
       from_utc_timestamp(start_time, 'Europe/Paris') AS debut_paris,
       from_utc_timestamp(end_time, 'Europe/Paris')   AS fin_paris,
       duree_s
FROM mco.monitoring.v_job_runs
WHERE start_time >= date_trunc('day', current_timestamp()) - INTERVAL 4 HOURS;



CREATE OR REPLACE VIEW mco.monitoring.v_morning_status AS
WITH echecs AS (
  SELECT criticite, count(*) AS n FROM mco.monitoring.v_night_status
  WHERE etat IN ('FAILED', 'ERROR', 'TIMED_OUT') GROUP BY criticite),
non_demarres AS (
  SELECT criticite, count(*) AS n FROM mco.monitoring.v_jobs_not_started GROUP BY criticite),
fraicheur AS (
  SELECT count(*) AS n FROM mco.monitoring.v_table_freshness
  WHERE statut = 'ROUGE' AND criticite = 'P1')
SELECT CASE
  WHEN coalesce((SELECT n FROM echecs WHERE criticite = 'P1'), 0)
     + coalesce((SELECT n FROM non_demarres WHERE criticite = 'P1'), 0)
     + (SELECT n FROM fraicheur) > 0 THEN 'ROUGE'
  WHEN coalesce((SELECT sum(n) FROM echecs), 0)
     + coalesce((SELECT sum(n) FROM non_demarres), 0) > 0 THEN 'ORANGE'
  ELSE 'VERT' END AS statut_global,
  current_timestamp() AS calcule_a;
