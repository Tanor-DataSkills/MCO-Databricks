## Générer le rapport manuellement dans les 3 premiers jours avant automatisation( la disponibilité des dashboards et alerts teams)

Avant que les vues D1 et le dashboard D1 Contrôle 7h30 ne soient en place, on exécute manuellement les requêtes ci-dessous pour exploiter leurs sorties:

### A- Jobs echec-reussis.sql: Total_runs, reussis, echecs

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

**Taux de succes = 41/48 = 85,4%**

### B- Requête Jobs planifiés-non démarés.sql : (à adapter à votre référentiel)

les jobs planifiés et non démarrés les tables système ne détiennent pas l'information. Il faut donc créer une table référentielle mco.referentiel_jobs (job_id, criticité, heure prévue, SLA, owner), alimenté une fois par l’API Jobs (GET /api/2.1/jobs/list, champ schedule) puis enrichi à la main. Le total « 42 planifiés » est le nombre de lignes de ce référentiel attendues la nuit.

>
     SELECT r.job_id, r.job_name, r.heure_prevue
     FROM <catalog>.mco.referentiel_jobs r
     LEFT JOIN system.lakeflow.job_run_timeline t
     ON r.job_id = t.job_id
     --Ne conserver dans la jointure que les exécutions démarrées depuis minuit, tout en gardant dans le résultat les jobs n'ayant aucune exécution aujourd'hui (grâce au LEFT JOIN)
     AND t.period_start_time >= date_trunc('day', current_timestamp())  
     WHERE t.job_id IS NULL   --Ne garde que les jobs pour lesquels aucune ligne n'a été trouvée dans job_run_timeline depuis le début de la journée
     AND r.heure_prevue < current_timestamp();
>

Liste des jobs bien présents dans le reférentiel mais pas démarrés(absent dans system.lakeflow.job_run_timeline) de minuit à maintenant

<img width="585" height="101" alt="image" src="https://github.com/user-attachments/assets/4b82f219-6539-4a5d-a12d-d50c794f0a3e" />


**Jobs planifiés non démarrés = 2**

### C- Requête Jobs echecs de la nuit.sql : Détail des incidents (Détection globale des incidents récents « échecs de la nuit » (Échecs et non-démarrés))

En MCO (Maintien en Condition Opérationnelle), cette requête sert à superviser et diagnostiquer les exécutions de jobs qui ne se sont pas terminées avec succès sur une fenêtre temporelle récente (typiquement pour le suivi de production, l'astreinte ou le triage d'incidents).
Elle sert de base au contrôle matinal (type /check7h30) pour repérer les anomalies impactant les rapports métiers de la journée.

>
     SELECT j.name, t.job_id, t.run_id, t.result_state,
            t.termination_code, t.period_start_time, t.period_end_time
     FROM system.lakeflow.job_run_timeline t
     JOIN (SELECT job_id, name,
             ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY change_time DESC) rn
           FROM system.lakeflow.jobs) j
     ON t.job_id = j.job_id AND j.rn = 1
     WHERE t.period_end_time >= date_trunc('day', current_timestamp()) - INTERVAL 2 HOURS
     AND t.result_state IN ('FAILED','ERROR','TIMED_OUT','CANCELED')
     ORDER BY t.period_end_time DESC;
>

<img width="1512" height="165" alt="image" src="https://github.com/user-attachments/assets/916c064b-a7e0-403b-8eff-bb8612baac60" />


### Lecture rapide en exploitation:

**etl_facturation_quotidienne (FAILED) :** échec récent à surveiller en priorité (impact potentiel sur le reporting ou la facturation du soir).

**sync_referentiel_clients (TIMED_OUT) :** a atteint sa durée maximale autorisée après 2 heures ; vérifier un volume anormal ou un verrou côté source/cible.

**ml_scoring_churn_nuit (CANCELED) :** arrêté manuellement (USER_CANCELED) ; vérifier si un opérateur l'a coupé volontairement lors d'une opération de maintenance.

**ingest_evenements_iot (ERROR) :**  incident côté fournisseur cloud en fin de soirée la veille, visible uniquement parce que le filtre remonte à 22:00 la veille.

---

### Pour remplir le tableau détail des anomalies:


<img width="1281" height="602" alt="image" src="https://github.com/user-attachments/assets/cd3f7135-e323-42a4-bc5b-aed8bcd86043" />

---

• **Job, run ID, statut, heure :** sont disponibles dans Requête 02 « échecs de la nuit »

• **Criticité :** colonne de la table référentiel

• **Cause probable et confiance :** jugement de l’analyste, appuyé sur le termination_code, les logs du driver et DESCRIBE HISTORY de la table. Aucune requête ne la fournit

• **Action et statut :** saisis à la main, ou récupérés du ticketing


### D- requête Dérive de durée.sql: Dérive de durée (dernier run vs médiane 30 j)

Son objectif principal est de détecter les dérives de performances et l'instabilité temporelle des jobs sur une fenêtre glissante de 30 jours, en s'appuyant sur les tables système d'Unity Catalog (system.lakeflow.job_run_timeline). Elle met en lumière les traitements dont le temps d'exécution maximal dépasse de plus de 50% ($ratio > 1.5$) leur temps médian habituel, signalant un risque potentiel sur les SLA de restitution des données.

il ne suffit pas de constater que le job a pris du temps mais l'intérêt est de savoir la cause racine qui repose sur l'inspection de quatre grands coupables en production.

>
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
>

<img width="1519" height="524" alt="image" src="https://github.com/user-attachments/assets/ee7441b2-510d-4e81-ab59-c259815052b2" />

---

**Dérives de durée : build_gold_orders 74 min contre une médiane de 41 min (x1,8)**

**1- Analyse de la dispersion (Médiane vs Max) :**

- L'utilisation de la médiane (percentile(dur, 0.5)) permet d'ignorer le bruit statistique quotidien. Si la médiane est stable mais que le max s'envole (ex: job_silver_sales_412 avec un ratio de 3.0), cela indique un comportement non déterministe ou dépendant de la volumétrie externe.
    
- Le cas spécifique de job_gold_orders_991 (74 min vs 41 min, ratio 1.8) montre un dépassement significatif qui commence à rogner la marge de sécurité avant l'ouverture des rapports métiers à 8h00.
    
**2- Causes racines typiques identifiées par ce pattern :**

- Data Skew (1) : Répartition inégale des clés de partitioning dans Delta Lake, provoquant l'attente de la dernière task (effet straggler)
    
- Problème de Petits Fichiers (Small Files) (2) : Accumulation de micro-fichiers nécessitant une maintenance (OPTIMIZE / VACUUM manquée)
    
- Contention de ressources (3) : Jobs concurrents planifiés à la même heure sur le même pool de serveurs ou le même cluster partagé, générant de la mise en attente (queueing)
    
- Volumétrie amont variable (4) : Un système source qui livre un volume de données 2 à 3 fois supérieur certains jours de la semaine (ex: lundis ou fins de mois)
    
**3- Plan d'action MCO immédiat :**

- Pour les jobs dont le ratio dépasse 2.0 (ex: job_silver_sales_412, job_ml_scoring_002), programmer une analyse des logs d'exécution par task (requete 2 system.lakeflow.task_run_timeline) pour identifier le goulet d'étranglement (Shuffle read/write, GC, I/O)
    
- Vérifier la politique d'autoscaling des clusters associés et planifier une revue de code Spark (optimisation des jointures, broadcast joins, partitions)
    
- Pour affiner l'analyse d'un job spécifique et identifier si le goulet d'étranglement lié aux durées d'exécution des tâches ou à des erreurs de planification on utilise la requête 2 afin d'identifier le  ou les tasks ayant causé c retard


**Contrôles data**

### E- Requête Fraicheur.sql: Santé d’une table Delta (fraîcheur, petits fichiers)

Ces deux commandes servent à auditer, diagnostiquer et superviser l'état d'une table transactionnelle sans lire les données métier elles-mêmes.

**Contrôles data : fraîcheur OK sur 11 tables clés sur 12. silver.sales.orders : dernière ingestion J-1 18:05 (KO)**

>
    DESCRIBE HISTORY <catalog>.<schema>.<table> LIMIT 20;
    DESCRIBE DETAIL  <catalog>.<schema>.<table>;
>

**Exemples DESCRIBE HISTORY:**

>
     DESCRIBE HISTORY silver.sales.orders LIMIT 20;
>

<img width="1428" height="570" alt="image" src="https://github.com/user-attachments/assets/43a9c1ca-df20-414c-a8f2-bf29839892f2" />

---

• La dernière modification de la table remonte à hier (J-1) à 18:05 (Version 3)

• Aucune écriture n'a eu lieu lors du batch de nuit (normalement planifié entre 02:00 et 04:00 aujourd'hui). Cela confirme l'absence de rafraîchissement des données pour la journée en cours

**Exemples DESCRIBE DETAIL:**

>
     DESCRIBE DETAIL silver.sales.orders;
>

<img width="1805" height="135" alt="image" src="https://github.com/user-attachments/assets/9456a4ab-3f2c-432a-80f2-c8619ed165ff" />

---

• La date de dernière modification (lastModified) est figée au 06/06 à 18:05

• La table comporte 14 fichiers pour une taille d'environ ~45 Mo, ce qui indique qu'aucun phénomène de small files explosion critique n'est présent pour le moment, mais l'absence de mise à jour bloque le pipeline aval (Gold)


**Conclusion - Contrôles Data (MCO)**

1- État de la fraîcheur des données : OK sur 11 tables clés sur 12

2- Anomalie détectée :

- La table silver.sales.orders est en KO : sa dernière ingestion valide date de J-1 à 18:05, ce qui indique l'échec ou le saut du traitement planifié de la nuit dernière
    
- Impact aval : Les agrégations et dashboards de la couche Gold basés sur silver.sales.orders affichent des données obsolètes (stale data)
    
- Action corrective immédiate : Lancer le diagnostic du job d'ingestion associé via son job_id pour identifier le blocage (erreur de source, timeout ou verrou Unity Catalog) avant de relancer manuellement le pipeline
    
### 6- Redaction du rapport 

- Appliquer les règles du statut, remplir le modèle, ajouter une note
  
- Relire (P1 : second avis), publier avant 8h dans le canal teams avant 08h
  
- Actualiser dans le même fil si la situation a changé à 08 h 15(Message de suivi à faire sur le canal)
  
- Après publication, ouvrez ou complétez les incidents du registre (avec detecte_ts) et archivez le rapport


### F- Requête Tâche en cause: Analyse complémentaire (System Tables - Niveau Tasks / Erreurs)

Maintenant que le constat est fait et que le rapport matinal est mis à la disposition des équipes, on doit mettre en place une fiche d'incident pour chacune des erreurs.
L'objectif  de cette requête est d'effectuer un diagnostic de niveau 2 (investigation d'incident) suite à la détection d'un run global en échec. Puisque la requête 1 a identifié que les run_id = 983472,48211, 48230  ont échoué, cette requête liste toutes les tâches qui composaient ce workflow pour identifier la tâche exacte qui a fait échouer l'ensemble du DAG. 
Cette requête est très importante pour remplir la fiche d'incident avec des informations telles que: symptomes, Cause racine apparente, Impact aval


>
      SELECT task_key, result_state, termination_code, period_start_time, period_end_time
      FROM system.lakeflow.job_task_run_timeline
      WHERE run_id = 983472 ORDER BY period_start_time;
>


<img width="1313" height="143" alt="image" src="https://github.com/user-attachments/assets/02623756-e56c-4881-9c56-f726ec682807" />

• **Symptôme :** Le job ingest_sales_daily a échoué à 03:12  en 15 minutes. Le job aval transform_bronze_to_silver a également été annulé par ricochet (CANCELED)

• **Cause racine apparente :** La tâche read_landing a échoué avec le code de terminaison AZURE_STORAGE_CONNECTION_ERROR (problème d'accès ou indisponibilité temporaire d'ADLS / expiration de SAS token ou Managed Identity / problème réseau)

• **Impact aval :** Vu que la source brute n'a pas pu être lue par read_landing, la tâche suivante transform_bronze_to_silver n'a pas pu s'exécuter, ce qui bloque net la mise à jour de la table cible silver.sales.orders, impactant le SLA de mise à disposition des données métiers pour les équipes

Pour l'automatisation un job rapport_matinal_teams doit etre créer qui va composer et envoyer le message à partir des vues ; vous ajoutez seulement la note.
