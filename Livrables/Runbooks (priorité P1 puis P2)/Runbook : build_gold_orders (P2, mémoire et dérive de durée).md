## Runbook : build_gold_orders (P2, mémoire et dérive de durée)

<img width="782" height="403" alt="image" src="https://github.com/user-attachments/assets/f6ed7029-a51b-451b-8f1c-dbe50dc546bd" />

**Rôle et dépendances :** construit la couche gold des commandes à partir de silver.sales.orders. Amont : `ingest_sales_daily`. Aval : À COMPLÉTER.

<img width="1519" height="390" alt="image" src="https://github.com/user-attachments/assets/91aebb66-6e0b-4c78-a598-4be49f20b9f8" />

**Relance sécurisée :**

• Prérequis : silver.sales.orders est à jour pour le jour (sinon la table gold serait calculée sur des données périmées, cas du 09/11 où l’ingestion était en échec), cause de l’OOM traitée, aucun autre run actif.
• Idempotence : À COMPLÉTER (mode d’écriture de la table gold) ; sans MERGE ni overwrite, risque de doublons.
• Validation : volume vs J-1, fraîcheur, doublons sur la clé.

**Rollback :** RESTORE de la table gold, validation N2 requise.

**Correctifs durables :** ajuster la taille du cluster ou traiter le skew (suite de l’incident du 06/11) ; alerte de dérive de durée sur ce job.
