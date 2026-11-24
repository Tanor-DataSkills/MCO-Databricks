# Collecter périodiquement des métriques de fraîcheur et de volumétrie sur la table mco.ref.table_registry, puis les historiser pour alimenter un tableau de bord ou des alertes

from pyspark.sql import functions as F
rows = []
for r in spark.table("mco.ref.table_registry").collect():
    try:
        a = spark.table(r.table_name).agg(
            F.max(r.colonne_ingestion).alias("m"), F.count("*").alias("n")).first()
        rows.append((r.table_name, a.m, a.n))
    except Exception:
        rows.append((r.table_name, None, None))   # table illisible : statut INCONNU
(spark.createDataFrame(rows, "table_name string, max_ingestion_ts timestamp, row_count long")
   .withColumn("mesure_ts", F.current_timestamp())
   .select("table_name", "mesure_ts", "max_ingestion_ts", "row_count")
   .write.mode("append").saveAsTable("mco.ops.table_metrics"))
