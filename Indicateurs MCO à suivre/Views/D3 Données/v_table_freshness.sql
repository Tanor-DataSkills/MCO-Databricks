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
