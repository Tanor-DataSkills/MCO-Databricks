def log_dq(table, controle, valeur, seuil, ok):
    spark.sql(f"INSERT INTO mco.ops.dq_results VALUES "
              f"('{table}','{controle}',current_timestamp(),'{'OK' if ok else 'KO'}',{valeur},{seuil})")
