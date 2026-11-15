-- Doublons sur la clé
SELECT <cle_metier>, count(*) c
FROM silver.sales.orders
GROUP BY 1 HAVING c > 1;

-- Fraîcheur
SELECT max(<colonne_ingestion>) FROM silver.sales.orders;
