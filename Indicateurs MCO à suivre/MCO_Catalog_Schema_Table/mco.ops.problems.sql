CREATE TABLE IF NOT EXISTS mco.ops.problems (
  probleme_id STRING, titre STRING, ouvert_le DATE, clos_le DATE,
  owner STRING, statut STRING COMMENT 'OUVERT | EN_COURS | CLOS');

