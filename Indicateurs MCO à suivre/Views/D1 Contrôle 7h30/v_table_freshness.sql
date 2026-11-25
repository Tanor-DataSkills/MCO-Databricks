
/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_table_freshness

# Objectif: Fraîcheur de chaque table du référentiel.Préparer les colonnes devant servir dans le calcul des indicateurs(taux de reussite de la nuit, les echecs de la nuit) dans la mco.monitoring.v_morning_status

# Dépendances: 4 ( après création et alimentation de mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/ )
# Ordre de création : 5 ( mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/v_job_runs.sql)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1    
# Indicateurs: Tables critiques non fraîches(Âge depuis max_ingestion_ts > seuil du référentiel)
# Job: 
# Table ou View appelée par : mco.monitoring.v_morning_status
# Sources ou Sous requetes: derniere, mco.ops.table_metrics, mco.ref.table_registry
##############################################################################################################################################################################################################################*/

CREATE OR REPLACE VIEW mco.monitoring.v_table_freshness AS
WITH derniere AS (
  SELECT table_name,
         max_by(max_ingestion_ts, mesure_ts) AS max_ingestion_ts,
         max(mesure_ts) AS mesure_ts
  FROM mco.ops.table_metrics GROUP BY table_name)
SELECT t.table_name, t.criticite, t.seuil_fraicheur_h,
       d.max_ingestion_ts, d.mesure_ts,
       round((unix_timestamp(current_timestamp()) - unix_timestamp(d.max_ingestion_ts)) / 3600, 1) AS age_h,
       CASE WHEN d.max_ingestion_ts IS NULL THEN 'INCONNU'
            WHEN (unix_timestamp(current_timestamp()) - unix_timestamp(d.max_ingestion_ts)) / 3600 > t.seuil_fraicheur_h THEN 'ROUGE'
            ELSE 'VERT' END AS statut
FROM mco.ref.table_registry t
LEFT JOIN derniere d ON t.table_name = d.table_name;
