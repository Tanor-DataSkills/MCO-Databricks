----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--                                                        mco.monitoring.v_morning_status
       
--Objectif: Préparer les colonnes devant servir dans le calcul des indicateurs(taux de reussite de la nuit, les echecs de la nuit) dans la mco.monitoring.v_morning_status
--Ordre de création: 3 ( après création de mco.monitoring.v_job_runs & Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites).sql) 
--Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1    
--View appelée par : mco.monitoring.v_morning_status
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------       

/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_morning_status

# Objectif: Alimenter les champs "table_name", "mesure_ts", "max_ingestion_ts", "row_count" de la table mco.ops.table_metrics devant servir dans le calcul des indicateurs(fraîcheur et de volumétrie) dans la mco.monitoring.v_freshness

# La table mco.ops.table_metrics collecte périodiquement des métriques de fraîcheur et de volumétrie sur un ensemble de tables référencées, puis les historise pour alimenter un tableau de bord ou des alertes.

# Ordre d'alimentation: 3 ( après création et alimentation de mco.ref.job_registry et mco.ref.table_registry & Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites).sql) 
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1    
# Job: Ce Code à coller dans un notebook Databricks, puis le planifier comme job qui doit être exécuté de manière quotidienne ou horaire dans un workflow Databricks pour intégrer automatiquement
# Table ou View appelée par : v_table_freshness.sql
# Sources ou Sous requetes: mco.monitoring.v_night_status/mco.monitoring.v_table_freshness/
##############################################################################################################################################################################################################################*/



--Sources ou Sous requetes: mco.monitoring.v_job_runs
  
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
