# Processus d’élaboration du rapport matinal 7h30

## A. Préparation (une seule fois, semaine 1)

1- Définir l'objectif : dire avant 8h si la nuit s'est bien passée, ce qui est en échec et ce qui est fait

2- Choisir les destinataires et le canal : un canal Teams dédié (MCO, owners P1, management en lecture), avec archive datée

3- Fixer les règles du statut :

ROUGE : un job P1 en échec ou non démarré, ou une table P1 non fraîche

ORANGE : un échec ou un non-démarré sur P2 ou P3

VERT : sinon

4- Préparer le modèle de message (voir plus bas)

5- Obtenir les accès : system tables, dashboard D1 ou requêtes, canal Teams, outil de ticketing

6- Répéter en doublon pendant 3 jours avec un collègue, et noter les points de friction

## B. Routine quotidienne


## C. Contenu du rapport

## D. Passer du manuel à l’automatique

1.  Manuel : checklist et requêtes, texte rédigé à la main
   
2. Assisté : application Console MCO (checklist, diagnostic, rapport généré)
   
3. Automatisé : job rapport_matinal_teams qui compose et envoie le message à partir des vues ; le MCO ajoute seulement la note.
Commencer par l’étape 1 : on automatise un processus qui tourne déjà.

## E. Critères de qualité

• Publié avant 8h, y compris quand tout est vert

• Chaque anomalie a une cause probable, une action et une heure ; le P1 indique explicitement le risque SLA

• Aucune cause présentée comme certaine sans preuve (« probable » ou « confirmée »)

• Un seul canal pour le statut, pas de doublon

• Terminé quand le rapport sort à l’heure 5 jours de suite
