- Fréquence: Un par job, P1 d’abord (100 % des P1 à la semaine 6)
  
- Contenu: Identité, dépendances, erreurs connues, relance, backfill, rollback

# RUNBOOK

Le Runbook est un document de reférence qui sert à résoudre rapidement des incidents. Il donne la marche à suivre exacte pour rétablir le service sans avoir à improviser. 
Le Runbook servira de guide pour corriger et traiter les incidents.

## Méthodologie:

A- commencer par rédiger un Runbook par job, en commençant par les P1 (objectif : 100 % à la semaine 6).

B- Après chaque incident, ajoutez la nouvelle erreur de la table erreurs récurrentes(en bas).

C- Faites-le relire par l’owner du job, puis testez-le en sandbox avec un collègue qui ne connaît pas le job : si il y arrive, le runbook est bon.

D- Revoyez-le à chaque modification majeure du pipeline.

## Runbook par job

1. Fiche d'identité : nom, owner, criticité, planning, SLA
2. Rôle fonctionnel, sources, sorties (tables), dépendances
3. Compute : type de cluster, taille, pool, libs
4. Où regarder : lien run, logs, dashboard
5. Erreurs connues → cause → action (tableau)
6. Procédure de relance : prérequis, idempotence, commande, validation
7. Procédure de reprise/backfill : bornes de dates, nettoyage préalable
8. Rollback (Delta RESTORE TO VERSION AS OF)
9. Escalade : N2/N3, astreinte, contacts
10. Historique des révisions

## Exemple Runbook par job**

**Runbook ingest_sales_daily (v1.1)**

**1- Fiche d'identité :**

<img width="689" height="406" alt="image" src="https://github.com/user-attachments/assets/50f59ce9-9c10-42e1-80c0-ce9a31398836" />

**2- Rôle fonctionnel :**

• **Source :** ERP, fichiers déposés dans landing/sales

• **Sortie :** silver.sales.orders, alimentée par MERGE

• **Aval :** À COMPLÉTER (jobs, dashboards, consommateurs)

**3- Dépendances :** 

amont : export ERP (fichiers dans landing/sales). Aval : À COMPLÉTER (jobs, dashboards, consommateurs)

**4- Compute :** 

job cluster, 4 workers Standard_DS4_v2, runtime LTS, autoscaling désactivé

**5- Où regarder (tâche en cause) :** 

Exécutez la requête `Tache en cause.sql`

>
    SELECT task_key, result_state, termination_code, period_start_time, period_end_time
    FROM system.lakeflow.job_task_run_timeline
    WHERE run_id = <RUN_ID>
    ORDER BY period_start_time;
>

**6- Erreurs connues :** 

Au cas où le job en question aurait connu d'autres erreurs on les renseigne sur la table ci-dessous:


**Diagnostic FileNotFoundException**
>
   display(dbutils.fs.ls("abfss://landing@<storage_account>.dfs.core.windows.net/sales/<DATE>/"))
>

• Dossier vide ou absent : livraison en retard.
• Dossier présent : vérifier la date calculée par le job et le chemin paramétré.
• Erreur de droits : escalader.
Dans les deux cas, vérifiez si l’erreur est déjà arrivée récemment : à partir de 2 occurrences, ouvrez un problème.

**7-Relance sécurisée :**

• Fichiers du jour présents et complets (nombre et taille cohérents avec J-1)

• Aucun autre run actif sur ce job

• Cause comprise et corrigée

• Pour ConcurrentAppendException : l’écriture concurrente est terminée

• Idempotence : l'écriture dans silver.sales.orders se fait par MERGE : une relance ne crée pas de doublon, à condition que la clé de merge soit unique côté source (clé à confirmer : À COMPLÉTER, <cle_metier>)

• Commande : repair run des seules tâches en échec (code ci-dessous)

• Validation : run en SUCCEEDED, volume proche de J-1, aucun doublon sur la clé, fraîcheur du jour (requêtes ci-dessous), puis prévenir les consommateurs aval

Commande & Validation

>
    curl -X POST "$DATABRICKS_HOST/api/2.1/jobs/runs/repair" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"run_id": <RUN_ID>, "rerun_all_failed_tasks": true}'
>

>
    -- Doublons sur la clé
      SELECT <cle_metier>, count(*) c
      FROM silver.sales.orders
      GROUP BY 1 HAVING c > 1;

     -- Fraîcheur
      SELECT max(<colonne_ingestion>) FROM silver.sales.orders;
>

**8- Backfill :** 

Définir les bornes de dates, relancer par tranches (par exemple 3 jours) et valider chaque tranche (doublons, volume, fraîcheur) avant la suivante. Le MERGE permet de rejouer une tranche sans doublon.

Il répond à la question Comment rattraper plusieurs jours (bornes, tranches, validation) ?

**9- Rollback :** 

>
  DESCRIBE HISTORY silver.sales.orders;
  RESTORE TABLE silver.sales.orders TO VERSION AS OF <N>;
>

Validation explicite du N2 requise avant tout RESTORE : les consommateurs aval peuvent avoir déjà lu les données.
Il répond à la question Comment revenir en arrière (RESTORE TABLE ... TO VERSION AS OF) si la reprise a mal tourné ?
Le Rollback est soumis à validation explicite du N2, car c’est une action destructive.

**10- Correctifs durables :**

1-  Tâche d'attente du fichier (timeout 07:00) avec alerte explicite en début de workflow.
2-  Heure de livraison ERP contractualisée. 
3-  Revue des plannings des jobs qui écrivent dans silver.sales.orders et condition de partition dans le MERGE.

**11- Historique :** 


<img width="741" height="533" alt="image" src="https://github.com/user-attachments/assets/53285ec5-4bbd-4d93-b800-19d84647b0cd" />

v1.1 (14/11/2026), complété avec les données réelles du job.
Elle répond à la question Quelle version, quand mise à jour ?

**12- Escalade :** N2/N3, astreinte, contacts

**Fiche erreurs récurrentes :**

Après chaque incident on rempli la table ci-dessous:

<img width="842" height="565" alt="image" src="https://github.com/user-attachments/assets/e8a7db23-b911-44b5-8336-6cc9b99d8cf1" />
