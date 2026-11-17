CREATE TABLE IF NOT EXISTS mco.ref.job_registry (
  job_id STRING, job_name STRING, criticite STRING, owner STRING,
  heure_prevue STRING COMMENT 'HH:mm, heure de Paris',
  sla_heure STRING COMMENT 'HH:mm, heure de Paris',
  runbook_url STRING, actif BOOLEAN);
