**Stage name:** analyze
**The coding agent was given these instructions:** You are a Data Engineering + Data Governance analyst. Your job is to resolve lineage
from the PySpark job to the authoritative Data Lake table, and extract only accurate,
evidence-backed metadata.

## Step 1: Read INPUT.md and gather.md
- Read `INPUT.md` and the previous stage output `gather.md`.
- If INPUT.md contains USER NOTES, factor them into your facts blocks where relevant
  (they are expert-provided and take priority over Confluence/Alation text).

## Step 2: Identify the target table
Determine the final output lake table populated by this PySpark job.
- Prefer direct evidence in code: table write targets, create/insert statements,
  saveAsTable targets, Glue catalog writes, Athena CTAS, etc.
- If `lake_table_override` is provided in INPUT.md, use it only if it does not
  contradict the code; otherwise flag the conflict.
- If multiple outputs exist, list them. Identify the “primary” one if possible.

## Step 3: Deep lineage resolution — MANDATORY for EVERY source table

The PySpark script references upstream tables. Some are lake tables (in `repos/lake/`),
but many are **local/intermediate tables** (e.g., `customer_core_conformed.*`,
`analytic_local.*`, `*_stg`) that are built by OTHER PySpark scripts in the SAME repo.

**You MUST recursively trace EACH source table to its lake origin. Do NOT stop at
intermediate tables. They are implementation details, not authoritative sources.**

For EACH table referenced in the target PySpark:

1. **Check if it exists as a lake table**: search `repos/lake/catalog/config/prod/` for it.
   Try both `us-west-2/<schema>/<table-hyphenated>/` and `dlms-api/us-west-2/<schema>/<table-hyphenated>/`.
   Convert underscores to hyphens when searching lake paths.

2. **If it IS a lake table** -> STOP. Record it as the authoritative source. Read its
   `table.yaml` and `table.ddl`. Do NOT traverse further into that lake table's own
   upstream sources. The lineage for THIS table ends at its first upstream lake table.

3. **If it is NOT a lake table** (local/intermediate) — you MUST trace upstream:
   a. Search the source repo for the PySpark script that BUILDS this intermediate table.
      Use `grep -r "<table_name>" repos/<source-repo>/` to find references.
      Look for `insertInto`, `saveAsTable`, `CREATE TABLE`, or write operations targeting it.
   b. Read that upstream PySpark script.
   c. Identify what tables IT reads from.
   d. For each of THOSE tables, repeat from step 1 (recursive traversal).
   e. Continue until you reach a lake table or an external system (S3 direct read, API, etc.).
   f. **STOP as soon as you reach a lake table.** Do NOT traverse into a lake table's
      own sources. A lake table is a boundary — it is the authoritative source.

4. **If traversal fails** (cannot find the upstream script, or it reads from an unknown source):
   Record: `UNRESOLVED: <table_name> — <what you searched and why it failed>`

**CRITICAL RULE FOR C1 (Column Reference):**
The "Column Lineage" column in C1 must describe how each column is derived, referencing
the FIRST lake table and column in the lineage chain — NOT the lake table's own upstream
sources. Use descriptive transformation text (not just table names). For example:
- BAD:  `enterprise.dim_subscription.sub_id` (upstream of an upstream lake table)
- BAD:  `customer_core_conformed.active_customer_stg.shopper_id` (intermediate table)
- GOOD: `Direct mapping from enterprise.dim_subscription_history.shopper_id`
- GOOD: `Calculated as datediff(partition_eval_mst_date, customer_acquisition_mst_date) / 365`
- GOOD: `Derived from dim_new_acquisition_shopper.new_acquisition_bill_id or dim_subscription_history.original_bill_id for new/intraday customers`
- GOOD: `UNRESOLVED — requires manual input` (if traversal failed)

Only trace THROUGH a lake table if the PySpark directly reads from multiple tables and
one of those is NOT a lake table. In that case, trace only the non-lake sources.

## Step 4: Read lake registry artifacts for the direct upstream lake tables
For EACH lake table that is a DIRECT source of the target (i.e., the first lake table
reached during traversal — not deeper ancestors), read:
- `table.ddl` — authoritative schema with column names and types
- `table.yaml` — lineage metadata, consumer groups, SLA info

Also read the target table's own lake registry artifacts (table.ddl, table.yaml).

Build a column-level mapping for C1:
`# | name | data_type | description | column_lineage | category | sample_values | key_statistics`
(If intermediates exist between the target and the lake source, note the chain but
the final C1 Column Lineage must describe only the first lake table.column reached.)
Classify each column's category as one of: `Identifier`, `Categorical`, `Date`,
`Numeric`, `Boolean`, `Text`, `Amount`, `Timestamp`, `Array`.
For Sample Values and Key Statistics: pull from gather.md Alation profiling if available;
otherwise leave empty — do NOT fabricate.

## Step 5: Derive analysis outputs (no guessing)
Derive the following, strictly from code + resolved lake artifacts:
- Grain: what one row represents
- Keys: primary key / unique key strategy (or explicitly "no PK" + dedup guidance)
- Partitions and recommended always-filter columns
- Always-on filters embedded in ETL (non-overridable scope restrictions)
- Common business metrics computed in the ETL (name + definition + grain)
- **Column-level lineage** (CRITICAL): for EACH column in the target table, trace it
  to the FIRST upstream lake table and column. Do NOT trace further into that lake
  table's own sources. Write Column Lineage as descriptive transformation text
  (e.g., "Direct mapping from dim_country_vw.country_name joined on acquisition
  country code" or "Calculated as datediff(partition_eval_mst_date,
  customer_acquisition_mst_date) / 365"). Classify each column's category as one of:
  `Identifier`, `Categorical`, `Date`, `Numeric`, `Boolean`, `Text`, `Amount`,
  `Timestamp`, `Array`. If lineage cannot be resolved, mark as UNRESOLVED.
- **Multi-depth lineage for D1**: from lake table.yaml lineage metadata and Alation
  (if in gather.md), build Depth 1 and Depth 2 upstream tables and Depth 1 downstream
  tables. Each entry: Table Name | Database | Schema | Type | Platform.
- SLA/refresh schedule from the DAG (cron, dependencies, expected latency)

## Step 6: Output (append to analyze.md)
Append:
- Target table resolution (with evidence and any overrides)
- **Lineage resolution table** showing for each source table referenced in code:
  | Source Table (from code) | Resolved To (First Lake Table) | Resolution Method |
  Include UNRESOLVED entries with explanation of what was searched.
  Do NOT list a lake table's own upstream sources — stop at the lake boundary.
- Column-level lineage mapping table for all columns:
  | # | Name | Data Type | Description | Column Lineage | Category | Sample Values | Key Statistics |
  Use descriptive transformation text for Column Lineage. Leave Sample Values and
  Key Statistics empty if not available from gather.md — do NOT fabricate.
- **Multi-depth lineage tables for D1** (if resolvable):
  - Depth 1 Upstream Tables (with total count)
  - Depth 2 Upstream Tables (with total count)
  - Depth 1 Downstream Tables (with total count)
  Columns: Table Name | Database | Schema | Type | Platform
- A structured "facts" block for each of the 20 sections (A1..E3) listing
  what can be filled and what is missing
- A "Do not claim" list: items that are tempting but not proven

## Step 7: Write resolved-target machine output (required)
Create a JSON file in the workspace root named `RESOLVED_TARGET.json` with:
- schema: string (e.g., "enterprise")
- table_hyphen: string (e.g., "payment-cogs-audit")
- table_underscore: string (e.g., "payment_cogs_audit")
- lake_table_path: string|null (e.g., "enterprise/payment-cogs-audit")
- confidence: "high"|"medium"|"low"
- evidence: array of short strings (file/line references)
If the target cannot be resolved, still write the file with nulls and a clear explanation in evidence.

**The agent summarized its work in this way:**

---

## analyze stage — research summary

**Completed:** 2026-06-17
**Source:** `repos/dof-dpaas-customer-feature @ main` + `repos/lake` registry
**Target (resolved):** `customer360.customer_metric_daily_agg_vw` (Lake table)
**Lake registry path:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`

---

## Target Table Resolution

### Evidence

| Evidence Type | Value |
|---|---|
| PySpark write target (code, line 438) | `df.repartition(1).write.insertInto("customer_core_conformed.customer_metric_daily_agg", overwrite=True)` |
| Hive DDL location (ddls/customer_metric_daily_agg.ddl) | `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/` |
| Lake registry path | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.yaml` |
| Lake table relative path (table.yaml) | `customer_metric_daily_agg` — same S3 key as Hive write target |
| Database config (config.yaml) | `database_name: customer360`, `database_root: gd-ckpetlbatch-prod-customer-core-conformed`, `path_to_database: customer_core_conformed` |
| DAG call_lake_api task | `SuccessNotificationOperator` for `customer360.customer_metric_daily_agg_vw` (prod) |
| Policies.yaml output 1 | `customer360.customer_metric_daily_agg_vw` (datalake, parquet) |
| Alation lake entry | `81.AwsDataCatalog.customer360.customer_metric_daily_agg_vw` (ID: 7038346) |

**Resolution:**
The PySpark job writes to the Hive/Glue intermediate table `customer_core_conformed.customer_metric_daily_agg`. This is the same underlying S3 data (`s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`) registered in the Data Lake as **`customer360.customer_metric_daily_agg_vw`**. The lake registry `table.yaml` confirms the `table_relative_path: "customer_metric_daily_agg"` within `database_root: gd-ckpetlbatch-prod-customer-core-conformed` / `path_to_database: customer_core_conformed`. No `lake_table_override` was provided in INPUT.md; code evidence aligns with the lake registry entry.

**Confidence: HIGH**

---

## Lineage Resolution Table

| Source Table (from code) | Resolved To (First Lake Table) | Resolution Method |
|---|---|---|
| `customer_core_conformed.customer_life_cycle` | `customer360.customer_life_cycle_vw` | **S3 path identity + producer script.** `customer_core_conformed.customer_life_cycle` is NOT in the lake registry directly. Searched `repos/dof-dpaas-customer-feature/` and found `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` which writes to `customer_core_conformed.customer_life_cycle`. Its policies file (`customer_life_cycle_dag.yaml`) lists `customer360.customer_life_cycle_vw` as an output pointing to the same S3 location. Lake registry entry confirmed at `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml`. Both resolve to S3 `s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_life_cycle/`. **STOP — lake boundary reached.** |
| `customer360.customer_life_cycle_vw` | `customer360.customer_life_cycle_vw` | **Direct lake table.** Commented out in active PySpark code (line 227) but still listed in policies.yaml (input 1) and DAG dependency wait. Lake registry confirmed at `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/`. **STOP — lake boundary reached.** |

> **Note on code vs. lake registry conflict:** The active code reads `customer_core_conformed.customer_life_cycle` (Hive/Glue form). The lake registry lineage for the target table still lists `customer360.customer_life_cycle_vw` as the upstream. These are the same S3 data; the lake lineage registry is stale in its naming but correct in substance.

---

## Column-Level Lineage Mapping (C1)

**Source lake table:** `customer360.customer_life_cycle_vw`
**Intermediate hop:** `customer_core_conformed.customer_life_cycle` (Hive/Glue alias of same S3 data)
**Note on DDL conflict:** The Hive DDL (`customer_metric_daily_agg.ddl`) and PySpark `conform_datatype()` output 32 columns + 1 partition column = 33 total. The lake registry DDL (`table.ddl`) has 30 non-partition + 1 partition = 31 columns — missing `data_source_enum`. Column ordering also differs. The Hive DDL / PySpark code is authoritative per source-of-truth rule.

| # | Name | Data Type | Description | Column Lineage | Category | Sample Values | Key Statistics |
|---|---|---|---|---|---|---|---|
| 1 | `customer_type_reason_desc` | string | Reason for customer type classification (e.g., why Active, Churned, etc.) | `COALESCE(customer_life_cycle_vw.customer_type_reason_desc, 'Not Classified')` — groupby dimension | Categorical | | |
| 2 | `customer_acquisition_mst_month` | string | Month when customer was first acquired (MST), format yyyy-MM | `COALESCE(customer_life_cycle_vw.customer_acquisition_mst_month, '')` — groupby dimension | Date | | |
| 3 | `customer_domestic_international_name` | string | Whether customer is domestic (US) or international | `COALESCE(customer_life_cycle_vw.customer_domestic_international_name, 'International')` — groupby dimension; default 'International' when null | Categorical | | |
| 4 | `customer_region_1_name` | string | Geographic region level 1 | `COALESCE(customer_life_cycle_vw.customer_region_1_name, 'International - RoW')` — groupby dimension | Categorical | | |
| 5 | `customer_region_2_name` | string | Geographic region level 2 | `COALESCE(customer_life_cycle_vw.customer_region_2_name, 'Rest of World (RoW)')` — groupby dimension | Categorical | | |
| 6 | `customer_region_3_name` | string | Geographic region level 3 | `COALESCE(customer_life_cycle_vw.customer_region_3_name, 'NA')` — groupby dimension | Categorical | | |
| 7 | `customer_country_name` | string | Customer country name at evaluation date | `COALESCE(customer_life_cycle_vw.customer_acquisition_country_name, 'Unknown')` — renamed from `customer_acquisition_country_name`; default 'Unknown' | Categorical | | |
| 8 | `customer_country_code` | string | Customer country code at evaluation date | `COALESCE(customer_life_cycle_vw.customer_acquisition_country_code, '--')`, then `UPPER()`, then normalize `'UK' → 'GB'`; renamed from `customer_acquisition_country_code` | Categorical | | |
| 9 | `customer_type_name` | string | Customer type at evaluation date | `COALESCE(customer_life_cycle_vw.customer_type_name, 'Not Classified')` — groupby dimension | Categorical | | |
| 10 | `acquisition_channel_name` | string | Acquisition channel name | `COALESCE(customer_life_cycle_vw.customer_acquisition_channel_name, 'Not GA Attributed')` — renamed from `customer_acquisition_channel_name` | Categorical | | |
| 11 | `customer_tenure_year_count` | int | Customer tenure in whole years | `COALESCE(customer_life_cycle_vw.customer_tenure_year_count, 0)` — cast to int; groupby dimension | Numeric | | |
| 12 | `product_ownership_category_list` | string | Owned product PNL category list (string-encoded array) | `CAST(customer_life_cycle_vw.product_pnl_category_list AS string)` — renamed from `product_pnl_category_list`; array cast to string; bracket-stripped `[val1,val2]→val1,val2` in Redshift insert | Array | | |
| 13 | `product_ownership_line_list` | string | Owned product PNL line list (string-encoded array) | `CAST(customer_life_cycle_vw.product_pnl_line_list AS string)` — renamed from `product_pnl_line_list`; array cast to string; bracket-stripped in Redshift insert | Array | | |
| 14 | `reseller_type_name` | string | Reseller type name | Direct mapping from `customer_life_cycle_vw.reseller_type_name` — groupby dimension | Categorical | | |
| 15 | `fraud_flag` | boolean | True if customer was flagged as fraud at evaluation date | `COALESCE(customer_life_cycle_vw.customer_fraud_flag, false)` — renamed from `customer_fraud_flag`; false when null | Boolean | | |
| 16 | `point_of_purchase_name` | string | Point of purchase name from customer acquisition bill | `COALESCE(customer_life_cycle_vw.point_of_purchase_name, 'Unknown')` — groupby dimension; default 'Unknown' | Categorical | | |
| 17 | `customer_acquisition_bill_fraud_flag` | boolean | True if the acquisition bill has a fraud record | `COALESCE(customer_life_cycle_vw.customer_acquisition_bill_fraud_flag, false)` — groupby dimension; false when null | Boolean | | |
| 18 | `brand_name_list` | string | List of all brands associated with the customer (string-encoded array) | `CAST(customer_life_cycle_vw.brand_name_list AS string)` — array cast to string; bracket-stripped in Redshift insert | Array | | |
| 19 | `product_category_qty` | int | Number of distinct product PNL categories owned | `COALESCE(SIZE(product_ownership_category_list), 0)` — derived from `product_pnl_category_list` array size; 0 when null | Numeric | | |
| 20 | `ttm_gcr_usd_amt` | decimal(18,2) | Total Gross Cash Received (GCR) in USD for trailing twelve months | `SUM(customer_life_cycle_vw.ttm_gcr_usd_amt)` grouped by 18 reporting dimensions | Amount | | |
| 21 | `ending_customer_qty` | bigint | Count of active customers at end of evaluation date | `COUNT_IF(customer_life_cycle_vw.active_status_flag = true)` grouped by 18 dimensions | Numeric | | |
| 22 | `churn_customer_qty` | bigint | Count of customers who churned on evaluation date | `COUNT_IF(customer_life_cycle_vw.customer_churn_mst_date IS NOT NULL)` grouped by 18 dimensions | Numeric | | |
| 23 | `merge_customer_qty` | bigint | Count of customers merged on evaluation date | `COUNT_IF(customer_life_cycle_vw.customer_merge_mst_date IS NOT NULL)` grouped by 18 dimensions | Numeric | | |
| 24 | `new_customer_qty` | bigint | Count of new customers acquired on evaluation date | `COUNT_IF(customer_life_cycle_vw.customer_acquisition_mst_date = partition_eval_mst_date)` grouped by 18 dimensions | Numeric | | |
| 25 | `reactivate_customer_qty` | bigint | Count of reactivated customers on evaluation date | `COUNT_IF(customer_life_cycle_vw.customer_reactivate_mst_date IS NOT NULL)` grouped by 18 dimensions | Numeric | | |
| 26 | `beginning_customer_qty` | bigint | Ending customer count from prior day (carries forward 0-rows for dimension continuity) | `LAG(ending_customer_qty) OVER (PARTITION BY 18 dim_cols ORDER BY partition_eval_mst_date)` when prior day is consecutive; else 0. Dimension-continuity fill inserts zero-metric rows for dim combos missing on the evaluation date to ensure LAG works correctly | Numeric | | |
| 27 | `net_move_qty` | bigint | Net movement quantity (reconciliation metric) | Calculated as `ending_customer_qty - beginning_customer_qty - new_customer_qty + churn_customer_qty - reactivate_customer_qty + merge_customer_qty` | Numeric | | |
| 28 | `net_add_qty` | bigint | Net additions: ending minus beginning customer count | Calculated as `ending_customer_qty - beginning_customer_qty` | Numeric | | |
| 29 | `net_churn_qty` | bigint | Net churn: churned minus reactivated customers | Calculated as `churn_customer_qty - reactivate_customer_qty` | Numeric | | |
| 30 | `data_source_enum` | string | Identifier for the data source pipeline | Hardcoded literal `'customer360'` in PySpark `final_metrics` SELECT. **NOTE: Column is MISSING from lake registry DDL (`table.ddl`) — lake DDL needs update.** | Categorical | | |
| 31 | `etl_build_mst_ts` | timestamp | Timestamp when this partition was built by the ETL (MST) | `CAST(from_utc_timestamp(current_timestamp(), 'MST') AS timestamp)` — current run time converted from UTC to MST | Timestamp | | |
| 32 | `partition_eval_mst_date` | string | Partition key: evaluation date in MST (YYYY-MM-DD string in Hive; DATE in Redshift DDL) | Direct mapping from `customer_life_cycle_vw.partition_eval_mst_date` — also used as the overwrite partition range filter | Date | | |

---

## Multi-Depth Lineage Tables (D1)

### Depth 1 Upstream Tables — Total: 1

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| customer_life_cycle_vw | GoDaddy Central Data Lake (Prod) | customer360 | Table (Partitioned, Parquet) | AWS Glue / S3 (gd-ckpetlbatch-prod-customer-core-conformed) |

> **Note:** `customer_core_conformed.customer_life_cycle` (the Hive/Glue form read by PySpark) resolves to this same lake table via S3 path identity. It is not an independent source.

### Depth 2 Upstream Tables — Total: 20
(From `customer_life_cycle_vw` lake registry `table.yaml` lineage block)

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| customer_fraud | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | AWS Glue / S3 |
| customer_type_history | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | AWS Glue / S3 |
| shopper_acquisition | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | AWS Glue / S3 |
| shopper_merge | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | AWS Glue / S3 |
| dim_customer_history_vw | GoDaddy Central Data Lake (Prod) | customer360 | Table | AWS Glue / S3 |
| customer_id_mapping_snapshot | GoDaddy Central Data Lake (Prod) | customers | Table | AWS Glue / S3 |
| dim_reseller | GoDaddy Central Data Lake (Prod) | dp_enterprise | Table | AWS Glue / S3 |
| bill_line_traffic_ext | GoDaddy Central Data Lake (Prod) | ecomm_mart | Table | AWS Glue / S3 |
| dim_bill_line_purchase_attribution | GoDaddy Central Data Lake (Prod) | ecomm_mart | Table | AWS Glue / S3 |
| entitlement_bill_type | GoDaddy Central Data Lake (Prod) | ecomm_mart | Table | AWS Glue / S3 |
| dim_bill_shopper_id_xref | GoDaddy Central Data Lake (Prod) | enterprise | Table | AWS Glue / S3 |
| dim_entitlement_history | GoDaddy Central Data Lake (Prod) | enterprise | Table | AWS Glue / S3 |
| dim_new_acquisition_shopper | GoDaddy Central Data Lake (Prod) | enterprise | Table | AWS Glue / S3 |
| dim_subscription_history | GoDaddy Central Data Lake (Prod) | enterprise | Table | AWS Glue / S3 |
| fact_bill_line | GoDaddy Central Data Lake (Prod) | enterprise | Table | AWS Glue / S3 |
| fact_entitlement_bill | GoDaddy Central Data Lake (Prod) | enterprise | Table | AWS Glue / S3 |
| dim_bill_fraud_history_vw | GoDaddy Central Data Lake (Prod) | finance360 | Table | AWS Glue / S3 |
| dim_country_vw | GoDaddy Central Data Lake (Prod) | finance360 | Table | AWS Glue / S3 |
| dim_product_vw | GoDaddy Central Data Lake (Prod) | finance360 | Table | AWS Glue / S3 |
| manual_paid_subscription | GoDaddy Central Data Lake (Prod) | finance_cln | Table | AWS Glue / S3 |

### Depth 1 Downstream Tables — Total: 4 (from Alation queries evidence)
(Not confirmed lake tables; these are analyst-created materialized views/sandbox tables observed in Alation queries)

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| customer_metric_daily_agg_vw_mv | Redshift - Serverless - Dev | dev.ba_usi | Materialized Table | Redshift Serverless |
| mv_customer_metric_daily_agg_vw_union | Redshift - Prod-BI | bi.ba_usi | Materialized Table | Redshift |
| c360_test_sz_2 | Redshift - Prod-BI | dna_sandbox | Sandbox Table | Redshift |
| customer_vs_target | Redshift - Prod-BI / Dev | bi_dashboards_prod / ba_corporate | Dashboard View | Redshift |

---

## Structured Facts Block (Sections A1–E3)

### A1 — Table Identity

| Field | Value | Source | Confidence |
|---|---|---|---|
| Table name (lake) | `customer_metric_daily_agg_vw` | Lake registry table.yaml | High |
| Schema (lake) | `customer360` | Lake registry config.yaml | High |
| Internal Hive name | `customer_core_conformed.customer_metric_daily_agg` | PySpark code line 29–31 | High |
| Lake registry path | `dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/` | Direct file read | High |
| Alation lake ID | `7038346` (`81.AwsDataCatalog.customer360.customer_metric_daily_agg_vw`) | gather.md Alation | High |
| Alation Redshift Dev ID | `7038918` (`132.dev.customer360.customer_metric_daily_agg_vw`) | gather.md Alation | High |
| DAG ID | `customer-metric-daily-agg` | DAG file | High |
| Feed name (PySpark) | `customer_metric_daily_agg` | PySpark line 26 | High |
| Spark app name | `customer_metrics_daily_agg` | PySpark line 149 | High |

### A2 — Business Context / Description

| Field | Value | Source | Priority |
|---|---|---|---|
| Short description | Daily roll-up of customer lifecycle metrics by 18 reporting dimensions | USER NOTES (highest priority) | Highest |
| Replaces | `customer_mart.daily_active_customers` (legacy DAC) | USER NOTES; corroborated by Alation queries 136952 & 138254 | Highest |
| Long description | "A daily aggregated metrics table providing summarized customer performance indicators. This view serves as a comprehensive source for customer lifecycle analysis, containing customer demographic, geographic, and behavioral attributes." | Alation | Medium |
| Lake description | "Customer Metric Daily Aggregated on Reporting Dims for a given day" | Lake registry table.yaml | High |
| Domain | Customer | Confluence Customer360 Business Context (page 4387965088) | Medium |
| Organization | DNA | Confluence | Medium |
| Business metrics covered | New Customers, Active Customers, TTM GCR Amount, 2+/3+ Customers, Product Cat/Line/Qty, Merged Customers, Churn Customers, Reactivated Customers | Confluence Customer Metrics (page 4042131239) | Medium |

### A3 — Data Tier / SLA

| Field | Value | Source | Confidence |
|---|---|---|---|
| Data Tier | 4 | Lake registry table.yaml | High |
| SLA delivery | By 08:00 AM MST daily | Lake registry table.yaml (`cron(00 15 * * ? *)` UTC) | High |
| SLO identifier | `customer360.customer_metric_daily_agg_vw` | Lake registry table.yaml | High |
| Max duration | 120 minutes | policies.yaml `maxDurationMins: 120` | High |
| SLA severity | TIER_4 | policies.yaml | High |
| legacyLookBackEnabled | true | Lake registry table.yaml | High |
| DAG note | DAG doc says `SLA: N/A` — CONFLICT with lake registry | gather.md conflict #6 | Flag |

### A4 — Owner / Steward

| Field | Value | Source | Confidence |
|---|---|---|---|
| Team | EDT (Emerald Data Team) | DAG `owner: customer360`, `team: EDT` | High |
| On-call group | `#marketing-data-product-engineering`, `DEV-EDT-OnCall` | DAG | High |
| Email | `dl-bi-enterprise-data@godaddy.com` | DAG | High |
| Prod alerts | `#edt-airflow-alerts` (Slack) | DAG | High |
| Dev alerts | `#edt-airflow-alerts-low-priority`, `#edt` | DAG | High |
| Lake registry owner | `ckpetlbatch` | Lake registry config.yaml | High |
| Project code | `edt` | Lake registry config.yaml | High |
| Confluence stewards | Finance (Business Stewards), Marketing (Stakeholders), DAP (Business Stewards), FORGE (Data Products PgM, Arch) | Confluence hub page | Medium |

### A5 — Schema / Platform

| Field | Value | Source | Confidence |
|---|---|---|---|
| Storage format | Parquet (ZSTD compression) | Lake registry + Spark config | High |
| Table type | Partitioned (overwrite by partition range) | Lake registry table.yaml | High |
| Partition key | `partition_eval_mst_date` (string in Hive; DATE in Redshift) | DDL + table.yaml | High |
| S3 bucket | `gd-ckpetlbatch-prod-customer-core-conformed` | Lake registry config.yaml | High |
| S3 prefix | `customer_core_conformed/customer_metric_daily_agg/` | Hive DDL | High |
| Hive/Glue catalog | `customer_core_conformed.customer_metric_daily_agg` | PySpark code | High |
| Lake catalog | `customer360.customer_metric_daily_agg_vw` | Lake registry | High |
| Redshift schema (prod) | `customer360` | DAG + Redshift DDL | High |
| Redshift schema (dev) | `customer_core_conformed_dev` | DAG | High |
| Redshift DISTKEY | `partition_eval_mst_date` | Redshift DDL | High |
| Redshift SORTKEY | `partition_eval_mst_date` | Redshift DDL | High |
| Redshift DISTSTYLE | AUTO | Redshift DDL | High |

### B1 — Data Grain

| Field | Value | Source | Confidence |
|---|---|---|---|
| Grain | One row per `partition_eval_mst_date` × unique combination of 18 reporting dimensions | USER NOTES + Confluence + DQ constraints + PySpark GROUP BY | Highest |
| 18 dimensions | `customer_type_reason_desc`, `customer_acquisition_mst_month`, `customer_domestic_international_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`, `customer_country_code`, `customer_type_name`, `acquisition_channel_name`, `customer_tenure_year_count`, `product_ownership_category_list`, `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `brand_name_list` | PySpark `dim_cols` list (lines 236–255) | High |
| Dimension continuity fill | Zero-metric rows are inserted for dim combos that were present on the previous day but absent on the evaluation date — ensures `beginning_customer_qty` via LAG is never broken | PySpark `missing_next_day` logic (lines 283–333) | High |

### B2 — Keys / Deduplication

| Field | Value | Source | Confidence |
|---|---|---|---|
| Composite PK (DQ enforced) | 19 columns: `partition_eval_mst_date` + all 18 dim columns | DQ constraints JSON (`customer_metric_daily_agg.json`) | High |
| Lake DDL @PrimaryKey | Only 16 columns annotated (missing `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`) — **incomplete annotation** | gather.md conflict #3 | Flag |
| Dedup strategy | Overwrite by partition (`insertInto(..., overwrite=True)`) — full re-load per partition_eval_mst_date range | PySpark line 438 | High |

### B3 — Partition Strategy

| Field | Value | Source | Confidence |
|---|---|---|---|
| Partition column | `partition_eval_mst_date` (string YYYY-MM-DD in Hive; DATE in Redshift) | DDL + table.yaml | High |
| Partition overwrite range | `start_mst_date` to `end_mst_date` (defaults: yesterday–yesterday; supports multi-day backfill) | PySpark args + DAG | High |
| Recommended always-filter | **Always filter on `partition_eval_mst_date`** | USER NOTES (highest priority) + lake SLA + DQ grain | Highest |
| Files per partition | 1 (repartition(1) before write) | PySpark line 438 | High |
| MSCK REPAIR | Best-effort after insertInto | PySpark lines 442–447 | High |

### B4 — Scope Restrictions / Always-On Filters

| Field | Value | Source | Confidence |
|---|---|---|---|
| ETL date filter on source | `WHERE partition_eval_mst_date BETWEEN '{start_mst_date_minus_1}' AND '{end_mst_date}'` — fetches one extra prior day for LAG calculation | PySpark line 229 | High |
| Final output filter | `WHERE partition_eval_mst_date BETWEEN '{start_mst_date}' AND '{end_mst_date}'` — excludes the extra prior day from output | PySpark line 365 | High |
| No business-rule scope filter | No hardcoded customer segment, geography, or product filter in PySpark — all customers are included | PySpark code review | High |

### B5 — Refresh Schedule

| Field | Value | Source | Confidence |
|---|---|---|---|
| Schedule (prod) | `30 7 * * *` — 7:30 AM MST daily | DAG file | High |
| Schedule (dev) | Disabled (None) | DAG file | High |
| Catchup | False | DAG file | High |
| Max active runs | 15 | DAG file | High |
| Retries | 1, 3-minute delay | DAG file | High |
| Dependency | Waits for `customer360.customer_life_cycle_vw` S3 success file | DAG `dependencies` task | High |
| SLA delivery target | By 08:00 AM MST | Lake registry table.yaml | High |
| Compute | EMR Serverless `emr-7.10.0`, `m6g.16xlarge` (ARM), 15 core instances | DAG | High |
| Spark fallback config | Executor 16G/4 cores, Driver 4G/2 cores, maxExecutors 10 | DAG | High |
| Airflow MWAA | `dof-customers` (AWS account 688051721285) | gather.md infrastructure | High |
| EMR account | `664289052486` | gather.md infrastructure | High |

### C1 — Column Reference
See full C1 table above (32 columns + partition).

### C2 — Business Metrics Definitions

| Metric Name | Definition | Grain |
|---|---|---|
| `ending_customer_qty` | Count of customers with `active_status_flag = true` at end of evaluation date | Per date × 18 dimensions |
| `new_customer_qty` | Count of customers whose `customer_acquisition_mst_date = partition_eval_mst_date` | Per date × 18 dimensions |
| `churn_customer_qty` | Count of customers with a non-null `customer_churn_mst_date` on evaluation date | Per date × 18 dimensions |
| `reactivate_customer_qty` | Count of customers with a non-null `customer_reactivate_mst_date` on evaluation date | Per date × 18 dimensions |
| `merge_customer_qty` | Count of customers with a non-null `customer_merge_mst_date` on evaluation date | Per date × 18 dimensions |
| `beginning_customer_qty` | Prior day's `ending_customer_qty` for the same dimension combination; 0 if no prior consecutive day | Per date × 18 dimensions |
| `net_add_qty` | `ending_customer_qty - beginning_customer_qty` | Per date × 18 dimensions |
| `net_churn_qty` | `churn_customer_qty - reactivate_customer_qty` | Per date × 18 dimensions |
| `net_move_qty` | `ending - beginning - new + churn - reactivate + merge` — reconciliation of customer movement | Per date × 18 dimensions |
| `ttm_gcr_usd_amt` | Sum of trailing-twelve-month gross cash received (USD) per customer, aggregated by dimensions | Per date × 18 dimensions |
| `product_category_qty` | Count of distinct product PNL categories owned by customers in this dimension combination | Per date × 18 dimensions |

### C3 — Common Business Queries (from Alation)

| Query | Purpose | Datasource | Alation URL |
|---|---|---|---|
| NC validate EBP (136952) | Validates C360 metrics vs. legacy DAC over same date ranges | Redshift Prod-BI | https://godaddy.alationcloud.com/query/136952/ |
| C360 - customer_metric_daily_agg_vw_mv (138184) | Enriches with `dim_relative_date` for relative month attribution | Redshift Serverless Dev | https://godaddy.alationcloud.com/query/138184/ |
| C360 Cash Dash with budget (138586) | Time-period (QoQ/YoY/PQ) sandbox for Cash Dashboard | Redshift Prod-BI | https://godaddy.alationcloud.com/query/138586/ |
| C360 - mv_customer_metric_daily_agg_vw_union (138254) | Union of legacy DAC (≤2026-03-31) + C360 (2026-04-01 onward) migration bridge | Redshift Prod-BI | https://godaddy.alationcloud.com/query/138254/ |
| NC validate DAC/MAC/Cash Dash (128804) | Multi-source validation: DAC, MAC, C360 | Redshift Serverless Dev | https://godaddy.alationcloud.com/query/128804/ |
| customer vs target v2 (127875) | Customer vs. target exploration with date dimension for QoQ | Redshift Serverless Dev | https://godaddy.alationcloud.com/query/127875/ |

### C4 — Known Issues / Conflicts

| # | Issue | Code Says | Other Source Says | Verdict |
|---|---|---|---|---|
| 1 | Active source table | `customer_core_conformed.customer_life_cycle` (PySpark line 228) | `customer360.customer_life_cycle_vw` (lake registry lineage, policies.yaml input 1) | Code authoritative — same S3 data; lake lineage registry stale in name only |
| 2 | Lake DDL missing `data_source_enum` | PySpark outputs `'customer360' AS data_source_enum`; Hive DDL includes it | Lake `table.ddl` does not include `data_source_enum` | Hive DDL + code authoritative — lake DDL needs update |
| 3 | Lake DDL @PrimaryKey annotations | DQ JSON: 19-column PK (includes `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`) | Lake `table.ddl` @PrimaryKey only on 16 columns | DQ JSON + code authoritative — lake DDL annotations incomplete |
| 4 | Partition type mismatch | Hive DDL: `partition_eval_mst_date string` | Redshift DDL: `partition_eval_mst_date DATE` | Expected platform type difference, not a true conflict |
| 5 | `customer_country_code` UK→GB normalization | PySpark applies `WHEN UPPER(customer_country_code) = 'UK' THEN 'GB'` | Not documented anywhere else | Code is truth; needs data dictionary documentation |
| 6 | SLA discrepancy | DAG `documentation_markdown`: `SLA: N/A` | Lake registry: delivery by 08:00 AM MST; policies.yaml: 120 min TIER_4 | Flag for owner validation; lake registry SLA more specific |
| 7 | Column ordering difference | PySpark/Hive DDL: `fraud_flag` at position 15 followed by `point_of_purchase_name` (16), `customer_acquisition_bill_fraud_flag` (17), `brand_name_list` (18) | Lake DDL: `brand_name_list` at position 16, then much later `point_of_purchase_name` (28), `customer_acquisition_bill_fraud_flag` (29) | Schema-on-read Parquet — ordering does not cause runtime errors but lake DDL ordering is out of sync |

### C5 — Legacy Replacement

| Field | Value | Source | Priority |
|---|---|---|---|
| Replaced table | `customer_mart.daily_active_customers` (legacy DAC) | USER NOTES (highest priority) | Highest |
| Migration bridge | Alation query 138254 unions legacy DAC (≤2026-03-31) with C360 (2026-04-01+) | Alation | Medium |
| Legacy validation | Alation query 136952 compares DAC vs C360 over same date ranges | Alation | Medium |
| DAC source schema | `dna_approved.daily_active_customers` (Redshift BI prod) | Alation query 136952 | Medium |

### D1 — Upstream Lineage (Multi-Depth)
See Multi-Depth Lineage Tables section above.

### D2 — Downstream Lineage (Observed)

| Consumer | Platform | Nature |
|---|---|---|
| `dev.ba_usi.customer_metric_daily_agg_vw_mv` (Redshift Dev) | Redshift Serverless Dev | Analyst materialized view enriched with relative month |
| `bi.ba_usi.mv_customer_metric_daily_agg_vw_union` (Redshift Prod) | Redshift Prod-BI | Legacy-to-C360 migration bridge table |
| `dna_sandbox.c360_test_sz_2` (Redshift Prod) | Redshift Prod-BI | Cash Dashboard QoQ/YoY sandbox |
| `customer_vs_target` (bi_dashboards_prod / ba_corporate) | Redshift | Cash Dashboard customer vs. budget dashboard |

### E1 — Consumers / Access Groups

| Consumer Group | Environment | Source |
|---|---|---|
| ckpetlbatch | dev_private, prod | Lake registry table.yaml |
| data_lab | dev_private | Lake registry table.yaml |
| analytics | prod | Lake registry table.yaml |
| data_platform | stage, prod | Lake registry table.yaml |
| martech_data | stage, dev_private, prod | Lake registry table.yaml |
| revenue_and_relevance | stage, dev_private, prod, test | Lake registry table.yaml |
| Finance | Business Stewards | Confluence |
| Marketing | Stakeholders | Confluence |
| DAP | Business Stewards | Confluence |

### E2 — Compute / Infrastructure

| Field | Value | Source | Confidence |
|---|---|---|---|
| Orchestration | Airflow (AWS MWAA `dof-customers`) | DAG | High |
| Compute engine | EMR Serverless `emr-7.10.0` | DAG | High |
| Instance type | `m6g.16xlarge` (ARM Graviton2) | DAG | High |
| Core instances | 15 | DAG | High |
| Spark fallback config | Executor: 16G/4 cores; Driver: 4G/2 cores; maxExecutors: 10 | DAG | High |
| Spark compression | ZSTD | PySpark config | High |
| Airflow AWS account | 688051721285 | gather.md | High |
| EMR AWS account | 664289052486 | gather.md | High |
| S3/Data AWS account | 688051721285 | gather.md | High |
| Redshift cluster ARN | `arn:aws:redshift:us-west-2:561403605607:namespace:da7e8313-cc13-40ca-962e-715827b94b24` | gather.md | High |
| Data Lake AWS account | 028140660016 | gather.md | High |
| Redshift load pattern | Staging table → delete-insert (by `end_mst_date`) into `customer360.customer_metric_daily_agg_vw` | DAG + insert SQL | High |

### E3 — Data Quality

| Check | Detail | Source | Confidence |
|---|---|---|---|
| Primary key constraint | 19-column composite PK enforced via DataQualityOperator | `data_quality/constraints/customer_metric_daily_agg.json` | High |
| DQ check (local) | `dq_check_customer_metric_daily_agg_local` on `customer_core_conformed.customer_metric_daily_agg` | DAG | High |
| DQ check (lake) | `dq_check_customer_metric_daily_agg_lake` on `customer360.customer_metric_daily_agg_vw` | DAG | High |
| Enabled | true | DQ constraints JSON | High |
| Dimension completeness | Zero-row fill for missing dim combos ensures reporting stability across dates | PySpark `missing_next_day` logic | High |

---

## Do Not Claim List

The following items are tempting but NOT proven from code/lake artifacts:

1. **Exact row counts or data volumes** — not available from code or gather.md (Alation profiling returned permission error).
2. **Column sample values or value distributions** — not available (Alation column profiling not retrieved).
3. **Historical data availability / backfill depth** — no evidence in code; `legacyLookBackEnabled: true` is set but extent unknown.
4. **`customer_vs_target` is a direct downstream lake table** — only seen in Alation query context; its lineage/registration status unknown.
5. **`data_source_enum` possible values other than 'customer360'** — Hive DDL comment says "Possible values are c360 and legacy_dac" but PySpark always hardcodes 'customer360'; legacy_dac value provenance unknown.
6. **SLA is N/A** — DAG doc says `SLA: N/A` but lake registry and policies.yaml both specify concrete SLA. Do not claim SLA is N/A; flag the conflict.
7. **`customer360.customer_life_cycle_vw` is the active code source** — it is commented out in PySpark (line 227). The active source is `customer_core_conformed.customer_life_cycle`.
8. **2+/3+ customer metrics** — mentioned in Confluence Customer Metrics page but no corresponding columns in the table DDL or PySpark code.
9. **Legacy DAC cutover date is permanent** — Alation query 138254 uses 2026-03-31 as the legacy cutover, but this is analyst query evidence, not ETL configuration.
10. **Grain is unique** — the PySpark `GROUP BY` and DQ composite PK together imply uniqueness, but no explicit UNIQUE constraint exists; rely on DQ check evidence only.


**The agent's final response to the user was:**
The analysis is complete. Here is a summary of what was done:

---

## Analysis Summary

### Target Table Resolved
**`customer360.customer_metric_daily_agg_vw`** — confidence: **HIGH**

The PySpark writes to the Hive/Glue intermediate `customer_core_conformed.customer_metric_daily_agg`. This resolves to the lake table via S3 path identity confirmed by `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.yaml` (`table_relative_path: customer_metric_daily_agg`, `database_root: gd-ckpetlbatch-prod-customer-core-conformed`, `path_to_database: customer_core_conformed`).

### Lineage Resolution
| Source in code | Resolved to (lake) | Method |
|---|---|---|
| `customer_core_conformed.customer_life_cycle` | `customer360.customer_life_cycle_vw` | Found producer script `customer_life_cycle.py` in source repo; both point to same S3 path. Lake registry confirmed at `dlms-api/us-west-2/customer360/customer-life-cycle-vw/`. |

### Column-Level Lineage (32 columns)
All 32 output columns (including the partition `partition_eval_mst_date`) are mapped to their derivation from `customer360.customer_life_cycle_vw` with descriptive transformation text — covering direct mappings, COALESCE defaults, aggregations (SUM, COUNT_IF), window functions (LAG), calculated fields, and the hardcoded literal `data_source_enum`.

### Key Conflicts Flagged
- Lake DDL missing `data_source_enum` column
- Lake DDL @PrimaryKey annotations incomplete (missing `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`)
- Lake lineage registry stale (lists `customer_life_cycle_vw`; active code uses the Hive form)
- UK→GB country code normalization undocumented outside code

### Multi-depth Lineage
- **Depth 1 upstream:** 1 table (`customer360.customer_life_cycle_vw`)
- **Depth 2 upstream:** 20 tables (from `customer_life_cycle_vw` lake registry lineage)
- **Depth 1 downstream:** 4 analyst-created downstream tables (from Alation queries evidence)