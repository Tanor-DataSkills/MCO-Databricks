CREATE TABLE IF NOT EXISTS mco.ops.incidents (
  incident_id STRING, job_id STRING, run_id STRING, criticite STRING, categorie STRING,
  echec_ts TIMESTAMP, detecte_ts TIMESTAMP, resolu_ts TIMESTAMP,
  mode_relance STRING COMMENT 'AUTO | MANUELLE | AUCUNE',
  runbook_existant BOOLEAN, probleme_id STRING);
