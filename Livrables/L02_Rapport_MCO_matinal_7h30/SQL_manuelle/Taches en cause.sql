/*##############################################################################################################################################################################################################################
#                                                              Taches en cause.sql

# Objectif: Maintenant que le constat est fait et que le rapport matinal est mis à la disposition des équipes, on doit mettre en place une fiche d'incident pour chacune des erreurs. 
L'objectif de cette requête est d'effectuer un diagnostic de niveau 2 (investigation d'incident) suite à la détection d'un run global en échecs.

# Dépendances:  ()
# Ordre de création : 5 (Après création Jobs echec-reussis.sql / Jobs planifiés-non démarés.sql /Jobs echecs de la nuit.sql / Dérive de durée.sql )
# Livrables concernés: L02_Rapport_MCO_matinal_7h30 -->Rapport 3 premier jours(manuel)  
# Indicateurs: Dérives de durée : État de la fraîcheur des données : OK sur 11 tables clés sur 12
# Sources ou Sous requetes: 
##############################################################################################################################################################################################################################*/

