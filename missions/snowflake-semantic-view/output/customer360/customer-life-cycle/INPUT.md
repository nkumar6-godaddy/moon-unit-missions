Generate a Snowflake Semantic View YAML for a Data Lake table.
The PySpark script and its calling DAG are the source of truth.
Output must conform to the Snowflake semantic view YAML spec
(see docs/snowflake-spec-reference.md).

## USER NOTES (HIGHEST PRIORITY)
These notes come directly from the table owner/expert. They take priority over
Confluence, Alation, and other secondary sources — but NOT over PySpark/DAG code.
Incorporate them into Snowflake descriptions, custom_instructions, and metrics.

Don't use the customer_state_enum column to derive any metrics, it is an internal column for auditing purposes only and should not be used. 
Always use the date columns to determine the state of the customer. Example: if acquisition date is equal to the partition date then it is a new customer.

## TARGET (INPUT)
- Identifier: customer360
- Name: customer-life-cycle
- PySpark GitHub URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/pyspark/customer_life_cycle.py
- Source repo URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git
- Source git ref: main
- Source file path: customer360/customer-metrics/src/pyspark/customer_life_cycle.py
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
- Max queries (for metric/usage context): 10
