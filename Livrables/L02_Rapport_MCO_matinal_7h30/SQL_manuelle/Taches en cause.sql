/*##############################################################################################################################################################################################################################
#                                                              Taches en cause.sql

# Objectif: Maintenant que le constat est fait et que le rapport matinal est mis à la disposition des équipes, on doit mettre en place une fiche d'incident pour chacune des erreurs. 
# L'objectif de cette requête est d'effectuer un diagnostic de niveau 2 (investigation d'incident) suite à la détection d'un run global en échecs.
# Puisque la requête Jobs echecs de la nuit.sql a identifié que les run_id = 983472,48211, 48230 ont échoué, cette requête liste toutes les tâches qui composaient ce workflow pour identifier la tâche exacte 
# qui a fait échouer l'ensemble du DAG. Cette requête est très importante pour remplir la fiche d'incident avec des informations telles que: symptomes, Cause racine apparente, Impact aval

# Dépendances:  ()
# Ordre de création : 6 (Après création Jobs echec-reussis.sql / Jobs planifiés-non démarés.sql /Jobs echecs de la nuit.sql / Dérive de durée.sql / Fraicheur )
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: Infos pour remplir fiche d'incident: symptomes, Cause racine apparente, Impact aval
# Sources ou Sous requetes: Avoir les accès à system.lakeflow.job_task_run_timeline
##############################################################################################################################################################################################################################*/

  SELECT task_key, result_state, termination_code, period_start_time, period_end_time
  FROM system.lakeflow.job_task_run_timeline
  WHERE run_id = <run-id> ORDER BY period_start_time;
