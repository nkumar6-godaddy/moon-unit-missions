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
- Optional lake table override
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
# Example: if source repo URL is https://github.com/gdcorp-dna/my-repo.git
# then folder is repos/my-repo/
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

## Step 4: Collect nearby repo context (secondary sources)
- Read relevant files under sibling folders:
  - `ddl/` (table DDLs) — helpful but may be stale
  - `policies/` — helpful but may be stale
  - `data_quality/` — checks and expectations (treat as evidence, not truth)
Record any conflicts with code explicitly.

## Step 5: Fetch Confluence pages (if provided)
For each URL in INPUT.md under CONFLUENCE PAGES, fetch page content via Atlassian REST API.
The page ID is the numeric part of the URL path.

**IMPORTANT: Parent pages may link to child pages.** A provided URL might be a parent/hub
page (e.g., "Customer360") containing links to multiple child pages for individual tables.
You MUST:
1. Fetch the provided page first.
2. List its child pages using:
   ```bash
   curl -s -u "$ATLASSIAN_CREDS" \
     "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}/child/page?limit=50"
   ```
3. From the child pages, identify which ones are relevant to the target table
   (match by table name, job name, or domain keywords).
4. Fetch ONLY the relevant child pages (not all of them).
5. If the provided page itself has useful content, use it too.

Credentials:
- Prefer `MOONUNIT_JIRA` env var (JSON: {"url","email","api_token"}) OR
- `MOONUNIT_ATLASSIAN` env var (JSON: {"email","api_token"})

Example:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA || process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Extract only content relevant to business meaning, grain, metrics, filters, SLAs, ownership.

## Step 6: Alation lookup (if enabled)
If INPUT.md says Alation is enabled:
1. First check if `MOONUNIT_ALATION` env var is available:
```bash
node -e "if(!process.env.MOONUNIT_ALATION){console.log('MOONUNIT_ALATION not set');process.exit(1)}else{console.log('OK')}"
```
If it's not available, skip Alation and note this in gather.md under "Alation: skipped (credentials not available)".

2. If available, create API token:
```bash
ALATION_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ALATION); console.log(JSON.stringify({refresh_token:j.refresh_token, user_id:j.user_id||j.ALATION_USER_ID}))")
TOKEN=$(curl -s -X POST "https://godaddy.alationcloud.com/integration/v1/createAPIAccessToken/" \
  -H "Content-Type: application/json" \
  -d "$ALATION_CREDS" | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).api_access_token))")
```

3. **Fetch table entries for the target table name** (once you know it from code analysis).
   Search Alation for the table by name to find BOTH the Redshift Serverless and Lake entries:
```bash
curl -s -H "Token: $TOKEN" \
  "https://godaddy.alationcloud.com/integration/v2/table/?name=<TABLE_NAME>&limit=50"
```
   From the results, identify:
   - **Redshift Serverless Dev entry**: look for entries where the Alation key
     starts with `dev.` (e.g., `63.dev.customer360.table_name`). This is the
     Dev Serverless environment. ALWAYS use the `dev.*` entry, NOT the `bi.*`
     (prod) entry. Record its Alation table ID.
   - **Lake entry**: look for entries where the key matches the Hive/Glue catalog
     (often contains the schema directly like `<schema>.<table>`). Record its Alation table ID.

   Construct Alation URLs as: `https://godaddy.alationcloud.com/table/<ID>/`

4. Record in gather.md under "## Alation" a structured block:
   - Redshift Dev Serverless table (dev.* key): name, database ("Redshift - Serverless - Dev"), schema, Alation URL, Table ID, Type (e.g., View, Table)
   - Lake table: name, database ("GoDaddy Central Data Lake (Prod)"), schema, Alation URL, Lake Alation ID, Type
   - Table description (if available)
   - Column profiling data if available (sample values, distinct count, null count, min/max, common values) — for C1 Sample Values and Key Statistics columns

## Step 6b: Fetch Alation queries referencing this table

After you know the target table name (from PySpark/DAG), fetch saved queries in Alation
that reference it. Use `Max queries` from INPUT.md (default 10).

```bash
TABLE_NAME=<table_name_only e.g. customer_metric_daily_agg_vw>
MAX_QUERIES=<from INPUT.md>
curl -s -H "Token: $TOKEN" \
  "https://godaddy.alationcloud.com/integration/v1/query/?content__icontains=${TABLE_NAME}&order_by=-last_saved_at&limit=${MAX_QUERIES}"
```

For EACH query in the response, record under "## Alation Queries" in gather.md:

| Field | Source |
|---|---|
| Query ID | `id` |
| Title | `title` |
| Author | `author.display_name` or `author.username` or empty |
| Description | `description` if present; else one-line summary from SQL |
| Schedule | `schedule_cron`, `schedule_name`, or "Not scheduled" |
| Last Saved | `last_saved_at` |
| Last Run | `schedule_db_ts_last_execution` or latest execution event if available |
| Datasource | map `datasource_id` to name if possible; else empty |
| Alation Query URL | `https://godaddy.alationcloud.com/query/<id>/` |
| SQL | `content` field — copy verbatim, do not modify |

If the query API returns no results, try `content__icontains=<schema>.<table>` as well.
If still none, note "No Alation queries found" under ## Alation Queries.

## Step 7: Output (append to gather.md)
Append a structured, evidence-oriented report including:
- PySpark job identity (repo/ref/path), and the exact output write target(s) found (if any)
- DAG identity (path, schedule, params calling the PySpark)
- Enumerated upstream/local tables referenced in the PySpark
- Any DDL/policy/DQ files consulted and what they claim
- Confluence summaries (if any)
- Alation section with:
  - Redshift Dev Serverless table info (dev.* entry: table name, database, schema, Alation URL, Table ID, Type, description)
  - Lake table info (name, database, schema, Alation URL, Lake Alation ID, Type)
  - Column profiling data (sample values, statistics) if retrieved
- Alation Queries section (full query details per Step 6b)
- Multi-depth lineage from Alation or lake registry (if available): Depth 1/2 upstream, Depth 1 downstream
- A "Conflicts / discrepancies" section listing any contradictions with the code

**The agent summarized its work in this way:**

---

## Stage: gather — customer_life_cycle

**Gathered:** 2026-06-10  
**Source repo:** `repos/dof-dpaas-customer-feature` (branch: `main`, ref checked out)  
**PySpark path:** `customer360/customer-metrics/src/pyspark/customer_life_cycle.py`

---

## 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo | `https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git` |
| Branch/Ref | `main` |
| Script path | `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |
| FEED_NAME constant | `customer_life_cycle` |
| Initial author | aghosh, 2025-10-31 |
| Purpose (header comment) | "Driver table for customer life cycle. It keeps track of customer life cycle details for active and churned customers. Main driver table for customer aggregated metrics." |

### Output Write Target (from PySpark code — authoritative)

```python
combined_customer_life_cycle_df.repartition(30).write.insertInto(
    "customer_core_conformed.customer_life_cycle", overwrite=True
)
spark.sql("MSCK REPAIR TABLE customer_core_conformed.customer_life_cycle")
```

| Field | Value |
|---|---|
| Lake database | `customer_core_conformed` |
| Lake table | `customer_life_cycle` |
| Qualified name | `customer_core_conformed.customer_life_cycle` |
| Write mode | `insertInto` with `overwrite=True` (dynamic partition overwrite) |
| Post-write | `MSCK REPAIR TABLE` (best-effort; failures logged and skipped) |
| S3 location (from DDL) | `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/` |
| Format | Parquet |
| Partition key | `partition_eval_mst_date` (string) |
| DDL file used | `customer_life_cycle.ddl` (passed to EMR via `--files`) |

**Note on lake-facing table:** The DAG also calls `SuccessNotificationOperator` with `db_name="customer360"`, `table_name="customer_life_cycle_vw"`, which registers completion of the **lake-facing view** `customer360.customer_life_cycle_vw`. The internal staging write goes to `customer_core_conformed.customer_life_cycle`.

---

## 2. DAG Identity

| Field | Value |
|---|---|
| DAG file | `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` |
| DAG ID | `customer-life-cycle` |
| Data pipeline name | `customer-life-cycle` |
| Schedule | `"20 7 * * *"` → **7:20 AM MST daily** (disabled in dev-private) |
| Start date | 2026-01-01 |
| Catchup | False |
| Max active runs | 15 |
| Owner | `customer360` |
| Retries | 1 (retry_delay: 3 min) |
| EMR release | `emr-7.10.0` |
| EMR master | `m6g.xlarge` |
| EMR core | `m6g.16xlarge` × 15 nodes |
| Spark catalog | AWS Glue Data Catalog (Iceberg extensions enabled) |
| Pyspark script S3 | `s3://gd-{team}-{env}-dof-customers-pipeline-code/pyspark/customer360/customer-metrics/src/pyspark/customer_life_cycle.py` |
| Alerts Slack | `#edt-airflow-alerts` (prod) / `#edt-airflow-alerts-low-priority` (non-prod) |
| Dev group | `#edt` (private) |
| OnCall group | `#marketing-data-product-engineering` |
| OnCall email | `dl-bi-enterprise-data@godaddy.com` |
| OnCall SNOW | `DEV-EDT-OnCall` |
| SLA (DAG doc) | N/A |
| Data tier (DAG doc) | N/A |
| Tags | `domain:customer`, `sub-domain:active-customer`, `layer:enterprise`, `team:EDT`, `pipeline-group:active-customer`, `special:daily` |

**DAG task flow:**
1. `dag_config` (Python: resolve eval_mst_date, switchboard params)
2. `dependencies` (S3KeySensor group — waits for all upstream table success files)
3. `end_dependency_check`
4. `create_redshift_tables_done` (creates Redshift tables via SQL files)
5. `create_emr`
6. `run_customer_life_cycle` (EMR Serverless spark-submit)
7. `remove_emr`
8. `customer_life_cycle_local_dq` (DataQualityOperator on `customer_core_conformed.customer_life_cycle`)
9. `conditional_call_lake_api` (branch: prod only calls lake API)
10. `call_lake_api` (SuccessNotificationOperator for `customer360.customer_life_cycle_vw`)
11. `customer_life_cycle_lake_dq` (DataQualityOperator on `customer360.customer_life_cycle_vw`)
12. `s3_to_redshift_customer_life_cycle_stg` (S3→Redshift staging load)
13. `insert_customer_life_cycle` (SQL upsert into Redshift prod table)
14. `check_for_failure_branch` → `succeed_dag_run` / `fail_dag_run`

**Eval date logic:** Passed as DAG param `eval_mst_date`; defaults to `logical_date` in MST timezone if not provided. Success file date = eval_mst_date + 1 day.

**Redshift targets:**
- Staging: `{customer_core_conformed_prod|customer_core_conformed_dev}.customer_life_cycle_vw_stg`
- Prod: `{customer360|customer_core_conformed_dev}.customer_life_cycle_vw`
- Source S3 for Redshift COPY: `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/customer_life_cycle/partition_eval_mst_date={eval_mst_date}/`

---

## 3. Input Tables (Upstream Dependencies)

Declared in PySpark `get_tables()` and confirmed by DAG S3KeySensor wait dependencies and `policies/customer_life_cycle_dag.yaml`.

| # | Table | Environment | Notes |
|---|---|---|---|
| 1 | `analytic_feature.shopper_acquisition` | all envs | Acquisition date, fraud flag, country code, channel |
| 2 | `analytic_feature.customer_type_history` | all envs | Customer type name and reason |
| 3 | `customer360.dim_customer_history_vw` | all envs | Private label ID (format: iceberg) |
| 4 | `finance360.dim_country_vw` | all envs | Country name/region lookup (format: iceberg) |
| 5 | `dp_enterprise.dim_reseller` | prod/stage: `dp_enterprise`; dev: `dp_enterprise_linked` | Reseller type by private_label_id |
| 6 | `enterprise.dim_new_acquisition_shopper` | prod/stage: `enterprise`; dev: `enterprise_linked` | New acquisition bill/date |
| 7 | `enterprise.dim_subscription_history` | prod/stage: `enterprise`; dev: `enterprise_linked` | Subscription details (for intraday and eval+1 logic) |
| 8 | `ecomm_mart.bill_line_traffic_ext` | all envs | Bill channel attribution (≥ 2022-08) |
| 9 | `customer_core_conformed.customer_ttm_payment_driver` | all envs | TTM GCR, bill list |
| 10 | `customer_core_conformed.customer_active_subscription_detail_driver` | all envs | Active subscriptions, product lists, intraday flag |
| 11 | `customer_core_conformed.active_customer_stg` | all envs | Active customer status (2-day window: d-1 and d) |
| 12 | `analytic_feature.customer_fraud` | all envs | Fraud date and reinstatement |
| 13 | `analytic_feature.shopper_merge` | all envs | Merge date |
| 14 | `ecomm_mart.dim_bill_line_purchase_attribution` | all envs | Point of purchase name |
| 15 | `finance360.dim_bill_fraud_history_vw` | all envs | Acquisition bill fraud flag |
| 16 | `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` | hardcoded prod | Legacy bill line traffic (< 2022-08); direct S3 read |

**Note:** `finance360.dim_bill_fraud_history_vw` appears twice in `policies/customer_life_cycle_dag.yaml` — once as `parquet`, once as `iceberg`. This is a policy-file duplication, not a code conflict.

---

## 4. Key Business Logic (from PySpark source)

### Grain
One row per **shopper_id + partition_eval_mst_date**. Confirmed by DQ constraint:
```json
{ "column": "Array(\"partition_eval_mst_date\", \"shopper_id\")", "code": ".isPrimaryKey(\"partition_eval_mst_date\", \"shopper_id\")" }
```

### Customer Status at Eval Date
Derived from `active_customer_stg` comparing day-1 vs day-0 partitions:
| Status | Definition |
|---|---|
| `new` | NOT active on d-1, IS active on d |
| `existing` | Active on d-1, still active on d |
| `churned` | Active on d-1, NOT active on d |
| `intraday` | Acquired today but not yet in active_customer_stg |

### Customer State Enum (final derived field, priority order)
1. `intraday` if customer_status = 'intraday'
2. `merged` if customer_merge_mst_date IS NOT NULL
3. `churned` if customer_churn_mst_date IS NOT NULL
4. `reactivated` if customer_reactivate_mst_date IS NOT NULL
5. `new` if customer_acquisition_mst_date = partition_eval_mst_date
6. `active` otherwise

### Data Source for Churned vs Non-Churned
- Non-churned (new, existing, intraday): subscription/TTM from `partition_eval_mst_date = eval_mst_date`
- Churned: subscription/TTM from `partition_eval_mst_date = eval_mst_date_minus_1`

### Key Filters Applied
- **Subscription filter:** `finance_payable_resource_flag = true` AND (`subscription_billing_shopper_differ_flag = false` OR LEKA customers OR `domain_payment_override_flag = true`)
- **TTM filter:** `trxn_currency_code <> 'N/A'` AND `net_positive_ttm_payment_flag = true`
- **Intraday:** `intraday_flag = true`, cross-checked against `dim_new_acquisition_shopper` and NOT in `active_customer_stg`
- **123 Reg override:** shoppers with `private_label_id = 587240` get `customer_type_name = '123 Reg'`
- **UK→GB normalization:** `customer_acquisition_country_code` = 'UK' remapped to 'GB'

### Date Parameters
- `eval_mst_date`: primary evaluation date (default: yesterday MST)
- `eval_mst_date_minus_1`: used for churned customers' data, and 2-day TTM window
- `eval_mst_date_plus_1`: used to query `dim_subscription_history` (history is available next day)

---

## 5. DDL / Policy / DQ Files Consulted

### DDL: `customer_life_cycle.ddl` (Hive/Glue — used by PySpark)
- 35 columns + partition key `partition_eval_mst_date`
- `STORED AS PARQUET`
- `LOCATION 's3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/'`
- Claimed primary keys in comment: `resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date` — **STALE/INCORRECT**: these are from an older table. Actual PK enforced in DQ is `partition_eval_mst_date + shopper_id`.

### DDL: `ddls/create_customer_life_cycle.sql` (Redshift table)
- Creates `{database}.customer_life_cycle_vw` in Redshift
- `DISTSTYLE AUTO`, `DISTKEY (partition_eval_mst_date)`, `SORTKEY (partition_eval_mst_date)`
- `partition_eval_mst_date` is `DATE` type in Redshift (vs `string` in Hive/Glue) — minor type difference

### Policy: `policies/customer_life_cycle_dag.yaml`
- Pipeline version: 1.0.0
- SLA: `maxDurationMins: 120`, severity: `TIER_4`
- Lists 2 outputs: `customer360.customer_life_cycle_vw` (datalake) and `customer_core_conformed.customer_life_cycle` (S3)
- **Discrepancy:** `finance360.dim_bill_fraud_history_vw` listed twice (parquet + iceberg). Code reads it once.
- **Discrepancy:** `analytic_feature.shopper_tenure` listed in Confluence design doc as source for tenure but NOT in PySpark code. Tenure is computed directly from `shopper_acquisition_mst_date`.

### DQ: `data_quality/constraints/customer_life_cycle.json`
- Primary key check: `isPrimaryKey("partition_eval_mst_date", "shopper_id")` — enabled
- Applied against `customer_core_conformed.customer_life_cycle`

### Lake Registry: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/`
- `table.yaml`: description = "Analytic Dataset for Customer Life Cycle"
- `table_relative_path`: `customer_life_cycle` (S3 subfolder)
- `storage_format`: Parquet
- `table_type`: PARTITIONED
- `partition_keys`: `partition_eval_mst_date` (string)
- **SLA:** `deliveryCadenceUTC: "cron(00 15 * * ? *)"` → delivery by 08:00 AM MST every day; `sloIdentifier: customer360.customer_life_cycle_vw`; `legacyLookBackEnabled: true`
- **Data tier:** 4
- **Consumers (permissions):** ckpetlbatch.dev_private, data_lab.dev_private, analytics.prod, data_platform.stage, data_platform.prod, ckpetlbatch.prod, data_platform.stage/customer_analytics, data_platform.prod/care_analytics, martech_data (all envs), revenue_and_relevance (all envs + test), data_platform.stage/partners, data_platform.prod/partners

#### Upstream lineage in lake registry (may be broader than PySpark code)
The lake `table.yaml` lists these upstream tables (more than what the current PySpark reads — likely includes historical/planned sources):
```
analytic_feature.customer_fraud
analytic_feature.customer_type_history
analytic_feature.shopper_acquisition
analytic_feature.shopper_merge
customer360.dim_customer_history_vw
customers.customer_id_mapping_snapshot         ← NOT in current PySpark
dp_enterprise.dim_reseller
ecomm_mart.bill_line_traffic_ext
ecomm_mart.dim_bill_line_purchase_attribution
ecomm_mart.entitlement_bill_type               ← NOT in current PySpark
enterprise.dim_bill_shopper_id_xref            ← NOT in current PySpark
enterprise.dim_entitlement_history             ← NOT in current PySpark
enterprise.dim_new_acquisition_shopper
enterprise.dim_subscription_history
enterprise.fact_bill_line                      ← NOT in current PySpark
enterprise.fact_entitlement_bill               ← NOT in current PySpark
finance360.dim_bill_fraud_history_vw
finance360.dim_country_vw
finance360.dim_product_vw                      ← NOT in current PySpark
finance_cln.manual_paid_subscription           ← NOT in current PySpark
```
**⚠️ Discrepancy:** Lake registry lists 7 additional upstream sources not used in the current PySpark script. These may be aspirational/historical lineage entries that should be validated.

---

## 6. Confluence Pages

### Parent: Customer360 (ID: 3779199819)
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360  
Relevant child pages found: Customer Lifecycle, Customer Metrics, and others.

### Child: Customer Lifecycle (ID: 3970861345)
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3970861345/Customer+Lifecycle  
Summary of relevant content:
- **Purpose:** "Physical Model for Customer Lifecycle table which will act as driver for Customer Metrics requested by Finance."
- Column mapping spreadsheet: SharePoint link referenced
- Column mapping confirms: `customer_acquisition_mst_date` has guards for future dates
- **Acquisition date rules:**
  - New customer + future acq date → use subscription_create_mst_date or evaluation_date
  - Existing customer + non-past acq date → NULL
- **Churn definition:** Customer was active on d-1 but not on d; churn date = evaluation_date; all metrics/active products are NULL for churned (only dim values retained)
- **Reactivation:** New customer in active table whose acquisition date is older than today (prior churn event)
- **Merge date:** `shopper_merge_end_mst_date` from `analytic_feature.shopper_merge` — set for the original (churned) shopper only
- **Intraday churn:** Customers with `subscription_create_mst_date = subscription_cancel_mst_date = eval_mst_date`
- Referenced Alation article: https://godaddy.alationcloud.com/article/98/churned-customer
- Column mapping spreadsheet referenced but not accessible (SharePoint)

### Child: Customer Metrics (ID: 4042131239)
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131239/Customer+Metrics  
- Finance requirements doc referenced (FDM Customer Metrics and Attributes spreadsheet)
- Conceptual data model diagram (Gliffy) referenced but not readable via API
- Contains Customer Lifecycle Conceptual Data Model and Customer Lifecycle Events

---

## 7. Alation

### Lake Entry
| Field | Value |
|---|---|
| Table Name | `customer_life_cycle_vw` |
| Database | GoDaddy Central Data Lake (Prod) |
| Schema | `AwsDataCatalog.customer360` |
| Alation Key | `81.AwsDataCatalog.customer360.customer_life_cycle_vw` |
| Alation Table ID | `7038345` |
| Alation URL | https://godaddy.alationcloud.com/table/7038345/ |
| Type | TABLE |
| DS_ID | 81 |

**Table Description (from Alation):**
> A comprehensive snapshot table that tracks the complete lifecycle journey of customers from acquisition through various lifecycle states. This table captures daily snapshots of customer status, enabling analysis of state transitions, and changes between consecutive evaluation periods.
>
> **Key Features:**
> - Lifecycle tracking (acquisition, churn, reactivation, merge, fraud)
> - Active subscription product tracking
> - Multi-dimensional state tracking through Foreign Keys
> - Trailing twelve month (TTM) GCR
>
> **Primary Key(s):** Customer_id
>
> **Common Use Cases:** Physical Model for Customer Lifecycle table which will act as driver for Customer Metrics requested by Finance.
>
> **GitHub Repo:** https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/dag/customer_life_cycle_dag.py
>
> **Data Design:** https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3970861345/Customer+Lifecycle

**Column descriptions in Alation match DDL.** Alation lists `customer_state_enum` as `"Customer states as of evaluation date (active, churned, merged, fraud)"` — note `fraud` instead of `reactivated`.

### Redshift Serverless Dev Entry
| Field | Value |
|---|---|
| Table Name | `customer_life_cycle_vw` |
| Database | Redshift - Serverless - Dev |
| Schema | `dev.customer360` |
| Alation Key | `132.dev.customer360.customer_life_cycle_vw` |
| Alation Table ID | `7038917` |
| Alation URL | https://godaddy.alationcloud.com/table/7038917/ |
| Type | TABLE |
| DS_ID | 132 |
| Description | N/A (no description set) |

### Other Redshift Entries Found (not used per instructions)
- `63.bi.customer_core_conformed_dev.customer_life_cycle_vw` (ID: 7038691) — bi.* entry (prod), not the dev.* entry
- `63.bi.customer360.customer_life_cycle_vw` (ID: 7038888)
- `147.cet.customer360_spectrum.customer_life_cycle_vw` (ID: 7044063)

### Column Profiling
No column profiling data available via the Alation v2 table API endpoint used (profiling statistics not returned in the table list response). Would require additional per-column API calls not performed in this gather stage.

---

## 8. Alation Queries

10 most recently saved queries referencing `customer_life_cycle_vw` retrieved from Alation (datasource_id: 132 = Redshift Serverless Dev).

| Query ID | Title | Author | Description | Schedule | Last Saved | Last Run | Datasource | Alation URL |
|---|---|---|---|---|---|---|---|---|
| 123877 | [Serverless] Lighthouse Intent Dash | N/A | Migrated from query ID: 122917 | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/123877/ |
| 139259 | C360 - mv_customer_churn_diagnostic | N/A | | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/139259/ |
| 139061 | Union: Customer Lifecycle AND 2+Customer History | N/A | | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/139061/ |
| 138820 | C360 - two_plus_churn_driver_tree | N/A | | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/138820/ |
| 138821 | C360 - two_plus_customer_adds | N/A | | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/138821/ |
| 138886 | Micro Merchant Phase 2 Policy Instant Payouts | N/A | Phase 2 Policy Instant Payouts for MicroMerchants | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/138886/ |
| 135046 | Micro Merchants Fast Payouts Analysis | N/A | Micro Merchants Fast Payouts Analysis | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/135046/ |
| 123350 | Care Shopper Exploration | N/A | Migrated from query ID: 79354 | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/123350/ |
| 138291 | Google Migration Query V14 — DRAFT (refund-aware renewals; refunded renewals count as cancelled) | N/A | | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/138291/ |
| 138288 | Google Migration Query V13 — DRAFT (churn via customer_life_cycle_vw, 2a2b_v2, C3 >= 2026-04-01) | N/A | | Not scheduled | N/A | N/A | 132 | https://godaddy.alationcloud.com/query/138288/ |

**Note:** `last_saved_at`, `author`, and `last_run` fields were null/missing in the Alation API response for all queries (API returned `undefined` for these fields). Authors may not be exposed via this API version.

### SQL Excerpts (key patterns referencing customer_life_cycle_vw)

**Query 123877 — [Serverless] Lighthouse Intent Dash** (SQL excerpt showing table usage):
```sql
drop table if exists product_ownership_date;
create temp table product_ownership_date as 
select rpt_date,  max(partition_eval_mst_date) as closest_product_date
from gdlh_intent a
JOIN (SELECT distinct partition_eval_mst_date FROM dev.customer360.customer_life_cycle_vw) b 
ON b.partition_eval_mst_date <=a.rpt_date 
GROUP BY 1;
```
*Used to align care contact dates to nearest available lifecycle partition.*

**Query 139259 — C360 - mv_customer_churn_diagnostic** (SQL excerpt):
```sql
-- 1. Date spine: one row per calendar month from 2024-05-01 to today
DROP TABLE IF EXISTS as_of_date;
CREATE TEMP TABLE as_of_date DISTSTYLE ALL AS
SELECT
    calendar_date                              AS start_date,
    TRUNC(DATE_ADD('month', 1, calendar_date)) AS end_date
FROM dna_approved.dim_...
-- [references customer_life_cycle_vw for churn diagnostics]
```

**Query 139061 — Union: Customer Lifecycle AND 2+Customer History** (SQL excerpt):
```sql
DROP TABLE IF EXISTS dev.ba_usi.mv_legacy_c360_lifecycle;
CREATE TABLE dev.ba_usi.mv_legacy_c360_lifecycle AS
WITH acq_channel_shoppers AS (
    SELECT item_tracking_code, channel_grouping_name AS ga_channel_grouping_name,
           bill_isc_channel_name, merged_shopper_id ...
-- [unions customer_life_cycle_vw with legacy customer history]
```

**Query 138820 — C360 - two_plus_churn_driver_tree** (SQL excerpt):
```sql
DROP TABLE IF EXISTS dev.ba_usi.mv_two_plus_churn_driver_tree_pre;
CREATE TABLE dev.ba_usi.mv_two_plus_churn_driver_tree_pre AS
WITH acq_channel_shoppers AS (
    SELECT item_tracking_code, ...
-- [2+ product customer churn analysis using customer_life_cycle_vw]
```

**Query 138821 — C360 - two_plus_customer_adds** (SQL excerpt):
```sql
DROP TABLE IF EXISTS dev.ba_usi.mv_two_plus_customer_adds;
CREATE TABLE dev.ba_usi.mv_two_plus_customer_adds AS
WITH acq_channel_shoppers AS (
    SELECT item_tracking_code, channel_...
-- [2+ product customer new adds analysis using customer_life_cycle_vw]
```

**Query 138288 — Google Migration Query V13** (SQL excerpt):
```sql
/*=====================================================================
  Google Migration Query V13 — DRAFT (new-query fork of V12 #138268)
  -------------------------------------------------------------------
  What's new vs V12:
    Shopper churn is now sourced from customer_life_cycle_vw instead...
-- [Google Migration cohort analysis; churn sourced from customer_life_cycle_vw]
```

**Query 138291 — Google Migration Query V14** (SQL excerpt):
```sql
/*=====================================================================
  Google Migration Query V14 — DRAFT (refund-aware renewals)
  -------------------------------------------------------------------
  What's new vs V13 (#138288): ...
-- [Domain renewal/cancellation analysis building on V13]
```

**Query 138886 — Micro Merchant Phase 2 Policy Instant Payouts** (SQL excerpt):
```sql
drop table if exists business;
create temp table business as
select * from dev.poynt_cln.business_cln
where snap_date in (Select max(snap_date) from dev.poynt_cln.business_cln) and region='US';
-- [Micro Merchant analysis that joins to customer_life_cycle_vw]
```

**Query 135046 — Micro Merchants Fast Payouts Analysis** (SQL excerpt):
```sql
drop table if exists scores;
create temp table scores as
(SELECT business_uuid, neural_net_model_score_rate, xgb_model_score_rate, max_score, ...
-- [Fast payouts scoring that references customer_life_cycle_vw]
```

**Query 123350 — Care Shopper Exploration** (SQL excerpt):
```sql
DROP TABLE IF EXISTS s360_history_stg;
CREATE temp TABLE s360_history_stg AS
SELECT shopper_id, evaluation_mst_date, customer_type_name, acq_bill_mst_date,
       0 as shopper_mrr_gcr_usd_amt, crm_portfolio_type_name, acq_country_name, ...
-- [Care shopper cohort query referencing customer_life_cycle_vw for lifecycle status]
```

---

## 9. Lineage Summary

### Depth 1 Upstream (from PySpark code — authoritative)
1. `analytic_feature.shopper_acquisition`
2. `analytic_feature.customer_type_history`
3. `customer360.dim_customer_history_vw`
4. `finance360.dim_country_vw`
5. `dp_enterprise.dim_reseller`
6. `enterprise.dim_new_acquisition_shopper`
7. `enterprise.dim_subscription_history`
8. `ecomm_mart.bill_line_traffic_ext`
9. `customer_core_conformed.customer_ttm_payment_driver`
10. `customer_core_conformed.customer_active_subscription_detail_driver`
11. `customer_core_conformed.active_customer_stg`
12. `analytic_feature.customer_fraud`
13. `analytic_feature.shopper_merge`
14. `ecomm_mart.dim_bill_line_purchase_attribution`
15. `finance360.dim_bill_fraud_history_vw`
16. `s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/` (legacy, direct S3)

### Depth 1 Downstream (from DAG and Alation queries)
- `customer_core_conformed.customer_life_cycle_vw_stg` (Redshift staging, loaded by DAG)
- `customer360.customer_life_cycle_vw` (Redshift prod, populated from staging)
- `dev.ba_usi.mv_legacy_c360_lifecycle` (Alation query 139061)
- `dev.ba_usi.mv_two_plus_churn_driver_tree_pre` (Alation query 138820)
- `dev.ba_usi.mv_two_plus_customer_adds` (Alation query 138821)
- Various ad-hoc analytics: Lighthouse intent dash, Google Migration cohort, Micro Merchant analysis, Care shopper exploration

---

## 10. Output Schema (from PySpark `conform_datatype` + DDL — authoritative)

| Column | Hive Type | Redshift Type | Description |
|---|---|---|---|
| `shopper_id` | string | VARCHAR(256) | PK component; unique numeric ID for shopper profile |
| `customer_id` | string | VARCHAR(256) | PK component; unique UUID across GoDaddy systems |
| `customer_acquisition_bill_id` | string | VARCHAR(256) | FK to shopper_acquisition; bill triggering first net positive status |
| `customer_acquisition_mst_date` | date | DATE | Date of acquisition bill (MST) |
| `customer_acquisition_mst_month` | string | VARCHAR(256) | Month of acquisition, truncated to month |
| `customer_acquisition_country_code` | string | VARCHAR(256) | Country code of acquisition; 'UK' remapped to 'GB' |
| `customer_acquisition_channel_name` | string | VARCHAR(256) | Channel of acquisition |
| `customer_tenure_year_count` | int | INTEGER | Tenure in years |
| `customer_acquisition_country_name` | string | VARCHAR(256) | Country name |
| `customer_region_1_name` | string | VARCHAR(256) | Geographic region 1 |
| `customer_region_2_name` | string | VARCHAR(256) | Geographic region 2 |
| `customer_region_3_name` | string | VARCHAR(256) | Geographic region 3 |
| `customer_domestic_international_name` | string | VARCHAR(256) | Domestic or international |
| `reseller_type_id` | int | INTEGER | FK to dp_enterprise.dim_reseller |
| `reseller_type_name` | string | VARCHAR(256) | Reseller name |
| `customer_type_name` | string | VARCHAR(256) | Customer type at eval date; '123 Reg' override for private_label_id=587240 |
| `customer_type_reason_desc` | string | VARCHAR(256) | Why classified as this type |
| `customer_fraud_flag` | boolean | BOOLEAN | True if flagged fraud at eval date |
| `active_paid_subscription_list` | array<string> | SUPER | FK to dim_subscription_history; active paid subscription_ids |
| `product_pnl_category_list` | array<string> | SUPER | Product PNL categories |
| `product_pnl_category_qty` | int | INTEGER | Count of distinct PNL categories |
| `product_pnl_line_list` | array<string> | SUPER | Product PNL lines |
| `ttm_all_bill_list` | array<string> | SUPER | All TTM bill IDs |
| `brand_name_list` | array<string> | SUPER | Associated brands |
| `ttm_gcr_usd_amt` | decimal(18,2) | DECIMAL(18,2) | Trailing 12-month Gross Cash Received (USD) |
| `customer_churn_mst_date` | date | DATE | Most recent churn date; NULL if not churned |
| `customer_reactivate_mst_date` | date | DATE | Most recent reactivation date |
| `customer_merge_mst_date` | date | DATE | Date merged into another account |
| `customer_fraud_mst_date` | date | DATE | Date fraud flag was set |
| `customer_state_enum` | string | VARCHAR(256) | Enumerated: active, churned, merged, reactivated, new, intraday |
| `active_status_flag` | boolean | BOOLEAN | True if active at eval date |
| `point_of_purchase_name` | string | VARCHAR(256) | Point of purchase from acquisition bill |
| `customer_acquisition_bill_fraud_flag` | boolean | BOOLEAN | True if acquisition bill in dim_bill_fraud_history_vw |
| `etl_build_mst_ts` | timestamp | TIMESTAMP | ETL build timestamp (MST) |
| `partition_eval_mst_date` | string (Hive) / DATE (Redshift) | — | Partition key; data collection date |

---

## 11. Conflicts / Discrepancies

| # | Source | Claim | Code Says | Action |
|---|---|---|---|---|
| 1 | `customer_life_cycle.ddl` (header comment) | Primary key: `resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date` | DQ constraint enforces `partition_eval_mst_date + shopper_id` | DDL header comment is stale/copied from another table. Code (DQ) is correct. |
| 2 | `policies/customer_life_cycle_dag.yaml` | `finance360.dim_bill_fraud_history_vw` listed twice (once as parquet, once as iceberg) | Used once in PySpark | Policy YAML has duplicate entry; no code impact. |
| 3 | Lake `table.yaml` lineage | Lists 7 additional upstream tables (e.g., `customers.customer_id_mapping_snapshot`, `enterprise.fact_bill_line`, `finance_cln.manual_paid_subscription`, etc.) | PySpark does not read these tables | Lake registry lineage is more expansive than current code; may be aspirational or historical. Needs validation. |
| 4 | Confluence (Customer Lifecycle design doc) | `analytic_feature.shopper_tenure` listed as source for `customer_tenure_year_count` | PySpark computes tenure directly from `shopper_acquisition_mst_date`; no read of `shopper_tenure` table | Design doc is outdated. Code is authoritative. |
| 5 | Alation table description | `customer_state_enum` described as "active, churned, merged, fraud" | PySpark produces: active, churned, merged, reactivated, new, intraday | Alation description is incomplete/incorrect. Code is authoritative. |
| 6 | Alation Lake description | Primary key is `Customer_id` (alone) | DQ constraint and PySpark write use composite PK: `partition_eval_mst_date + shopper_id` | Alation description is incorrect. Code/DQ is authoritative. |
| 7 | Redshift DDL `partition_eval_mst_date` type | `DATE` | Hive DDL uses `string` | Type mismatch between Hive and Redshift schemas; functionally equivalent but technically inconsistent. |
| 8 | DAG SLA documentation | "N/A" | Lake registry SLA: delivery by 08:00 AM MST daily (`cron(00 15 * * ? *)`) | DAG doc is not updated; lake registry SLA is the authoritative SLA. |


**The agent's final response to the user was:**
All research has been gathered and appended to `gather.md`. Here is a summary of what was found:

---

## Summary

**Table:** `customer360.customer_life_cycle_vw` (Lake) / `customer_core_conformed.customer_life_cycle` (internal)

### PySpark & DAG (Source of Truth)
- **Script:** `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` (author: aghosh, 2025-10-31)
- **DAG:** `customer_life_cycle_dag.py` — DAG ID `customer-life-cycle`, schedule `20 7 * * *` (7:20 AM MST daily), EMR 7.10.0 on m6g.16xlarge × 15 nodes
- **Output:** `customer_core_conformed.customer_life_cycle` (Hive/Glue, Parquet, partitioned by `partition_eval_mst_date`), then mirrored to Redshift as `customer360.customer_life_cycle_vw`
- **Grain:** One row per `shopper_id + partition_eval_mst_date` (enforced by DQ PK constraint)

### Business Logic
- Classifies customers as `new`, `existing`, `churned`, or `intraday` by comparing two consecutive days of `active_customer_stg`
- Final `customer_state_enum` = intraday > merged > churned > reactivated > new > active
- UK→GB country code normalization; 123 Reg type override (private_label_id=587240)
- 16 upstream sources including legacy S3 direct read for pre-2022-08 bill data

### Supporting Sources
- **Confluence** (Customer Lifecycle page ID 3970861345): confirms design intent; references outdated `shopper_tenure` table not used in code
- **Alation Lake entry** (ID 7038345): good description; but incorrectly lists PK as `Customer_id` alone and omits `reactivated`/`new`/`intraday` from state enum
- **Alation Dev entry** (ID 7038917): `132.dev.customer360.customer_life_cycle_vw`; no description set
- **10 Alation queries** retrieved — key consumers: Google Migration cohort analysis, C360 churn diagnostics, 2+ product customer driver trees, Lighthouse care analytics, Micro Merchant analysis

### 8 Conflicts/Discrepancies Documented
Most notable: stale DDL PK comment, Alation state enum incomplete, lake registry lineage lists 7 sources not in current PySpark, DAG SLA doc says "N/A" but lake registry specifies 8 AM MST delivery SLA.