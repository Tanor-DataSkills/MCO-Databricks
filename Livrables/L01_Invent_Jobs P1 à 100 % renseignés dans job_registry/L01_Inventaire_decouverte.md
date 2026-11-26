**Date:**

**Nom du livrable:** Livrable 1: Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites)

**Ordre de livraison:** Première livraison (semaine 1)

**Requêtes SQL concernées:** Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites).sql

**Critère de validation:** Jobs P1 à 100 % renseignés dans job_registry ; validé par le management

**Type de livrables: 1 tableau**

**Version:**




# Livrable 1: Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites)

### C'est le premier livrable à fournir.



<img width="1861" height="186" alt="image" src="https://github.com/user-attachments/assets/31913e4e-02fb-43ff-8ee8-1e74e938e2ba" />




## Interprétation et plan d'action pour le premier livrable MCO

Pour faire de cette première extraction un livrable MCO opposable et actionnable auprès des équipes Run/Build, voici la lecture opérationnelle des résultats et les actions associées :

### 1. Sécuriser le périmètre critique (P1 et criticités manquantes)
   
- Constat sur l'exemple : J-102 (P1) démarre à 03:50 pour 03:00 déclaré (+50 min) et met 25 min, soit une fin médiane à 04:15 pour un SLA à 04:30 (marge réduite à 15 min, avec un taux de succès à 93,3 %). Par ailleurs, J-999 tourne en production sans criticité ni owner.

- Action :

  - [ ] Traiter en priorité 100 % des anomalies sur les P1 (recaler l'ordonnancement de J-102 ou vérifier la dépendance amont avec J-101).

  - [ ] Qualifier immédiatement les jobs sans criticite (J-999) afin de ne pas laisser un traitement potentiellement critique en fin de liste (ELSE 4).

### 2. Lancer une campagne de remédiation du référentiel (mco.ref.job_registry)
   
Constat sur l'exemple : J-205 (P2) fonctionne en production mais n'a ni owner, ni SLA, ni runbook_url. En cas d'incident la nuit, l'astreinte ne sait ni qui escalader ni quelle procédure appliquer.

Action :

- Exporter les lignes présentant owner manquant, SLA manquant ou runbook manquant et fixer un jalon (ex. sous 15 jours) aux Tech Leads pour compléter mco.ref.job_registry.

- Imposer ces champs comme prérequis bloquants lors de la mise en production de tout nouveau job.

### 3. Assainir les jobs « fantômes » et les faux positifs techniques
   
**Constat sur l'exemple :** J-310 est marqué actif mais n'a aucun run CRON sur 30 jours et aucune table produite.

**Action :**

- Si le job est décommissionné : passer g.actif = false dans job_registry pour nettoyer le livrable.

- Si le job tourne autrement (déclenchement événementiel, API, ou export vers un fichier/SFTP hors Unity Catalog) : documenter ce mode dans le référentiel ou adapter la requête (par exemple en intégrant d'autres trigger_type dans la CTE runs ou en distinguant les jobs d'export).

### 4. Affiner deux règles métier pour la V2 du livrable
   
- Gestion des jobs infra-journaliers (horaires / micro-batch) : le calcul debut_med_min et la comparaison avec une heure_prevue unique génèrent des faux positifs (planning déclaré ≠ observé) sur les jobs qui tournent toutes les heures. Prévoir un champ frequence (DAILY, HOURLY, EVENT) pour n'appliquer le contrôle d'écart horaire que sur les jobs journaliers.

- Ajout d'une colonne de marge SLA : croiser demarrage_observe + duree_med_min avec g.sla_heure permettra d'afficher directement un indicateur de risque de dépassement de SLA dès le premier coup d'œil.


### Actions à faire après l'inventaire

- Priorité 1 : traiter les anomalies des jobs P1 jusqu'à zéro (owner, SLA, planning, runbook). Chargez les corrections par CSV, comme décrit pour job_registry.

- Compléter les tables produites manquantes avec les owners, puis les inscrire dans table_registry avec leurs seuils.

- Ajouter à la main les dépendances non détectées pour les P1 (livraisons ERP, déclencheurs).

- Corriger les plannings déclarés faux, ou ouvrir un problème si le job se déclenche de façon imprévue.

- Ouvrir un problème pour chaque P1 sous 98 % de succès et chaque job sans run.

- Rédiger les runbooks dans l'ordre : P1 avec le plus de jobs aval d'abord.

- Figer l'inventaire : export en livrable daté, puis relance mensuelle de la requête pour suivre le nombre d'anomalies.
