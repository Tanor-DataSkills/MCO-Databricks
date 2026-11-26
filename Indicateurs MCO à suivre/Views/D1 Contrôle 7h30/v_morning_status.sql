
/*##############################################################################################################################################################################################################################
#                                                               mco.monitoring.v_morning_status

# Objectif: View conçue pour synthétiser l'état matinal d'une plateforme data / de traitements batch dans un contexte MCO (Maintien en Condition Opérationnelle). Son objectif est de produire un feu tricolore (ROUGE, ORANGE, VERT) 
# pour orienter rapidement la priorisation des incidents au démarrage de la journée.
# Exclusivement dédié au calcul de l'indicateur statut global: ROUGE : au moins un job P1 en échec ou non démarré, ou une table P1 non fraîche. ORANGE : au moins un échec ou un non-démarré sur P2 ou P3. VERT : sinon.
 
# Dépendances: 7 ( après création et alimentation de mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/ v_job_runs.sql / v_table_freshness / v_night_status / v_jobs_not_started )
# Ordre de création : 8 ( mco.ref.job_registry / mco.ref.table_registry / mco.ops.table_metrics/v_job_runs.sql / v_table_freshness.sql / v_night_status / v_jobs_not_started / v_morning_status)
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->mco.monitoring.v_morning_status-->D1   
# Indicateurs: Statut global( Vert/Orange/Rouge) :La view  mco.monitoring.v_morning_status donne la couleur selon le résultat de l'execution du job
# Table ou View appelée par :
# Sources ou Sous requetes: mco.monitoring.v_night_status / mco.monitoring.v_jobs_not_started / mco.monitoring.v_table_freshness/
##############################################################################################################################################################################################################################*/

CREATE OR REPLACE VIEW mco.monitoring.v_morning_status AS
-- Compter le nombre de jobs de nuit en echec
 WITH echecs AS (
  SELECT criticite, count(*) AS n FROM mco.monitoring.v_night_status
  WHERE etat IN ('FAILED', 'ERROR', 'TIMED_OUT') GROUP BY criticite),
-- Compter le nombre de des jobs non démarrés
 non_demarres AS (
  SELECT criticite, count(*) AS n FROM mco.monitoring.v_jobs_not_started GROUP BY criticite),
-- Compter les tables de criticité P1 non raffraichis
 fraicheur AS (
  SELECT count(*) AS n FROM mco.monitoring.v_table_freshness
  WHERE statut = 'ROUGE' AND criticite = 'P1')

 SELECT CASE
 --ROUGE : Criticité haute / impact métier immédiat) : Au moins un job P1 en échec, un job P1 non démarré ou une table P1 non rafraîchie
  WHEN coalesce((SELECT n FROM echecs WHERE criticite = 'P1'), 0)
     + coalesce((SELECT n FROM non_demarres WHERE criticite = 'P1'), 0)
     + (SELECT n FROM fraicheur) > 0 THEN 'ROUGE'
--ORANGE : (Dégradation modérée / vigilance) : Il subsiste au moins un échec ou un job non démarré toutes criticités confondues (typiquement P2 ou P3)
 WHEN coalesce((SELECT sum(n) FROM echecs), 0)
     + coalesce((SELECT sum(n) FROM non_demarres), 0) > 0 THEN 'ORANGE'
  ELSE 'VERT' END AS statut_global,  --VERT (Nominal) : aucun échec, aucun job non démarré, et toutes les tables P1 sont à jour
  current_timestamp() AS calcule_a;
