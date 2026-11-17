CREATE OR REPLACE VIEW mco.monitoring.v_problem_backlog AS
SELECT statut, count(*) AS nb,
       round(avg(datediff(coalesce(clos_le, current_date()), ouvert_le)), 0) AS anciennete_moy_j
FROM mco.ops.problems
GROUP BY statut;
