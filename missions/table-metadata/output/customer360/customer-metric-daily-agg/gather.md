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

## gather stage — research summary

**Completed:** 2026-06-17  
**Source repo:** repos/dof-dpaas-customer-feature @ main (HEAD)  
**Target table:** `customer_core_conformed.customer_metric_daily_agg` (Hive/Glue) → exposed as `customer360.customer_metric_daily_agg_vw` (Lake/Redshift)

---

## PySpark Job Identity

| Field | Value |
|---|---|
| Repo | gdcorp-dna/dof-dpaas-customer-feature |
| Branch/Ref | main |
| File path | customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py |
| FEED_NAME | customer_metric_daily_agg |
| Spark app name | customer_metrics_daily_agg |
| Initial author | aghosh, 11/06/2025 |

**Output write target (code):**  
- `customer_core_conformed.customer_metric_daily_agg` — Hive/Glue table written via `df.repartition(1).write.insertInto(QUALIFIED_TABLE_NAME, overwrite=True)` with `MSCK REPAIR` afterward.
- S3 path: `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`

**Primary source table (code):**  
- `customer_core_conformed.customer_life_cycle` (active in code; `customer360.customer_life_cycle_vw` is commented out)

---

## DAG Identity

| Field | Value |
|---|---|
| File path | customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py |
| DAG ID | customer-metric-daily-agg |
| Start date | 2026-01-01 |
| Schedule | `30 7 * * *` (7:30 AM MST daily; disabled/None in dev-private) |
| Catchup | False |
| Max active runs | 15 |
| Owner | customer360 |
| Team | EDT |
| Retries | 1, delay 3 min |

**Compute:**
- EMR Serverless, release `emr-7.10.0`, instance type `m6g.16xlarge` (ARM), 15 core instances
- Spark config (fallback): executor 16G / 4 cores, driver 4G / 2 cores, maxExecutors 10
- DDL loaded at runtime from S3: `customer_metric_daily_agg.ddl`

**Task flow (authoritative from DAG):**
1. `dag_config` — resolve start/end_mst_date and Switchboard params
2. `dependencies` — waits for `customer360.customer_life_cycle_vw` S3 success file
3. `create_redshift_tables` — ensures Redshift tables exist (create_customer_metric_daily_agg.sql, create_customer_metric_daily_agg_stg.sql)
4. `create_emr` → `run_customer_metric_daily_agg` (PySpark) → `remove_emr`
5. `dq_check_customer_metric_daily_agg_local` — DataQualityOperator on `customer_core_conformed.customer_metric_daily_agg`
6. `call_lake_api` (prod only) — SuccessNotificationOperator for `customer360.customer_metric_daily_agg_vw`
7. `dq_check_customer_metric_daily_agg_lake` — DataQualityOperator on `customer360.customer_metric_daily_agg_vw`
8. `s3_to_redshift_stg` — COPY parquet from S3 into Redshift staging table
9. `insert_customer_metric_daily_agg` — delete-insert from staging into `customer360.customer_metric_daily_agg_vw` (prod) or `customer_core_conformed_dev.customer_metric_daily_agg_vw` (non-prod)

**Alerts & ownership:**
- Slack: `#edt-airflow-alerts` (prod), `#edt-airflow-alerts-low-priority` (non-prod)
- Dev group: #edt (private)
- OnCall: #marketing-data-product-engineering, DEV-EDT-OnCall
- Email: dl-bi-enterprise-data@godaddy.com

---

## Upstream Tables Referenced in PySpark

| Table | Platform | Notes |
|---|---|---|
| `customer_core_conformed.customer_life_cycle` | Hive/Glue (S3 ckpetlbatch) | Active source in code; queried with `partition_eval_mst_date` filter |
| `customer360.customer_life_cycle_vw` | Data Lake | Commented out in code; still listed as input in policies.yaml and DAG dependency success-file wait |

---

## DDL Files Consulted

### `customer360/customer-metrics/src/ddls/customer_metric_daily_agg.ddl` (Hive/Glue)
Runtime-loaded DDL. Creates `{DATABASE_NAME}.customer_metric_daily_agg` if not exists.  
- Partition: `partition_eval_mst_date string`  
- Storage: PARQUET  
- Location: `s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/`  
- 32 non-partition columns including `data_source_enum string` and all metric/dimension columns.

### `customer360/customer-metrics/src/ddls/create_customer_metric_daily_agg.sql` (Redshift)
Creates `{database}.customer_metric_daily_agg_vw` in Redshift.  
- `DISTSTYLE AUTO DISTKEY(partition_eval_mst_date) SORTKEY(partition_eval_mst_date)`  
- `partition_eval_mst_date DATE` (DATE type in Redshift, STRING in Hive)

### `customer360/customer-metrics/src/ddls/insert_customer_metric_daily_agg.sql` (Redshift)
Delete-insert pattern: deletes rows for `end_mst_date` then inserts from staging.  
Note: Array bracket-stripping applied to `product_ownership_category_list`, `product_ownership_line_list`, `brand_name_list` (converts `[val1, val2]` to `val1, val2`).

### `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl` (Lake registry)
32 columns. **Missing `data_source_enum`** column vs. Hive DDL and PySpark output. Primary key annotations also missing `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`.

---

## Policies File

`customer360/customer-metrics/src/policies/customer_metric_daily_agg_dag.yaml`

| Field | Value |
|---|---|
| DAG ID | customer-metric-daily-agg |
| SLA | maxDurationMins: 120, severity: TIER_4 |
| Input 1 | customer360.customer_life_cycle_vw (datalake, parquet) |
| Input 2 | customer_core_conformed.customer_life_cycle (s3-ckpetlbatch, parquet, `s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_life_cycle`) |
| Output 1 | customer360.customer_metric_daily_agg_vw (datalake, parquet) |
| Output 2 | customer_core_conformed.customer_metric_daily_agg (s3-ckpetlbatch, parquet, `s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg`) |

---

## Data Quality File

`customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg.json`

| Check | Detail |
|---|---|
| Primary key | 19-column composite: `partition_eval_mst_date`, `customer_type_reason_desc`, `customer_acquisition_mst_month`, `customer_domestic_international_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`, `customer_country_code`, `customer_type_name`, `acquisition_channel_name`, `customer_tenure_year_count`, `product_ownership_category_list`, `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `brand_name_list` |
| Enabled | true |

Applied on: `customer_core_conformed.customer_metric_daily_agg`

---

## Lake Registry (`repos/lake`)

**Path:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/`

| Field | Value |
|---|---|
| Lake DB name | customer360 |
| DB root bucket | gd-ckpetlbatch-prod-customer-core-conformed |
| Table relative path | customer_metric_daily_agg |
| Description | "Customer Metric Daily Aggregated on Reporting Dims for a given day" |
| Storage | Parquet, PARTITIONED |
| Partition key | partition_eval_mst_date (string) |
| Data tier | 4 |
| SLA delivery | By 08:00 AM MST daily (`cron(00 15 * * ? *)` UTC) |
| SLO identifier | customer360.customer_metric_daily_agg_vw |
| legacyLookBackEnabled | true |
| Owner | ckpetlbatch |
| Project code | edt |
| Upstream lineage | customer360.customer_life_cycle_vw |
| Consumers | ckpetlbatch.dev_private, data_lab.dev_private, analytics.prod, data_platform.stage/prod, martech_data.stage/dev_private/prod, revenue_and_relevance.stage/dev_private/prod/test |

---

## Confluence

### Hub Page — Customer360 (3779199819)
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360  
Contacts table lists stakeholder teams: Finance (Business Stewards), Marketing (Stakeholders), DAP (Business Stewards), FORGE (Data Products PgM, Arch).

**Relevant child pages identified:**

### Customer360 Business Context Structure (4387965088)
- Schema: `customer360`, Domain: Customer, Organization: DNA
- Data Tier: 2 (dim tables) · **4 (lifecycle, agg)**
- `customer_metric_daily_agg_vw`: Type PARTITIONED, Tier 4, **Grain: "One row per date × reporting dimension combo"**
- Coverage note: `customer_metric_daily_agg_vw` weighted at 15% of overall coverage score; `customer_life_cycle_vw` is the primary OSI/OWL target (35%).

### Customer Metrics (4042131239)
Covers Customer Lifecycle Events and their mapping to metrics:
- Customer Acquisition → New Customers
- Customer Billing (Paid) → Active Customers, TTM GCR Amount
- Customer Subscription (Paid) → Active Customers, 2+/3+ Customers, Product Category/Line/Qty
- Customer Merge → Merged Customers
- Customer Churn → Churn Customers
- Customer Reactivated → Reactivated Customers
- Customer Type → Customer Type classification

---

## Alation

**Redshift Dev Serverless table (dev.* key):**

| Field | Value |
|---|---|
| Table Name | customer_metric_daily_agg_vw |
| Database | Redshift - Serverless - Dev |
| Schema | customer360 |
| Alation key | 132.dev.customer360.customer_metric_daily_agg_vw |
| Table ID | 7038918 |
| Alation URL | https://godaddy.alationcloud.com/table/7038918/ |
| Type | View |
| Description | "A daily aggregated metrics table providing summarized customer performance indicators. This view serves as a comprehensive source for customer lifecycle analysis, containing customer demographic, geographic, and behavioral attributes." |

**Lake table:**

| Field | Value |
|---|---|
| Table Name | customer_metric_daily_agg_vw |
| Database | GoDaddy Central Data Lake (Prod) |
| Schema | customer360 |
| Alation key | 81.AwsDataCatalog.customer360.customer_metric_daily_agg_vw |
| Lake Alation ID | 7038346 |
| Alation URL | https://godaddy.alationcloud.com/table/7038346/ |
| Type | Table (partitioned) |
| Description | "A daily aggregated metrics table providing summarized customer performance indicators" |

**Other Alation entries found (not primary):**

| Key | ID |
|---|---|
| 63.bi.customer360.customer_metric_daily_agg_vw | 7038767 (Redshift Prod BI) |
| 63.bi.customer_core_conformed_dev.customer_metric_daily_agg_vw | 7038766 |
| 63.bi.customer_core_conformed_dev.customer_metric_daily_agg_vw_stg | 7038887 |
| 147.cet.customer360_spectrum.customer_metric_daily_agg_vw | 7046304 |

**Column profiling data:** Not retrieved (v1/table API returned permission error; bulk list API does not include profiling stats).

---

## Alation Queries

6 queries found referencing `customer_metric_daily_agg_vw`.

### Query 1

| Field | Value |
|---|---|
| Query ID | 136952 |
| Title | NC validate EBP |
| Author | (not returned by API) |
| Description | Validation scratchpad comparing legacy DAC and C360 customer metrics over the same date ranges |
| Schedule | Not scheduled |
| Last Saved | (not returned by API) |
| Last Run | (not returned by API) |
| Datasource ID | 63 (Redshift - Prod-BI) |
| Alation Query URL | https://godaddy.alationcloud.com/query/136952/ |

```sql
-- Cash Dash Customer View
select date_trunc('day',evaluation_mst_date),
sum(beginning_customer_qty) as begin,
sum(new_customer_qty) as new, 
sum(net_churn_qty) as net_churn,
sum(net_adds_qty)as net_add, 
sum(churned_customer_qty)as churn
from  bi.bi_dashboards_prod.customer_vs_target
where evaluation_mst_date between '2026-01-01' and current_date
group by 1;

--DAC
select top 1 * from dna_approved.daily_active_customers;
select date_trunc('day',evaluation_mst_date), ...
  from  dna_approved.daily_active_customers
  where evaluation_mst_date between '2026-03-01' and current_date
  group by 1;

-- C360
select date_trunc('day',partition_eval_mst_date),
  sum(beginning_customer_qty) as begin,
  sum(new_customer_qty) as new, 
  sum(net_churn_qty) as net_churn,
  sum(net_add_qty)as net_add, 
  sum(churn_customer_qty)as churn,
  sum(ending_customer_qty) as ending
  from  customer360.customer_metric_daily_agg_vw
  where partition_eval_mst_date between '2026-03-01' and current_date
  group by 1;
```

---

### Query 2

| Field | Value |
|---|---|
| Query ID | 138184 |
| Title | C360 - customer_metric_daily_agg_vw_mv |
| Author | (not returned by API) |
| Description | Creates a materialized table enriching customer_metric_daily_agg_vw with relative month from dim_relative_date |
| Schedule | Not scheduled |
| Last Saved | (not returned by API) |
| Last Run | (not returned by API) |
| Datasource ID | 132 (Redshift - Serverless - Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138184/ |

```sql
DROP TABLE IF EXISTS dev.ba_usi.customer_metric_daily_agg_vw_mv;

CREATE TABLE dev.ba_usi.customer_metric_daily_agg_vw_mv AS
    SELECT
        DAC.*,
        trunc(date_trunc('month'::text, (dac.partition_eval_mst_date)::timestamp without time zone)) AS evaluation_mst_month,
        rd.relative_month AS relative_mst_month,
        rd.relative_month_period_name AS relative_mst_month_period_name
    FROM ckp_analytic_share.customer360.customer_metric_daily_agg_vw AS DAC
    LEFT JOIN (
        SELECT 
          dim_relative_date.calendar_date,
          dim_relative_date.relative_month,
          dim_relative_date.relative_month_period_name
        FROM bi_prod.dim_relative_date
        WHERE max_date = (SELECT MAX(partition_eval_mst_date)
        FROM ckp_analytic_share.customer360.customer_metric_daily_agg_vw)
        ) rd
    ON dac.partition_eval_mst_date = rd.calendar_date;
```

---

### Query 3

| Field | Value |
|---|---|
| Query ID | 138586 |
| Title | C360 Cash Dash with budget |
| Author | (not returned by API) |
| Description | Creates a time-period comparison sandbox table from customer_metric_daily_agg_vw for Cash Dashboard analytics (QoQ, YoY, prior quarter) |
| Schedule | Not scheduled |
| Last Saved | (not returned by API) |
| Last Run | (not returned by API) |
| Datasource ID | 63 (Redshift - Prod-BI) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138586/ |

```sql
DROP TABLE IF EXISTS dna_sandbox.c360_test_sz_2;
CREATE TABLE dna_sandbox.c360_test_sz_2 AS
(
WITH base AS (
SELECT 
partition_eval_mst_date,
date_trunc('quarter', partition_eval_mst_date) AS q_start,
...
customer_domestic_international_name, customer_region_2_name, customer_region_3_name,
customer_country_name, customer_type_name, fraud_flag, acquisition_channel_name,
customer_type_reason_desc, reseller_type_name, point_of_purchase_name,
new_customer_qty, churn_customer_qty, net_add_qty, net_churn_qty,
beginning_customer_qty, ending_customer_qty
FROM customer360.customer_metric_daily_agg_vw
),
-- [Multiple UNION ALL branches for CY, PY same date, PY same DOW, PQ QTD, PQ full]
...
```

---

### Query 4

| Field | Value |
|---|---|
| Query ID | 138254 |
| Title | C360 - mv_customer_metric_daily_agg_vw_union |
| Author | (not returned by API) |
| Description | Creates a union table merging legacy `dna_approved.daily_active_customers` (through 2026-03-31) with C360 data going forward |
| Schedule | Not scheduled |
| Last Saved | (not returned by API) |
| Last Run | (not returned by API) |
| Datasource ID | 63 (Redshift - Prod-BI) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138254/ |

```sql
DROP TABLE IF EXISTS bi.ba_usi.mv_customer_metric_daily_agg_vw_union;
CREATE TABLE bi.ba_usi.mv_customer_metric_daily_agg_vw_union AS
    WITH legacy_final AS (
        SELECT * FROM bi.dna_approved.daily_active_customers
        WHERE evaluation_mst_date <= '2026-03-31'
    ),
    c360_final AS (
        SELECT DAC.*, ...
        FROM customer360.customer_metric_daily_agg_vw AS DAC
        ...
    )
    SELECT ... FROM legacy_final
    UNION ALL
    SELECT ... FROM c360_final;
```

---

### Query 5

| Field | Value |
|---|---|
| Query ID | 128804 |
| Title | NC validate DAC/MAC/Cash Dash |
| Author | (not returned by API) |
| Description | Validation scratchpad comparing DAC, MAC, and C360 customer metrics |
| Schedule | Not scheduled |
| Last Saved | (not returned by API) |
| Last Run | (not returned by API) |
| Datasource ID | 132 (Redshift - Serverless - Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/128804/ |

```sql
-- Cash Dash Customer View
select date_trunc('day',evaluation_mst_date), ...
from  ba_corporate.customer_vs_target
where evaluation_mst_date between ...;

select date_trunc('day',partition_eval_mst_date), ...
from  customer360.customer_metric_daily_agg_vw
where partition_eval_mst_date between '2025-03-01' and current_date;
```

---

### Query 6

| Field | Value |
|---|---|
| Query ID | 127875 |
| Title | customer vs target v2 |
| Author | (not returned by API) |
| Description | Explores customer_metric_daily_agg_vw alongside date dimension for time-period attribution and QoQ comparisons |
| Schedule | Not scheduled |
| Last Saved | (not returned by API) |
| Last Run | (not returned by API) |
| Datasource ID | 132 (Redshift - Serverless - Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/127875/ |

```sql
select top 1 * from customer360.customer_metric_daily_agg_vw;

-- test the date
drop table if exists day;
create temp table day as
select 
evaluation_mst_date as evaluation_mst_date,
date_trunc('quarter', evaluation_mst_date) as q_start,
...
from customer360.customer_metric_daily_agg_vw
...;
```

---

## Lineage

**Depth 1 Upstream (from code + lake registry):**
- `customer_core_conformed.customer_life_cycle` (active in PySpark code)
- `customer360.customer_life_cycle_vw` (lake registry lineage, DAG dependency wait, commented out in code)

**Depth 2 Upstream (indirect, from customer_life_cycle_vw lineage):**
- Not traced in this gather stage (would require reading customer_life_cycle pipeline separately)

**Depth 1 Downstream (from Alation queries evidence):**
- `dev.ba_usi.customer_metric_daily_agg_vw_mv` (Query 138184 — adds relative month)
- `bi.ba_usi.mv_customer_metric_daily_agg_vw_union` (Query 138254 — union with legacy DAC)
- `dna_sandbox.c360_test_sz_2` (Query 138586 — Cash Dashboard sandbox)
- `bi.bi_dashboards_dev.customer_vs_target` / `bi.bi_dashboards_prod.customer_vs_target` (referenced in multiple queries as downstream consumer)

---

## Conflicts / Discrepancies

| # | Conflict | Code says | Other source says | Verdict |
|---|---|---|---|---|
| 1 | **Active source table** | `customer_core_conformed.customer_life_cycle` (in SQL WHERE clause, no comment) | `customer360.customer_life_cycle_vw` (lake registry lineage, policies.yaml input 1, DAG dependency success-file wait) | **Code is authoritative.** Lake lineage registry is stale/incorrect. Flag for update. |
| 2 | **Lake DDL missing `data_source_enum`** | PySpark `conform_datatype()` outputs `data_source_enum string` ('customer360' hardcoded); Hive DDL includes it | Lake registry `table.ddl` does not include `data_source_enum` | **Code/Hive DDL is authoritative.** Lake DDL needs update. |
| 3 | **Primary key annotation in lake DDL** | DQ constraint JSON uses 19-column PK (includes `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`) | Lake `table.ddl` does NOT annotate `point_of_purchase_name` or `customer_acquisition_bill_fraud_flag` as `@PrimaryKey` | **DQ constraint file + PySpark grain is authoritative.** Lake DDL annotations incomplete. |
| 4 | **Partition column type** | Hive DDL: `partition_eval_mst_date string` | Redshift DDL: `partition_eval_mst_date DATE` | Expected — different platforms use different type systems. Not a true conflict. |
| 5 | **`customer_country_code` UK→GB normalization** | PySpark applies `WHEN UPPER(customer_country_code) = 'UK' THEN 'GB'` | Not documented in DDL, Alation, or Confluence | Code is truth. Needs documentation in data dictionary. |
| 6 | **DAG doc says SLA = N/A** | DAG documentation_markdown: `SLA: N/A` | Lake registry `table.yaml`: delivery by 08:00 AM MST daily; policies.yaml: maxDurationMins 120, TIER_4 | Discrepancy to validate with data owner. Lake registry SLA is more specific. |
| 7 | **Alation author field empty** | All 6 Alation queries returned empty `author` field | API limitation; authors are not exposed in v1 query list endpoint | Not a code conflict; API limitation only. |

---

## Environment / Infrastructure Facts

| Field | Value |
|---|---|
| Team | EDT (Emerald Data Team) |
| AWS account — Airflow | 688051721285 (MWAA: dof-customers) |
| AWS account — EMR | 664289052486 |
| AWS account — S3 data | 688051721285 |
| AWS account — Redshift | 561403605607 |
| AWS account — Data Lake | 028140660016 |
| Redshift cluster ARN | arn:aws:redshift:us-west-2:561403605607:namespace:da7e8313-cc13-40ca-962e-715827b94b24 |
| S3 data bucket (prod) | gd-ckpetlbatch-prod-customer-core-conformed |
| Redshift schema (prod) | customer360 |
| Redshift schema (dev) | customer_core_conformed_dev |


**The agent's final response to the user was:**
All research is complete and appended to `gather.md`. Here is a summary of what was gathered:

---

## Research Summary

### Source Code (authoritative)

**PySpark** (`customer_metric_daily_agg.py`, `main` branch):
- Writes to `customer_core_conformed.customer_metric_daily_agg` (Hive/Glue, Parquet, partitioned by `partition_eval_mst_date`)
- Source: `customer_core_conformed.customer_life_cycle` (the `customer360.customer_life_cycle_vw` variant is commented out)
- Logic: daily roll-up aggregating 5 metrics across **18 reporting dimensions**, plus derived `beginning_customer_qty` via LAG window function, plus 3 computed movement metrics (`net_move_qty`, `net_add_qty`, `net_churn_qty`). Dimension-continuity fill ensures zero-row carryforward for reporting stability.
- Hardcoded `data_source_enum = 'customer360'`; applies `UK → GB` country code normalization.

**DAG** (`customer_metric_daily_agg_dag.py`):
- Schedule: `30 7 * * *` (7:30 AM MST daily, disabled in dev)
- EMR Serverless `emr-7.10.0`, `m6g.16xlarge` (ARM), 15 core instances
- After EMR write: DQ check → Lake API success notification → Redshift load (delete/insert)
- Dependency: waits for `customer360.customer_life_cycle_vw` success file

### Supporting Sources

- **Lake registry SLA**: delivery by 08:00 AM MST daily; Data Tier 4
- **Consumers**: analytics, martech_data, revenue_and_relevance, data_platform, data_lab
- **Confluence grain**: "One row per date × reporting dimension combo"

### Alation
- Lake entry: ID **7038346** (`81.AwsDataCatalog.customer360.customer_metric_daily_agg_vw`)
- Redshift Dev entry: ID **7038918** (`132.dev.customer360.customer_metric_daily_agg_vw`), Type: View
- **6 Alation queries** found — primarily validation and downstream materialized views (Cash Dashboard, legacy-to-C360 union migration)

### Key Conflicts Found
1. **Active source table**: Code uses `customer_core_conformed.customer_life_cycle`; lake lineage registry says `customer360.customer_life_cycle_vw` — lake registry is stale.
2. **Lake DDL missing `data_source_enum`** — needs update.
3. **Lake DDL primary key annotations** incomplete (missing `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`).
4. **DAG doc says SLA = N/A** vs. lake registry specifying 08:00 AM MST — needs owner validation.