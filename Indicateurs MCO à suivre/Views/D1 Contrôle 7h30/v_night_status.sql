
/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_night_status

# Objectif: La supervision des traitements nocturnes (batchs / jobs). Elle permet aux équipes d'exploitation de vérifier rapidement si les jobs de la nuit se sont bien déroulés, à quelle heure locale ils ont tourné et combien de temps ils ont pris.

# Dépendances: 3 ( après création et alimentation de mco.ref.job_registry / mco.ref.table_registry / mco.monitoring.v_job_runs
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->>D1    
# Indicateurs: Taux de réussite de la nuit(Runs SUCCEEDED / runs terminés, hors CANCELED et EN_COURS, depuis 20h (UTC) la veille) 
#              & Échecs de la nuit(Runs avec etat dans (FAILED, ERROR, TIMED_OUT))
# Job: 
# Table ou View appelée par : mco.monitoring.v_morning_status
# Sources ou Sous requetes: mco.monitoring.v_job_runs
##############################################################################################################################################################################################################################*/

CREATE OR REPLACE VIEW mco.monitoring.v_night_status AS
SELECT job_id, job_name, criticite, run_id, etat, termination_code,
       from_utc_timestamp(start_time, 'Europe/Paris') AS debut_paris,
       from_utc_timestamp(end_time, 'Europe/Paris')   AS fin_paris,
       duree_s
FROM mco.monitoring.v_job_runs
WHERE start_time >= date_trunc('day', current_timestamp()) - INTERVAL 4 HOURS;


