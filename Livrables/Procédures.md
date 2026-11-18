# 1- Plan d’action

**Semaine 1 : cartographier et sécuriser**

Inventaire des jobs/workflows : criticité (P1/P2/P3), propriétaire, planning, SLA, dépendances amont/aval, tables produites.

Obtenir les accès : workspace, system tables, Log Analytics, outil de ticketing, Key Vault (lecture).

Dérouler le contrôle 7h30 en doublon avec un collègue, noter les points de friction.

Lister les 10 incidents les plus fréquents des 3 derniers mois.

**Semaines 2-3 : stabiliser**

Standardiser le contrôle 7h30 (checklist + notebook/dashboard unique).

Runbooks des 10 jobs critiques et des 5 erreurs récurrentes.

Alertes de base : échec, dépassement de durée, job non démarré.

Premiers problèmes ouverts (RCA sur les top récurrents).

**Semaines 4-6 : industrialiser**

Dashboard de supervision (Databricks SQL ou Power BI) et KPI MCO.

Contrôles data : fraîcheur, volumétrie, schéma, doublons, nulls.

Automatisation : relance auto sur erreurs transitoires (retries, backoff), notebook de diagnostic, résumé matinal automatique.

**Semaines 7-12 : transmettre et améliorer**

Sessions de formation (une par erreur récurrente), exercices de relance en sandbox.

Revue mensuelle des problèmes et des KPI.

Réduction des coûts et durées (clusters, tailles, concurrence).


# 2- Livrables : 

## A- Rapport MCO matinal 7h30

1- On commence par exécuter la requête `Jobs échecs-reussis.sql` pour avoir le nombre de **jobs reussis** et **echecs**

2- jobs **planifiés et non démarrés** sont fournis par la requête `Jobs planifiés non démarrés.sql`.Il faut au préalable que la table référentielle `mco.referentiel_jobs` soit déja alimentée par l’API Jobs (GET /api/2.1/jobs/list, champ schedule) puis enrichi à la main(car les tables systeme ne disposent pas l'info).

3- Pour avoir les détails des jobs avec anomalies; jobs en échec survenus durant la fin de nuit et le début de matinée (fenêtre glissante débutant 2 heures avant le début de la journée courante). Elle sert de base au contrôle matinal (type /check7h30) pour repérer les anomalies impactant les rapports métiers de la journée. La requête `Jobs échecs de la nuit.sql` dont les champs ci-dessous:
**job_name, job_id, run_id, result_state, termination_code, period_start_time, period_end_time**

4- La requête `dérive de la durée.sql` permet d'apprécier les jobs longs à surveiller(l'interprétation dépend de la comparaison entre le percentile de durée et la durée. Voir tableau d'interprétation dérive de durée.

5- Pour avoir le controle data ou la fraicheur des tables on utilise la requete `fraîcheur.sql`

6- Pour chaque job échoué on effectue un diagnostic de niveau 2 (investigation d'incident) suite à la détection d'un run global en échec. Puisque la `Jobs échecs de la nuit.sql` a identifié que les jobs en echec et les run_id associés. On utilise les run_id en echec dans la requête `Tache en cause.sql` pour identifier la tâche exacte qui a fait échouer l'ensemble du DAG.
Résultat attendu :

• Identifier la tâche en échec

• Identifier son état d'exécution

• Identifier le code de terminaison

• Déterminer à quel moment l'incident s'est produit

Pour chaque task le **terminal_code** donne le message d'érreur permet d'avoir les infos comme symptômes(**FileNotFoundException, ConcurrentAppendException**) , causes racines(Fichier non livré ou livraison en retard, Écriture concurrente,...) pour créer la fiche d'incident avec 

## 7- Diagnostique - Causes - Actions

### A- ConcurrentAppendException`

- Si **Symptome : `ConcurrentAppendException`** lors d'une écriture dans une table Delta.On peut utiliser la requête  DESCRIBE HISTORY silver.sales.orders.
  
  **Cause possible :**
     - [ ] Écriture concurrente** (Plusieurs jobs écrivent simultanément dans la même table)
  
  **Diagnostique :**
     - [ ]  Exécuter la requête fraicheur.sql pour avoir l'historique de la table delta
     - [ ]  dentifier les jobs ayant écrit simultanément

  **Résolution :**
     - [ ] Attendre la fin de l'écriture concurrente
     - [ ] Décaler les plannings et optimiser les conditions du MERGE

  **Relance :**
     - [ ] Vérifier au préalable que l'écriture concurrente est terminée
           
  **Validation :**
     - [ ] Vérifier SUCCEEDED, les volumes et les doublons

  **Prévention :**
     - [ ] Revoir l'orchestration des jobs et les conditions de partitionnement
  
  **Escalade :**
     - [ ] Escalader au N2 si les conflits persistent


### B- DeltaConcurrentModificationException

- Si le **Symptome** est **DeltaConcurrentModificationException** alors il s'agit d' **Échec d'une transaction Delta à la suite d'une modification concurrente.**


 **Causes possibles :**
   - [ ] Transactions concurrentes (Plusieurs opérations modifient simultanément les mêmes données)
   - [ ] Conflit de fichiers (Opérations incompatibles sur des fichiers ou partitions communes)
  
  **Diagnostique :**
   - [ ]  Historique Delta(Consulter DESCRIBE HISTORY)
   - [ ]  Exécutions(Identifier les jobs responsables des modifications concurrentes)

  **Résolution :**
   - [ ] Coordination (Attendre la fin des transactions et examiner la stratégie d'écriture)
   - [ ] Optimisation (Revoir les périmètres d'écriture et les opérations concurrentes)

  **Relance :**
   - [ ] Conditions préalables (Vérifier l'absence de conflit et l'intégrité des données)
           
  **Validation :**
   - [ ] Vérifier l'historique Delta, les volumes et les doublons

  **Prévention :**
   - [ ] Revoir l'orchestration et les périmètres de modification
  
  **Escalade :** Escalader au N2 pour analyse approfondie

### C- FileNotFoundException
     
- Si le **Symptome** est **FileNotFoundException** lors de la lecture des fichiers ERP dans ADSL

  **Causes possibles :**
   - [ ] Livraison ERP (Fichier non livré ou livraison en retard)
   - [ ] Répertoire absent ou vide(Chemin source incorrect ou fichiers indisponibles)
   - [ ] Date incorrecte(Date calculée par le job erronée)
   - [ ] Permissions(Droits d'accès ADLS insuffisants (403))
         
  
  **Diagnostique :**
   - [ ]  on peut utiliser la requête `diagnostic FileNotFoundException.sql` pour vérifier dans ADLS la présence ou pas du fichier afin de confirmer la cause et de savoir quel action faire:
        - [ ] Si Dossier vide ou absent : Livraison ERP (Fichier non livré ou livraison en retard)
        - [ ] Si Dossier présent : vérifier la date calculée par le job et le chemin paramétré.
        - [ ] Si Erreur de droits : escalader.
        - [ ] Dans les deux cas, vérifiez si l’erreur est déjà arrivée récemment : à partir de 2 occurrences, ouvrez un problème.
    
  **Résolution :**
     - [ ] Si c'est un Fichier absent, Contacter l'équipe ERP et attendre la livraison
     - [ ] Si c'est un Chemin incorrect, Corriger le paramétrage via le N2.
     - [ ] Si Erreur 403(Si Erreur de droits), Escalader au N2 pour correction des permissions
     - [ ] Si les Fichiers présents, Vérifier leur complétude avant toute reprise

  **Relance :**
     - [ ] Vérifier au préalable que les Fichiers complets, cause identifiée et corrigée, aucun run concurrent
           
  **Validation :**
     - [ ] Vérifier SUCCEEDED, les volumes et les doublons

  **Prévention :**
     - [ ] Ajouter une tâche d'attente des fichiers avec timeout à 07:00 et une alerte explicite

  **Escalade :**
     - [ ] À partir de 2 occurrences récentes, ouvrir un problème pour rechercher la cause racine.


### D- 403 Forbidden ou AuthorizationPermissionMismatch
  
- Si le **Symptome** est **403 Forbidden ou AuthorizationPermissionMismatch** il faut Contrôler les autorisations RBAC et ACL.

**Causes possibles:**
 
   - [ ] RBAC (Rôle Azure insuffisant)
   - [ ] ACL (Permissions manquantes sur le répertoire ADLS)
   - [ ] Identité (Service Principal ou Managed Identity incorrecte)
  
  **Diagnostique :**
  - [ ]  Vérification des droits (Contrôler les autorisations RBAC et ACL)
  - [ ]  Identité (Vérifier l'identité utilisée par le job)

  **Résolution :**
  - [ ] Correction des droits (Faire intervenir l'équipe Azure / N2)
  - [ ] Conditions préalables (Confirmer le rétablissement des permissions)

  **Relance :**
  - [ ] Conditions préalables(Confirmer le rétablissement des permissions)
        
  **Validation :**
  - [ ] Contrôle post-reprise(Vérifier l'accès aux fichiers et le statut du job)

  **Prévention :**
  - [ ] Actions correctives(Mettre en place une revue périodique des droits)

  **Escalade :**
  - [ ] Récurrence (Escalader au N3 si le problème concerne l'infrastructure ou l'identité Azure)


  ### E- OutOfMemoryError (OOM)
  
- Si le **Symptome** est **OutOfMemoryError** ou **arrêt d'un executor pour manque de mémoire**, on Examine les stages, executors et tâches.

**Causes possibles:**
 
   - [ ] Volume important (Augmentation du volume de données)
   - [ ] Partitionnement (Partitions trop volumineuses ou déséquilibrées)
   - [ ] Compute (Ressources mémoire insuffisantes)
  
  **Diagnostique :**
  - [ ]  Spark UI (Examiner les stages, executors et tâches)
  - [ ]  Compute (Vérifier l'utilisation CPU et mémoire)

  **Résolution :**
  - [ ] Optimisation (Analyser les partitions, les jointures et les traitements consommateurs de mémoire)
  - [ ] Compute (Étudier une augmentation des ressources avec validation N2)

  **Relance :**
  - [ ] Conditions préalables(Cause identifiée et ressources ou traitement corrigés)
        
  **Validation :**
  - [ ] Contrôle post-reprise(Vérifier le statut, les volumes et les temps d'exécution)

  **Prévention :**
  - [ ] Actions correctives(Optimiser le partitionnement et surveiller les volumes)

  **Escalade :**
  - [ ] Escalader au N3 si le problème est lié aux limites de capacité Azure

### F- SchemaMismatch / Schema Evolution

- Si le **symptome** est **Incompatibilité entre le schéma source et le schéma de la table Delta** on examine le schéma source en Exécutant DESCRIBE TABLE silver.sales.orders.


**Causes possibles:**
 
   - [ ] Évolution ERP (Ajout, suppression ou modification d'une colonne)
   - [ ] Typage (Incompatibilité de types de données)
   - [ ] Contrat de données (Modification non anticipée du format source)
  
  **Diagnostique :**
  - [ ]  Schéma source (Examiner le schéma des fichiers ERP)
  - [ ]  Schéma cible (Exécuter DESCRIBE TABLE silver.sales.orders)
  - [ ]  Analyse (Identifier les différences et leur impact fonctionnel)

  **Résolution :**
  - [ ] Analyse (Identifier les différences et leur impact fonctionnel)
  - [ ] Correction (Adapter le mapping et faire valider l'évolution du schéma)

  **Relance :**
  - [ ] Conditions préalables(Schéma compatible et correction validée)
        
  **Validation :**
  - [ ] Contrôle post-reprise(Vérifier les colonnes, les types et l'intégrité des données)

  **Prévention :**
  - [ ] Actions correctives(Mettre en place des contrôles de conformité du schéma source)

  **Escalade :**
  - [ ] Recurrence(Solliciter le N2 et l'Owner fonctionnel ERP)
        

  ### G- SecretExpired / AuthenticationFailure    
  
- Si le **Symptome**  **SecretExpired / AuthenticationFailureest** signifie un **Échec d'authentification ou erreur liée à un secret expiré.** il faut Contrôler la date d'expiration et l'identité utilisée.


**Causes possibles:**
 
   - [ ] Expiration (Secret ou certificat expiré)
   - [ ] Configuration (Mauvais identifiant ou configuration d'authentification)
   - [ ] Identité (Problème de Service Principal ou Managed Identity)
  
  **Diagnostique :**
  - [ ]  Vérification (Contrôler la date d'expiration et l'identité utilisée)

  **Résolution :**
  - [ ] Renouvellement (Renouveler le secret selon la procédure de sécurité)

  **Relance :**
  - [ ] Conditions préalables(Authentification testée et accès rétabli)
        
  **Validation :**
  - [ ] Contrôle post-reprise(Vérifier la connexion à la source et le statut du job)

  **Prévention :**
  - [ ] Actions correctives(Mettre en place des alertes d'expiration anticipées)

  **Escalade :**
  - [ ] Recurrence(Escalader au N2 ou à l'équipe sécurité)


### H- JobTimeout / SLAExceeded

- Si **Symptome** est **JobTimeout / SLAExceeded** signifie que Le job dépasse son temps d'exécution attendu ou son timeout configuré. Alors Examiner les durées des dernières exécutions et Identifier les stages les plus longs.

**Causes possibles:**
 
   - [ ] Volume (Augmentation du volume traité)
   - [ ] Compute (Ressources insuffisantes)
   - [ ] Dépendance (Retard d'un job amont ou d'une livraison ERP)
   - [ ] Performance (Requête Spark ou MERGE trop coûteux)
  
  **Diagnostique :**
  - [ ] Historique (Examiner les durées des dernières exécutions)
  - [ ]  Spark UI (Identifier les stages les plus longs)


  **Résolution :**
  - [ ] Optimisation (Analyser les performances et les dépendances)
  - [ ] Orchestration (Adapter les horaires ou les dépendances après validation)

  **Relance :**
  - [ ] Conditions préalables(Vérifier qu'aucun run concurrent n'est actif et que la cause est corrigée)
        
  **Validation :**
  - [ ] Contrôle post-reprise(Confirmer la disponibilité des données avant le SLA)

  **Prévention :**
  - [ ] Actions correctives(Définir des seuils d'alerte et suivre les temps d'exécution)

  **Escalade :**
  - [ ] Informer le N2 et les consommateurs métier en cas de risque SLA


### I- DataQualityFailure


- Si **Symptome** est **DataQualityFailure** signifie qu'il y'a **Échec d'un contrôle de qualité des données**.

  
**Causes possibles:**
 
   - [ ] Doublons (Plusieurs enregistrements pour une même clé métier)
   - [ ] Données nulles (Présence de valeurs obligatoires manquantes)
   - [ ] Volume (Écart important avec le volume attendu)
   - [ ] Fraîcheur (Données trop anciennes ou incomplètes)
  
  **Diagnostique :**
  - [ ] Unicité (Vérifier les doublons sur la clé métier)
  - [ ] Complétude (Vérifier les colonnes obligatoires)
  - [ ] Fraîcheur (Contrôler la dernière date d'ingestion)


  **Résolution :**
  - [ ] Analyse source (Identifier l'origine de l'anomalie)
  - [ ] Correction (Corriger ou faire corriger les données sources)

  **Relance :**
  - [ ] Conditions préalables(Données corrigées et contrôles de qualité satisfaits)
        
  **Validation :**
  - [ ] Contrôle post-reprise(Vérifier les règles de qualité et la cohérence métier)

  **Prévention :**
  - [ ] Actions correctives(Automatiser les contrôles et les alertes qualité)

  **Escalade :**
  - [ ] Informer le N2 et l'Owner métier

   
   On peut maintenant générer **Rapport MCO matinal 7h30** grâce aux infos dont nous disposons avant de créer les incidents:

  RAPPORT MCO 7h30 – 2026-11-18
  Statut global : ROUGE


<img width="827" height="315" alt="image" src="https://github.com/user-attachments/assets/4b21d116-2bc9-4d17-8fae-32c1e9692213" />


Contrôles effectués : 6/6

Incidents ouverts :
- INC-20261109-02 refresh_customer_360 (run 48230) [P2] Conflit Delta : ouvert
  
- INC-20261109-01 ingest_sales_daily (run 48211) [P1] Source en retard : ouvert

Incidents du jour :

- aucun


Notes : 

P1 ingest_sales_daily (run 48211) : échec à 03:12, 

fichier ERP absent de landing/sales

Équipe ERP contactée à 07:48. Relance (repair run) dès réception du fichier

Risque SLA 08:00 sur le tableau Ventes J-1

INC-2026-1109-01, 3e occurrence en 30 j (PB-014)

P2 refresh_customer_360 (run 48230) : ConcurrentAppendException à 04:40, 2e occurrence (PB-015)

Repair run prévu à 07:50, après la fin de load_crm_delta

P3 export_finance_gl : non démarré (prévu 05:00), trigger désactivé après le déploiement

Réactiver le trigger puis lancer à la main

build_gold_orders : 74 min contre 41 min en médiane (x1,8), à surveiller

Fraîcheur : silver.sales.orders KO (dernière ingestion J-1 18:05), les 11 autres tables clés sont OK

Prochaine mise à jour : 08:15
