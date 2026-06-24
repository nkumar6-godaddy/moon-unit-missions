Enrich column descriptions in a Data Lake table DDL file following the
Data Governance Council's Column Description Standard for Data Lake Assets.

## TARGET TABLE
- Database: marketing-mart
- Table: customer-suppression
- DDL path: catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.ddl
- YAML path: catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.yaml

## CONFLUENCE PAGES
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10370826/Customer+-+Customer+Suppression
  (Customer - Customer Suppression — overview and requirements page from Alation table description.)
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3114766874/Analysis+and+Design+of+Customer+Suppression
  (Analysis and Design of Customer Suppression — detailed analysis and design specification.)
## REFERENCE TABLES
- customer360.dim_customer_vw (Alation table_id: 7022291)
  Upstream dependency from data lake registry lineage — customer360.dim_customer_vw: shopper and profile data in customer360
- ecomm_cln.gdshop_blocked_country_region_cln (Alation table_id: 6593908)
  Upstream dependency from data lake registry lineage — ecomm_cln.gdshop_blocked_country_region_cln: A blacklist of country regions maintained by eComm for pre-purchase checks.
- ecomm_cln.gdshop_blocked_country_cln (Alation table_id: 6593902)
  Upstream dependency from data lake registry lineage — ecomm_cln.gdshop_blocked_country_cln: A blacklist of countries maintained by eComm for pre-purchase checks.
- signals_platform_cln.oeg_email_event_send_cln (Alation table_id: 6622143)
  Upstream dependency from data lake registry lineage — signals_platform_cln.oeg_email_event_send_cln: Contains send events from the Outbound Email Generator (OEG). Partitioned hourly.
- signals_platform_cln.oeg_email_event_open_cln (Alation table_id: 6622040)
  Upstream dependency from data lake registry lineage — signals_platform_cln.oeg_email_event_open_cln: Contains open events from the Outbound Email Generator (OEG). Partitioned hourly.
- signals_platform_cln.profile_audit_lake_cln_v2 (Alation table_id: 7035769)
  Upstream dependency from data lake registry lineage — signals_platform_cln.profile_audit_lake_cln_v2: Profile audit events store.
## ALATION
- Enabled: true
- User ID: 213
- Refresh token: use $ALATION_REFRESH_TOKEN env var
- Certified Data Dictionary: Document Folder ID 6
