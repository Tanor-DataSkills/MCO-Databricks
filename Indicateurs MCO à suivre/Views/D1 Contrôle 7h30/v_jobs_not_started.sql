
/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_jobs_not_started

# Objectif: Cette view permet d'identifier les jobs planifiés qui n'ont pas encore démarré aujourd'hui alors que leur heure prévue (avec une tolérance de 15 minutes) est dépassée.
           # Alors que v_job_runs observe les exécutions effectivement lancées (EN_COURS, SUCCESS, FAILED), v_jobs_not_started répond à une angle mort classique 
           # en exploitation : « Qu'est-ce qui aurait dû démarrer aujourd'hui et qui n'est même pas parti ? » (scheduler bloqué, dépendance amont absente, job désactivé côté workspace ou oublié)
           # Logique générale en contexte MCO: Pour chaque job actif (g.actif = true) déclaré dans le référentiel mco.ref.job_registry, la vue vérifie trois conditions :
           -- Pas d'exécution démarrée aujourd'hui (en heure de Paris) dans mco.monitoring.v_job_runs.
           -- L'heure prévue + 15 minutes est dépassée par l'heure locale actuelle.
           -- Si ces conditions sont réunies, le job apparaît dans la vue comme en retard de démarrage.

# Dépendances: 4 ( après création et alimentation de mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/ v_job_runs.sql )
# Ordre de création : 7 ( mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/v_job_runs.sql / v_table_freshness.sql / v_night_status / v_jobs_not_started)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->>D1    
# Indicateurs: 1
    # Jobs non démarrés (Jobs actifs du référentiel sans run aujourd'hui, 15 min après l'heure prévue) ------>  Carte Non démarrés
# Job: 
# Table ou View appelée par : mco.monitoring.v_morning_status
# Sources ou Sous requetes: mco.ref.job_registry / mco.monitoring.v_job_runs
##############################################################################################################################################################################################################################*/

CREATE OR REPLACE VIEW mco.monitoring.v_jobs_not_started AS
SELECT g.job_id, g.job_name, g.criticite, g.heure_prevue   -- On part du référentiel mco.ref.job_registry g (qui recense les jobs suivis en MCO, leur criticité et leur heure_prevue quotidienne)
FROM mco.ref.job_registry g          
LEFT JOIN mco.monitoring.v_job_runs r                      --rattacher ave l'historique d'exécution consolidé(v_job_runs r)
  ON r.job_id = g.job_id
 AND from_utc_timestamp(r.start_time, 'Europe/Paris') --est placée dans le ON (et non dans le WHERE):Ne croiser qu'avec les runs démarrés aujourd'hui (à partir de 00:00:00 heure de Paris), tout en conservant via le LEFT JOIN les jobs qui n'ont eu aucun run aujourd'hui (même s'ils ont tourné hier).
     >= date_trunc('day', from_utc_timestamp(current_timestamp(), 'Europe/Paris'))
WHERE g.actif                                                   --ne retient que les jobs actifs dans le référentiel MCO (les jobs mis en pause ou retirés du périmètre sont ignorés)
  AND r.job_id IS NULL           -- Filtre uniquement les jobs actifs n'ayant aucune exécution démarrée aujourd'hui(Les jobs referencés non présents dans les runs(v_job_runs))
  AND from_utc_timestamp(current_timestamp(), 'Europe/Paris')
      > to_timestamp(concat(date_format(from_utc_timestamp(current_timestamp(), 'Europe/Paris'), 'yyyy-MM-dd'),
                            ' ', g.heure_prevue)) + INTERVAL 15 MINUTES;  -- Ne remonte le job que si l'heure locale actuelle dépasse cette limite (heure_prevue + 15 min)
