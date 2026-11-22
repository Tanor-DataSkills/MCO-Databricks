----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                      L01  --Inventaire des jobs (criticité, owner, planning, SLA, dépendances, tables produites)
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Objectif: Il permet notamment d'identifier les jobs critiques, leurs responsables, leurs horaires, leur niveau de service, leurs dépendances et les tables qu'ils alimentent.
--Ordre de création: Livrable 1 ( après création de mco.ref.job_registry, mco.monitoring.v_job_runs, system.access.table_lineage)
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Sous requetes: runs + obs + lin + prod + cons + dep + tp + am + av + mco.ref.job_registry
--runs: la view mco.monitoring.v_job_runs (vue de télémétrie d'exécution) : historise les lancements de jobs (job_id, run_id, etat, duree_s, start_time en UTC, trigger_type)     
--obs: Calcul des statistiques d'execution pour les job terminés dans les 30 derniers jors(nbre de runs (runs_30j), le taux de succès (succes_pct), la durée médiane en minutes (duree_med_min) et l'heure médiane de début exprimée en minutes depuis minuit (debut_med_min)
--lin: Extrait et dédoublonne les relations de lignage entre jobs et tables sur les 30 derniers jours(dépendances job-tables) à partir des journaux système de Unity Catalog (system.access.table_lineage)
--prod: Tables produites (écrites) par chaque job
--cons: Tables consommées en lecture par chaque job
--dep: Dépendance entre les jobs(amont-aval).(Ce bloc relie les jobs consommateurs (cons c) aux jobs producteurs (prod p) lorsqu'ils partagent la même table (c.table_name = p.table_name) tout en excluant qu'un job soit considéré en amont/aval de lui-même (c.job_id <> p.job_id). Le GROUP BY dédoublonne les paires (aval_id, amont_id) (par exemple si deux tables relient le même couple de jobs).
--tp: Si un job JOB_001 produit à la fois 2 tables (silver.erp.commandes et silver.erp.lignes_cmd) alors on associe job_id et une colonne nommée tables contenant ["silver.erp.commandes", "silver.erp.lignes_cmd"]
--am: Depuis mco.ref.job_registry on récupère le nom du job qu'on met en liste pour l'associer au amont_id
--av: Depuis mco.ref.job_registry on récupère le nom du job qu'on met en liste pour l'associer au aval_id                                        
--Select final (runs + jobs + mco.ref.job_registry(Récupération des champs métiers mco): Enrichissement MCO et calcul d'indicateurs

-- Les executions de job déclenchés par planification dans les 30 derniers jours avec debut en heure Europe/Paris)                                        
WITH runs AS (
  SELECT job_id, run_id, etat, duree_s,
         from_utc_timestamp(start_time, 'Europe/Paris') AS debut  --et convertit start_time vers le fuseau local Europe/Paris
  FROM mco.monitoring.v_job_runs
  WHERE start_time >= current_date() - 30 AND trigger_type = 'CRON'), --filtre les exécutions des 30 derniers jours (current_date() - 30) déclenchées par planification (trigger_type = 'CRON') 

  --Calcule, pour chaque job_id les statistiques d'exécution réelles(le volume de runs (runs_30j), le taux de succès (succes_pct), la durée médiane en minutes (duree_med_min) et l'heure médiane de début exprimée en minutes depuis minuit (debut_med_min))
  obs AS (
  SELECT job_id,
         count(*) AS runs_30j,                                                              --le nombre total de runs terminés sur les 30 derniers jours pour ce job
         round(100 * avg(CASE WHEN etat = 'SUCCEEDED' THEN 1 ELSE 0 END), 1) AS succes_pct, --taux de succès
         round(percentile(duree_s, 0.5) / 60, 0) AS duree_med_min,                        -- duree mediane des execution d'un job
         CAST(percentile(hour(debut) * 60 + minute(debut), 0.5) AS INT) AS debut_med_min  --extrait l'horaire médian de démarrage en minutes depuis minuit
  FROM runs WHERE etat <> 'EN_COURS' GROUP BY job_id), --exclusion des runs en cours afin de n'analyser que des exécutions terminées (succès, échec, annulé, etc.) et regroupe tout par job_id (GROUP BY job_id)

  --Quel job lit quelle table (src) et écrit dans quelle table (tgt) dans les 30 derniers jours.
  lin AS (
  SELECT DISTINCT CAST(entity_metadata.job_info.job_id AS STRING) AS job_id,
         source_table_full_name AS src, target_table_full_name AS tgt
  FROM system.access.table_lineage
  WHERE entity_metadata.job_info.job_id IS NOT NULL  --Accéder à une structure imbriquée (STRUCT) et ne garder que les événements rattachés à un job (et exclut par exemple les requêtes ad hoc exécutées interactivement dans un notebook ou l'éditeur SQL sans job_id)
    AND event_date >= current_date() - 30),
                                        
prod AS (SELECT job_id, tgt AS table_name FROM lin WHERE tgt IS NOT NULL GROUP BY job_id, tgt), --isoler uniquement les tables produites (écrites) par chaque job
cons AS (SELECT job_id, src AS table_name FROM lin WHERE src IS NOT NULL GROUP BY job_id, src), --isoler uniquement les tables consommées en lecture par chaque job

--Si le job JOB_001 produit la table silver.erp.commandes que le job JOB_002 à son tour lit(consomme) la table silver.erp.commandes pour produire une autre table(gold.sales.kpi_ventes)
-- alors JOB_002 est en aval de JOB_001 (JOB_001 est en amont de JOB_002 via silver.erp.commandes)                                     
dep AS (  -- c lit une table produite par p : p est en amont de c
  SELECT c.job_id AS aval_id, p.job_id AS amont_id    -- Un job_id associé à une table consommée c est appelé aval_id; Un job_id associé à une table produite p est appelé amont_id
  FROM cons c JOIN prod p ON c.table_name = p.table_name AND c.job_id <> p.job_id
  GROUP BY c.job_id, p.job_id),

--Si le job JOB_001 produit à la fois 2 tables (silver.erp.commandes et silver.erp.lignes_cmd) alors on associe job_id et une colonne nommée tables contenant ["silver.erp.commandes", "silver.erp.lignes_cmd"]                                       
tp AS (SELECT job_id, collect_set(table_name) AS tables FROM prod GROUP BY job_id),

--On associe à chacun des jobs_id aval_id et amont_id de la dep à des noms de job obtenus depuis mco.ref.job_registry g2 qu'on met en liste                  
am AS (SELECT d.aval_id AS job_id, collect_set(g2.job_name) AS jobs
       FROM dep d JOIN mco.ref.job_registry g2 ON d.amont_id = g2.job_id GROUP BY d.aval_id),
av AS (SELECT d.amont_id AS job_id, collect_set(g2.job_name) AS jobs
       FROM dep d JOIN mco.ref.job_registry g2 ON d.aval_id = g2.job_id GROUP BY d.amont_id)

SELECT g.job_id, g.job_name, g.criticite, g.owner,
       g.heure_prevue AS planning_declare,
                                        
    --debut_med_min est stocké en nombre de minutes depuis minuit (ex. 135 pour 02:15) Il faut un concat et lpad pour ajouter un zéro à gauche si nécessaire pour transformer 135 en 02:15.
    --si on classe toutes les heures de démarrage observées de la plus tôt à la plus tard, la moitié des exécutions ont démarré avant ou à cette heure, et l'autre moitié après ou à cette heure                                    
      concat(lpad(CAST(o.debut_med_min DIV 60 AS STRING), 2, '0'), ':',
             lpad(CAST(o.debut_med_min % 60 AS STRING), 2, '0')) AS demarrage_observe,
       g.sla_heure,
       array_join(array_sort(tp.tables), ', ') AS tables_produites, --colonne abritant la liste des tables produites par le job
       array_join(array_sort(am.jobs), ', ')   AS jobs_amont,       --colonne abritant la liste des job en amont du job en question 
       array_join(array_sort(av.jobs), ', ')   AS jobs_aval,        --colonne abritant la liste des job en aval du job en question
       o.runs_30j, o.succes_pct, o.duree_med_min, g.runbook_url,    --Indicateurs de performance opérationnelle
   
    --Moteur de contrôle qualité et détection d'anomalies                                    
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
