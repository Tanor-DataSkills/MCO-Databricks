

## Disposition

1.  Bandeau KPI : taux de succès 24 h, jobs en échec, jobs non démarrés, MTTR 30 j.
2.  Tableau des échecs de la nuit (requête du contrôle 7h30).
3.  Graphique taux de succès par jour sur 30 jours.
4.  Top 10 des jobs les plus en échec.
5.  Dérive de durée (ratio vs médiane).
6.  Fraîcheur des tables clés (feu vert/orange/rouge).
7.  Coût DBU par job sur 30 jours.


## Mise en place

1.  Créer le catalog, les schémas et les tables de mco.ref et mco.ops ; remplir job_registry et table_registry avec vos jobs et tables réels (commencer par les P1).
2.  Créer les vues dans cet ordre : v_job_runs, v_table_freshness, v_night_status, v_jobs_not_started, v_morning_status, v_job_reliability_daily, v_duration_drift, v_volume_drift, v_dq_summary, v_incident_kpi_monthly, v_sla_compliance_daily, v_problem_backlog, v_cost_by_job, v_cost_waste.
3.  Droits : les vues s'exécutent avec les droits de leur propriétaire ; donner aux lecteurs SELECT sur mco.monitoring uniquement, pas sur les system tables. Le propriétaire a besoin de SELECT sur system.lakeflow et system.billing.
4.  Construire chaque dashboard sur les vues indiquées, avec un rafraîchissement planifié (tableau de synthèse en début de section) et un abonnement e-mail ou Teams pour D1 à 07h25.
5.  Brancher une alerte SQL sur v_morning_status (statut ROUGE) et sur v_jobs_not_started.
