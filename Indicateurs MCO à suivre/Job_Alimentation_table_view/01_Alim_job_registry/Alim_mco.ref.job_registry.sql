/*##############################################################################################################################################################################################################################
#                                                               mco.ref.job_registry

# Objectif: Ce jeu de requêtes met en place un référentiel de gouvernance opérationnelle (mco.ref.job_registry) alimenté automatiquement depuis les tables système Unity Catalog (system.lakeflow.jobs) 
# puis enrichi manuellement (ou via workflow/formulaire) par les équipes MCO et Data Owners.Elle doit etre controlé et alimenté régulièrement avec les équipe lors des réunions.

# La table mco.ref.job_registry.sql contient les champs job_id STRING, job_name STRING, criticite STRING, owner STRING, heure_prevue STRING COMMENT 'HH:mm, heure de Paris',
sla_heure STRING COMMENT 'HH:mm, heure de Paris', runbook_url STRING, actif BOOLEAN);

# Ordre d'alimentation: 1 ( après création des tables)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1    
# Job: L'alimentation de cette table se fait via un pipeline en deux étapes : Automatisation de la structure puis Enrichissement de la gouvernance MCO.
# Table ou View appelée par : mco_ref.table_registry.sql
# Sources ou Sous requetes: system.lakeflow.jobs, ('/Volumes/<catalog>/<schema>/<volume>/jobs_p1.csv')
##############################################################################################################################################################################################################################*/




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


--Pour une mises à jour au fil de l’eau
--Pour un changement isolé (nouveau SLA, runbook rédigé)

UPDATE mco.ref.job_registry
SET runbook_url = '<URL_RUNBOOK>'
WHERE job_id = '<JOB_ID>';
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Étape 3 : Enrichissement par les Owners / MCO (UPDATE)
--2 méthodes de faire la saisie des informations des champs métier criticite,owner,heure_prevue,sla_heure,runbook_url de la table  mco.ref.job_registry:
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                           
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                      --Méthodes 1: Utiliser directement un UPDATE SET

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

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                      --Méthodes 2: Utiliser un un volume et MERGE

--Après l’atelier avec les owners, l’équipe dépose un fichier jobs_p1.csv dans un Volume (disponible dans Alim_mco_metier_job_registry.csv)
--Puis un MERGE met à jour les lignes existantes :
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--fichier jobs_p1.csv à charger dans volume( pour toute nouvelle modification on modifie le jobs_p1.csv puis recharger dans le volume puis executer la MERGE qui alimente le mco.ref.job_registry

--job_id,criticite,owner,heure_prevue,sla_heure,runbook_url
        -- 1001,P1,Équipe Data Ventes,04:00,08:00,'https://wiki.company.internal/databricks/runbooks/etl_finance_pnl'
        -- 1002,P2,Équipe Data Engineering,04:30,<SLA>,<URL_RUNBOOK>
        -- 1003,P2,<OWNER>,<HEURE>,<SLA>,<URL_RUNBOOK>
         --1004,P3,<OWNER>,05:00,<SLA>,<URL_RUNBOOK>

--MERGE qui met à jour les lignes existantes dans mco.ref.job_registry

CREATE OR REPLACE TEMP VIEW src AS
SELECT * FROM read_files('/Volumes/<catalog>/<schema>/<volume>/jobs_p1.csv',
                         format => 'csv', header => true);

MERGE INTO mco.ref.job_registry t
USING src s ON t.job_id = s.job_id
WHEN MATCHED THEN UPDATE SET
  t.criticite = s.criticite, t.owner = s.owner, t.heure_prevue = s.heure_prevue,
  t.sla_heure = s.sla_heure, t.runbook_url = s.runbook_url;

--Pour une mises à jour au fil de l’eau
--Pour un changement isolé (nouveau SLA, runbook rédigé)

UPDATE mco.ref.job_registry
SET runbook_url = '<URL_RUNBOOK>'
WHERE job_id = '<JOB_ID>';
