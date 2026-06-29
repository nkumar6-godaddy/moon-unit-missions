Generate an OSI-compliant semantic model (YAML) for a Data Lake table.
The PySpark script and its calling DAG are the source of truth.
Output must conform to OSI Core Spec v0.2.0.dev0 (see docs/osi-spec-reference.md).

## TARGET (INPUT)
- Identifier: marketing-mart
- Name: customer-suppression
- PySpark GitHub URL: https://github.com/gdcorp-dna/dps-customermarketing/blob/main/customer/eds-customer-suppression/src/pyspark/customer_suppression.py
- Source repo URL: https://github.com/gdcorp-dna/dps-customermarketing.git
- Source git ref: main
- Source file path: customer/eds-customer-suppression/src/pyspark/customer_suppression.py
- Lake table override (optional): 
- Semantic model name (optional): 

## WORKSPACE REPOS (container)
- Source repo folder: repos/dps-customermarketing/
- Lake repo folder: repos/lake/

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10370826/Customer+-+Customer+Suppression

## ALATION
- Enabled: true
- Search query override: 
- Max queries (for metric/usage context): 10
