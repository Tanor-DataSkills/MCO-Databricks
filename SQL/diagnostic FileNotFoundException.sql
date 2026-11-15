-----------------------------------------------------------
--Vérifier la présence des fichiers avec dbutils.fs.ls().
-----------------------------------------------------------
--Si Dossier vide ou absent : livraison en retard.
-- Si Dossier présent : vérifier la date calculée par le job et le chemin paramétré.
-- Si Erreur de droits : escalader.
-- Dans les deux cas, vérifiez si l’erreur est déjà arrivée récemment : à partir de 2 occurrences, ouvrez un problème.

display(
    dbutils.fs.ls(
abfss://landing@<storage_account>.dfs.core.windows.net/sales/<DATE>/"
    )
)
