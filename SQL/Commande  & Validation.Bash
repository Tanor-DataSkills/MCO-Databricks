curl -X POST "$DATABRICKS_HOST/api/2.1/jobs/runs/repair" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"run_id": <RUN_ID>, "rerun_all_failed_tasks": true}'

