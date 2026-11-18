Runbook : refresh_customer_360 (P2, conflit Delta)

<img width="781" height="397" alt="image" src="https://github.com/user-attachments/assets/8d7e2f13-ae65-42e0-b087-068bb66df9d7" />


**Rôle et dépendances :**

rafraîchit la vue client 360 (table de sortie : À COMPLÉTER). Écrit dans la même table que load_crm_delta, d’où le conflit constaté. Aval : À COMPLÉTER.


<img width="1505" height="251" alt="image" src="https://github.com/user-attachments/assets/dbbfd35a-e8b8-4f91-a062-ec0b987f1541" />


**Relance sécurisée :**

• Prérequis : le run de load_crm_delta est terminé, aucun autre run de refresh_customer_360 n’est actif.
• Idempotence : l’écriture semble se faire par MERGE (analyse PB-015) ; à confirmer avec l’owner avant de relancer.
• Commande : repair run (commandes communes).

>
    # Statut d’un run
    curl -s "$DATABRICKS_HOST/api/2.1/jobs/runs/get?run_id=<RUN_ID>" -H "Authorization: Bearer $TOKEN"

    # Relance des seules tâches en échec (repair run)
    curl -X POST "$DATABRICKS_HOST/api/2.1/jobs/runs/repair" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"run_id": <RUN_ID>, "rerun_all_failed_tasks": true}'
>

• Validation : run SUCCEEDED, volume proche de J-1, aucun doublon sur la clé client, fraîcheur du jour.

>
    DESCRIBE HISTORY <catalog>.<schema>.<table> LIMIT 20;
    -- Rollback, validation explicite du N2 requise :
    RESTORE TABLE <catalog>.<schema>.<table> TO VERSION AS OF <N>;
>

• Précédent : le 09/11, repair run à 07:50, succès à 08:15 (25 min).

**Rollback :** RESTORE de la table vers la version précédant l’écriture fautive, après validation du N2.

**Correctifs durables :** décaler le planning de 45 min (12/11) ; ajouter la condition de partition au MERGE (27/11) ; ajouter la revue des plannings à la checklist de déploiement (20/11).
