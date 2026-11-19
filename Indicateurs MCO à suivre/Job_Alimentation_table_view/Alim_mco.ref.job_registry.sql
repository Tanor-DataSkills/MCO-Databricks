MERGE INTO mco.ref.job_registry t
USING (SELECT job_id, name FROM (
         SELECT job_id, name, delete_time,
                row_number() OVER (PARTITION BY job_id ORDER BY change_time DESC) rn
         FROM system.lakeflow.jobs)
       WHERE rn = 1 AND delete_time IS NULL) s
ON t.job_id = s.job_id
WHEN MATCHED THEN UPDATE SET t.job_name = s.name  --Si un job_id existe déjà dans la table cible mco.ref.job_registry et que son nom a changé, elle met à jour job_name
WHEN NOT MATCHED THEN INSERT (job_id, job_name, actif) VALUES (s.job_id, s.name, true) --Si un nouveau job apparaît dans le catalogue Unity Catalog mais n'est pas encore référencé dans le MCO, elle l'insère en initialisant le champ actif = true
WHEN NOT MATCHED BY SOURCE THEN UPDATE SET t.actif = false;  
--Si un job présent dans la table cible mco.ref.job_registry n'est plus retourné par la source (job supprimé ou désactivé durablement), elle bascule son statut à actif = false 
--au lieu de le supprimer physiquement (ce qui préserve les liens avec les incidents passés)
