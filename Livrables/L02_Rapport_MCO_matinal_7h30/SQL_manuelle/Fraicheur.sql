/*##############################################################################################################################################################################################################################
#                                                               Fraicheur.sql

# Objectif: Ces deux commandes servent à auditer, diagnostiquer et superviser l'état d'une table transactionnelle sans lire les données métier elles-mêmes.

# Dépendances:  ()
# Ordre de création : 5 (Après création Jobs echec-reussis.sql / Jobs planifiés-non démarés.sql /Jobs echecs de la nuit.sql / Dérive de durée.sql )
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: Dérives de durée : build_gold_orders 74 min contre une médiane de 41 min (x1,8)
# Sources ou Sous requetes: 
##############################################################################################################################################################################################################################*/

DESCRIBE HISTORY <catalog>.<schema>.<table> LIMIT 20;
DESCRIBE DETAIL  <catalog>.<schema>.<table>;
