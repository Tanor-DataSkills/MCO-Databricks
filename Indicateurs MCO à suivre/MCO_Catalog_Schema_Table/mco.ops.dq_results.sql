CREATE TABLE IF NOT EXISTS mco.ops.dq_results (
  table_name STRING, controle STRING, run_ts TIMESTAMP,
  statut STRING COMMENT 'OK | KO', valeur DOUBLE, seuil DOUBLE);

