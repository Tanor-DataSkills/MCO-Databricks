-- Objectifs: Faire l'inventaire complet des jobs 100% renseignés(priorisant les P1) et non renseignés
-- Livrables concernés: Livrable 1: Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites)

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                       --Inventaire des Jobs P1 complets à 100 %
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    job_id,
    job_name,
    criticite,
    owner,
    heure_prevue,
    sla_heure,
    runbook_url,
    actif
FROM mco.ref.job_registry
WHERE actif = true
  AND UPPER(TRIM(criticite)) = 'P1'
  AND TRIM(COALESCE(job_id, '')) <> ''
  AND TRIM(COALESCE(job_name, '')) <> ''
  AND TRIM(COALESCE(owner, '')) <> ''
  AND TRIM(COALESCE(heure_prevue, '')) <> ''
  AND TRIM(COALESCE(sla_heure, '')) <> ''
  AND TRIM(COALESCE(runbook_url, '')) <> ''
ORDER BY sla_heure ASC, heure_prevue ASC, job_name ASC;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                       --Inventaire des Jobs non renseignés
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    job_id,
    job_name,
    criticite,
    owner,
    heure_prevue,
    sla_heure,
    runbook_url,
    actif,
    CONCAT_WS(
        ', ',
        CASE WHEN TRIM(COALESCE(criticite, '')) = '' THEN 'criticite' END,
        CASE WHEN TRIM(COALESCE(owner, '')) = '' THEN 'owner' END,
        CASE WHEN TRIM(COALESCE(heure_prevue, '')) = '' THEN 'heure_prevue' END,
        CASE WHEN TRIM(COALESCE(sla_heure, '')) = '' THEN 'sla_heure' END,
        CASE WHEN TRIM(COALESCE(runbook_url, '')) = '' THEN 'runbook_url' END
    ) AS champs_manquants
FROM mco.ref.job_registry
WHERE actif = true
  AND (
       TRIM(COALESCE(criticite, '')) = ''
    OR TRIM(COALESCE(owner, '')) = ''
    OR TRIM(COALESCE(heure_prevue, '')) = ''
    OR TRIM(COALESCE(sla_heure, '')) = ''
    OR TRIM(COALESCE(runbook_url, '')) = ''
  )
ORDER BY
    CASE UPPER(TRIM(COALESCE(criticite, '')))
        WHEN 'P1' THEN 1
        WHEN 'P2' THEN 2
        WHEN 'P3' THEN 3
        ELSE 0
    END ASC,
    job_name ASC;
