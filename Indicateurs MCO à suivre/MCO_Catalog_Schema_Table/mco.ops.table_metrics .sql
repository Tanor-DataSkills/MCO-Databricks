CREATE TABLE IF NOT EXISTS mco.ops.table_metrics (
  table_name STRING, mesure_ts TIMESTAMP, max_ingestion_ts TIMESTAMP, row_count BIGINT);
