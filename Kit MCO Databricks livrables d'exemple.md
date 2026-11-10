# Kit MCO Databricks : livrables d'exemple

Poste : Data Engineer MCO Azure Databricks | Version 1.0 | Date de référence : lundi 9 novembre 2026

> Toutes les données ci-dessous sont **fictives** (jobs, run\_id, chiffres, noms). Elles illustrent le format attendu : remplacez-les par vos données de production.

## 1. Rapport matinal 7h30

**Date : lundi 09/11/2026 | Statut global : ORANGE | Rédigé à 07h42**

| Indicateur | Valeur |
| --- | --- |
| Jobs planifiés cette nuit | 42 |
| Réussis | 39 (92,9 %) |
| Échecs | 2 |
| Non démarré | 1 |
| Jobs P1 impactés | 1 (`ingest_sales_daily`) |
| Risque SLA 08h00 | Oui, tableau Ventes J-1 |

**Détail des anomalies**

| Job | Criticité | Run ID | Statut | Cause probable (confiance) | Action | Statut action |
| --- | --- | --- | --- | --- | --- | --- |
| ingest\_sales\_daily | P1 | 48211 | FAILED à 03:12 | Fichier source absent du conteneur landing (élevée) | Contact équipe amont, relance dès réception | En cours |
| refresh\_customer\_360 | P2 | 48230 | FAILED à 04:40 | ConcurrentAppendException (moyenne) | Repair run à 07h50 | À faire |
| export\_finance\_gl | P3 | Un/a | Non démarré (prévu 05:00) | Déclencheur désactivé après déploiement (moyenne) | Réactiver le trigger, lancer manuellement | À faire |

**Dérives de durée :** `build_gold_orders` 74 min contre une médiane de 41 min (x1,8).

**Contrôles data :** fraîcheur OK sur 11 tables clés sur 12. `silver.sales.orders` : dernière ingestion J-1 18:05 (KO).

**Prochaine mise à jour : 08h15.**

## 2. Fiche incident

| Champ | Valeur |
| --- | --- |
| ID | INC-2026-1109-01 |
| Date et heure de détection | 09/11/2026 07:35 (alerte reçue 03:14, non traitée par l'astreinte) |
| Job / run\_id | ingest\_sales\_daily / 48211 |
| Criticité | P1 |
| Symptôme | Task `read_landing` en échec : `FileNotFoundException` sur `abfss://landing@<storage>/sales/2026-11-08/` |
| Impact | Table `silver.sales.orders` non mise à jour, dashboard Ventes J-1 obsolète, 3 consommateurs aval |
| Cause racine | Probable : export de l'ERP en retard (confiance élevée, à confirmer par l'équipe amont) |
| Actions horodatées | 07:35 analyse du run. 07:40 vérification du conteneur (dossier vide). 07:48 appel équipe ERP. |
| Relance | À planifier à réception du fichier : repair run des tâches en échec |
| Vérification data post-relance | Count source vs cible, absence de doublons sur `order_id` |
| Correctif durable | Ajouter une tâche d'attente de fichier avec timeout et alerte, owner : MCO, échéance 20/11 |
| Problème associé | Oui : PB-2026-014 |

## 3. Registre incidents et problèmes

**Incidents**

| ID | Date | Job | Crit. | Catégorie | MTTD | MTTR | Récurrent | Problème |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| INC-1109-01 | 09/11 | ingest\_sales\_daily | P1 | Source en retard | 4 h 23 | en cours | Oui (3e fois en 30 j) | PB-014 |
| INC-1109-02 | 09/11 | refresh\_customer\_360 | P2 | Conflit Delta | 3 h 10 | 25 min | Oui (2e fois) | PB-015 |
| INC-1106-01 | 06/11 | build\_gold\_orders | P2 | OOM executor | 20 min | 1 h 40 | Non | n/a |
| INC-1103-01 | 03/11 | sp\_sync\_hr | P3 | Secret expiré | 15 min | 2 h | Oui (2e fois) | PB-016 |

**Problèmes**

| ID | Titre | Occurrences | Cause racine | Action corrective | Owner | Échéance | Statut |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PB-014 | Fichier ERP livré en retard | 3 | Pas de contrôle d'arrivée ni de dépendance contractuelle | Tâche d'attente fichier + SLA avec l'équipe ERP | MCO + ERP | 20/11 | Ouvert |
| PB-015 | Conflit d'écriture sur customer\_360 | 2 | Deux jobs écrivent la même table en parallèle | Décaler le planning et partitionner le MERGE | DE | 27/11 | Ouvert |
| PB-016 | Expiration du secret SPN | 2 | Rotation manuelle non suivie | Rotation automatisée + alerte J-30 dans Key Vault | Sécurité | 30/11 | Ouvert |

## 4. Runbook exemple : ingest\_sales\_daily

**1. Identité**

| Champ | Valeur |
| --- | --- |
| Owner | Équipe Data Ventes |
| Criticité | P1 |
| Planning | Tous les jours à 03:00 (UTC+1) |
| SLA | Données disponibles avant 07:00 |
| Astreinte | N2 : DE Ventes, N3 : Architecte plateforme |

**2. Rôle fonctionnel :** ingestion des commandes ERP J-1 vers `bronze.sales.orders_raw`, puis `silver.sales.orders`.

**3. Dépendances :** amont : export ERP (fichiers dans `landing/sales/<date>/`). Aval : `build_gold_orders`, dashboard Ventes J-1.

**4. Compute :** job cluster, 4 workers Standard\_DS4\_v2, runtime LTS, autoscaling désactivé.

**5. Erreurs connues**

| Message | Cause | Action |
| --- | --- | --- |
| FileNotFoundException landing | Fichier ERP en retard | Contacter ERP, attendre, relancer |
| ConcurrentAppendException | Écriture simultanée | Attendre la fin de l'autre job, relancer |
| AnalysisException: cannot resolve column | Dérive de schéma amont | Comparer schéma, escalader N2, ne pas relancer |
| 401 / secret expiré | Rotation de secret | Escalader sécurité |

**6. Relance sécurisée**

- Prérequis : fichier source présent, aucun autre run actif, cause de l'échec comprise.
- Idempotence : l'écriture silver utilise un `MERGE` sur `order_id` (relance sans doublon).
- Commande : `POST /api/2.1/jobs/runs/repair` avec `{"run_id": <RUN_ID>, "rerun_all_failed_tasks": true}`.
- Validation : count source vs cible, `max(ingestion_ts)` du jour, aucun doublon sur la clé.

**7. Backfill :** définir les bornes de dates, vérifier l'idempotence, lancer par tranche de 7 jours, valider chaque tranche.

**8. Rollback**

```sql
DESCRIBE HISTORY silver.sales.orders;
RESTORE TABLE silver.sales.orders TO VERSION AS OF <N>;
```

*Validation explicite du N2 requise avant tout RESTORE.*

**9. Historique :** v1.0 (09/11/2026), création.

## 5. Fiche erreur récurrente

| Champ | Contenu |
| --- | --- |
| Message type | `ConcurrentAppendException: Files were added to the partition by a concurrent update` |
| Cause | Deux jobs écrivent dans la même table ou partition |
| Diagnostic en 3 min | `DESCRIBE HISTORY <table>` : repérer deux opérations concurrentes. Vérifier les plannings des jobs. |
| Action | Attendre la fin du job concurrent, puis repair run |
| Prévention | Décaler les plannings, partitionner, ajouter une condition de partition dans le MERGE |
| Lien problème | PB-015 |

## 6. RCA / post-mortem (exemple)

**Incident :** INC-1109-02, refresh\_customer\_360 en échec le 09/11.

**Chronologie**

- 04:30 : `refresh_customer_360` démarre.
- 04:35 : `load_crm_delta` écrit dans la même table.
- 04:40 : échec par `ConcurrentAppendException`.
- 07:50 : repair run, succès à 08:15.

**5 pourquoi**

1. Pourquoi l'échec ? Écritures concurrentes.
2. Pourquoi concurrentes ? Les plannings se chevauchent depuis le déploiement du 02/11.
3. Pourquoi non détecté ? Pas de revue des plannings au déploiement.
4. Pourquoi pas d'alerte rapide ? Alerte P2 envoyée en boîte mail non surveillée la nuit.
5. Pourquoi récurrent ? Aucune règle d'exclusion mutuelle entre jobs partageant une table.

**Cause racine :** absence de contrôle de collision de planning et de conditions de partition dans le MERGE.

| Action | Owner | Échéance | Mesure d'efficacité |
| --- | --- | --- | --- |
| Décaler le planning de 45 min | DE | 12/11 | 0 échec en 30 j |
| Ajouter la condition de partition au MERGE | DE | 27/11 | 0 ConcurrentAppend |
| Checklist de déploiement : revue des plannings | MCO | 20/11 | 100 % des déploiements |

## 7. Dashboard de supervision (spécification)

**Disposition**

1. Bandeau KPI : taux de succès 24 h, jobs en échec, jobs non démarrés, MTTR 30 j.
2. Tableau des échecs de la nuit (requête du contrôle 7h30).
3. Graphique taux de succès par jour sur 30 jours.
4. Top 10 des jobs les plus en échec.
5. Dérive de durée (ratio vs médiane).
6. Fraîcheur des tables clés (feu vert/orange/rouge).
7. Coût DBU par job sur 30 jours.

**Requête : taux de succès journalier**

```sql
SELECT date(period_start_time) AS jour,
       count(*) AS runs,
       sum(CASE WHEN result_state = 'SUCCEEDED' THEN 1 ELSE 0 END) / count(*) AS taux_succes
FROM system.lakeflow.job_run_timeline
WHERE period_start_time >= current_date() - 30
  AND result_state IS NOT NULL
GROUP BY 1 ORDER BY 1;
```

**Requête : jobs planifiés non démarrés (à adapter à votre référentiel)**

```sql
SELECT r.job_id, r.job_name, r.heure_prevue
FROM <catalog>.mco.referentiel_jobs r
LEFT JOIN system.lakeflow.job_run_timeline t
  ON r.job_id = t.job_id
 AND t.period_start_time >= date_trunc('day', current_timestamp())
WHERE t.job_id IS NULL
  AND r.heure_prevue < current_timestamp();
```

**Requête : fraîcheur d'une table**

```sql
SELECT '<table>' AS table_name,
       max(ingestion_ts) AS derniere_ingestion,
       CASE WHEN max(ingestion_ts) < current_timestamp() - INTERVAL 24 HOURS
            THEN 'ROUGE' ELSE 'VERT' END AS statut
FROM <catalog>.<schema>.<table>;
```

## 8. Contrôles data : notebook de contrôle final

```python
from pyspark.sql import functions as F

table = "<catalog>.<schema>.<table>"
key = "<cle_metier>"
df = spark.table(table)
errors = []

# Fraîcheur
last = df.agg(F.max("ingestion_ts")).first()[0]
if last is None or (F.current_timestamp() is None):
    errors.append("Fraîcheur : aucune donnée")

# Doublons
dup = df.groupBy(key).count().filter("count > 1").count()
if dup > 0:
    errors.append(f"Doublons sur {key} : {dup}")

# Nulls sur colonnes obligatoires
for c in ["<col1>", "<col2>"]:
    n = df.filter(F.col(c).isNull()).count()
    if n > 0:
        errors.append(f"Nulls sur {c} : {n}")

# Volumétrie vs J-1 (via DESCRIBE HISTORY / table de métriques)
# comparer count du jour à la médiane 7 jours, seuil <seuil_pct> %

if errors:
    raise Exception("Contrôles KO : " + " | ".join(errors))  # échec bloquant P1
```

*Pensez à remplacer le contrôle de fraîcheur par une comparaison explicite avec l'heure courante et un seuil adapté à chaque table.*

## 9. Matrice d'alerting

| Alerte | Seuil | Criticité | Canal | Destinataire |
| --- | --- | --- | --- | --- |
| Échec job P1 | Immédiat | Critique | Teams + SMS | Astreinte N2 |
| Échec job P2 | Immédiat | Majeure | Teams | Équipe MCO |
| Durée anormale | > 1,5 x médiane | Warning | Teams | Équipe MCO |
| Job non démarré | H + 15 min | Majeure | Teams | Équipe MCO |
| Données non fraîches | 07:00 | Majeure | Teams + mail | MCO + owner |
| Secret proche expiration | J - 30 | Warning | Mail | Sécurité + MCO |

## 10. Rapport MCO hebdomadaire (exemple)

**Semaine 45 : du 02/11 au 08/11/2026**

| Indicateur | S45 | S44 | Tendance |
| --- | --- | --- | --- |
| Taux de succès jobs | 96,4 % | 97,8 % | En baisse |
| Incidents P1 | 2 | 1 | En hausse |
| Incidents P2 | 5 | 6 | Stable |
| MTTR moyen | 1 h 55 | 2 h 20 | En amélioration |
| MTTD moyen | 1 h 10 | 1 h 25 | En amélioration |
| Relances automatiques | 4 sur 11 (36 %) | 2 sur 12 | En hausse |
| Respect SLA 07h30 | 4 jours sur 5 | 5 sur 5 | En baisse |
| Coût total DBU | 12 480 | 11 950 | +4,4 % |

**Faits marquants :** déploiement du 02/11 à l'origine de collisions de planning ; retard ERP récurrent sur les ventes.

**Problèmes :** 3 ouverts (PB-014, PB-015, PB-016), 0 clos cette semaine.

**Actions de la semaine suivante :** décaler le planning de customer\_360, créer l'alerte de fichier manquant, finaliser 2 runbooks P1.

**Points de décision :** SLA contractuel avec l'équipe ERP à valider avec le management.

## 11. Revue mensuelle : tableau des KPI

| KPI | Définition | Cible | Octobre (exemple) |
| --- | --- | --- | --- |
| Taux de succès | Runs réussis / runs totaux | > 98 % | 97,2 % |
| MTTD | Délai entre échec et détection | < 15 min | 42 min |
| MTTR | Délai entre détection et résolution | < 2 h | 2 h 05 |
| Incidents récurrents | Même cause >= 2 fois | Baisse de 30 % | 8 |
| % incidents avec runbook | Incidents couverts / total | 100 % P1 | 64 % |
| % relances automatisées | Relances auto / relances totales | > 50 % | 31 % |
| Respect SLA 7h30 | Jours conformes / jours ouvrés | 100 % | 90 % |
| Problèmes clos | Nombre clos dans le mois | >= 3 | 2 |

## 12. Support de formation (30 min) : lire un échec de job

| Minutes | Contenu |
| --- | --- |
| 0 à 5 | Objectif et cas réel : INC-1109-02 |
| 5 à 12 | Parcours Workflows : run, tâche, sortie, logs driver |
| 12 à 20 | Démo : requêtes system tables pour trouver la tâche en cause |
| 20 à 27 | Exercice en sandbox : diagnostiquer un échec fourni et décider relance ou escalade |
| 27 à 30 | Quiz et rappel des règles (aucune relance sur erreur de données) |

**Quiz rapide**

1. Quand utilise-t-on un repair run plutôt qu'une relance complète ?
2. Quel risque une relance fait-elle courir sur une table sans MERGE idempotent ?
3. Quelle commande permet de revenir à une version précédente d'une table Delta ?

*Réponses attendues : 1) quand seules certaines tâches ont échoué et que les autres ont produit des résultats valides. 2) des doublons. 3) `RESTORE TABLE ... TO VERSION AS OF`.*

## 13. Utilisation du kit

- Copiez chaque section en document de travail, remplacez les valeurs fictives par vos données.
- Alimentez le registre à chaque incident, et la revue mensuelle à partir des requêtes KPI.
- Vérifiez les colonnes des system tables selon votre configuration avant de produire les dashboards.
