----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-                                                        v_night_status
       
--Objectif: a supervision des traitements nocturnes (batchs / jobs). Elle permet aux équipes d'exploitation de vérifier rapidement si les jobs de la nuit se sont bien déroulés, à quelle heure locale ils ont tourné et combien de temps ils ont pris.
--Ordre de création: 3 ( après création de mco.monitoring.v_job_runs & Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites).sql) 
--Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1    
--View appelée par : mco.monitoring.v_morning_status
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------       

--Sources ou Sous requetes: mco.monitoring.v_job_runs

       
CREATE OR REPLACE VIEW mco.monitoring.v_night_status AS
SELECT job_id, job_name, criticite, run_id, etat, termination_code,
       from_utc_timestamp(start_time, 'Europe/Paris') AS debut_paris,
       from_utc_timestamp(end_time, 'Europe/Paris')   AS fin_paris,
       duree_s
FROM mco.monitoring.v_job_runs
WHERE start_time >= date_trunc('day', current_timestamp()) - INTERVAL 4 HOURS;


