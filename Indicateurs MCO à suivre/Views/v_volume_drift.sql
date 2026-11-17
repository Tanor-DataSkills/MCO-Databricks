CREATE OR REPLACE VIEW mco.monitoring.v_volume_drift AS
WITH jour AS (
  SELECT table_name, date(mesure_ts) AS jour,
         max_by(row_count, mesure_ts) AS row_count
  FROM mco.ops.table_metrics GROUP BY table_name, date(mesure_ts)),
med AS (
  SELECT table_name, jour, row_count,
         percentile(row_count, 0.5) OVER (
           PARTITION BY table_name ORDER BY jour
           ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS mediane_7j
  FROM jour)
SELECT m.table_name, m.jour, m.row_count, m.mediane_7j, t.seuil_volumetrie_pct,
       round(100 * (m.row_count - m.mediane_7j) / m.mediane_7j, 1) AS ecart_pct,
       CASE WHEN abs(100 * (m.row_count - m.mediane_7j) / m.mediane_7j) > t.seuil_volumetrie_pct
            THEN 'HORS_SEUIL' ELSE 'OK' END AS statut
FROM med m
JOIN mco.ref.table_registry t ON m.table_name = t.table_name
WHERE m.mediane_7j > 0;


