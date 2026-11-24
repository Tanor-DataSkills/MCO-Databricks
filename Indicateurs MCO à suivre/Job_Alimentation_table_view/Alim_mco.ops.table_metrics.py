##########################################################################################################################################################################################
#                                                               mco.ops.table_metrics
##########################################################################################################################################################################################
# Ordre d'alimentation:
# Job:
# Code à coller dans un notebook Databricks, puis le planifier comme job

# La table mco.ops.table_metrics collecte périodiquement des métriques de fraîcheur et de volumétrie sur un ensemble de tables référencées, puis les historise pour alimenter un tableau de bord ou des alertes.

# Collecter périodiquement des métriques de fraîcheur et de volumétrie sur la table mco.ref.table_registry, puis les historiser pour alimenter un tableau de bord ou des alertes

from pyspark.sql import functions as F
rows = []
for r in spark.table("mco.ref.table_registry").collect(): #Chaque ligne r fournit au minimum table_name (nom complet de la table cible) et colonne_ingestion (colonne horodatée indiquant la dernière ingestion ou mise à jour)

    # On mesure la fraîcheur (derniere valeur horodatage d'ingestion connu) et la volumétrie (nombre total de lignes) pour chaque nom de table
    try:
        a = spark.table(r.table_name).agg(
            F.max(r.colonne_ingestion).alias("m"), F.count("*").alias("n")).first() 
        rows.append((r.table_name, a.m, a.n))    # On rajoute les champs calculés dans le dataframe vide rows
    except Exception:                            # En cas d'erreur(table absente) ou d'exception le script enregistre (r.table_name, None, None)
        rows.append((r.table_name, None, None))  # table illisible : statut INCONNU
(spark.createDataFrame(rows, "table_name string, max_ingestion_ts timestamp, row_count long")
   .withColumn("mesure_ts", F.current_timestamp())   # Historisation des mesures
   .select("table_name", "mesure_ts", "max_ingestion_ts", "row_count")
   .write.mode("append").saveAsTable("mco.ops.table_metrics"))   # Ajout en mode append dans mco.ops.table_metrics
