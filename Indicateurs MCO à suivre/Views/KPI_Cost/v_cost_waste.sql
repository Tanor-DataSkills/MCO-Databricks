CREATE OR REPLACE VIEW mco.monitoring.v_cost_waste AS
SELECT c.job_id, r.job_name, r.criticite,
       sum(c.dbu) AS dbu_total,
       sum(CASE WHEN r.etat IN ('FAILED', 'ERROR', 'TIMED_OUT') THEN c.dbu ELSE 0 END) AS dbu_runs_en_echec
FROM mco.monitoring.v_cost_by_job c
LEFT JOIN mco.monitoring.v_job_runs r ON c.run_id = r.run_id
WHERE c.usage_date >= current_date() - 30
GROUP BY c.job_id, r.job_name, r.criticite;
