Generate an accurate business context / metadata document for a Data Lake table.
The PySpark script and its calling DAG are the source of truth.

## TARGET (INPUT)
- Identifier: customer360
- Name: dim-customer
- PySpark GitHub URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer/dim-customer/src/pyspark/dim_customer.py
- Source repo URL: https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git
- Source git ref: main
- Source file path: customer/dim-customer/src/pyspark/dim_customer.py
- Lake table override (optional): customer360/dim-customer-vw

## WORKSPACE REPOS (container)
- Source repo folder: repos/dof-dpaas-customer-feature/
- Lake repo folder: repos/lake/

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3829375759/Customer360+-+v1.0+Dim+Customer+Release+Notes

## ALATION
- Enabled: true
- Search query override: 
- Max queries (most recently saved, include in B2): 10
