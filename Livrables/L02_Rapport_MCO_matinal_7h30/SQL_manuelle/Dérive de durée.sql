# Objectif: Son objectif principal est de détecter les dérives de performances et l'instabilité temporelle des jobs sur une fenêtre glissante de 30 jours, en s'appuyant sur les tables système d'Unity Catalog (system.lakeflow.job_run_timeline). Elle met en lumière les traitements dont le temps d'exécution maximal dépasse de plus de 50% 
#(ratio >1.5) leur temps médian habituel, signalant un risque potentiel sur les SLA de restitution des données.

# Il ne suffit pas de constater que le job a pris du temps mais l'intérêt est de savoir la cause racine qui repose sur l'inspection de quatre grands coupables en production.

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
