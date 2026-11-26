/*##############################################################################################################################################################################################################################
#                                                               Jobs planifiés-non démarés.sql

# Objectif: les jobs planifiés et non démarrés les tables système ne détiennent pas l'information. Il faut donc créer une table référentielle mco.referentiel_jobs (job_id, criticité, heure prévue, SLA, owner), 
# alimenté une fois par l’API Jobs (GET /api/2.1/jobs/list, champ schedule) puis enrichi à la main. Le total « 42 planifiés » est le nombre de lignes de ce référentiel attendues la nuit..

# Dépendances: 2 (mco.referentiel_jobs / system.lakeflow.job_run_timeline)
# Ordre de création : 2 (Après Jobs echec-reussis.sql )
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: Total Jobs planifiés non démarrés
# Sources: Avoir les droits d'accès à system.lakeflow.job_run_timeline
##############################################################################################################################################################################################################################*/

 SELECT r.job_id, r.job_name, r.heure_prevue
 FROM <catalog>.mco.referentiel_jobs r
 LEFT JOIN system.lakeflow.job_run_timeline t
 ON r.job_id = t.job_id
 --Ne conserver dans la jointure que les exécutions démarrées depuis minuit, tout en gardant dans le résultat les jobs n'ayant aucune exécution aujourd'hui (grâce au LEFT JOIN)
 AND t.period_start_time >= date_trunc('day', current_timestamp())  
 WHERE t.job_id IS NULL   --Ne garde que les jobs pour lesquels aucune ligne n'a été trouvée dans job_run_timeline depuis le début de la journée
 AND r.heure_prevue < current_timestamp();


