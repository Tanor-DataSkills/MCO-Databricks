### Simulation d'exécution (Avant / Après)

**État avant exécution :** Le Job 101 a été renommé, le Job 102 existe déjà, le Job 103 a été supprimé de Databricks, et un nouveau Job 104 vient d'être créé.

**Résultat après exécution du MERGE :**


<img width="1129" height="175" alt="image" src="https://github.com/user-attachments/assets/dd245204-7464-4ea2-bd9f-8c9d71659549" />


**Interprétation des résultats :** Le job 104 inséré possède des attributs MCO vides (NULL). C'est précisément sur ces enregistrements que l'équipe MCO doit intervenir.


### Comment alimenter et enrichir la table (Process MCO)

L'alimentation de cette table se fait via un pipeline en deux étapes : Automatisation de la structure puis Enrichissement de la gouvernance MCO.

**Étape 1 : Synchronisation automatique (Job planifié)**

Le script MERGE ci-dessus doit être exécuté de manière quotidienne ou horaire dans un workflow Databricks pour intégrer automatiquement les nouveaux jobs et désactiver les anciens.

**Étape 2 : Détection des nouveaux jobs à qualifier (Requête de contrôle)**

Pour identifier les nouveaux pipelines apparus suite au MERGE qui nécessitent une classification MCO, exécute la requête de contrôle suivante (priorité aux P1) :
>
      SELECT 
            job_id, 
            job_name, 
            actif
      FROM mco.ref.job_registry
      WHERE actif = true 
      AND (criticite IS NULL OR owner IS NULL)
      ORDER BY job_name ASC;
>

**Étape 3 : Enrichissement par les Owners / MCO (UPDATE)**

Une fois les nouveaux jobs identifiés, l'équipe MCO complète les informations opérationnelles en se coordonnant avec les équipes de développement (en commençant impérativement par les flux critiques P1) :

>
   -- Exemple d'affectation pour un job critique P1 nouvellement détecté
      UPDATE mco.ref.job_registry
      SET 
         criticite = 'P1',
         owner = 'Data Engineering Core',
         sla_heure = '07:00',
         runbook_url = 'https://wiki.company.internal/databricks/runbooks/etl_finance_pnl'
      WHERE job_id = 104;
>
