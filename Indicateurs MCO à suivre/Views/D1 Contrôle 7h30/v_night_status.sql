CREATE OR REPLACE VIEW mco.monitoring.v_night_status AS
SELECT job_id, job_name, criticite, run_id, etat, termination_code,
       from_utc_timestamp(start_time, 'Europe/Paris') AS debut_paris,
       from_utc_timestamp(end_time, 'Europe/Paris')   AS fin_paris,
       duree_s
FROM mco.monitoring.v_job_runs
WHERE start_time >= date_trunc('day', current_timestamp()) - INTERVAL 4 HOURS;


