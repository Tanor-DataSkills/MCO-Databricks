CREATE TABLE IF NOT EXISTS mco.ref.table_registry (
  table_name STRING, criticite STRING, colonne_ingestion STRING,
  seuil_fraicheur_h INT, seuil_volumetrie_pct INT, job_id STRING);
