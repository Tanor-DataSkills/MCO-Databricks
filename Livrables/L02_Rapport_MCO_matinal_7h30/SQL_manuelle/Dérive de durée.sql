WITH r AS (
  SELECT job_id, run_id,
       unix_timestamp(period_end_time) - unix_timestamp(period_start_time) AS dur
 FROM system.lakeflow.job_run_timeline
--Filtre sur les jobs réussis dans les 30 derniers jours
WHERE period_start_time >= current_date() - 30 AND result_state = 'SUCCEEDED')
--Calcul de la durée médiane et la durée la plus élevée des exécutions & Comparer le ratio avec 1.5l(ratio >1.5)
SELECT job_id, percentile(dur, 0.5) AS med_s, max(dur) AS max_s,
   max(dur) / percentile(dur, 0.5) AS ratio
FROM r GROUP BY job_id HAVING ratio > 1.5 ORDER BY ratio DESC;
