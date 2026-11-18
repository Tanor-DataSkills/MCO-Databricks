## Runbook : export_finance_gl (P3, job non démarré)

<img width="380" height="314" alt="image" src="https://github.com/user-attachments/assets/5d4e8fb6-2f21-45ae-8027-8cbf29b98e4f" />


**Rôle et dépendances :** export de la comptabilité générale (destinataire : À COMPLÉTER)

<img width="1503" height="224" alt="image" src="https://github.com/user-attachments/assets/5647a6aa-40d0-44d7-9dcd-62c6e623c625" />

**Relance sécurisée :**

• Prérequis : trigger réactivé, aucune exécution déjà faite par un autre moyen (pour éviter un double export)

• Idempotence : À COMPLÉTER ; vérifier auprès de la finance qu’un export réalisé en retard n’est pas dupliqué

• Validation : run SUCCEEDED, fichier ou table d’export présent, finance prévenue

**Correctifs durables :** ajouter la vérification du planning à la checklist de déploiement ; brancher l’alerte SQL sur v_jobs_not_started.
