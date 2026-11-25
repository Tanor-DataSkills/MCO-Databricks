
/*####################################################################################################################################################################################################################################################
#                                                               mco.monitoring.v_night_status

# Objectif: La supervision des traitements nocturnes (batchs / jobs). Elle permet aux équipes d'exploitation de vérifier rapidement si les jobs de la nuit se sont bien déroulés, à quelle heure locale ils ont tourné et combien de temps ils ont pris.
         # Elle s'appui sur la view socle centrale mco.monitoring.v_job_runs(qui liste l'ensemble des runs de la nuit) pour fournir une synthèse rapide des exécutions de la nuit et du matin (avec les horaires convertis en heure locale de Paris) 
         # pour faciliter la revue de début de journée / astreinte nocturne
# Dépendances: 4 ( après création et alimentation de mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/ v_job_runs.sql )
# Ordre de création : 6 ( mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/v_job_runs.sql / v_table_freshness.sql / v_night_status)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->D1    
# Indicateurs: 2
    # Taux de réussite de la nuit(Runs SUCCEEDED / runs terminés, hors CANCELED et EN_COURS, depuis 20h (UTC) la veille) ------>  Carte Taux de reussite(sur databricks créer un widget : count(*), sum(CASE WHEN etat='SUCCEEDED' THEN 1 ELSE 0 END) et le taux = succès / count(*))
    # Execution de la nuit ------> Carte Taux de reussite(sur databricks créer un widget : count(*)
    # Échecs de la nuit(Runs avec etat dans (FAILED, ERROR, TIMED_OUT))------------------> Tableau echecs de la nuit(Job/ Crit/ Run/ État/ Code/ Début/ Fin/ Durée (min))
    # Échecs de la nuit(Runs avec etat dans (FAILED, ERROR, TIMED_OUT))------------------> Tableau echecs de la nuit(Job/ Crit/ Run/ État/ Code/ Début/ Fin/ Durée (min))
# Job: 
# Table ou View appelée par : mco.monitoring.v_morning_status
# Sources ou Sous requetes: mco.monitoring.v_job_runs
####################################################################################################################################################################################################################################################*/

CREATE OR REPLACE VIEW mco.monitoring.v_night_status AS
SELECT job_id, job_name, criticite, run_id, etat, termination_code, --Ne garder que les colonnes clés pour le triage opérationnel(Identification & criticité et Statut d'exécution)
       from_utc_timestamp(start_time, 'Europe/Paris') AS debut_paris,
       from_utc_timestamp(end_time, 'Europe/Paris')   AS fin_paris,
       duree_s
FROM mco.monitoring.v_job_runs
--Elle filtre les exécutions démarrées à partir de 20h00 la veille (00:00 du jour moins 4 heures), ce qui couvre typiquement les batchs nocturnes, les chargements de nuit et les traitements de début de matinée
WHERE start_time >= date_trunc('day', current_timestamp()) - INTERVAL 4 HOURS; 


