MERGE INTO mco.ref.job_registry t
USING (SELECT job_id, name FROM (
         SELECT job_id, name, delete_time,
                row_number() OVER (PARTITION BY job_id ORDER BY change_time DESC) rn
         FROM system.lakeflow.jobs)
       WHERE rn = 1 AND delete_time IS NULL) s
ON t.job_id = s.job_id
WHEN MATCHED THEN UPDATE SET t.job_name = s.name
WHEN NOT MATCHED THEN INSERT (job_id, job_name, actif) VALUES (s.job_id, s.name, true)
WHEN NOT MATCHED BY SOURCE THEN UPDATE SET t.actif = false;
