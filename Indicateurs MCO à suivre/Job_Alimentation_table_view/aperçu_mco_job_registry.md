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
