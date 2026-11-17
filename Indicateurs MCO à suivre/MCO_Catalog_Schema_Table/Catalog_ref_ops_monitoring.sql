CREATE CATALOG IF NOT EXISTS mco;
CREATE SCHEMA IF NOT EXISTS mco.ref;
CREATE SCHEMA IF NOT EXISTS mco.ops;
CREATE SCHEMA IF NOT EXISTS mco.monitoring;

CREATE TABLE IF NOT EXISTS mco.ref.job_registry (
  job_id STRING, job_name STRING, criticite STRING, owner STRING,
  heure_prevue STRING COMMENT 'HH:mm, heure de Paris',
  sla_heure STRING COMMENT 'HH:mm, heure de Paris',
  runbook_url STRING, actif BOOLEAN);

CREATE TABLE IF NOT EXISTS mco.ref.table_registry (
  table_name STRING, criticite STRING, colonne_ingestion STRING,
  seuil_fraicheur_h INT, seuil_volumetrie_pct INT, job_id STRING);

CREATE TABLE IF NOT EXISTS mco.ops.incidents (
  incident_id STRING, job_id STRING, run_id STRING, criticite STRING, categorie STRING,
  echec_ts TIMESTAMP, detecte_ts TIMESTAMP, resolu_ts TIMESTAMP,
  mode_relance STRING COMMENT 'AUTO | MANUELLE | AUCUNE',
  runbook_existant BOOLEAN, probleme_id STRING);

CREATE TABLE IF NOT EXISTS mco.ops.problems (
  probleme_id STRING, titre STRING, ouvert_le DATE, clos_le DATE,
  owner STRING, statut STRING COMMENT 'OUVERT | EN_COURS | CLOS');

CREATE TABLE IF NOT EXISTS mco.ops.dq_results (
  table_name STRING, controle STRING, run_ts TIMESTAMP,
  statut STRING COMMENT 'OK | KO', valeur DOUBLE, seuil DOUBLE);

CREATE TABLE IF NOT EXISTS mco.ops.table_metrics (
  table_name STRING, mesure_ts TIMESTAMP, max_ingestion_ts TIMESTAMP, row_count BIGINT);
