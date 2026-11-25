## Views utilisées: 

v_morning_status / v_night_status / v_jobs_not_started / v_duration_drift / v_table_freshness


<img width="1500" height="722" alt="image" src="https://github.com/user-attachments/assets/af3e2984-9e61-4314-9a33-f9612d023925" />


## D1 · Contrôle 7h30 (Databricks dashboards)

- Dashboards → Create dashboard (tableaux de bord AI/BI), puis l'onglet Data.

- Ajoutez 6 jeux de données (un SELECT par vue, sur un SQL warehouse) :

- Canvas : ajoutez un compteur (statut), des compteurs pour les chiffres, puis quatre tableaux. Pour les indicateurs de la nuit, calculez dans le widget : count(*), sum(CASE WHEN etat='SUCCEEDED' THEN 1 ELSE 0 END) et le taux = succès / count(*).

- Ajoutez un filtre sur criticite, relié aux jeux de données concernés.

- Planification : rafraîchissement toutes les 15 min de 06:00 à 09:00, avec un abonnement e-mail à 07:25 pour l'équipe MCO.

- Droits : lecteurs en SELECT sur mco.monitoring seulement ; choisissez les identifiants du propriétaire pour les données intégrées, afin que les lecteurs n'aient pas besoin d'accéder aux system tables.

Avant cela, les vues doivent exister (mco_views.sql), les registres être remplis et le collecteur de table_metrics tourner, sinon les tableaux seront vides. Je peux aussi vous faire la même maquette pour D2, D3, D4 ou D5.

<img width="1639" height="771" alt="image" src="https://github.com/user-attachments/assets/4a0c6ee5-0e9d-431f-84c2-a33f2ff26d81" />

<img width="1513" height="450" alt="image" src="https://github.com/user-attachments/assets/63aa81a8-cd4d-4080-8b3b-45e7f8c50bd6" />
