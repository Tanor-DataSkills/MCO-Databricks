/*La table mco.ref.table_registry associe chaque table Delta/Unity Catalog à son job_id producteur dans mco.ref.job_registry, sa criticité, sa colonne d'ingestion 
et ses seuils de surveillance (seuil_fraicheur_h, seuil_volumetrie_pct)*/



/*Colonne d'ingestion candidate ?
Dans le cadre du MCO Databricks, une colonne d'ingestion candidate est une colonne de type horodatage (TIMESTAMP ou TIMESTAMP_NTZ) repérée automatiquement 
dans une table via system.information_schema.columns parce que son nom évoque un chargement ou une mise à jour technique (ex. ingestion_ts, load_date, etl_insert_ts, updated_at).

On la qualifie de « candidate » (et non pas encore « retenue ») car la requête ne peut pas deviner le sens métier réel d'une colonne uniquement à son nom. 
Une table peut avoir plusieurs colonnes correspondantes (par exemple inserted_at à la création de la ligne et updated_at lors d'une modification), 
ou n'en avoir aucune si l'horodatage est nommé autrement (ex. event_ts, business_date).*/
