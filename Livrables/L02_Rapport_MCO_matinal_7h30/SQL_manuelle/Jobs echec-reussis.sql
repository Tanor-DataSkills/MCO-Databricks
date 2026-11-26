/*##############################################################################################################################################################################################################################
#                                                               Jobs echec-reussis.sql

# Objectif: View conçue pour synthétiser l'état matinal d'une plateforme data / de traitements batch dans un contexte MCO (Maintien en Condition Opérationnelle). Son objectif est de produire un feu tricolore (ROUGE, ORANGE, VERT) 
# pour orienter rapidement la priorisation des incidents au démarrage de la journée.
# Exclusivement dédié au calcul de l'indicateur statut global: ROUGE : au moins un job P1 en échec ou non démarré, ou une table P1 non fraîche. ORANGE : au moins un échec ou un non-démarré sur P2 ou P3. VERT : sinon.
 
# Dépendances: 1 (system.lakeflow.job_run_timeline)
# Ordre de création : 1 (Avoir les droits d'accèd pour system.lakeflow.job_run_timeline)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: runs_total / reussis / echecs
# Sources ou Sous requetes: system.lakeflow.job_run_timeline
##############################################################################################################################################################################################################################*/


# Total_runs, reussis, echecs

SELECT
  count(DISTINCT run_id) AS runs_total,
  count(DISTINCT CASE WHEN result_state = 'SUCCEEDED' THEN run_id END) AS reussis,
  count(DISTINCT CASE WHEN result_state IN ('FAILED','ERROR','TIMED_OUT') THEN run_id END) AS echecs
FROM system.lakeflow.job_run_timeline
WHERE period_end_time >= date_trunc('day', current_timestamp()) - INTERVAL 2 HOURS
  AND result_state IS NOT NULL;
