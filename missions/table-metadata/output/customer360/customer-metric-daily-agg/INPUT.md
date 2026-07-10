Generate an accurate business context / metadata document for a Data Lake table.
The PySpark script and its calling DAG are the source of truth.

## USER NOTES (HIGHEST PRIORITY)
These notes come directly from the table owner/expert. They take priority over
Confluence, Alation, and other secondary sources — but NOT over PySpark/DAG code.
Incorporate them into the relevant metadata sections (A2, C4, C7, B1, etc.).

Daily roll-up of customer lifecycle metrics by 18 reporting dimensions.
Replaces legacy customer_mart.daily_active_customers.
Always filter on partition_eval_mst_date.

## TARGET (INPUT)
- Identifier: customer360
- Name: customer-metric-daily-agg
- PySpark GitHub URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py
- Source repo URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git
- Source git ref: main
- Source file path: customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py
- Lake table override (optional): 

## WORKSPACE REPOS (container)
- Source repo folder: repos/dof-dpaas-customer-feature/
- Lake repo folder: repos/lake/

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360

## ALATION
- Enabled: true
- Search query override: 
- Max queries (most recently saved, include in B2): 10
