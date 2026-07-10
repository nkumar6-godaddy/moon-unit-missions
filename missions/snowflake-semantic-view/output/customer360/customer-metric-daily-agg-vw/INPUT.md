Generate a Snowflake Semantic View YAML for a Data Lake table.
The PySpark script and its calling DAG are the source of truth.
Output must conform to the Snowflake semantic view YAML spec
(see docs/snowflake-spec-reference.md).

## TARGET (INPUT)
- Identifier: customer360
- Name: customer-metric-daily-agg-vw
- PySpark GitHub URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py
- Source repo URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git
- Source git ref: main
- Source file path: customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py
- Lake table override (optional): 
- Semantic view name (optional): 
- Snowflake database: MARKETING_CORE_DEV

## WORKSPACE REPOS (container)
- Source repo folder: repos/dof-dpaas-customer-feature/
- Lake repo folder: repos/lake/

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360

## ALATION
- Enabled: true
- Search query override: 
- Max queries (for metric/usage context): 5
