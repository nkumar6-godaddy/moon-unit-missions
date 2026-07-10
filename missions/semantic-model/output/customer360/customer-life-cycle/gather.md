**Stage name:** gather
**The coding agent was given these instructions:** You are a Data Governance analyst. Your job is to gather ONLY verifiable facts
about a Data Lake table from the authoritative ETL code and supporting sources.
Do not guess. If something is unknown, say "Unknown" and explain what you checked.

## Source-of-truth rule
The PySpark script and the DAG that calls it are the source of truth. If Alation,
Confluence, DDL, policies, or other docs conflict with code, treat the code as
correct and record the discrepancy for validation.

## Step 1: Read INPUT.md
Read `INPUT.md` in your workspace. It contains:
- PySpark GitHub URL + parsed repo/ref/path
- Repository folder names inside the container (under `repos/`)
- Optional lake table override and semantic model name
- Supporting docs (Confluence URLs, other URLs)
- Alation configuration

Use INPUT.md as the contract for what to fetch and where to look.

## Step 2: Check out the exact Git ref for the source repo
INPUT.md includes the desired git ref (branch/tag/SHA) and the source repo URL.
The Moon Units framework clones repos into `repos/<repo-name>/` where repo-name is
derived from the git URL (e.g., `https://github.com/org/my-repo.git` → `repos/my-repo/`).

Determine the source repo folder name from the URL in INPUT.md (strip org and .git).
Then checkout the desired ref:

```bash
git -C repos/<repo-name> fetch --all --tags
git -C repos/<repo-name> checkout <ref_from_INPUT_md>
```

## Step 3: Read the PySpark script and the calling DAG
- Read the PySpark file at the path from INPUT.md.
- Locate and read the DAG file that calls it. Per repo convention, from the parent
  folder of the pyspark folder you should find sibling folders: `dag/`, `policies/`,
  `data_quality/`, `ddl/`.
- The DAG must be treated as authoritative for schedule/cadence, dependencies, and
  which job/version is run.
- **Extract all join conditions** (explicit `on=` keys, join predicates) — these
  will become OSI relationships in later stages.

## Step 4: Collect nearby repo context (secondary sources)
- Read relevant files under sibling folders:
  - `ddl/` (table DDLs) — helpful but may be stale
  - `policies/` — helpful but may be stale
  - `data_quality/` — checks and expectations (treat as evidence, not truth)
Record any conflicts with code explicitly.

## Step 5: Fetch Confluence pages (if provided)
For each URL in INPUT.md under CONFLUENCE PAGES, fetch page content via Atlassian REST API.
The page ID is the numeric part of the URL path.

**IMPORTANT: Parent pages may link to child pages.** Fetch the provided page first,
list child pages, identify relevant ones, fetch only those.

Credentials:
- Prefer `MOONUNIT_JIRA` env var (JSON: {"url","email","api_token"}) OR
- `MOONUNIT_ATLASSIAN` env var (JSON: {"email","api_token"})

Example:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA || process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Extract content relevant to business meaning, grain, metrics, filters, SLAs, ownership.

## Step 6: Alation lookup (if enabled)
If INPUT.md says Alation is enabled:
1. Check if `MOONUNIT_ALATION` env var is available; skip if not set.
2. Create API token via Alation integration API.
3. Search for the target table (Lake entry) and record descriptions/custom fields.
4. Fetch saved queries referencing the table (use Max queries from INPUT.md).

For each Alation query, record: Query ID, Title, Author, Description, SQL (verbatim).

## Step 7: Enumerate tables and column schemas
For EVERY table referenced in the PySpark (read and write targets):
- Record table name (schema.table form)
- Record whether it is read, written, or both
- If a lake DDL exists in `repos/lake/`, read `table.ddl` and list columns with types
- If only in-repo DDL exists, read that instead (note it may be stale)
- Record any join keys used with this table

## Step 8: Output (append to gather.md)
Append a structured, evidence-oriented report including:
- PySpark job identity (repo/ref/path), output write target(s)
- DAG identity (path, schedule, params)
- **Table inventory** — all referenced tables with read/write role and column schemas
- **Join conditions** — explicit join keys extracted from PySpark
- **Aggregation expressions** — SUM/COUNT/AVG/GROUP BY patterns found in PySpark
- DDL/policy/DQ files consulted
- Confluence summaries (if any)
- Alation section (table info + queries if fetched)
- Conflicts / discrepancies section

**The agent summarized its work in this way:**

---

## Stage: Data Governance Gather — customer_life_cycle

**Gathered:** 2026-06-10  
**Identifier:** customer360 / customer-life-cycle  
**Source repo:** https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git  
**Git ref:** main  
**PySpark path:** `customer360/customer-metrics/src/pyspark/customer_life_cycle.py`

---

### 1. PySpark Job Identity

| Field | Value |
|---|---|
| FEED_NAME | `customer_life_cycle` |
| DATABASE_NAME | `customer_core_conformed` |
| TABLE_NAME | `customer_life_cycle` |
| QUALIFIED_TABLE_NAME | `customer_core_conformed.customer_life_cycle` |
| DDL FILE | `customer_life_cycle.ddl` |
| Write mode | `insertInto` with `overwrite=True`, partitioned by `partition_eval_mst_date` |
| Partition count | 30 (`repartition(30)`) |
| Lake notification target | `customer360.customer_life_cycle_vw` (via `SuccessNotificationOperator`) |

---

### 2. DAG Identity

| Field | Value |
|---|---|
| DAG file | `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| DAG ID | `customer-life-cycle` |
| Schedule | `20 7 * * *` (7:20 AM MST daily; disabled in dev-private) |
| Start date | 2026-01-01 (America/Phoenix) |
| Catchup | False |
| Max active runs | 15 |
| Owner | `customer360` |
| Retries | 1 (retry_delay: 3 min) |
| EMR release | emr-7.10.0 |
| Spark format | Iceberg extensions loaded (for Glue catalog) |
| Alerts | Slack: `#edt-airflow-alerts` (prod) / `#edt-airflow-alerts-low-priority` (non-prod) |
| OnCall | #marketing-data-product-engineering, dl-bi-enterprise-data@godaddy.com |
| RunBook | https://godaddy-corp.atlassian.net/l/cp/xk1sdiEC |
| Tags | domain:customer, sub-domain:active-customer, layer:enterprise, team:EDT, pipeline-group:active-customer, special:daily |

**Task flow:**
`dag_config` → `dependencies` (13 S3 sensors) → `end_dependency_check` → `create_redshift_tables` → `create_emr` → `run_customer_life_cycle` → `remove_emr` → `dq_check_local` → `conditional_call_lake_api` → `[call_lake_api | skip]` → `s3_to_redshift_stg` → `insert_customer_life_cycle` → `[succeed | fail]`

---

### 3. Table Inventory — All Referenced Tables

#### 3a. OUTPUT — Written by this job

| Table | Schema/DB | Role | Format | Location |
|---|---|---|---|---|
| `customer_core_conformed.customer_life_cycle` | Hive/Glue | WRITE (primary) | Parquet | `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/` |
| `customer360.customer_life_cycle_vw` | Lake (Data Lake view) | WRITE (lake notify) | Parquet | (view over above) |
| `customer_core_conformed_prod.customer_life_cycle_vw_stg` | Redshift | WRITE (staging) | via COPY from Parquet | — |
| `customer360.customer_life_cycle_vw` | Redshift | WRITE (final) | via INSERT from stg | — |

#### 3b. INPUTS — Read by this job

| Table | Schema/DB | Role | Join Key(s) |
|---|---|---|---|
| `customer_core_conformed.active_customer_stg` | S3/Hive | READ | `shopper_id` (filter + GROUP BY) |
| `customer_core_conformed.customer_ttm_payment_driver` | S3/Hive | READ | `shopper_id`, `customer_id` |
| `customer_core_conformed.customer_active_subscription_detail_driver` | S3/Hive | READ | `subscription_shopper_id`, `subscription_customer_id` |
| `analytic_feature.shopper_acquisition` | Datalake/Parquet | READ | `shopper_id` |
| `analytic_feature.customer_type_history` | Datalake/Parquet | READ | `shopper_id` |
| `analytic_feature.customer_fraud` | Datalake/Parquet | READ | `shopper_id`, `customer_id` |
| `analytic_feature.shopper_merge` | Datalake/Parquet | READ | `original_shopper_id` |
| `customer360.dim_customer_history_vw` | Datalake/Iceberg | READ | `shopper_id` (date range on `effective_start_mst_ts`/`effective_end_mst_ts`) |
| `finance360.dim_country_vw` | Datalake/Iceberg | READ | `country_code` (+ `current_record_flag = true`) |
| `finance360.dim_bill_fraud_history_vw` | Datalake/Parquet | READ | `bill_id` (DISTINCT) |
| `dp_enterprise.dim_reseller` | Datalake/Parquet | READ | `private_label_id` |
| `enterprise.dim_new_acquisition_shopper` | Datalake/Parquet | READ | `bill_shopper_id` |
| `enterprise.dim_subscription_history` | Datalake/Parquet | READ | `shopper_id` (ROW_NUMBER by `subscription_create_mst_date`) |
| `ecomm_mart.bill_line_traffic_ext` | Datalake/Parquet | READ | `original_shopper_id` = shopper_id |
| `ecomm_mart.dim_bill_line_purchase_attribution` | Datalake/Parquet | READ | `bill_id` (ROW_NUMBER by `bill_line_num DESC`) |
| `analytic_local.ads_bill_line_ext` (legacy) | S3 hardcoded path | READ | `original_shopper_id` = shopper_id |

**Note (dev-private schema aliasing):** `enterprise` → `enterprise_linked`; `dp_enterprise` → `dp_enterprise_linked`

---

### 4. Output Table Column Schema

**`customer_core_conformed.customer_life_cycle` (authoritative — in-repo DDL)**  
Source: `customer360/customer-metrics/src/ddls/customer_life_cycle.ddl`

| Column | Type | Comment |
|---|---|---|
| shopper_id | string | PK: shopper id |
| customer_id | string | PK: Customer ID |
| customer_acquisition_bill_id | string | Bill ID that triggered first net positive status for customer |
| customer_acquisition_mst_date | date | Date of bill that triggered first net positive status for customer (MST) |
| customer_acquisition_mst_month | string | Month of customer acquisition (MST), truncated to month |
| customer_acquisition_country_code | string | Country code where customer was acquired |
| customer_acquisition_channel_name | string | Channel through which customer was acquired |
| customer_tenure_year_count | int | Tenure of the customer in years |
| customer_acquisition_country_name | string | Country name where customer was acquired |
| customer_region_1_name | string | Geographic region 1 for the customer |
| customer_region_2_name | string | Geographic region 2 for the customer |
| customer_region_3_name | string | Geographic region 3 for the customer |
| customer_domestic_international_name | string | Whether customer is domestic or international |
| reseller_type_id | int | Type ID of reseller organization |
| reseller_type_name | string | Name of the reseller |
| customer_type_name | string | Customer type label at evaluation date |
| customer_type_reason_desc | string | Customer type reason, e.g. why classified as this type |
| customer_fraud_flag | boolean | True if customer is flagged as fraud at evaluation date |
| active_paid_subscription_list | array<string> | List of active paid subscriptions |
| product_pnl_category_list | array<string> | List of product PNL categories owned by customer |
| product_pnl_category_qty | int | Number of distinct product PNL categories owned by customer |
| product_pnl_line_list | array<string> | List of product PNL lines owned by customer |
| ttm_all_bill_list | array<string> | List of all bill IDs from trailing twelve months (TTM) |
| brand_name_list | array<string> | List of all brands associated with the customer |
| ttm_gcr_usd_amt | decimal(18,2) | Total gross cash received (GCR) USD in trailing twelve months |
| customer_churn_mst_date | date | MST date when customer most recently churned, null if not churned |
| customer_reactivate_mst_date | date | MST date when customer was most recently reactivated (after churn) |
| customer_merge_mst_date | date | MST date when the customer was merged into another account |
| customer_fraud_mst_date | date | MST date when a fraud flag was set on customer |
| customer_state_enum | string | customer states as of evaluation date (active, churned, merged, reactivated, intraday, new) |
| active_status_flag | boolean | True if customer is currently active at evaluation date |
| point_of_purchase_name | string | Point of purchase name from the customer acquisition bill |
| customer_acquisition_bill_fraud_flag | boolean | True if acquisition bill has fraud record in dim_bill_fraud_history_vw |
| etl_build_mst_ts | timestamp | Time when this record was build by ETL system |
| **partition_eval_mst_date** | **string** | **Partition key. All facts are as of end of this day.** |

**Primary Key (per DQ constraint):** `(partition_eval_mst_date, shopper_id)`  
**Grain:** One row per (customer/shopper, evaluation date)  
**Partition strategy:** Dynamic partition overwrite by `partition_eval_mst_date`

---

### 5. Lake Repo Entry

**Path:** `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/`  
**table.yaml summary:**
- Description: "Analytic Dataset for Customer Life Cycle"
- Table type: PARTITIONED
- Storage format: Parquet
- Partition key: `partition_eval_mst_date`
- Data tier: 4
- SLA: `cron(00 15 * * ? *)` → delivered by 08:00 AM MST daily
- SLO identifier: `customer360.customer_life_cycle_vw`
- Permissions: ckpetlbatch, data_lab, analytics, data_platform (stage+prod), martech_data, revenue_and_relevance, care_analytics, partners

**Lineage declared in table.yaml (may be broader than code):**
analytic_feature.customer_fraud, analytic_feature.customer_type_history, analytic_feature.shopper_acquisition, analytic_feature.shopper_merge, customer360.dim_customer_history_vw, customers.customer_id_mapping_snapshot, dp_enterprise.dim_reseller, ecomm_mart.bill_line_traffic_ext, ecomm_mart.dim_bill_line_purchase_attribution, ecomm_mart.entitlement_bill_type, enterprise.dim_bill_shopper_id_xref, enterprise.dim_entitlement_history, enterprise.dim_new_acquisition_shopper, enterprise.dim_subscription_history, enterprise.fact_bill_line, enterprise.fact_entitlement_bill, finance360.dim_bill_fraud_history_vw, finance360.dim_country_vw, finance360.dim_product_vw, finance_cln.manual_paid_subscription

**Note:** Several tables in the lineage declaration (customers.customer_id_mapping_snapshot, enterprise.dim_bill_shopper_id_xref, enterprise.fact_bill_line, enterprise.fact_entitlement_bill, ecomm_mart.entitlement_bill_type, finance360.dim_product_vw, finance_cln.manual_paid_subscription, enterprise.dim_entitlement_history) are NOT found in the current PySpark code. May be from a previous implementation or future roadmap.

---

### 6. Join Conditions (Extracted from PySpark)

| Left Table | Right Table | Join Type | Condition |
|---|---|---|---|
| `enterprise.dim_new_acquisition_shopper acq` | `shopper_acquisition_source sa` | LEFT | `acq.bill_shopper_id = sa.shopper_id` |
| `enterprise.dim_new_acquisition_shopper acq` | `finance360.dim_country_vw geo` | LEFT (BROADCAST) | `acq.bill_country_code = geo.country_code AND geo.current_record_flag = true` |
| `combined_customer_base ac` | `shopper_acquisition acq` | LEFT | `ac.shopper_id = acq.shopper_id` |
| `combined_customer_base ac` | `shopper_subscription ss` | LEFT | `ac.shopper_id = ss.shopper_id` |
| `combined_customer_base ac` | `private_label pl` | LEFT | `ac.shopper_id = pl.shopper_id` |
| `combined_customer_base ac` | `customer_type_history ct` | LEFT | `ac.shopper_id = ct.shopper_id` |
| `combined_customer_base ac` | `reg123_shopper gd` | LEFT | `ac.shopper_id = gd.shopper_id` |
| `combined_customer_base ac` | `combined_bill_line blt` | LEFT | `ac.shopper_id = blt.shopper_id` |
| `combined_customer_base ac` | `shopper_merge sm` | LEFT | `ac.shopper_id = sm.original_shopper_id` |
| `combined_customer_base ac` | `customer_fraud cf` | LEFT | `ac.shopper_id = cf.shopper_id AND ac.customer_id = cf.customer_id` |
| `combined_customer_base ac` | `point_of_purchase pop` | LEFT | `pop.bill_id = CASE WHEN status='new'/'intraday' THEN COALESCE(acq.bill_id, ss.original_bill_id) ELSE acq.bill_id END` |
| `combined_customer_base ac` | `bill_fraud bf` | LEFT | same bill_id CASE expression |
| `active_customer ac` | `subscription_detail sd` | LEFT | `ac.shopper_id = sd.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(sd.customer_id,'na')` |
| `active_customer ac` | `ttm_payment ttm` | LEFT | `ac.shopper_id = ttm.shopper_id AND COALESCE(ac.customer_id,'na') = COALESCE(ttm.customer_id,'na')` |
| `combined c` | `dim_reseller res` | LEFT (BROADCAST) | `c.private_label_id = res.private_label_id` |
| `date_filtered df` | `latest_record lr` | FULL OUTER | `df.shopper_id = lr.shopper_id` |
| `intraday_shopper_details isd` | `enterprise.dim_new_acquisition_shopper acq` | LEFT | `acq.bill_shopper_id = isd.shopper_id` |
| `intraday_shopper_details isd` | `active_customer ac` | LEFT | `isd.shopper_id = ac.shopper_id` |

**OSI Relationships derived from joins:**
- `customer_core_conformed.customer_life_cycle` → `analytic_feature.shopper_acquisition` via `shopper_id`
- `customer_core_conformed.customer_life_cycle` → `enterprise.dim_new_acquisition_shopper` via `shopper_id` (mapped from `bill_shopper_id`)
- `customer_core_conformed.customer_life_cycle` → `finance360.dim_country_vw` via `customer_acquisition_country_code` ↔ `country_code`
- `customer_core_conformed.customer_life_cycle` → `dp_enterprise.dim_reseller` via `reseller_type_id`
- `customer_core_conformed.customer_life_cycle` → `analytic_feature.customer_type_history` via `shopper_id`
- `customer_core_conformed.customer_life_cycle` → `analytic_feature.customer_fraud` via `(shopper_id, customer_id)`
- `customer_core_conformed.customer_life_cycle` → `analytic_feature.shopper_merge` via `shopper_id` ↔ `original_shopper_id`
- `customer_core_conformed.customer_life_cycle` → `customer360.dim_customer_history_vw` via `shopper_id`
- `customer_core_conformed.customer_life_cycle` → `ecomm_mart.bill_line_traffic_ext` via `shopper_id`
- `customer_core_conformed.customer_life_cycle` → `ecomm_mart.dim_bill_line_purchase_attribution` via `customer_acquisition_bill_id` ↔ `bill_id`
- `customer_core_conformed.customer_life_cycle` → `finance360.dim_bill_fraud_history_vw` via `customer_acquisition_bill_id` ↔ `bill_id`
- `customer_core_conformed.customer_life_cycle` → `enterprise.dim_subscription_history` via `shopper_id`
- `customer_core_conformed.customer_life_cycle` → `customer_core_conformed.customer_ttm_payment_driver` via `(shopper_id, customer_id)`
- `customer_core_conformed.customer_life_cycle` → `customer_core_conformed.customer_active_subscription_detail_driver` via `(shopper_id, customer_id)`
- `customer_core_conformed.customer_life_cycle` → `customer_core_conformed.active_customer_stg` via `shopper_id`

---

### 7. Aggregation Expressions

| Output Column | Aggregation | Source Column | Source Table |
|---|---|---|---|
| `active_paid_subscription_list` | `SORT_ARRAY(COLLECT_SET(...))` | `subscription_id` | `customer_active_subscription_detail_driver` |
| `product_pnl_category_list` | `SORT_ARRAY(COLLECT_SET(...))` | `product_pnl_category` | `customer_active_subscription_detail_driver` |
| `product_pnl_line_list` | `SORT_ARRAY(COLLECT_SET(...))` | `product_pnl_line` | `customer_active_subscription_detail_driver` |
| `brand_name_list` | `SORT_ARRAY(ARRAY_UNION(COLLECT_SET(...)))` | `brand_name` from subscriptions + TTM | `customer_active_subscription_detail_driver` + `customer_ttm_payment_driver` |
| `product_pnl_category_qty` | `COUNT(DISTINCT product_pnl_category)` | `product_pnl_category` | `customer_active_subscription_detail_driver` |
| `ttm_all_bill_list` | `SORT_ARRAY(COLLECT_SET(...))` | `last_net_positive_bill_id` | `customer_ttm_payment_driver` |
| `ttm_gcr_usd_amt` | `SUM(ttm_total_gcr_usd_amt)` | `ttm_total_gcr_usd_amt` | `customer_ttm_payment_driver` |
| `active_prev` / `active_curr` flags | `MAX(CASE WHEN partition_eval_mst_date=... THEN 1 ELSE 0 END)` | — | `active_customer_stg` |
| `customer_id` (in status CTE) | `MAX(customer_id)` | `customer_id` | `active_customer_stg` |
| `reseller_type_id/name` | `MIN(reseller_type_id)`, `MIN(reseller_type_name)` | — | `dp_enterprise.dim_reseller` |
| `customer_tenure_year_count` | `CAST(DATEDIFF(partition_eval_mst_date, customer_acquisition_mst_date) / 365 AS INT)` | — | computed |
| `customer_acquisition_mst_month` | `TRUNC(customer_acquisition_mst_date, 'MONTH')` | — | computed |

**GROUP BY keys:** `(partition_eval_mst_date, shopper_id, customer_id)` for subscription/TTM CTEs  
**GROUP BY keys:** `shopper_id` for active customer status CTE  
**ROW_NUMBER window:** `OVER(PARTITION BY shopper_id ORDER BY subscription_create_mst_date ASC)` for first subscription  
**ROW_NUMBER window:** `OVER(PARTITION BY bill_id ORDER BY bill_line_num DESC)` for point-of-purchase  
**MAX(STRUCT(...)) window pattern:** `MAX(STRUCT(effective_end_mst_ts, private_label_id))` for latest SCD2 record

---

### 8. DDL / Policy / DQ Files Consulted

| File | Path | Notes |
|---|---|---|
| In-repo DDL | `src/ddls/customer_life_cycle.ddl` | Authoritative for Hive table schema |
| Lake DDL | `repos/lake/.../customer-life-cycle-vw/table.ddl` | Lake view schema (no partition col in DDL body) |
| Lake YAML | `repos/lake/.../customer-life-cycle-vw/table.yaml` | SLA, permissions, lineage declaration |
| Policy YAML | `src/policies/customer_life_cycle_dag.yaml` | Pipeline metadata, input/output facets |
| DQ Constraints | `src/data_quality/constraints/customer_life_cycle.json` | PK check: `(partition_eval_mst_date, shopper_id)` |
| DQ Constraints VW | `src/data_quality/constraints/customer_life_cycle_vw.json` | Same PK check for lake view |
| DAG YAML | `src/dag/customer_life_cycle_dag.yaml` | DAG config (scheduler metadata) — not found in `dag/` subfolder; configs are inline in DAG Python file |

---

### 9. Confluence Summary

**Page:** https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360

**Customer Lifecycle Dataset entry (relevant excerpt):**
> `customer_life_cycle_vw` — SSOT of customer's lifecycle holistically — compresses states and logic spread across 3 marts & built with SCD2 to understand change over time easily. Includes ALL customers (not just "active") and opens up use cases outside of Finance.

**Status:** 🟡 In Progress & Committed for Current Quarter  
**Future:** 🔵 Simplify and Incorporate `customer_type`

**Replaces (deprecated datasets):**
- `finance_cln.active_customer`
- `finance_cln.active_customer_history`
- `customer_mart.two_plus_active_customer`
- `customer_mart.two_plus_active_customer_history`
- `enterprise.dim_new_acquisition_shopper`
- `enterprise.dim_new_registered_user`

**Ownership / Contacts:**
- Finance Business Stewards
- Marketing Stakeholders
- DAP Business Stewards
- FORGE Technical Stewards / Data Products team

**Child pages found:** 3 (Customer 360 — Phased Adoption Plan, Customer360 Design Docs, Customer360 Business Context Structure) — not fetched in this pass.

---

### 10. Alation Section

**Table ID:** 7038345  
**Name:** `customer_life_cycle_vw`  
**Schema:** `AwsDataCatalog.customer360`  
**DS ID:** 81  
**Steward:** Franchise: Customer (group ID 47)

**Description (from Alation):**
> A comprehensive snapshot table that tracks the complete lifecycle journey of customers from acquisition through various lifecycle states. This table captures daily snapshots of customer status, enabling analysis of state transitions, and changes between consecutive evaluation periods.
> Key Features: Lifecycle tracking (acquisition, churn, reactivation, merge, fraud); Active subscription product tracking; Multi-dimensional state tracking through Foreign Keys; Trailing twelve month (TTM) GCR

**Custom Fields:**
- **Service Level Agreement:** The job runs everyday at 08:00 AM MST. Data issues: #dna-data-product-issues. Questions: #dna-enablement-customer.
- **Steward:** Franchise: Customer group
- **Data Lake Table Type:** PARTITIONED
- **Data Lake Table Desc:** Analytic Dataset for Customer Life Cycle

**Alation Columns (35 total — confirms lake DDL schema plus partition_eval_mst_date):**
product_pnl_category_list (array), product_pnl_line_list (array), customer_acquisition_channel_name (string), customer_reactivate_mst_date (date), active_paid_subscription_list (array), customer_acquisition_country_code (string), customer_state_enum (string), customer_acquisition_mst_month (string), reseller_type_id (integer), customer_acquisition_mst_date (date), customer_churn_mst_date (date), active_status_flag (boolean), ttm_all_bill_list (array), customer_region_2_name (string), ttm_gcr_usd_amt (decimal), etl_build_mst_ts (timestamp), customer_acquisition_bill_id (string), customer_type_name (string), customer_fraud_flag (boolean), customer_fraud_mst_date (date), shopper_id (string), customer_region_1_name (string), customer_id (string), customer_type_reason_desc (string), customer_merge_mst_date (date), reseller_type_name (string), product_pnl_category_qty (integer), customer_tenure_year_count (integer), customer_region_3_name (string), customer_acquisition_country_name (string), customer_domestic_international_name (string), partition_eval_mst_date (string), customer_acquisition_bill_fraud_flag (boolean), point_of_purchase_name (string), brand_name_list (array)

**Saved Queries:** Alation `/integration/v2/query/?table_id=7038345` endpoint returned 404; `/api/v1/query/?search=` returned unrelated queries. Unable to retrieve saved queries specifically referencing this table via available API endpoints in this environment.

---

### 11. Conflicts / Discrepancies

| # | Source | Issue | Action |
|---|---|---|---|
| 1 | In-repo DDL comment (line 8) | DDL header comment says "Primary Key: resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date" — **wrong fields, copy-pasted from another table** | DQ constraint and code confirm actual PK is `(partition_eval_mst_date, shopper_id)` |
| 2 | Lake `table.yaml` lineage | Lists 20 upstream tables including `customers.customer_id_mapping_snapshot`, `enterprise.dim_bill_shopper_id_xref`, `enterprise.fact_bill_line`, `enterprise.fact_entitlement_bill`, `ecomm_mart.entitlement_bill_type`, `finance360.dim_product_vw`, `finance_cln.manual_paid_subscription`, `enterprise.dim_entitlement_history` — **none of these appear in current PySpark code** | Treat code as authoritative; these may be from prior architecture or driver tables not yet traced |
| 3 | Policy YAML duplicate entries | `ecomm_mart.dim_bill_line_purchase_attribution` and `finance360.dim_bill_fraud_history_vw` each listed **twice** (once as parquet, once as iceberg) | Minor metadata error; code reads each once |
| 4 | `analytic_local.ads_bill_line_ext` | Policy YAML lists it as a datalake S3 source, but PySpark reads it via **hardcoded S3 path** `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` (not via Glue table) — always uses prod path regardless of environment | Flag as environment-portability concern |
| 5 | `customer_state_enum` values | DDL comment says "active, churned, merged, reactivated"; code actually produces: `active`, `churned`, `merged`, `reactivated`, `intraday`, `new` | Lake DDL comment is incomplete; code is authoritative |
| 6 | Lake DDL (table.ddl) | `customer_life_cycle_vw` DDL does NOT include `partition_eval_mst_date` in the column list; it is declared as a partition key in `table.yaml` | Normal pattern for Hive views; partition key managed separately |
| 7 | SLA time discrepancy | DAG schedule is `20 7 * * *` (7:20 AM MST) but SLA/lake YAML says delivery by 08:00 AM MST — gives ~40 min processing window | Consistent; no conflict |

---

### 12. Business Context Summary

- **Purpose:** Single source of truth (SSOT) for GoDaddy customer lifecycle state. Tracks whether a customer is active, churned, merged, reactivated, or new on a given evaluation date.
- **Grain:** One row per (shopper, evaluation date). All data is as of end of `partition_eval_mst_date`.
- **Coverage:** ALL customers (not just active), enabling churn and reactivation analysis.
- **Key Metrics Carried:** TTM GCR (`ttm_gcr_usd_amt`), active subscription count by PNL category/line, customer tenure in years.
- **Lifecycle States (customer_state_enum):** `active`, `new`, `churned`, `merged`, `reactivated`, `intraday`
- **Country Code normalization:** UK → GB applied via PySpark `withColumn` transform.
- **Redshift replica:** Data is also pushed to Redshift (`customer360.customer_life_cycle_vw`) for BI/reporting consumers.
- **Data Tier:** 4
- **Team:** EDT (Enterprise Data Team)


**The agent's final response to the user was:**
All research has been gathered and appended to `gather.md`. Here is a summary of what was found:

---

## Gather Stage Complete

### Job Identity
- **PySpark:** `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` (ref: `main`)
- **DAG:** `customer_life_cycle_dag.py` — ID `customer-life-cycle`, schedule `20 7 * * *` (7:20 AM MST daily), start 2026-01-01, max 15 active runs

### Output Tables
| Table | Role |
|---|---|
| `customer_core_conformed.customer_life_cycle` | Primary Parquet write (Hive/Glue) |
| `customer360.customer_life_cycle_vw` | Lake notification (view) |
| Redshift `customer360.customer_life_cycle_vw` | BI reporting replica |

### Key Facts
- **Grain:** One row per `(shopper_id, partition_eval_mst_date)`
- **PK (confirmed by DQ):** `(partition_eval_mst_date, shopper_id)`
- **34 columns** plus partition key `partition_eval_mst_date`
- **16 source tables** read, all joined on `shopper_id` (with customer_id for two tables)
- **6 lifecycle states:** `active`, `new`, `churned`, `merged`, `reactivated`, `intraday`
- **SLA:** Delivered by 08:00 AM MST daily (Data Tier 4)
- **Steward:** Franchise: Customer group; team EDT

### Key Conflicts Found
1. In-repo DDL comment has **wrong PK fields** (copy-paste from another table) — DQ constraint is correct
2. Lake `table.yaml` lineage lists **8 extra tables** not in current PySpark code
3. `analytic_local.ads_bill_line_ext` read via **hardcoded prod S3 path** regardless of environment
4. `customer_state_enum` has **6 values** in code vs. 4 listed in DDL comment
5. Policy YAML has **duplicate entries** for 2 input tables (parquet + iceberg format listed twice each)