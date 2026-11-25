
/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_morning_status

# Objectif: Exclusivement dédié au calcul de l'indicateur statut global: ROUGE : au moins un job P1 en échec ou non démarré, ou une table P1 non fraîche. ORANGE : au moins un échec ou un non-démarré sur P2 ou P3. VERT : sinon.
# Dépendances: 6 ( après création et alimentation de mco.ref.job_registry/mco.ref.table_registry/mco.monitoring.v_table_freshness/ mco.monitoring.v_night_status/mco.monitoring.v_jobs_not_started
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1    
# Indicateurs: Statut global( Vert/Orange/Rouge) :La view  mco.monitoring.v_morning_status donne la couleur selon le résultat de l'execution du job
# Table ou View appelée par :
# Sources ou Sous requetes: mco.monitoring.v_night_status/mco.monitoring.v_jobs_not_started/mco.monitoring.v_table_freshness/
##############################################################################################################################################################################################################################*/

  
CREATE OR REPLACE VIEW mco.monitoring.v_morning_status AS
WITH echecs AS (
  SELECT criticite, count(*) AS n FROM mco.monitoring.v_night_status
  WHERE etat IN ('FAILED', 'ERROR', 'TIMED_OUT') GROUP BY criticite),
non_demarres AS (
  SELECT criticite, count(*) AS n FROM mco.monitoring.v_jobs_not_started GROUP BY criticite),
fraicheur AS (
  SELECT count(*) AS n FROM mco.monitoring.v_table_freshness
  WHERE statut = 'ROUGE' AND criticite = 'P1')
SELECT CASE
  WHEN coalesce((SELECT n FROM echecs WHERE criticite = 'P1'), 0)
     + coalesce((SELECT n FROM non_demarres WHERE criticite = 'P1'), 0)
     + (SELECT n FROM fraicheur) > 0 THEN 'ROUGE'
  WHEN coalesce((SELECT sum(n) FROM echecs), 0)
     + coalesce((SELECT sum(n) FROM non_demarres), 0) > 0 THEN 'ORANGE'
  ELSE 'VERT' END AS statut_global,
  current_timestamp() AS calcule_a;
