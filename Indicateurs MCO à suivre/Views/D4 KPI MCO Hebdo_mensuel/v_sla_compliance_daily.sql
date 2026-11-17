CREATE OR REPLACE VIEW mco.monitoring.v_sla_compliance_daily AS
WITH fin AS (
  SELECT date(from_utc_timestamp(start_time, 'Europe/Paris')) AS jour,
         job_id, job_name, sla_heure,
         max(CASE WHEN etat = 'SUCCEEDED'
                  THEN date_format(from_utc_timestamp(end_time, 'Europe/Paris'), 'HH:mm') END) AS fin_succes_hhmm
  FROM mco.monitoring.v_job_runs
  WHERE criticite = 'P1'
  GROUP BY date(from_utc_timestamp(start_time, 'Europe/Paris')), job_id, job_name, sla_heure)
SELECT jour, job_id, job_name, sla_heure, fin_succes_hhmm,
       CASE WHEN fin_succes_hhmm IS NOT NULL AND fin_succes_hhmm <= sla_heure THEN 1 ELSE 0 END AS sla_ok
FROM fin;
