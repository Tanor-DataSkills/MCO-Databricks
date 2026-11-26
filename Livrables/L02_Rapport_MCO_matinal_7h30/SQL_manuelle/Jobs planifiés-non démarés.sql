/*##############################################################################################################################################################################################################################
#                                                               Jobs planifiés-non démarés.sql

# Objectif: Cette requête SQL calcule un indicateur de synthèse des exécutions de jobs sur une fenêtre glissante incluant la fin de la veille et la journée en cours. En MCO (Maintien en Condition Opérationnelle),
# elle sert à suivre la fiabilité des traitements batch/orchestrés et à détecter rapidement une dérive ou une série d'échecs.

# Dépendances: 1 (system.lakeflow.job_run_timeline)
# Ordre de création : 1 (Avoir les droits d'accèd pour system.lakeflow.job_run_timeline)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: runs_total / reussis / echecs
# Sources ou Sous requetes: system.lakeflow.job_run_timeline
##############################################################################################################################################################################################################################*/
