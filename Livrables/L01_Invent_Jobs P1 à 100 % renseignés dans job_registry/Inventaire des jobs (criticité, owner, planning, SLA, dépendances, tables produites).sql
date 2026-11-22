----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                      L01  --Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites)
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Il permet notamment d'identifier les jobs critiques, leurs responsables, leurs horaires, leur niveau de service, leurs dépendances et les tables qu'ils alimentent.

WITH runs AS (
  SELECT job_id, run_id, etat, duree_s,
         from_utc_timestamp(start_time, 'Europe/Paris') AS debut
  FROM mco.monitoring.v_job_runs
  WHERE start_time >= current_date() - 30 AND trigger_type = 'CRON'),
obs AS (
  SELECT job_id,
         count(*) AS runs_30j,
         round(100 * avg(CASE WHEN etat = 'SUCCEEDED' THEN 1 ELSE 0 END), 1) AS succes_pct,
         round(percentile(duree_s, 0.5) / 60, 0) AS duree_med_min,
         CAST(percentile(hour(debut) * 60 + minute(debut), 0.5) AS INT) AS debut_med_min
  FROM runs WHERE etat <> 'EN_COURS' GROUP BY job_id),
lin AS (
  SELECT DISTINCT CAST(entity_metadata.job_info.job_id AS STRING) AS job_id,
         source_table_full_name AS src, target_table_full_name AS tgt
  FROM system.access.table_lineage
  WHERE entity_metadata.job_info.job_id IS NOT NULL
    AND event_date >= current_date() - 30),
prod AS (SELECT job_id, tgt AS table_name FROM lin WHERE tgt IS NOT NULL GROUP BY job_id, tgt),
cons AS (SELECT job_id, src AS table_name FROM lin WHERE src IS NOT NULL GROUP BY job_id, src),
dep AS (  -- c lit une table produite par p : p est en amont de c
  SELECT c.job_id AS aval_id, p.job_id AS amont_id
  FROM cons c JOIN prod p ON c.table_name = p.table_name AND c.job_id <> p.job_id
  GROUP BY c.job_id, p.job_id),
tp AS (SELECT job_id, collect_set(table_name) AS tables FROM prod GROUP BY job_id),
am AS (SELECT d.aval_id AS job_id, collect_set(g2.job_name) AS jobs
       FROM dep d JOIN mco.ref.job_registry g2 ON d.amont_id = g2.job_id GROUP BY d.aval_id),
av AS (SELECT d.amont_id AS job_id, collect_set(g2.job_name) AS jobs
       FROM dep d JOIN mco.ref.job_registry g2 ON d.aval_id = g2.job_id GROUP BY d.amont_id)
SELECT g.job_id, g.job_name, g.criticite, g.owner,
       g.heure_prevue AS planning_declare,
       concat(lpad(CAST(o.debut_med_min DIV 60 AS STRING), 2, '0'), ':',
              lpad(CAST(o.debut_med_min % 60 AS STRING), 2, '0')) AS demarrage_observe,
       g.sla_heure,
       array_join(array_sort(tp.tables), ', ') AS tables_produites,
       array_join(array_sort(am.jobs), ', ')   AS jobs_amont,
       array_join(array_sort(av.jobs), ', ')   AS jobs_aval,
       o.runs_30j, o.succes_pct, o.duree_med_min, g.runbook_url,
       concat_ws(' | ',
         if(g.criticite IS NULL, 'criticité manquante', NULL),
         if(g.owner IS NULL, 'owner manquant', NULL),
         if(g.sla_heure IS NULL, 'SLA manquant', NULL),
         if(g.heure_prevue IS NULL, 'planning non déclaré', NULL),
         if(g.heure_prevue IS NOT NULL AND o.debut_med_min IS NOT NULL
            AND abs(CAST(split(g.heure_prevue, ':')[0] AS INT) * 60
                    + CAST(split(g.heure_prevue, ':')[1] AS INT) - o.debut_med_min) > 30,
            'planning déclaré ≠ observé', NULL),
         if(tp.tables IS NULL, 'aucune table produite détectée', NULL),
         if(g.runbook_url IS NULL, 'runbook manquant', NULL),
         if(o.runs_30j IS NULL, 'aucun run planifié en 30 j', NULL)) AS anomalies
FROM mco.ref.job_registry g
LEFT JOIN obs o ON g.job_id = o.job_id
LEFT JOIN tp ON g.job_id = tp.job_id
LEFT JOIN am ON g.job_id = am.job_id
LEFT JOIN av ON g.job_id = av.job_id
WHERE g.actif
ORDER BY CASE g.criticite WHEN 'P1' THEN 1 WHEN 'P2' THEN 2 WHEN 'P3' THEN 3 ELSE 4 END,
         g.job_name;
