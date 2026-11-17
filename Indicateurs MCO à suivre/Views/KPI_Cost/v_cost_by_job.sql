CREATE OR REPLACE VIEW mco.monitoring.v_cost_by_job AS
SELECT u.usage_date,
       u.usage_metadata.job_id     AS job_id,
       u.usage_metadata.job_run_id AS run_id,
       sum(u.usage_quantity)       AS dbu,
       sum(u.usage_quantity * p.pricing.default) AS cout_catalogue
FROM system.billing.usage u
LEFT JOIN system.billing.list_prices p
  ON u.sku_name = p.sku_name AND u.cloud = p.cloud
 AND u.usage_end_time >= p.price_start_time
 AND (p.price_end_time IS NULL OR u.usage_end_time < p.price_end_time)
WHERE u.usage_metadata.job_id IS NOT NULL
  AND u.usage_date >= current_date() - 90
GROUP BY u.usage_date, u.usage_metadata.job_id, u.usage_metadata.job_run_id;

