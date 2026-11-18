## Livrables 1: Rapport MCO matinal 7h30

1- On commence par exécuter la requête `Jobs échecs-reussis.sql` pour avoir le nombre de **jobs reussis** et **echecs**

2- jobs **planifiés et non démarrés** sont fournis par la requête `Jobs planifiés non démarrés.sql`.Il faut au préalable que la table référentielle `mco.referentiel_jobs` soit déja alimentée par l’API Jobs (GET /api/2.1/jobs/list, champ schedule) puis enrichi à la main(car les tables systeme ne disposent pas l'info).

3- Pour avoir les détails des jobs avec anomalies; jobs en échec survenus durant la fin de nuit et le début de matinée (fenêtre glissante débutant 2 heures avant le début de la journée courante). Elle sert de base au contrôle matinal (type /check7h30) pour repérer les anomalies impactant les rapports métiers de la journée. La requête `Jobs échecs de la nuit.sql` dont les champs ci-dessous:
**job_name, job_id, run_id, result_state, termination_code, period_start_time, period_end_time**

4- La requête `dérive de la durée.sql` permet d'apprécier les jobs longs à surveiller(l'interprétation dépend de la comparaison entre le percentile de durée et la durée. Voir tableau d'interprétation dérive de durée.

5- Pour avoir le controle data ou la fraicheur des tables on utilise la requete `fraîcheur.sql`

6- Pour chaque job échoué on effectue un diagnostic de niveau 2 (investigation d'incident) suite à la détection d'un run global en échec. Puisque la `Jobs échecs de la nuit.sql` a identifié que les jobs en echec et les run_id associés. On utilise les run_id en echec dans la requête `Tache en cause.sql` pour identifier la tâche exacte qui a fait échouer l'ensemble du DAG.
Résultat attendu :
• Identifier la tâche en échec.
• Identifier son état d'exécution.
• Identifier le code de terminaison.
• Déterminer à quel moment l'incident s'est produit.
Pour chaque task le terminal_code donne le message d'érreur permet d'avoir les infos comme symptomes(FileNotFoundException, ConcurrentAppendException) , causes racines(Fichier non livré ou livraison en retard, Écriture concurrente,...) pour créer la fiche d'incident avec 

## 7- Diagnostique - Cause - Action

- Si **Symptome : `ConcurrentAppendException`** on peut utiliser la requête  DESCRIBE HISTORY silver.sales.orders.
  
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
     
- Si le **Symptome** est **FileNotFoundException** on peut utiliser la requête `diagnostic FileNotFoundException.sql` pour vérifier dans ADLS la présence ou pas du fichier afin de confirmer la cause et de savoir quel action faire.

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

- Si le symptome est 403 Forbidden ou AuthorizationPermissionMismatch il faut Contrôler les autorisations RBAC et ACL.

- Si le symptome est OutOfMemoryError ou arrêt d'un executor pour manque de mémoire, on Examine les stages, executors et tâches.

- Si le symptome est Incompatibilité entre le schéma source et le schéma de la table Delta on examine le schema source en Exécutant DESCRIBE TABLE silver.sales.orders.

- Si le symptome est Échec d'authentification ou erreur liée à un secret expiré il faut Contrôler la date d'expiration et l'identité utilisée.
- Si JobTimeout / SLAExceeded   lors Examiner les durées des dernières exécutions et Identifier les stages les plus longs.

- Si DeltaConcurrentModificationException alors Consulter DESCRIBE HISTORY.
