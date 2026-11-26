/*##############################################################################################################################################################################################################################
#                                                               Jobs planifiés-non démarés.sql

# Objectif: Cette requête SQL calcule un indicateur de synthèse des exécutions de jobs sur une fenêtre glissante incluant la fin de la veille et la journée en cours. En MCO (Maintien en Condition Opérationnelle),
# elle sert à suivre la fiabilité des traitements batch/orchestrés et à détecter rapidement une dérive ou une série d'échecs.

# Dépendances: 2 (mco.referentiel_jobs / system.lakeflow.job_run_timeline)
# Ordre de création : 2 (Avoir les droits d'accèd pour system.lakeflow.job_run_timeline)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: Total non démarrés
##############################################################################################################################################################################################################################*/

 SELECT r.job_id, r.job_name, r.heure_prevue
 FROM <catalog>.mco.referentiel_jobs r
 LEFT JOIN system.lakeflow.job_run_timeline t
 ON r.job_id = t.job_id
 --Ne conserver dans la jointure que les exécutions démarrées depuis minuit, tout en gardant dans le résultat les jobs n'ayant aucune exécution aujourd'hui (grâce au LEFT JOIN)
 AND t.period_start_time >= date_trunc('day', current_timestamp())  
 WHERE t.job_id IS NULL   --Ne garde que les jobs pour lesquels aucune ligne n'a été trouvée dans job_run_timeline depuis le début de la journée
 AND r.heure_prevue < current_timestamp();
