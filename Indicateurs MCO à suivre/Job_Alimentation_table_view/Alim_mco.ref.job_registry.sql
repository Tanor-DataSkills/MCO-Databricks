--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Étape 1 : Synchronisation automatique (Job planifié)
--Ce script MERGE doit être exécuté de manière quotidienne ou horaire dans un workflow Databricks pour intégrer automatiquement les nouveaux jobs et désactiver les anciens
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
MERGE INTO mco.ref.job_registry t
USING (SELECT job_id, name FROM (
         SELECT job_id, name, delete_time,
                row_number() OVER (PARTITION BY job_id ORDER BY change_time DESC) rn
         FROM system.lakeflow.jobs)
       WHERE rn = 1 AND delete_time IS NULL) s
ON t.job_id = s.job_id
WHEN MATCHED THEN UPDATE SET t.job_name = s.name  --Si un job_id existe déjà dans la table cible mco.ref.job_registry et que son nom a changé, elle met à jour job_name
WHEN NOT MATCHED THEN INSERT (job_id, job_name, actif) VALUES (s.job_id, s.name, true) --Si un nouveau job apparaît dans le catalogue Unity Catalog mais n'est pas encore référencé dans le MCO, elle l'insère en initialisant le champ actif = true
WHEN NOT MATCHED BY SOURCE THEN UPDATE SET t.actif = false;  
--Si un job présent dans la table cible mco.ref.job_registry n'est plus retourné par la source (job supprimé ou désactivé durablement), elle bascule son statut à actif = false 
--au lieu de le supprimer physiquement (ce qui préserve les liens avec les incidents passés)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Etape 2: Détection des nouveaux jobs à qualifier (Requête de contrôle)
--Pour identifier les nouveaux pipelines apparus suite au MERGE qui nécessitent une classification MCO, exécute la requête de contrôle (priorité aux P1) 
--Afin de remplir manuellement les champs métier (criticite, owner, SLA_heure) pour l'enrichissement de la gouvernance MCO:
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT 
    job_id, 
    job_name, 
    actif
FROM mco.ref.job_registry
WHERE actif = true 
  AND (criticite IS NULL OR owner IS NULL)
ORDER BY job_name ASC;

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Étape 3 : Enrichissement par les Owners / MCO (UPDATE)
--Une fois les nouveaux jobs identifiés, l'équipe MCO complète les informations opérationnelles en se coordonnant avec les équipes de développement 
--(en commençant impérativement par les flux critiques P1) :
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Exemple d'affectation pour un job critique P1 nouvellement détecté
UPDATE mco.ref.job_registry
SET 
    criticite = 'P1',
    owner = 'Data Engineering Core',
    sla_heure = '07:00',
    runbook_url = 'https://wiki.company.internal/databricks/runbooks/etl_finance_pnl'
WHERE job_id = 104;


