/*##############################################################################################################################################################################################################################
#                                                               Jobs echec-reussis.sql

# Objectif: Cette requête SQL calcule un indicateur de synthèse des exécutions de jobs sur une fenêtre glissante incluant la fin de la veille et la journée en cours. En MCO (Maintien en Condition Opérationnelle),
# elle sert à suivre la fiabilité des traitements batch/orchestrés et à détecter rapidement une dérive ou une série d'échecs.

# Dépendances: 1 (system.lakeflow.job_run_timeline)
# Ordre de création : 1 
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: runs_total / reussis / echecs
# Sources ou Sous requetes: avoir les droits d'accès à system.lakeflow.job_run_timeline
##############################################################################################################################################################################################################################*/

SELECT
  count(DISTINCT run_id) AS runs_total,
  count(DISTINCT CASE WHEN result_state = 'SUCCEEDED' THEN run_id END) AS reussis,
  count(DISTINCT CASE WHEN result_state IN ('FAILED','ERROR','TIMED_OUT') THEN run_id END) AS echecs
FROM system.lakeflow.job_run_timeline
WHERE period_end_time >= date_trunc('day', current_timestamp()) - INTERVAL 2 HOURS
  AND result_state IS NOT NULL;
