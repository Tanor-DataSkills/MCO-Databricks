## Générer le rapport manuellement dans les 3 premiers jours avant automatisation( la disponibilité des dashboards et alerts teams)

Avant que les vues D1 et le dashboard D1 Contrôle 7h30 ne soient en place, on exécute manuellement les requêtes ci-dessous pour exploiter leurs sorties:

### Requête 0: Total_runs, reussis, echecs

Cette requête SQL calcule un indicateur de synthèse des exécutions de jobs sur une fenêtre glissante incluant la fin de la veille et la journée en cours. En MCO (Maintien en Condition Opérationnelle), elle sert à suivre la fiabilité des traitements batch/orchestrés et à détecter rapidement une dérive ou une série d'échecs.

>

    SELECT
       count(DISTINCT run_id) AS runs_total,
       count(DISTINCT CASE WHEN result_state = 'SUCCEEDED' THEN run_id END) AS reussis,
       count(DISTINCT CASE WHEN result_state IN ('FAILED','ERROR','TIMED_OUT') THEN run_id END) AS echecs
    FROM system.lakeflow.job_run_timeline
    WHERE period_end_time >= date_trunc('day', current_timestamp()) - INTERVAL 2 HOURS
    AND result_state IS NOT NULL;
>

<img width="468" height="75" alt="image" src="https://github.com/user-attachments/assets/6a02c116-1a39-4fbb-9a21-3eea9f9ff457" />

**Taux de succes** = 41/48 = 85,4%

### Requête 01 : jobs planifiés non démarrés (à adapter à votre référentiel)

les jobs planifiés et non démarrés les tables système ne détiennent pas l'information. Il faut donc créer une table référentielle mco.referentiel_jobs (job_id, criticité, heure prévue, SLA, owner), alimenté une fois par l’API Jobs (GET /api/2.1/jobs/list, champ schedule) puis enrichi à la main. Le total « 42 planifiés » est le nombre de lignes de ce référentiel attendues la nuit.

>
     SELECT r.job_id, r.job_name, r.heure_prevue
     FROM <catalog>.mco.referentiel_jobs r
     LEFT JOIN system.lakeflow.job_run_timeline t
     ON r.job_id = t.job_id
--Ne conserver dans la jointure que les exécutions démarrées depuis minuit aujourd'hui, tout en gardant dans le résultat les jobs n'ayant aucune exécution aujourd'hui (grâce au LEFT JOIN)
     AND t.period_start_time >= date_trunc('day', current_timestamp())  
     WHERE t.job_id IS NULL
     AND r.heure_prevue < current_timestamp();
>
