CREATE OR REPLACE VIEW mco.monitoring.v_dq_summary AS
SELECT table_name, date(run_ts) AS jour,
       count(*) AS controles,
       sum(CASE WHEN statut = 'OK' THEN 1 ELSE 0 END) AS ok,
       sum(CASE WHEN statut = 'KO' THEN 1 ELSE 0 END) AS ko,
       round(100 * sum(CASE WHEN statut = 'OK' THEN 1 ELSE 0 END) / count(*), 1) AS taux_ok_pct
FROM mco.ops.dq_results
GROUP BY table_name, date(run_ts);
