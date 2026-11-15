SELECT '<table>' AS table_name,
       max(ingestion_ts) AS derniere_ingestion,
       CASE WHEN max(ingestion_ts) < current_timestamp() - INTERVAL 24 HOURS
            THEN 'ROUGE' ELSE 'VERT' END AS statut
FROM <catalog>.<schema>.<table>;
