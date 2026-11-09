# MCO-Databricks

Data Engineer Principal et Lead MCO expert sur Azure Databricks (Unity Catalog, Workflows, System Tables, PySpark/Delta Lake). Je viens d'intégrer l'équipe en tant que Data Engineer MCO avec un quadruple rôle : exploitation/MCO, supervision, automatisation et accompagnement/transmission.


## Mission Globale :

Nous allons construire ensemble, étape par étape, le kit complet du MCO Databricks de l'entreprise (requêtes, dashboards, runbooks, scripts d'auto-réparation et programme de montée en compétence) en nous basant sur un environnement réel déjà en production.


## Étape 1 — Health Check Matinal & Triage d'Incidents Databricks
  
L'objectif est de construire un dispositif de contrôle quotidien à 07h30 permettant à l'équipe MCO de répondre rapidement à quatre questions :

- La plateforme Databricks est-elle opérationnelle ?

- Quels Workflows et quelles tâches ont échoué depuis le dernier contrôle ?

- Quels traitements présentent des signes de dégradation ?

- Quelles actions faut-il entreprendre pour rétablir le service ?

Je vais concevoir cette première brique comme un véritable outil d'exploitation de production, et non comme une simple collection de requêtes SQL.

### 1. Architecture cible du Health Check


<img width="1032" height="650" alt="image" src="https://github.com/user-attachments/assets/d65b7fb9-5aa1-4684-b440-a499ca59fba1" />

**Sources de données**
La source principale sera Unity Catalog System Tables :
<img width="860" height="238" alt="image" src="https://github.com/user-attachments/assets/276fd938-3608-4c2e-9104-06ed242ac39b" />

Attention : les System Tables sont soumises à des droits d'accès, à une rétention et à des délais de disponibilité. Les données ne constituent pas nécessairement une vision instantanée de la plateforme.

Nous allons notamment utiliser task_runs comme source principale, sans supposer que tous les champs existent dans toutes les versions de l'environnement.

### 2. Préparation de l'environnement

Avant le déploiement, vérifier les accès :
>

      SHOW SCHEMAS IN system;

      SHOW TABLES IN system.workflow;

      DESCRIBE TABLE system.workflow.task_runs;

      DESCRIBE TABLE system.workflow.job_runs;
>

Contrôler également les autorisations de lecture

>
        SELECT
             COUNT(*) AS total_task_runs
        FROM system.workflow.task_runs;
>

**Pré-requis :**

- Un SQL Warehouse ou un environnement SQL permettant l'interrogation des System Tables.

- Un service principal ou une identité technique avec les permissions de lecture nécessaires.

- Un Workflow Databricks pour exécuter le contrôle à 07h30.

- Une convention de fuseau horaire : Europe/Paris.

### 3. Livrable A — Requêtes SQL du Health Check

Nous allons créer trois niveaux de contrôle :

- Niveau 1 : détection des tâches en échec.

- Niveau 2 : analyse des performances et des durées.

- Niveau 3 : identification des incidents récurrents.

### A1. Détection des tâches en échec sur les dernières 24 heures

>
      WITH failed_tasks AS (
        SELECT
              workspace_id,
              job_id,
              run_id,
              task_key,
              result_state,
              period_start_time,
              period_end_time,
              termination_code,
              message,
              DATEDIFF(
                       SECOND,
                       period_start_time,
                       period_end_time
                      ) AS duration_seconds
      FROM system.workflow.task_runs
      WHERE period_start_time >= CURRENT_TIMESTAMP() - INTERVAL 24 HOURS
      AND result_state IN (
                           'FAILED',
                           'ERROR',
                           'TIMED_OUT',
                           'CANCELED'
                         )
             )

      SELECT
            workspace_id,
            job_id,
            run_id,
            task_key,
            result_state,
            termination_code,
            duration_seconds,
            period_start_time,
            period_end_time,
            message
    FROM failed_tasks
    ORDER BY period_start_time DESC;

>

**Interprétation MCO :**

<img width="931" height="222" alt="image" src="https://github.com/user-attachments/assets/d56ef1a1-b76b-4c8c-a8b6-e438c50ef454" />

**Attention :** un CANCELED n'est pas systématiquement un incident. Il peut résulter d'une action utilisateur ou d'une politique d'exécution.

### A2. Détection des traitements anormalement longs

Un traitement qui réussit peut malgré tout constituer un incident MCO.

Nous devons identifier les tâches dont la durée augmente fortement.

>
       WITH task_durations AS (
           SELECT
                 job_id,
                 task_key,
                 run_id,
                 result_state,
                 period_start_time,
                 period_end_time,
                 TIMESTAMPDIFF(
                 SECOND,
                 period_start_time,
                 period_end_time
                 ) AS duration_seconds
        FROM system.workflow.task_runs
        WHERE period_start_time >= CURRENT_TIMESTAMP() - INTERVAL 7 DAYS
        AND period_end_time IS NOT NULL
        ),

       baseline AS (
       SELECT
            job_id,
            task_key,
            percentile_approx(duration_seconds, 0.50) AS median_duration,
            percentile_approx(duration_seconds, 0.95) AS p95_duration
      FROM task_durations
      WHERE period_start_time < CURRENT_TIMESTAMP() - INTERVAL 24 HOURS
      GROUP BY job_id, task_key
     ),

    latest AS (
    SELECT *
    FROM task_durations
    WHERE period_start_time >= CURRENT_TIMESTAMP() - INTERVAL 24 HOURS
    )

    SELECT
          l.job_id,
          l.task_key,
          l.run_id,
          l.result_state,
          l.duration_seconds,
          b.median_duration,
          b.p95_duration,
     ROUND(
         l.duration_seconds / NULLIF(b.median_duration, 0),
         2
     ) AS slowdown_factor
    FROM latest l
    JOIN baseline b
     ON l.job_id = b.job_id
    AND l.task_key = b.task_key
    WHERE l.duration_seconds > b.p95_duration
    ORDER BY slowdown_factor DESC;
>

Cette requête compare les exécutions récentes à l'historique de la tâche.

**Point important :** la baseline est ici calculée sur une fenêtre glissante de sept jours, hors dernières 24 heures. En production, il faudra tenir compte des variations de volumétrie et des traitements hebdomadaires.


### A3. Identification des tâches fréquemment en échec

Cette requête permet de détecter les traitements instables.

>
       SELECT
     job_id,
     task_key,

     COUNT(*) AS total_executions,

     SUM(
        CASE
            WHEN result_state IN ('FAILED', 'ERROR', 'TIMED_OUT')
            THEN 1
            ELSE 0
        END
     ) AS failed_executions,

     ROUND(
        100.0 *
        SUM(
            CASE
                WHEN result_state IN ('FAILED', 'ERROR', 'TIMED_OUT')
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
     ) AS failure_rate_pct,

     MAX(period_start_time) AS last_execution

     FROM system.workflow.task_runs

     WHERE period_start_time >= CURRENT_TIMESTAMP() - INTERVAL 7 DAYS

    GROUP BY
    job_id,
    task_key

    HAVING COUNT(*) >= 3

    ORDER BY failure_rate_pct DESC;
>

Cette requête permet de distinguer :

- Un incident isolé.

- Une tâche instable.

- Un problème récurrent nécessitant une analyse de fond.

### A4. Synthèse globale : état de santé de la plateforme

Cette requête constitue le résultat principal du contrôle matinal.

>
          WITH runs AS (
    SELECT
        workspace_id,
        job_id,
        run_id,
        task_key,
        MAX(result_state) AS result_state,
        SUM(
            TIMESTAMPDIFF(
                SECOND,
                period_start_time,
                period_end_time
            )
        ) AS duration_seconds,
        MIN(period_start_time) AS start_time,
        MAX(period_end_time) AS end_time
    FROM system.lakeflow.job_task_run_timeline
    WHERE period_start_time >= CURRENT_TIMESTAMP() - INTERVAL 24 HOURS
    GROUP BY
        workspace_id,
        job_id,
        run_id,
        task_key
    ),

   summary AS (
     SELECT
         COUNT(*) AS total_tasks,

        SUM(CASE WHEN result_state = 'SUCCEEDED'
            THEN 1 ELSE 0 END) AS succeeded,

        SUM(CASE WHEN result_state IN ('FAILED', 'ERROR', 'TIMED_OUT')
            THEN 1 ELSE 0 END) AS failed,

        SUM(CASE WHEN result_state = 'CANCELLED'
            THEN 1 ELSE 0 END) AS cancelled,

        SUM(CASE WHEN result_state IN ('SKIPPED', 'BLOCKED')
            THEN 1 ELSE 0 END) AS skipped_or_blocked

    FROM runs
    )

     SELECT
          *,
          ROUND(100.0 * failed / NULLIF(total_tasks, 0), 2)
          AS failure_rate_pct,

     CASE
         WHEN failed > 0 THEN 'RED'
         WHEN cancelled > 0 OR skipped_or_blocked > 0 THEN 'ORANGE'
         ELSE 'GREEN'
     END AS health_status

     FROM summary;
>

**Interprétation:**

<img width="877" height="218" alt="image" src="https://github.com/user-attachments/assets/69b2d40f-fb3a-4cca-918a-77ec39aa0442" />

**Une précision importante :** cette règle est volontairement conservatrice. Un SKIPPED peut être parfaitement normal dans un workflow conditionnel. Il faudra donc distinguer les tâches conditionnelles des tâches réellement attendues.

### A5. Points techniques importants sur les System Tables

Je recommande d'utiliser désormais le schéma canonique :

`system.lakeflow.job_task_run_timeline`

L'ancien schéma system.workflow est l'ancienne appellation de system.lakeflow. La documentation Databricks confirme également que les exécutions longues peuvent être réparties sur plusieurs lignes horaires. Il faut donc agréger les périodes par run_id pour ne pas compter plusieurs fois une même tâche. 

Quelques corrections de conception à retenir :

Les valeurs d'état officielles comprennent **`SUCCEEDED, FAILED, ERROR, TIMED_OUT, CANCELLED, SKIPPED et BLOCKED`**.

La table de chronologie ne fournit pas directement le message d'erreur complet.

Les System Tables peuvent présenter un retard de disponibilité, souvent autour d'une heure pour les tables de Jobs.

Les durées des périodes doivent être additionnées lorsqu'une exécution est découpée en plusieurs lignes.

La requête A4 est donc une synthèse des tâches observées, pas une preuve de disponibilité instantanée de toute la plateforme.

#### 4. Livrable B — Framework de Root Cause Analysis (RCA)

C'est le deuxième pilier du dispositif.

L'objectif est de standardiser le diagnostic, quel que soit l'ingénieur qui prend en charge l'incident.

**B1. Matrice de classification des erreurs**

OOM — Out Of Memory
Data Skew
Timeout
Delta Schema Drift

**B2. Arbre de diagnostic opérationnel**

Voici la démarche que doit appliquer un ingénieur MCO à chaque incident.

<img width="602" height="655" alt="image" src="https://github.com/user-attachments/assets/bde4e7c3-2bcc-418b-905b-472eed18742f" />

**B3. Fiches de diagnostic par incident**

<img width="887" height="373" alt="image" src="https://github.com/user-attachments/assets/c98559ff-1723-466b-a4cb-d0387ff6c741" />


<img width="784" height="300" alt="image" src="https://github.com/user-attachments/assets/7d5ff6cb-57a9-473c-9cd2-027b1c7961dc" />


<img width="774" height="301" alt="image" src="https://github.com/user-attachments/assets/69277bc5-24e5-412e-826a-81c972a6212d" />


<img width="900" height="396" alt="image" src="https://github.com/user-attachments/assets/d204478e-85bd-436b-aa1a-f810723b0474" />

En cas d'incident bloquant, remplis ce template dans votre outil de documentation (Confluence, Notion ou autre) pour capitaliser sur l'historique des pannes.

### 5. Livrable C — Template standardisé d'analyse de logs

Voici le document à utiliser dans votre outil de ticketing (Jira, ServiceNow, Azure DevOps ou autre).

>

          FICHE INCIDENT MCO — AZURE DATABRICKS
    1. Identification**
          Numéro de ticket :
          Date / heure de détection :
          Workspace :
          Job ID :
          Job Run ID :
          Task Run ID :
          Task Key :
          Environnement : DEV / QUAL / PROD
          Criticité : P1 / P2 / P3 / P4
          Ingénieur en charge :
     2. Description de l'incident**
          Symptôme observé :
          Message d'erreur exact :
          Première apparition :
          Dernière exécution réussie :
          Nombre d'exécutions impactées :
          Impact métier :
          Données impactées :
    3. Classification**
         Out Of Memory — Driver
         Out Of Memory — Executor
         Data Skew
         Timeout
         Delta Schema Drift
         Delta Concurrency / Conflict
         Infrastructure / Cluster
         Dépendance externe
         Autre
    4. Analyse technique**
         Driver logs :
         Executor logs :
         Spark UI / Stage ID :
         Nombre de partitions :
         Durée d'exécution :
         Mémoire Driver / Executor :
         Shuffle Read / Write :
         Configuration du cluster :
         Version Runtime Databricks :
         Changements récents :
     5. Root Cause Analysis**
         Cause technique :
         Cause racine :
         Facteurs aggravants :
         Pourquoi les contrôles existants n'ont-ils pas détecté le problème ?
         Incident déjà rencontré ? Oui / Non
     6. Remédiation**
         Action corrective :
         Responsable :
         Date / heure :
         Exécution d'un retry ou repair :
         Validation technique :
         Validation métier :
     7. Vérification post-incident**
         Job terminé avec succès
         Données contrôlées
         Absence de doublons
         Absence de perte de données
         Dépendances vérifiées
         Supervision opérationnelle
     8. Prévention**
         Action préventive :
         Automatisation envisageable :
         Seuil de détection :
         Runbook à créer / mettre à jour :
         Date de suivi :
    9. Clôture**
         Statut : OPEN / INVESTIGATION / RESOLVED / CLOSED
         MTTR :
         RCA validée par :
         Retour d'expérience partagé : Oui / Non
>


### 6. Livrable D — Déploiement du contrôle quotidien à 07h30

Nous allons maintenant transformer les requêtes en un processus d'exploitation automatisé.

**D1. Architecture du Workflow**
Je recommande de créer un Job Databricks nommé :

MCO_PROD_DAILY_HEALTH_CHECK

Avec les tâches suivantes :

<img width="758" height="273" alt="image" src="https://github.com/user-attachments/assets/335d29c5-d82e-469b-8ec2-92c063f2399f" />

<img width="1264" height="614" alt="image" src="https://github.com/user-attachments/assets/7473bed8-5cc6-4e2d-80e9-c1bf1d0c63cf" />

**D2. Configuration du déclenchement**

Dans la configuration du Job :

- Schedule : quotidien.

- Heure : 07h30.

- Timezone : Europe/Paris.

- Compute : Job Compute adapté à la charge SQL/Python.

- Retry : une tentative supplémentaire uniquement pour les erreurs transitoires.

- Timeout : à définir selon le SLA de collecte.

Expression Quartz :

>
   0 30 7 * * ?
>

Timezone

>
    Europe/Paris
>

**Attention :** la configuration du fuseau horaire doit être définie explicitement dans le Job, notamment pour gérer correctement les changements heure d'été / heure d'hiver.



**D3. Organisation des notebooks**

Je recommande cette arborescence :

<img width="498" height="560" alt="image" src="https://github.com/user-attachments/assets/640a8923-f3ee-4ab6-8e52-8cb7ef509e3f" />

**D4. Exemple de notebook de consolidation PySpark**

Ce notebook lit les résultats consolidés de la requête SQL et détermine le statut final.

>
                from pyspark.sql import functions as F

               # Configuration
                 CATALOG = "mco_catalog"
                 SCHEMA = "monitoring"

              # Lecture des résultats
               health_df = spark.sql("""
             SELECT *
             FROM system.lakeflow.job_task_run_timeline
             WHERE period_start_time >=
             CURRENT_TIMESTAMP() - INTERVAL 24 HOURS
             """)

             # Agrégation par exécution de tâche
              summary_df = (
              health_df
             .groupBy(
             "workspace_id",
             "job_id",
             "run_id",
             "task_key"
              )
             .agg(
             F.max("result_state").alias("result_state"),
             F.sum(
               F.unix_timestamp("period_end_time")
               - F.unix_timestamp("period_start_time")
               ).alias("duration_seconds")
         )
       )

        # Indicateurs
        metrics_df = summary_df.agg(
        F.count("*").alias("total_tasks"),
  
        F.sum(
           F.when(
             F.col("result_state").isin(
                "FAILED", "ERROR", "TIMED_OUT"
               ), 1
           ).otherwise(0)
       ).alias("failed_tasks")
    )

     metrics = metrics_df.first().asDict()

     total = metrics["total_tasks"] or 0
     failed = metrics["failed_tasks"] or 0

     if failed > 0:
    status = "RED"
    elif total == 0:
    status = "UNKNOWN"
    else:
     status = "GREEN"

    print("===== DAILY HEALTH CHECK =====")
   print(f"Total tasks : {total}")
   print(f"Failed tasks: {failed}")
   print(f"Health      : {status}")
>

Cette version constitue un prototype de consolidation. En production, il faudra également gérer les tâches annulées, bloquées et ignorées, comme dans la requête A4.

**D5. Où stocker les résultats ?**

Je conseille de créer trois tables Delta dans un catalogue dédié au MCO.


>
      CREATE SCHEMA IF NOT EXISTS
      mco_catalog.monitoring;
>

Table 1 : historique des contrôles.

>
        CREATE TABLE IF NOT EXISTS
        mco_catalog.monitoring.daily_health_check (
        execution_date DATE,
        execution_timestamp TIMESTAMP,
        workspace_id STRING,
        total_tasks BIGINT,
        succeeded_tasks BIGINT,
        failed_tasks BIGINT,
        cancelled_tasks BIGINT,
        skipped_tasks BIGINT,
        failure_rate DOUBLE,
        health_status STRING
     )
     USING DELTA;
>

Table 2 : historique des incidents.

>
       CREATE TABLE IF NOT EXISTS
    mco_catalog.monitoring.incidents (
    incident_id STRING,
    detection_timestamp TIMESTAMP,
    workspace_id STRING,
    job_id STRING,
    run_id STRING,
    task_key STRING,
    error_category STRING,
    error_message STRING,
    root_cause STRING,
    incident_status STRING,
    resolution_timestamp TIMESTAMP,
    resolution_action STRING
    )
    USING DELTA;
>

Table 3 : historique des anomalies de performance.
>
      CREATE TABLE IF NOT EXISTS
     mco_catalog.monitoring.performance_anomalies (
     detection_timestamp TIMESTAMP,
     workspace_id STRING,
     job_id STRING,
     task_key STRING,
     run_id STRING,
     observed_duration BIGINT,
     baseline_duration DOUBLE,
     slowdown_factor DOUBLE,
     anomaly_type STRING
   )
    USING DELTA;
>
**Important :** les trois tables sont des structures de stockage. Il faudra ajouter l'écriture MERGE ou INSERT dans les notebooks pour les alimenter, avec une clé d'idempotence afin de ne pas créer de doublons lors des reprises.


<img width="792" height="703" alt="image" src="https://github.com/user-attachments/assets/e14ac65a-01ee-437d-a20c-2f99cdef8ed9" />


**Checklist quotidienne de l'ingénieur MCO**

- [ ] Le Workflow MCO s'est exécuté correctement.

- [ ] Les System Tables sont accessibles.

- [ ] Aucun Job critique n'est en échec.

- [ ] Les traitements critiques ont respecté leurs SLA.

- [ ] Les tâches présentant des ralentissements ont été analysées.

- [ ] Les incidents ont été enregistrés dans le référentiel.

- [ ] Les incidents critiques ont été escaladés.

- [ ] Le compte rendu quotidien a été transmis.
      
**Point de vigilance production :** à 07h30, certaines exécutions de la nuit peuvent être encore en cours ou ne pas avoir été publiées dans les System Tables. Le Health Check doit donc distinguer les exécutions terminées, les exécutions en cours et les données dont la collecte est incomplète. Il ne faut pas déclarer GREEN sur la seule absence d'échecs.

### 8. Corrections et contrôles avant mise en production

Je veux attirer ton attention sur trois points qui évitent des faux positifs en exploitation.

**1. Compatibilité des noms de tables**

Dans ton environnement, commence par :
>
        SHOW TABLES IN system.lakeflow;
        SHOW TABLES IN system.workflow;
>

La référence actuelle est `system.lakeflow.job_task_run_timeline`. Si ton environnement expose encore l'ancien nom `system.workflow.task_runs`, vérifie son schéma avec DESCRIBE TABLE.

Dans les premières requêtes, ne conserve pas la colonne message sans avoir vérifié son existence : le message d'erreur détaillé n'est pas directement fourni par la table de chronologie.

**2. Correction de la requête A1**

Pour éviter de compter plusieurs fois les exécutions longues, utilise cette version agrégée :

>
     WITH task_runs AS (
     SELECT
        workspace_id,
        job_id,
        job_run_id,
        run_id,
        task_key,

        MAX(result_state) AS result_state,
        MAX(termination_code) AS termination_code,

        MIN(period_start_time) AS start_time,
        MAX(period_end_time) AS end_time,

        SUM(
            TIMESTAMPDIFF(
                SECOND,
                period_start_time,
                period_end_time
            )
        ) AS duration_seconds

    FROM system.lakeflow.job_task_run_timeline

    WHERE period_start_time >=
        CURRENT_TIMESTAMP() - INTERVAL 24 HOURS

    GROUP BY
        workspace_id,
        job_id,
        job_run_id,
        run_id,
        task_key
   )

    SELECT *
    FROM task_runs
    WHERE result_state IN (
      'FAILED',
      'ERROR',
      'TIMED_OUT'
   )
   ORDER BY start_time DESC;
>
**3. Gestion des données absentes**

Si aucune donnée n'est disponible, le statut doit être UNKNOWN, et non GREEN. L'absence de données n'est pas une preuve de bon fonctionnement.

### 9. Validation de l'étape 1

Livrables de l'étape 1 présentés
Nous avons maintenant posé les bases de :

- Le Health Check quotidien à 07h30.

- Les requêtes de détection des échecs.

- L'analyse des ralentissements et des récurrences.

- La classification des incidents.

- Le framework RCA.

- Le template de ticket d'incident.

- L'architecture du Workflow MCO.

- Le stockage de l'historique dans Delta Lake.

  Avant de passer à l'étape 2, je souhaite valider deux éléments essentiels concernant ton environnement réel.
