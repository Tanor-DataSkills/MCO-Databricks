
INSERT INTO mco.ops.incidents (incident_id, job_id, run_id, criticite, echec_ts, runbook_existant)
SELECT concat('INC-', date_format(r.end_time, 'yyyyMMdd'), '-', r.run_id),
       r.job_id, r.run_id, r.criticite, r.end_time, g.runbook_url IS NOT NULL
FROM mco.monitoring.v_job_runs r
LEFT JOIN mco.ref.job_registry g ON r.job_id = g.job_id
WHERE r.etat IN ('FAILED', 'ERROR', 'TIMED_OUT')
  AND r.criticite IN ('P1', 'P2')
  AND r.run_id NOT IN (SELECT run_id FROM mco.ops.incidents);


-- Le NOT IN et l’identifiant construit avec le run_id rendent la requête rejouable sans doublon. Le MCO complète ensuite à la main :

UPDATE mco.ops.incidents
SET categorie = '<CATEGORIE>', detecte_ts = '<TS>', resolu_ts = '<TS>',
    mode_relance = 'MANUELLE', probleme_id = '<PB_ID>'
WHERE incident_id = '<INCIDENT_ID>';
