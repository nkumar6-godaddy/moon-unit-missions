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
   - Redshift Dev Serverless table (dev.* key): name, database ("Redshift - Serverless - Dev"), schema, Alation URL
   - Lake table: name, schema, Alation URL
   - Any descriptions or custom fields found

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
  - Redshift Dev Serverless table info (dev.* entry: table name, database, schema, Alation URL)
  - Lake table Alation URL
  - Any descriptions or custom fields retrieved
- Alation Queries section (full query details per Step 6b)
- A "Conflicts / discrepancies" section listing any contradictions with the code

**The agent summarized its work in this way:**

---

# Gather Report: customer360 / dim-customer-vw

**Date gathered:** 2026-06-09  
**Analyst stage:** gather  
**Source of truth:** PySpark script + calling DAG (code overrides all other sources)

---

## 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo | `gdcorp-dna/dof-dpaas-customer-feature` |
| Ref (checked out) | `main` |
| Script path | `customer/dim-customer/src/pyspark/dim_customer.py` |
| GitHub URL | https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer/dim-customer/src/pyspark/dim_customer.py |
| Spark app name | `"dim_customer daily delta Load"` (from `SparkSessionManager`) |
| Shared common module | `dim_customer_iceberg_common.py` (co-deployed as `--py-files`) |

### Arguments accepted
| Arg | Required | Notes |
|---|---|---|
| `--aws_env` | yes | `dev-private`, `stage`, or `prod` |
| `--run_date` | yes | DAG run date (YYYY-MM-DD) |
| `--snapshot_mst_date` | yes | MST partition date being loaded |
| `--sb_app_id` | no | Switchboard app ID |
| `--sb_setting_id` | no | Switchboard setting ID |
| `--run_emr_task_id` | no | EMR task identifier |

### Output write target (authoritative from code)

`dim_customer_iceberg_common.py` line 11:
```
DELTA_DEST_TABLE = "customer_core_conformed.dim_customer"
```
S3 location (line 16):
```
s3://gd-ckpetlbatch-{aws_env}-customer-core-conformed/customer_core_conformed/dim_customer_v2
```

The script performs **SCD Type 2** MERGE + INSERT into `customer_core_conformed.dim_customer` (Iceberg table).

### Iceberg table DDL (authoritative — from `create_dim_customer_iceberg_table_if_not_exists`)

```sql
CREATE TABLE IF NOT EXISTS customer_core_conformed.dim_customer (
    customer_id                string COMMENT 'Primary key',
    shopper_id                 string,
    external_reseller_customer_id int,
    federation_partner_id       string,
    federation_partner_name     string,
    parent_customer_id          string,
    parent_shopper_id           string,
    private_label_id            int,
    company_flag                boolean,
    internal_shopper_flag       boolean,
    temporary_shopper_flag      boolean,
    closed_shopper_flag         boolean,
    city_name                   string,
    state_code                  string,
    zip_code                    string,
    country_code                string,
    email_domain_name           string,
    email_hash                  string,
    primary_phone_flag          boolean,
    mobile_phone_flag           boolean,
    secondary_phone_flag        boolean,
    default_currency_code       string,
    market_code                 string,
    created_mst_ts              timestamp,
    updated_mst_ts              timestamp,
    closed_mst_ts               timestamp,
    deleted_mst_ts              timestamp,
    row_hash                    string,
    key_hash                    string,
    effective_start_mst_ts      timestamp,
    effective_end_mst_ts        timestamp,
    current_record_flag         boolean,
    etl_build_mst_ts            timestamp,
    etl_insert_mst_ts           timestamp,
    etl_update_mst_ts           timestamp
)
USING ICEBERG
LOCATION 's3://gd-ckpetlbatch-{aws_env}-customer-core-conformed/customer_core_conformed/dim_customer_v2'
TBLPROPERTIES (
    'history.enabled' = 'true',
    'write_compression' = 'zstd',
    'write.parquet.compression-level' = '3',
    'write.target-file-size-bytes' = '134217728',
    'optimize_rewrite_data_file_threshold' = '10',
    'optimize_rewrite_delete_file_threshold' = '5'
)
```

**Note:** No partition spec is defined — the Iceberg table is unpartitioned in code. (Conflict with lake repo — see §9.)

### SCD Type 2 Logic

1. **MERGE**: Set `current_record_flag = FALSE`, `effective_end_mst_ts = effective_start_mst_ts - 1 second` for existing current records whose `row_hash` has changed.
2. **INSERT**: Add new rows for new `key_hash` values, or for changed `row_hash` values.
3. **Closed-shopper MERGE**: After insert, update records where `current_record_flag = TRUE AND closed_shopper_flag = TRUE` → set `current_record_flag = FALSE`, `effective_end_mst_ts = snapshot_mst_date 07:00:00`.
4. **UK→GB normalization**: `UPDATE ... SET country_code = 'GB' WHERE upper(country_code) = 'UK'`.

### Row-hash columns (change detection)
`shopper_id`, `external_reseller_customer_id`, `federation_partner_id`, `federation_partner_name`, `parent_customer_id`, `parent_shopper_id`, `private_label_id`, `company_flag`, `internal_shopper_flag`, `temporary_shopper_flag`, `closed_shopper_flag`, `city_name`, `state_code`, `zip_code`, `country_code`, `email_domain_name`, `email_hash`, `primary_phone_flag`, `mobile_phone_flag`, `secondary_phone_flag`, `default_currency_code`, `market_code`

- **row_hash**: SHA2-256 of `||`-concat of above columns
- **key_hash**: SHA2-256 of `customer_id`

### Published view (`customer360/dim-customer-vw`)

The DAG creates a Redshift view (and registers a Lake notification) for `customer360.dim_customer_vw`. The view SQL (`create_view.sql` template) is:

```sql
CREATE OR REPLACE VIEW {view_database}.dim_customer_vw AS
SELECT
    customer_id, shopper_id, external_reseller_customer_id,
    federation_partner_id, federation_partner_name,
    parent_customer_id, parent_shopper_id, private_label_id,
    company_flag, internal_shopper_flag, temporary_shopper_flag, closed_shopper_flag,
    city_name, state_code, zip_code, country_code,
    email_domain_name, email_hash,
    primary_phone_flag, mobile_phone_flag, secondary_phone_flag,
    default_currency_code, market_code,
    created_mst_ts, updated_mst_ts, closed_mst_ts, deleted_mst_ts,
    etl_build_mst_ts
FROM {table_database}.dim_customer
WHERE current_record_flag = true
WITH NO SCHEMA BINDING;
```

**Columns excluded from the view** (internal SCD mechanics only in physical table):
`row_hash`, `key_hash`, `effective_start_mst_ts`, `effective_end_mst_ts`, `etl_insert_mst_ts`, `etl_update_mst_ts`

---

## 2. DAG Identity

| Field | Value |
|---|---|
| DAG file path | `customer/dim-customer/src/dag/dim_customer_dag.py` |
| DAG ID | `dim_customer_dag` |
| Schedule (prod) | `35 01 * * *` — daily at 01:35 UTC (18:35 MST previous day) |
| Schedule (non-prod) | `None` (manual trigger only) |
| Start date | 2024-12-01 (MST timezone) |
| `max_active_runs` | 1 |
| `catchup` | False |
| `retries` | 2 |
| `depends_on_past` | False |
| Owner | `customer` |
| Team | EDT |
| On-call group | `DEV-EDT-OnCall` |
| Slack alerts | `edt-airflow-alerts` (prod) / `edt-airflow-alerts-low-priority` (non-prod) |
| SLA (policy YAML) | maxDurationMins: 90, severity: LOW |

### DAG workflow summary

```
dag_config
  ├── wait_fortknox_shopper_snap (S3KeySensor)
  ├── wait_rp_salesmonitor_internalshopper (S3KeySensor)
  ├── wait_dim_customer_attributes (S3KeySensor)
  ├── wait_customer_id_mapping_snapshot (PythonSensor, hours 08 or 09)
  ├── wait_profile_audit (PythonSensor, hours 08 or 09)
  └── compute_load_customer_iceberg_step_cmds
→ wait_upstream → create_emr_cluster
→ load_customer_daily_delta (dim_customer_daily_delta.py)
→ branch_restore_or_skip_iceberg
  → [restore_customer_iceberg | skip_restore_customer_iceberg]
→ after_restore_or_skip_iceberg
→ load_customer_iceberg_emr_steps (dynamically mapped, one per snapshot_mst_date)
  → dim_customer.py called once per MST date, max_active_tis_per_dagrun=1
→ terminate_emr_cluster → dex_validation
→ iceberg_snapshot_metadata
  → conditional_call_lake_api → call_lake_api (customer360.dim_customer_vw)
                               → call_lake_api_hist (customer360.dim_customer_history_vw)
  → dim_customer_rs_load (Redshift staging → promote → refresh views)
→ notify → check_for_failed_tasks → succeed/fail
```

### EMR configuration
- Release label: `emr-7.2.0`
- Iceberg runtime: `/usr/share/aws/iceberg/lib/iceberg-spark3-runtime.jar`
- Catalog: AWS Glue (`GlueCatalog`)
- Core instances: m6g.2xlarge × 8
- Master: m6g.2xlarge
- Architecture: ARM64 (m6g series)

### Run date logic
- Default daily: loads `run_date - 1` and `run_date` (2 MST days, `ice_rollback_calendar_days=1`)
- Single-day override: `skip_rollback=true` + `ice_rollback_calendar_days<=0`
- Backfill: `ice_rollback_calendar_days=N` → N days from `run_date - (N-1)` to `run_date`

---

## 3. Upstream Tables Referenced in PySpark

| Table | Usage | Source |
|---|---|---|
| `customer_core_conformed.dim_customer_daily_delta` | Primary source — read filtered by `partition_snap_mst_date = snapshot_mst_date` | `dim_customer.py` line 164–170 |
| `customer_core_conformed.dim_customer_attributes` | Source of federation partner data (fed_effective_start/end_mst_date) | `dim_customer.py` line 188–194 |
| `customer_core_conformed.dim_customer` | Target — MERGE + INSERT destination | `dim_customer_iceberg_common.py` |

### Upstream tables upstream of dim_customer_daily_delta (DAG-level sensors)

| Upstream | S3 Success path | Sensor type |
|---|---|---|
| `fortknox.fortknox_shopper_snap` | `{S3_SUCCESS_HOME}/fortknox/fortknox_shopper_snap/{date_s3}/_SUCCESS` | S3KeySensor |
| `signals_platform_cln.profile_audit_lake_cln_v2` | `{S3_SUCCESS_HOME}/signals_platform_cln/profile_audit_lake_cln_v2/{date_s3}/{08|09}/_SUCCESS` | PythonSensor |
| `godaddy.rp_salesmonitor_internalshopper_snap` | `{S3_SUCCESS_HOME}/godaddy/rp_salesmonitor_internalshopper_snap/{date_s3}/_SUCCESS` | S3KeySensor |
| `customers.customer_id_mapping_snapshot` | `{S3_SUCCESS_HOME}/customers/customer_id_mapping_snapshot/{date_s3}/{08|09}/_SUCCESS` | PythonSensor |
| `customer_core_conformed.dim_customer_attributes` | `{S3_SUCCESS_HOME}/local_process/customer_core_conformed/dim_customer_attributes/{date_s3}/_SUCCESS` | S3KeySensor |

---

## 4. Secondary Sources Consulted

### DDL files (`src/dag/templates/`)

| File | Database | Table | Notes |
|---|---|---|---|
| `create_staging.sql` | `customer_core_conformed_{prod|dev}` | `dim_customer` | Redshift staging table DDL; 35 columns (no `effective_start_mst_ts`/`etl_*` not visible here — same schema as Iceberg minus ZSTD encoding). DISTKEY on `customer_id`. |
| `create_view.sql` | `customer360` (prod) / `customer360_prototype` (dev) | `dim_customer_vw` | Current-record view; 30 columns; excludes `row_hash`, `key_hash`, `effective_start_mst_ts`, `effective_end_mst_ts`, `etl_insert_mst_ts`, `etl_update_mst_ts` |
| `create_history_view.sql` | `customer360` / `customer360_prototype` | `dim_customer_history_vw` | `SELECT * FROM dim_customer` — all 35 columns, no filter |
| `promote_to_prod.sql` | `customer_core_conformed_{prod|dev}` | `dim_customer` | Table swap: rename `_stage` → prod, old prod → `_old` |
| `s3_copy_manifest.sql` | `customer_core_conformed_{prod|dev}` | `dim_customer` | Redshift COPY from `s3://gd-ckpetlbatch-{aws_env}-customer-core-conformed/customer_core_conformed/dim_customer_v2/manifest.json` using IAM role |

### Policies file (`src/policies/dim_customer_dag.yaml`)

- Pipeline description: "This DAG generates the customer eds dataset"
- Declared outputs: `customer360.dim_customer_vw`, `customer360.dim_customer_history_vw`, `customer_core_conformed.dim_customer_daily_delta`, `customer_core_conformed.dim_customer`, `customer_core_conformed.dim_customer_v2`
- Declared inputs: `signals_platform_cln.profile_audit_lake_cln_v2`, `godaddy.rp_salesmonitor_internalshopper_snap`, `customers.customer_id_mapping_snapshot`, `customer_core_conformed.dim_customer_attributes`, `fortknox.fortknox_shopper_snap`
- SLA: maxDurationMins 90, severity LOW

### Data quality (`src/data_quality/constraints/`)

| File | Database | Table | Constraint |
|---|---|---|---|
| `dim_customer.json` | `customer_core_conformed` | `dim_customer` | `.isPrimaryKey("customer_id", "effective_end_mst_ts")` (composite PK) |
| `dim_customer_vw.json` | `customer360` | `dim_customer_vw` | `.isPrimaryKey("customer_id")` (single column PK — view shows only current records) |

### Lake repo (`repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/`)

**`table.yaml`:**
- Description: "shopper and profile data in customer360"
- table_relative_path: `dim_customer_v2`
- storage_format: Parquet
- table_type: ICEBERG
- data_tier: 2
- partition_keys declared: `current_record_flag` (boolean) — **CONFLICT: code creates Iceberg table with no partition spec (see §9)**
- SLA delivery: `cron(00 10 * * ? *)` = 10:00 UTC = 03:00 MST daily
- SLO identifier: `customer360.dim_customer_vw`
- data_filter: `current_record_flag = true`
- Declared lineage upstream (5 tables): `customers.customer_id_mapping_snapshot`, `fortknox.fortknox_shopper_snap`, `godaddy.rp_salesmonitor_internalshopper_snap`, `signals_platform_cln.profile_audit_lake_cln_v2`, `sso_metadata_cln.federation_metadata_snapshot_cln`, `sso_permissions_cln.identity_mapping_snapshot_cln` — **CONFLICT: last two not in DAG sensors or PySpark code (see §9)**
- Consumer permissions: 27+ roles including `ckpetlbatch`, `finance_data_mart`, `martech_data`, `analytics`, `data_platform`, `revenue_and_relevance`, `dri_data`, `cetinsights`, and others

**`table.ddl`:**  
Lake-registered DDL for `dim_customer_vw` (30 columns — matches `create_view.sql` output; excludes the 5 internal SCD columns). Includes column-level comments with `@PrimaryKey` and `@UniqueKey` annotations on `customer_id` and `shopper_id` respectively.

---

## 5. Confluence Summary

**Page:** [Customer360 - v1.0 Dim Customer Release Notes](https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3829375759/Customer360+-+v1.0+Dim+Customer+Release+Notes)  
**Page ID:** 3829375759  
**Release Date:** 06/16/2025 | **Status:** Released | **Type:** Major (v1.0.0)

### Key business context extracted

**Purpose:** Inaugural launch of Customer360 — first implementation of GoDaddy's 360 data product architecture, providing unified customer master data with enhanced discoverability, interoperability, and AI-powered self-service capabilities.

**Artifacts released:**
| Artifact | Platform | Purpose |
|---|---|---|
| `customer360.dim_customer_vw` | Lake Iceberg | Current-record customer dimension |
| `customer360.dim_customer_history_vw` | Lake Iceberg | Current + historical customer attributes |
| `customer360.dim_customer_vw` | Redshift | Current-record view for SQL consumers |
| `customer360.dim_customer_history_vw` | Redshift | Historical view for SQL consumers |
| `dev.customer360.dim_customer_vw` | Serverless Redshift | Dev access to current records |
| `dev.customer360.dim_customer_history_vw` | Serverless Redshift | Dev access to historical records |

**Business objectives:**
- Single destination (`customer360`) for all customer master data
- 100% FortKnox profile parity; SCD Type 2 eliminates need for historical snapshots
- Establishes blueprint for Product360, Order360, and other domain implementations
- AI companion (GoCaaS) for automated migration of existing FortKnox code

**Breaking changes (Q3 2025 deadline):**
- `fortknox.fortknox_shopper_snap` (profile attributes) deprecated September 30, 2025
- All consumers must migrate to Customer360 by that date

**Known limitations:**
- Historical baseline starts 06/01/2025 (no change history before that date)
- Audit datasets available from 04/01/2025 but full reconstruction has high engineering cost

**Child pages found (IDs):**
- 3829310172: "FortKnox to Customer Master Migration"
- 3901325712: "Dim_customer Comparison With Profile and Fortknox"
- 3912107059: "Fortknox vs Customer mapping snapshot Schedule Mismatch"
- 4174217429: "Dim_customer : Profile v1 vs v2 comparison"
(Not fetched — migration/comparison topics, not primary metadata for this table)

---

## 6. Alation

### Redshift Dev Serverless table (dev.* key)

| Field | Value |
|---|---|
| Name | `dim_customer_vw` |
| Alation key | `132.dev.customer360.dim_customer_vw` |
| Database | Redshift - Serverless - Dev (datasource_id: 132) |
| Schema | `customer360` |
| Alation table ID | 7027529 |
| Alation URL | https://godaddy.alationcloud.com/table/7027529/ |

### Lake table (AWS Data Catalog / Glue)

| Field | Value |
|---|---|
| Name | `dim_customer_vw` |
| Alation key | `81.AwsDataCatalog.customer360.dim_customer_vw` |
| Schema | `customer360` |
| Alation table ID | 7022291 |
| Alation URL | https://godaddy.alationcloud.com/table/7022291/ |

### Other entries found

| Alation ID | Key | Notes |
|---|---|---|
| 7024150 | `63.bi.customer360_prototype.dim_customer_vw` | Prototype Redshift — not authoritative |
| 7024281 | `63.bi.customer360_approved.dim_customer_vw` | Approved Redshift — not authoritative |
| 7027523 | `63.bi.customer360.dim_customer_vw` | Prod Redshift (bi.*) — do NOT use per instructions |
| 7044020 | `147.cet.customer360_spectrum.dim_customer_vw` | CET Spectrum — not authoritative |

### Alation description (from Lake entry 7022291, relevant excerpts)

- "This table facilitates as Customer Master Data table"
- "This is the master Dimensional dataset to get the customer attributes. It is an Iceberg Type 2 Dimension."
- Lake filter `current_record_flag = true` is applied but **NOT functional on EMR jobs** — consumers should always add `WHERE current_record_flag = True` explicitly
- `current_record_flag = False` indicates a closed customer_id (closed profile, temporary shopper, or merged shopper)
- Primary Keys (as stated in Alation): `customer_id, effective_end_mst_dt` — **NOTE: column name in Alation is `effective_end_mst_dt` (date suffix), but code and DDL use `effective_end_mst_ts` (timestamp suffix). This is an Alation documentation error.**
- Common use cases: "Customer Master Data to work as Enterprise layer on Customer attribute"
- GitHub repo linked: confirmed (points to `dim_customer_dag.py`)

---

## 7. Alation Queries

Query search: `content__icontains=dim_customer_vw`, datasource_id=132 (Redshift Serverless Dev), ordered by `-last_saved_at`, limit 10.

**Note:** `last_saved_at`, `author`, `last_run` fields were empty/null in API response for all 10 queries; `schedule_cron` and `schedule_name` were empty for all (Not scheduled).

| Query ID | Title | Author | Description | Schedule | Last Saved | Last Run | Datasource | Alation Query URL |
|---|---|---|---|---|---|---|---|---|
| 136716 | OLS Monthly Summary | Unknown | Compares online store (OLS/Nemo vs Bruce) monthly GMV/orders/sellers; joins `dev.customer360.dim_customer_vw` to `central_service_ols_order` on `customer_id` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/136716/ |
| 138294 | Google Migration Query -latest | Unknown | PROD Google migration progressive C3 renewals via renewal_360; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/138294/ |
| 139445 | Google Migration — COA Fallback Patch TEST | Unknown | TEST version of #138294; COA fallback patch; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/139445/ |
| 139371 | Commerce Queries - Rishabh | Unknown | OLA onboarding and OLS combined seller analysis; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/139371/ |
| 133392 | OLA Sizing - M365 | Unknown | Monthly bookings/order sizing for OLA (M365); joins dim_customer_vw for customer attributes | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/133392/ |
| 135108 | OLS Sizing Analysis | Unknown | OLS bookings sizing analysis by month; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/135108/ |
| 138967 | shopper merge all cohorts -google migration test | Unknown | TEST: Google migration with SHOPPER MERGE applied to all cohorts; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/138967/ |
| 138854 | renewals -google migration test version | Unknown | TEST: Google migration C3 renewals via `dev.dna_approved.renewal_360`; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/138854/ |
| 138773 | Google Migration — TEST (COA fallback for missing domaininfo_snap) | Unknown | TEST: COA fallback built on top of #138761; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/138773/ |
| 138761 | Google Migration — TEST (shopper_merge metric for C3) | Unknown | TEST PATCH: C3 shopper merge; output `goog_migrations_final_draft`; references `dev.customer360.dim_customer_vw` | Not scheduled | Unknown | Unknown | Redshift Serverless Dev (132) | https://godaddy.alationcloud.com/query/138761/ |

### SQL for each query (verbatim, first 300 chars shown; full SQL available at Alation URLs above)

**Query 136716 (OLS Monthly Summary) — representative excerpt:**
```sql
select 
  b.shopper_id, 
  order_num as order_number, 
  to_date(order_utc_ts,'YYYY-MM') as order_date, 
  sum(gmv_usd_amt) as gmv_in_usd 
from ckp_analytic_share.dna_approved.central_service_ols_order a 
inner join dev.customer360.dim_customer_vw b on a.customer_id = b.customer_id
where a.order_status != 'DRAFT'
```

**Query 138294 (Google Migration — PROD):**
```sql
/*=====================================================================
  Google Migration -- PROD (PROGRESSIVE C3 RENEWALS via renewal_360)
  Output: dev.ba_dri.goog_migrations_final_progressive
  Schedule: 0 9,14,17 * * * America/New_York
...
```
(Full SQL available at https://godaddy.alationcloud.com/query/138294/)

---

## 9. Conflicts / Discrepancies

| # | Field | Code says | Other source says | Source of conflict | Verdict |
|---|---|---|---|---|---|
| 1 | Iceberg partition key | None — table is unpartitioned (no `PARTITIONED BY` in CREATE TABLE) | Lake repo `table.yaml` declares `partition_keys: [{name: current_record_flag, type: boolean}]` | `dim_customer_iceberg_common.py` vs `lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/table.yaml` | **Code is authoritative. Lake yaml partition claim is incorrect/stale. Needs validation.** |
| 2 | Effective end column name | `effective_end_mst_ts` (timestamp) — used throughout DAG and DQ constraint | Alation descriptions for multiple entries state `effective_end_mst_dt` (date suffix) | Code/DDL vs Alation | **Code is authoritative. Alation has a typo: `_dt` should be `_ts`.** |
| 3 | Upstream lineage | DAG sensors: 5 tables (fortknox_shopper_snap, profile_audit_lake_cln_v2, rp_salesmonitor_internalshopper_snap, customer_id_mapping_snapshot, dim_customer_attributes) | Lake `table.yaml` lists 6 upstream including `sso_metadata_cln.federation_metadata_snapshot_cln` and `sso_permissions_cln.identity_mapping_snapshot_cln` | DAG code vs lake yaml | **Code is authoritative. The two SSO tables are NOT used in PySpark or DAG sensors. Lake yaml lineage is stale/aspirational.** |
| 4 | Lake filter behavior | Code: view uses `WHERE current_record_flag = true` (standard SQL) | Alation note: lake filter `current_record_flag = true` is NOT functional on EMR jobs | Code vs Alation runtime observation | **Not a conflict — Alation is correctly documenting a runtime limitation. Consumers of the Lake table via EMR must add explicit filter.** |
| 5 | View column `current_record_flag` | `create_view.sql` template does NOT include `current_record_flag` in the SELECT list | Lake `table.ddl` includes `current_record_flag` as a column in `dim_customer_vw` | `create_view.sql` template vs `lake/catalog/.../table.ddl` | **Conflict. The Redshift view SQL explicitly lists 30 columns and omits `current_record_flag` from projection (the WHERE clause filters on it but the column is not projected). The Lake DDL includes `current_record_flag` as a column. The Lake Iceberg table does expose `current_record_flag` (it is in the physical table); the Redshift view does not project it. These are different target systems — not a direct code conflict but a schema difference between Lake and Redshift representations.** |

---

## 10. Summary of Key Facts

| Attribute | Value | Evidence |
|---|---|---|
| Physical Iceberg table | `customer_core_conformed.dim_customer` | Code (`dim_customer_iceberg_common.py:11`) |
| Lake/Redshift view | `customer360.dim_customer_vw` | DAG (`call_lake_api`), `create_view.sql` |
| History view | `customer360.dim_customer_history_vw` | DAG (`call_lake_api_hist`), `create_history_view.sql` |
| S3 location | `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/dim_customer_v2` | Code + DAG |
| Schedule | Daily at 01:35 UTC (prod) | `dim_customer_dag.py:142` |
| SLA delivery | By 10:00 UTC (03:00 MST) daily | `table.yaml` SLA cron |
| Table type | Iceberg (SCD Type 2) | Code creates `USING ICEBERG` |
| Primary key (physical) | `(customer_id, effective_end_mst_ts)` | DQ constraint `dim_customer.json` |
| Primary key (view) | `customer_id` | DQ constraint `dim_customer_vw.json` |
| Owner/team | EDT | DAG + policies YAML |
| On-call | DEV-EDT-OnCall | DAG |
| Grain | One row per customer per SCD period (Type 2); view shows only current record per customer_id | Code logic |
| Row count (view) | One row per active customer_id | `WHERE current_record_flag = true` |
| Historical baseline | 06/01/2025 | Confluence release notes |
| Alation Lake URL | https://godaddy.alationcloud.com/table/7022291/ | Alation API |
| Alation Dev Serverless URL | https://godaddy.alationcloud.com/table/7027529/ | Alation API |


**The agent's final response to the user was:**
The gather.md has been updated. Here is a summary of what was researched and recorded:

---

## Research Summary

### Sources consulted

**Code (authoritative):**
- `customer/dim-customer/src/pyspark/dim_customer.py` — SCD Type 2 MERGE/INSERT into `customer_core_conformed.dim_customer` (Iceberg); processes one MST date per run; 22-column row_hash for change detection
- `dim_customer_iceberg_common.py` — `DELTA_DEST_TABLE = "customer_core_conformed.dim_customer"`, S3 at `…/dim_customer_v2`, full 35-column schema with no partition spec
- `dim_customer_dag.py` — Schedule `35 01 * * *` (prod), 5 upstream sensors, dynamically mapped EMR steps, posts success notifications for `customer360.dim_customer_vw` and `customer360.dim_customer_history_vw`

**Secondary sources:**
- `src/dag/templates/create_view.sql` — view DDL with 30 columns, `WHERE current_record_flag = true`
- `src/policies/dim_customer_dag.yaml` — SLA maxDurationMins: 90, declared inputs/outputs
- `src/data_quality/constraints/` — composite PK `(customer_id, effective_end_mst_ts)` on physical table; single-column PK `customer_id` on view
- Lake repo `table.yaml` — data_tier=2, SLA cron 10:00 UTC, 27+ consumer permissions
- Confluence page 3829375759 — release notes: v1.0 launched 06/16/2025, FortKnox deprecation deadline Q3 2025, historical baseline starts 06/01/2025
- Alation: Lake entry ID 7022291, Dev Serverless entry ID 7027529; 10 saved queries found

**Conflicts recorded (4 significant):**
1. Lake yaml claims `current_record_flag` as Iceberg partition key — code creates unpartitioned table
2. Alation uses `effective_end_mst_dt` (wrong suffix) — code uses `effective_end_mst_ts`
3. Lake yaml lineage includes 2 SSO tables not present in DAG or PySpark code
4. `create_view.sql` does not project `current_record_flag` in Redshift view; lake DDL does include it