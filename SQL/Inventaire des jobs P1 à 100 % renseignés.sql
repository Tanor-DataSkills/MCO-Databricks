-- Objectifs: Faire l'inventaire complet des jobs 100% renseignés(priorisant les P1) et non renseignés
--Livrables concernés: Livrable 1: Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites)

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
