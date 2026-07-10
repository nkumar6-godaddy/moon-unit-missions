**Stage name:** research
**The coding agent was given these instructions:** You are a Data Governance analyst researching a Data Lake table to produce a
Snowflake Semantic View YAML. This stage combines fact-gathering AND analysis
into a single pass. Do not guess. If something is unknown, say "Unknown" and
explain what you checked.

Read `docs/snowflake-spec-reference.md` in the workspace for the Snowflake
semantic view YAML schema contract.

# ═══════════════════════════════════════════════════════════════
# PART A — GATHER (verifiable facts from code and secondary sources)
# ═══════════════════════════════════════════════════════════════

## Source-of-truth rule
The PySpark script and the DAG that calls it are the source of truth. If Alation,
Confluence, DDL, policies, or other docs conflict with code, treat the code as
correct and record the discrepancy for validation.

## Step 1: Read INPUT.md
Read `INPUT.md` in your workspace. It contains:
- PySpark GitHub URL + parsed repo/ref/path
- Repository folder names inside the container (under `repos/`)
- Optional lake table override and semantic view name
- Snowflake database name for base_table.database
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
  will become Snowflake relationships in the generate stage.

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
These become candidate `verified_queries` in the Snowflake YAML.

## Step 7: Enumerate tables and column schemas
For EVERY table referenced in the PySpark (read and write targets):
- Record table name (schema.table form)
- Record whether it is read, written, or both
- If a lake DDL exists in `repos/lake/`, read `table.ddl` and list columns with types
- If only in-repo DDL exists, read that instead (note it may be stale)
- Record any join keys used with this table

# ═══════════════════════════════════════════════════════════════
# PART B — ANALYZE (map ETL to Snowflake semantic view concepts)
# ═══════════════════════════════════════════════════════════════

## Step 8: Identify the target table
Determine the final output lake table populated by this PySpark job.
- Prefer direct evidence in code: write targets, insertInto, saveAsTable, etc.
- If `lake_table_override` is provided, use it only if it does not contradict code.
- Record grain (what one row represents) with evidence.

## Step 9: Deep lineage resolution — MANDATORY for EVERY source table
For EACH table referenced in the PySpark:
1. Check if it exists as a lake table in `repos/lake/catalog/config/prod/`.
   Try both `us-west-2/<schema>/<table-hyphenated>/` and
   `dlms-api/us-west-2/<schema>/<table-hyphenated>/`.
2. If NOT a lake table, recursively trace upstream PySpark scripts until you reach
   a lake table or external system.
3. If traversal fails: record `UNRESOLVED: <table> — <reason>`

**CRITICAL:** Snowflake `base_table` values must reference lake tables only.
Never use intermediate/staging tables as base tables.

## Step 10: Classify tables (fact vs dimension)
For each resolved lake table included in the semantic view:
- **Target table** = primary fact table (the table this PySpark populates)
- **Upstream tables joined TO** = dimension tables
- Record classification with evidence (join direction in PySpark)

## Step 11: Classify columns into Snowflake categories
For EACH column on each table, classify into one of:
- **dimensions**: categorical attributes (strings, IDs, enums, flags, codes)
- **time_dimensions**: date/timestamp/time columns
- **facts**: row-level quantitative values (amounts, counts, numeric measures)

For EACH column, also produce a **lineage-enriched description** that includes:
1. Business meaning of the column
2. Source lake table and column it is derived from (first lake table boundary)
3. Transformation logic applied (joins, CASE, COALESCE, casts, aggregations, etc.)

Example descriptions (detailed, C1-style):
- "Unique numeric ID for the shopper profile; composite PK component. Derived from
  enterprise.dim_subscription_history.shopper_id for subscription-active customers;
  from enterprise.dim_bill_shopper_id_xref.merged_shopper_id for TTM-only customers"
- "Country code where customer was acquired. From
  enterprise.dim_new_acquisition_shopper.bill_country_code, uppercased with UK→GB
  normalization applied in ETL"
- "Tenure in years. Calculated as CAST(datediff(partition_eval_mst_date,
  customer_acquisition_mst_date) / 365 AS INT); acquisition date sourced from
  enterprise.dim_new_acquisition_shopper and enterprise.dim_subscription_history"

**CRITICAL lineage rules:**
- Trace THROUGH intermediate tables but NEVER cite them in the description — only
  cite the FIRST lake table boundary.
- If traversal fails: use `UNRESOLVED — requires manual input` in the description.

## Step 12: Extract relationships
From PySpark join conditions:
- Map each join to Snowflake relationship format:
  `left_table` (FK side) → `right_table` (PK side)
- Record `relationship_columns` as `left_column`/`right_column` pairs
- Name relationships descriptively (e.g., `orders_to_customers`)

## Step 13: Identify metrics
From PySpark aggregations, Alation queries, and Confluence docs:
- Name each metric (snake_case)
- SQL aggregate expression (SUM/COUNT/AVG/etc.)
- Description and synonyms
- Only include metrics with evidence — do not invent

## Step 14: Extract candidate verified_queries
From Alation saved queries (Step 6):
- Convert each saved query to a Snowflake `verified_queries` entry:
  name, question (from title/description), sql (verbatim)
- Only include queries that are directly relevant and correct

## Step 15: Determine semantic view metadata
- View name: use `semantic_model_name` from INPUT.md if provided, else derive from
  schema + table (e.g., `customer360_customer_life_cycle`)
- View description: from Confluence, Alation, or code comments
- custom_instructions draft: grain, required partition filter, PK caveats, array-field
  warnings, excluded join targets

## Step 16: Output (append to research.md)
Append a structured report with TWO clearly labeled sections:

### Part A: Gathered Facts
- PySpark job identity (repo/ref/path), output write target(s)
- DAG identity (path, schedule, params)
- Table inventory — all referenced tables with read/write role and column schemas
- Join conditions — explicit join keys extracted from PySpark
- Aggregation expressions — SUM/COUNT/AVG/GROUP BY patterns found in PySpark
- DDL/policy/DQ files consulted
- Confluence summaries (if any)
- Alation section (table info + saved queries if fetched)
- Conflicts / discrepancies section

### Part B: Snowflake Semantic View Analysis
- Target table resolution with evidence
- Lineage resolution table (intermediate → lake)
- **Table classification table**: | Lake Table | Logical Name | Role (fact/dim) | base_table | primary_key |
- **Materialized direct-reads table**: | Lake Table | materialized_in_fields | evidence |
- **Excluded dimensions table**: | Lake Table | reason | fields_on_fact |
- **Relationship table**: | name | left_table | right_table | left_column | right_column | evidence |
- **Column inventory per table** with Snowflake classification:
  | Column | Snowflake Category | expr | data_type | Description (with lineage) | synonyms |
- **Metrics table**: | name | expression | description | evidence |
- **Verified queries table**: | name | question | sql | source |
- **Semantic view metadata**: name, description, custom_instructions draft
- **Do-not-claim table**: | item | reason | — items that must NOT become tables or metrics

## Step 17: Write RESOLVED_TARGET.json (required)
Create `RESOLVED_TARGET.json` in workspace root:
```json
{
  "schema": "customer360",
  "table_hyphen": "customer-life-cycle-vw",
  "table_underscore": "customer_life_cycle_vw",
  "lake_table_path": "customer360/customer-life-cycle-vw",
  "semantic_view_name": "customer360_customer_life_cycle",
  "snowflake_database": "GODADDY_LAKE",
  "confidence": "high",
  "evidence": ["file/line references"]
}
```

## Step 18: Write PROVENANCE.json (required)
Create `PROVENANCE.json` in workspace root with lineage preservation contract:
```json
{
  "grain": "one row per (shopper_id, partition_eval_mst_date)",
  "primary_key_notes": "Composite PK; customer_id is not unique and may be null",
  "partition_filter": "partition_eval_mst_date",
  "intermediate_tables": [],
  "transitive_sources": [],
  "materialized_direct_reads": [],
  "excluded_dimensions": [],
  "array_fields": [],
  "legacy_sources": [],
  "do_not_claim": []
}
```
Use empty arrays `[]` for sections with no entries.

**The agent summarized its work in this way:**

---
# Research Stage Output — customer360 / customer-metric-daily-agg-vw

**Researcher:** Data Governance analyst (Stage 1)
**Date:** 2026-06-26
**Git ref checked out:** main (already at HEAD)

---

## PART A: Gathered Facts

### A1. PySpark Job Identity

| Field | Value |
|-------|-------|
| Script path | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` |
| Repo / ref | `dof-dpaas-customer-feature` / `main` |
| FEED_NAME | `customer_metric_daily_agg` |
| DATABASE_NAME | `customer_core_conformed` |
| TABLE_NAME | `customer_metric_daily_agg` |
| QUALIFIED_TABLE_NAME | `customer_core_conformed.customer_metric_daily_agg` |
| Write method | `df.repartition(1).write.insertInto("customer_core_conformed.customer_metric_daily_agg", overwrite=True)` |
| Author / date | aghosh / 2025-11-06 |

**Write targets (from code):**
1. `customer_core_conformed.customer_metric_daily_agg` — Hive/Parquet (primary write via insertInto)

---

### A2. DAG Identity

| Field | Value |
|-------|-------|
| DAG file | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` |
| DAG_ID | `customer-metric-daily-agg` |
| Schedule | `30 7 * * *` → 7:30 AM MST daily (dev-private: None / manual only) |
| catchup | False |
| max_active_runs | 15 |
| start_date | 2026-01-01 |
| Owner | customer360 |
| On-failure alert | edt-airflow-alerts (prod) / edt-airflow-alerts-low-priority (non-prod) |
| Oncall email | dl-bi-enterprise-data@godaddy.com |
| Oncall SNOW | DEV-EDT-OnCall |
| DAG tags | domain:customer, sub-domain:active-customer, layer:enterprise, team:EDT, pipeline-group:active-customer, special:daily |

**DAG upstream dependency:** Waits for `customer360/customer_life_cycle_vw/{date}/_SUCCESS` on S3 (12h timeout)

**DAG task flow:**
1. dag_config → dependencies (S3 sensor on customer_life_cycle_vw) → end_dependency_check
2. → create_redshift_tables_done (create Redshift DDLs) → create_emr → run_customer_metric_daily_agg → remove_emr
3. → dq_check_customer_metric_daily_agg_local (DQ on customer_core_conformed.customer_metric_daily_agg)
4. → conditional_call_lake_api → call_lake_api (SuccessNotificationOperator: **db_name=customer360, table_name=customer_metric_daily_agg_vw**)
5. → s3_to_redshift_customer_metric_daily_agg_stg → insert_customer_metric_daily_agg → [succeed/fail]
6. Separate: call_lake_api → dq_check_customer_metric_daily_agg_lake (DQ on customer360.customer_metric_daily_agg_vw)

**Key finding from DAG:** The `SuccessNotificationOperator` registers `customer360.customer_metric_daily_agg_vw` as the lake output.

---

### A3. Table Inventory — All Referenced Tables

| Table | Role | Platform |
|-------|------|----------|
| `customer_core_conformed.customer_life_cycle` | READ (source) | Hive/Parquet S3 (file) |
| `customer360.customer_life_cycle_vw` | READ trigger (success file sensor) | Lake (data lake) |
| `customer_core_conformed.customer_metric_daily_agg` | WRITE (primary output) | Hive/Parquet S3 |
| `customer360.customer_metric_daily_agg_vw` | WRITE (lake publish via lake API) | Lake (data lake) |
| `customer_core_conformed.customer_metric_daily_agg_vw_stg` | WRITE (Redshift staging) | Redshift |
| `customer360.customer_metric_daily_agg_vw` | WRITE (Redshift final) | Redshift (same name, different platform) |
| Spark temp views: `daily_metrics`, `candidates_next_day`, `missing_next_day`, `daily_metrics_union`, `daily_metrics_last_day` | Internal session-scoped | Spark memory only — NOT catalog tables |

**Note:** `customer_mart.daily_active_customers` is referenced by the backfill DAG only (`customer_metric_daily_agg_backfill.py`), NOT by the primary `customer_metric_daily_agg.py` job.

---

### A4. Column Schemas

#### `customer_core_conformed.customer_life_cycle` (source — Hive DDL + lake DDL)

From `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl`:

| Column | Type | Notes |
|--------|------|-------|
| customer_id | string | @PrimaryKey, UUID |
| shopper_id | string | @UniqueKey, eComm shopper numeric ID |
| customer_acquisition_bill_id | string | @ForeignKey (analytic_feature.shopper_acquisition) |
| customer_acquisition_mst_date | date | Date of first net positive status |
| customer_acquisition_mst_month | string | yyyy-MM truncated |
| customer_acquisition_country_code | string | Country code at acquisition |
| customer_acquisition_channel_name | string | Acquisition channel |
| customer_tenure_year_count | int | Tenure in years |
| customer_acquisition_country_name | string | Country name |
| customer_region_1_name | string | Geo region level 1 |
| customer_region_2_name | string | Geo region level 2 |
| customer_region_3_name | string | Geo region level 3 |
| customer_domestic_international_name | string | Domestic/International flag |
| reseller_type_id | int | @ForeignKey (dp_enterprise.dim_reseller) |
| reseller_type_name | string | Reseller name |
| customer_type_name | string | Customer type label |
| customer_type_reason_desc | string | Customer type reason |
| customer_fraud_flag | boolean | Fraud flag |
| active_paid_subscription_list | array<string> | @ForeignKey (enterprise.dim_subscription_history) |
| product_pnl_category_list | array<string> | Product PNL categories |
| product_pnl_category_qty | int | Count of distinct categories |
| product_pnl_line_list | array<string> | Product PNL lines |
| ttm_all_bill_list | array<string> | TTM bill IDs |
| brand_name_list | array<string> | Brand names |
| ttm_gcr_usd_amt | decimal(18,2) | TTM GCR USD |
| customer_churn_mst_date | date | Most recent churn date |
| customer_reactivate_mst_date | date | Most recent reactivation date |
| customer_merge_mst_date | date | Merge date |
| customer_fraud_mst_date | date | Fraud flag set date |
| customer_state_enum | string | @Enumerated(active, churned, merged, reactivated) |
| active_status_flag | boolean | Active at eval date |
| point_of_purchase_name | string | Acquisition POP name |
| customer_acquisition_bill_fraud_flag | boolean | Acquisition bill fraud |
| etl_build_mst_ts | timestamp | ETL build time |
| **partition_eval_mst_date** | **string** | **Partition column (DATE as string)** |

#### `customer_core_conformed.customer_metric_daily_agg` / `customer360.customer_metric_daily_agg_vw` (target)

From `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl` + Hive DDL:

| Column | Type | PK? | Notes |
|--------|------|-----|-------|
| customer_type_reason_desc | string | Yes | GROUP BY dim |
| customer_acquisition_mst_month | string | Yes | GROUP BY dim |
| customer_domestic_international_name | string | Yes | GROUP BY dim |
| customer_region_1_name | string | Yes | GROUP BY dim |
| customer_region_2_name | string | Yes | GROUP BY dim |
| customer_region_3_name | string | Yes | GROUP BY dim |
| customer_country_name | string | Yes | GROUP BY dim; renamed from customer_acquisition_country_name |
| customer_country_code | string | Yes | GROUP BY dim; UK→GB normalization applied |
| customer_type_name | string | Yes | GROUP BY dim |
| acquisition_channel_name | string | Yes | GROUP BY dim; renamed from customer_acquisition_channel_name |
| customer_tenure_year_count | int | Yes | GROUP BY dim |
| product_ownership_category_list | string | Yes | Encoded array; renamed from product_pnl_category_list |
| product_ownership_line_list | string | Yes | Encoded array; renamed from product_pnl_line_list |
| reseller_type_name | string | Yes | GROUP BY dim |
| fraud_flag | boolean | Yes | Renamed from customer_fraud_flag |
| brand_name_list | string | Yes | Encoded array |
| product_category_qty | int | No | size(product_ownership_category_list) |
| ttm_gcr_usd_amt | decimal(18,2) | No | SUM(ttm_gcr_usd_amt) |
| ttm_gcr_segment_enum | string | Yes | @Enumerated(0, <=500, >500); derived from ttm_gcr_usd_amt CASE |
| ending_customer_qty | bigint | No | COUNT_IF(active_status_flag=true) |
| churn_customer_qty | bigint | No | COUNT_IF(customer_churn_mst_date IS NOT NULL) |
| merge_customer_qty | bigint | No | COUNT_IF(customer_merge_mst_date IS NOT NULL) |
| new_customer_qty | bigint | No | COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date) |
| reactivate_customer_qty | bigint | No | COUNT_IF(customer_reactivate_mst_date IS NOT NULL) |
| beginning_customer_qty | bigint | No | LAG(ending_customer_qty) over prior-day partition |
| net_move_qty | bigint | No | ending - beginning - new + (churn - reactivate) + merge |
| net_add_qty | bigint | No | ending - beginning |
| net_churn_qty | bigint | No | churn - reactivate |
| point_of_purchase_name | string | Yes* | *DQ constraint includes it as PK; lake DDL does NOT annotate as @PrimaryKey — discrepancy |
| customer_acquisition_bill_fraud_flag | boolean | Yes* | *DQ constraint includes as PK; lake DDL does NOT annotate as @PrimaryKey — discrepancy |
| data_source_enum | string | No | @Enumerated(customer360, legacy_dac); hardcoded 'customer360' in primary DAG |
| etl_build_mst_ts | timestamp | No | ETL build time in MST |
| **partition_eval_mst_date** | **string** | **Yes** | **Partition key; always required in WHERE** |

---

### A5. Join Conditions / Aggregation Logic

**NO explicit joins to external catalog tables.** The PySpark uses:

1. **GROUP BY aggregation** on `customer_core_conformed.customer_life_cycle` (lines 207-244)
   - Aggregation keys: 20 columns (19 dimensions + partition_eval_mst_date)
   - Computed measures: SUM(ttm_gcr_usd_amt), COUNT_IF for 5 events
   
2. **LEFT ANTI JOIN** on Spark temp views (`candidates_next_day` anti-join `daily_metrics`) — dimension carry-forward pattern to fill zeros for combos present yesterday but absent today. This join is internal to the Spark session, not a join to any catalog table.

3. **UNION** (`daily_metrics` UNION ALL `missing_next_day`) to combine real and zero-filled rows.

4. **LAG window function** partitioned by all 19 dimension columns, ordered by partition_eval_mst_date → computes `beginning_customer_qty`.

**No relationship columns available for Snowflake `relationships:` section** — this semantic view will have a single table with no joins.

---

### A6. DDL and Policy Files Consulted

| File | Notes |
|------|-------|
| `src/ddls/customer_metric_daily_agg.ddl` | Hive table DDL — authoritative column list for staging table |
| `src/policies/customer_metric_daily_agg_dag.yaml` | Pipeline metadata (inputs/outputs, SLA, lineage) |
| `src/data_quality/constraints/customer_metric_daily_agg.json` | PK composite constraint (20 cols) |
| `src/data_quality/constraints/customer_metric_daily_agg_vw.json` | Same PK constraint for lake table |
| `repos/lake/.../customer-metric-daily-agg-vw/table.ddl` | Lake DDL — authoritative for lake schema |
| `repos/lake/.../customer-metric-daily-agg-vw/table.yaml` | Lake YAML (SLA, lineage, permissions) |
| `repos/lake/.../customer-life-cycle-vw/table.ddl` | Lake DDL for source table |
| `repos/lake/.../customer-life-cycle-vw/table.yaml` | Lake YAML for source table |
| `src/diagrams/customer_metric_daily_agg_data_flow.md` | Data flow diagram |
| `src/diagrams/customer_metric_daily_agg_data_model.md` | ER diagram |

---

### A7. Confluence Summary

**Page 3779199819 (Customer360 - main):**
- Organizational contacts: Finance stewards, Marketing stakeholders, DAP business stewards, FORGE data products team
- Contains contact table and links to child pages

**Child page 4387965088 (Customer360 Business Context Structure):**
- Schema: `customer360`, Domain: Customer, Organization: DNA
- Data Tier: 4 (lifecycle, agg tables)
- Datasets covered: `customer_life_cycle_vw` (one row per customer per eval date), `customer_metric_daily_agg_vw` (one row per date × reporting dimension combo), `dim_customer_vw` (current snapshot), `dim_customer_history_vw` (SCD2)
- Weight of `customer_metric_daily_agg_vw` in coverage matrix: 15%

---

### A8. Alation Section

| Field | Value |
|-------|-------|
| Table ID found | 7038346 (`customer_metric_daily_agg_vw`) |
| Alation description | "A daily aggregated metrics table providing summarized customer performance indicators. Key Features: Daily aggregation of customer metrics." |
| Saved queries | 5 queries returned (IDs: 1, 27, 130, 226, 324) — ALL have empty titles and empty SQL content; NOT usable as verified_queries |
| Alation search endpoint | `/api/v1/search/` returned 404; table found via `/api/v1/table/?name=customer_metric_daily_agg_vw` |

**Alation conclusion:** Table is registered. Description is brief. No usable saved queries found.

---

### A9. Conflicts / Discrepancies

| # | Discrepancy | Code says | Other source says | Resolution |
|---|------------|-----------|-------------------|-----------|
| 1 | `point_of_purchase_name` PK status | DQ constraint includes it in isPrimaryKey() | Lake DDL does NOT annotate with @PrimaryKey (listed after brand_name_list without annotation) | Trust DQ constraint; flag for lake DDL update |
| 2 | `customer_acquisition_bill_fraud_flag` PK status | DQ constraint includes it in isPrimaryKey() | Lake DDL does NOT annotate with @PrimaryKey | Trust DQ constraint; flag for lake DDL update |
| 3 | Source table name | PySpark reads `customer_core_conformed.customer_life_cycle` | DAG policy yaml lists `customer360.customer_life_cycle_vw` as lake input | NOT a real conflict — staging Hive table and lake view are same S3 data; DAG sensor uses lake success file, PySpark reads Hive directly |
| 4 | `customer_fraud_flag` vs `fraud_flag` | PySpark renames `customer_fraud_flag` → `fraud_flag` in conform_datatype (line 418) | Hive DDL and lake DDL both use `fraud_flag` correctly | No conflict — DDL is correct |
| 5 | `product_pnl_category_list` / `product_pnl_line_list` vs `product_ownership_*` | PySpark renames in GROUP BY | DDL uses `product_ownership_*` | No conflict — DDL reflects final renamed column |
| 6 | `customer_acquisition_country_name` vs `customer_country_name` | PySpark aliases to `customer_country_name` | DDL uses `customer_country_name` | No conflict |
| 7 | `customer_acquisition_channel_name` vs `acquisition_channel_name` | PySpark aliases to `acquisition_channel_name` | DDL uses `acquisition_channel_name` | No conflict |

---

## PART B: Snowflake Semantic View Analysis

### B1. Target Table Resolution

**Output lake table:** `customer360.customer_metric_daily_agg_vw`

**Evidence chain:**
1. PySpark writes `customer_core_conformed.customer_metric_daily_agg` via `insertInto` (line 466-468)
2. DAG `call_lake_api` operator: `db_name="customer360", table_name="customer_metric_daily_agg_vw"` → registers as lake table
3. Lake catalog: `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/` exists with `table.yaml` and `table.ddl`
4. Policy yaml output: `customer360.customer_metric_daily_agg_vw` (datalake platform)
5. DAG DQ check: `customer360.customer_metric_daily_agg_vw` (lake DQ task)
6. Data model diagram: "A Redshift copy is published as `customer360.customer_metric_daily_agg_vw`"
7. Lake YAML lineage: `upstream_table_dependencies: [customer360.customer_life_cycle_vw]`

**Confidence: HIGH**

---

### B2. Lineage Resolution Table

| Table Referenced in Code | Type | Lake Table | Evidence |
|--------------------------|------|-----------|---------|
| `customer_core_conformed.customer_life_cycle` | Hive/Parquet (file) | `customer360.customer_life_cycle_vw` | policy yaml, lake catalog at dlms-api/us-west-2/customer360/customer-life-cycle-vw/ |
| `customer_core_conformed.customer_metric_daily_agg` | Hive/Parquet (file staging) | `customer360.customer_metric_daily_agg_vw` | DAG SuccessNotificationOperator, lake catalog |
| `customer360.customer_life_cycle_vw` | Lake table | `customer360.customer_life_cycle_vw` | Direct — registered in lake catalog |
| Spark temp views (daily_metrics, etc.) | Session-scoped | NOT lake tables | Documented in data flow diagram |

---

### B3. Table Classification

| Lake Table | Logical Name | Role | base_table | Primary Key |
|-----------|--------------|------|-----------|-------------|
| `customer360.customer_metric_daily_agg_vw` | `customer_metric_daily_agg` | **FACT** (aggregated) | `MARKETING_CORE_DEV.customer360.customer_metric_daily_agg_vw` | Composite: all 20 PK columns |
| `customer360.customer_life_cycle_vw` | Not included in semantic view (source only; all relevant fields already aggregated into fact table) | SOURCE (not included) | N/A | N/A |

**Design decision:** This semantic view has a **single table**. The source `customer_life_cycle_vw` is consumed via aggregation — no row-level join keys exist from the aggregated table back to it. Including it as a join target would require un-aggregating the data and is not meaningful.

---

### B4. Materialized Direct-Reads Table

| Lake Table | Materialized In Fields | Evidence |
|-----------|----------------------|---------|
| `customer360.customer_life_cycle_vw` | `customer_type_reason_desc`, `customer_acquisition_mst_month`, `customer_domestic_international_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`, `customer_country_code`, `customer_type_name`, `acquisition_channel_name`, `customer_tenure_year_count`, `product_ownership_category_list`, `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `brand_name_list`, `ttm_gcr_segment_enum` (dim columns) + all metric columns | GROUP BY aggregation in PySpark lines 207-244 |

---

### B5. Excluded Dimensions Table

| Lake Table | Reason | Fields Available on Fact (if any) |
|-----------|--------|-----------------------------------|
| `customer360.customer_life_cycle_vw` | Shopper/customer-level granularity is aggregated away; no join key survives into fact table (no shopper_id, no customer_id in target) | All dimension attributes of customer_life_cycle_vw that were GROUP BY keys are materialized as dimensions on the fact table |

---

### B6. Relationship Table

**No relationships.** This semantic view contains a single logical table. No joins exist.

---

### B7. Column Inventory — `customer_metric_daily_agg`

#### Time Dimensions

| Column | Category | expr | data_type | Description | synonyms |
|--------|----------|------|-----------|-------------|---------|
| partition_eval_mst_date | time_dimension | partition_eval_mst_date | VARCHAR | Date of evaluation (MST). Partition column. Every query should include a filter on this column. Derived from customer360.customer_life_cycle_vw.partition_eval_mst_date (pass-through from GROUP BY). Stored as string in YYYY-MM-DD format. | eval_date, reporting_date, snapshot_date, date |
| etl_build_mst_ts | time_dimension | etl_build_mst_ts | TIMESTAMP | ETL build timestamp in MST. Set to CURRENT_TIMESTAMP in MST at write time. Metadata column; not a business measure. | etl_timestamp, build_time |

#### Dimensions (GROUP BY attributes — categorical)

| Column | Category | expr | data_type | Description | synonyms |
|--------|----------|------|-----------|-------------|---------|
| customer_type_reason_desc | dimension | customer_type_reason_desc | VARCHAR | Reason for customer type classification (e.g., subscription-active, TTM-only). COALESCE(value, 'Not Classified'). Derived from customer360.customer_life_cycle_vw.customer_type_reason_desc. | customer_type_reason, type_reason |
| customer_acquisition_mst_month | dimension | customer_acquisition_mst_month | VARCHAR | Month when customer was acquired (MST), in yyyy-MM format. COALESCE(value, ''). Derived from customer360.customer_life_cycle_vw.customer_acquisition_mst_month. | acquisition_month, cohort_month |
| customer_domestic_international_name | dimension | customer_domestic_international_name | VARCHAR | Domestic vs International classification for the customer. COALESCE(value, 'International'). Derived from customer360.customer_life_cycle_vw.customer_domestic_international_name. | domestic_international, geo_classification |
| customer_region_1_name | dimension | customer_region_1_name | VARCHAR | Geographic region level 1 (highest tier). COALESCE(value, 'International - RoW'). Derived from customer360.customer_life_cycle_vw.customer_region_1_name. | region_1, region, geo_region |
| customer_region_2_name | dimension | customer_region_2_name | VARCHAR | Geographic region level 2. COALESCE(value, 'Rest of World (RoW)'). Derived from customer360.customer_life_cycle_vw.customer_region_2_name. | region_2, sub_region |
| customer_region_3_name | dimension | customer_region_3_name | VARCHAR | Geographic region level 3 (most granular). COALESCE(value, 'NA'). Derived from customer360.customer_life_cycle_vw.customer_region_3_name. | region_3, local_region |
| customer_country_name | dimension | customer_country_name | VARCHAR | Country name where customer was acquired. COALESCE(customer_acquisition_country_name, 'Unknown') renamed. Derived from customer360.customer_life_cycle_vw.customer_acquisition_country_name. | country_name, country |
| customer_country_code | dimension | customer_country_code | VARCHAR | ISO country code. COALESCE(customer_acquisition_country_code, '--') renamed; UK normalized to GB via WHEN UPPER='UK' THEN 'GB'. Derived from customer360.customer_life_cycle_vw.customer_acquisition_country_code. | country_code, iso_country |
| customer_type_name | dimension | customer_type_name | VARCHAR | Customer type label at evaluation date (e.g., active, churned). COALESCE(value, 'Not Classified'). Derived from customer360.customer_life_cycle_vw.customer_type_name. | customer_type, type |
| acquisition_channel_name | dimension | acquisition_channel_name | VARCHAR | Channel through which customer was acquired. COALESCE(customer_acquisition_channel_name, 'Not GA Attributed') renamed. Derived from customer360.customer_life_cycle_vw.customer_acquisition_channel_name. | acquisition_channel, channel |
| customer_tenure_year_count | dimension | customer_tenure_year_count | INT | Customer tenure in years (integer, used as grouping band). COALESCE(value, 0). Derived from customer360.customer_life_cycle_vw.customer_tenure_year_count. | tenure_years, tenure |
| product_ownership_category_list | dimension | product_ownership_category_list | VARCHAR | String-encoded list of product PNL categories owned by customers in this dimension group. Cast from array<string>; renamed from product_pnl_category_list. Derived from customer360.customer_life_cycle_vw.product_pnl_category_list. Note: array encoded as string. | product_categories, pnl_category_list |
| product_ownership_line_list | dimension | product_ownership_line_list | VARCHAR | String-encoded list of product PNL lines owned by customers in this dimension group. Cast from array<string>; renamed from product_pnl_line_list. Derived from customer360.customer_life_cycle_vw.product_pnl_line_list. Note: array encoded as string. | product_lines, pnl_line_list |
| reseller_type_name | dimension | reseller_type_name | VARCHAR | Reseller type name. COALESCE(value, NULL) — no default applied. Derived from customer360.customer_life_cycle_vw.reseller_type_name. | reseller_type, reseller |
| fraud_flag | dimension | fraud_flag | BOOLEAN | True if customers in this group are flagged as fraud at evaluation date. COALESCE(customer_fraud_flag, false) renamed. Derived from customer360.customer_life_cycle_vw.customer_fraud_flag. | is_fraud, fraud |
| point_of_purchase_name | dimension | point_of_purchase_name | VARCHAR | Point of purchase name from acquisition bill. COALESCE(value, 'Unknown'). Derived from customer360.customer_life_cycle_vw.point_of_purchase_name. | pop, point_of_purchase |
| customer_acquisition_bill_fraud_flag | dimension | customer_acquisition_bill_fraud_flag | BOOLEAN | True if the acquisition bill has a fraud record. COALESCE(value, false). Derived from customer360.customer_life_cycle_vw.customer_acquisition_bill_fraud_flag. | bill_fraud_flag, acquisition_fraud |
| brand_name_list | dimension | brand_name_list | VARCHAR | String-encoded list of brands associated with customers in this group. Cast from array<string>. Derived from customer360.customer_life_cycle_vw.brand_name_list. Note: array encoded as string. | brands, brand_list |
| ttm_gcr_segment_enum | dimension | ttm_gcr_segment_enum | VARCHAR | TTM GCR bucket. Derived CASE: NULL or <=0 → '0'; >0 and <=500 → '<=500'; >500 → '>500'. Derived from customer360.customer_life_cycle_vw.ttm_gcr_usd_amt. Enumerated values: 0, <=500, >500. | gcr_segment, ttm_segment, revenue_bucket |
| data_source_enum | dimension | data_source_enum | VARCHAR | Source pipeline used to populate data. 'customer360' for primary daily DAG; 'legacy_dac' for backfill DAG (customer_mart.daily_active_customers pre-cutoff dates). Enumerated values: customer360, legacy_dac. | data_source, source |

#### Facts (row-level quantitative values)

| Column | Category | expr | data_type | Description | synonyms |
|--------|----------|------|-----------|-------------|---------|
| ttm_gcr_usd_amt | fact | ttm_gcr_usd_amt | DECIMAL | Sum of trailing twelve months gross cash received (GCR) in USD for this dimension group on the eval date. SUM(ttm_gcr_usd_amt) aggregated from customer360.customer_life_cycle_vw.ttm_gcr_usd_amt. | ttm_gcr, ttm_revenue, gross_cash_received |
| ending_customer_qty | fact | ending_customer_qty | BIGINT | Count of active customers at end of eval date for this dimension combination. COUNT_IF(active_status_flag = true) from customer360.customer_life_cycle_vw. | ending_customers, active_customers, customers |
| churn_customer_qty | fact | churn_customer_qty | BIGINT | Count of customers who churned on the eval date. COUNT_IF(customer_churn_mst_date IS NOT NULL). Derived from customer360.customer_life_cycle_vw.customer_churn_mst_date. | churned_customers, churn_count |
| merge_customer_qty | fact | merge_customer_qty | BIGINT | Count of customers merged on eval date. COUNT_IF(customer_merge_mst_date IS NOT NULL). Derived from customer360.customer_life_cycle_vw.customer_merge_mst_date. | merged_customers, merge_count |
| new_customer_qty | fact | new_customer_qty | BIGINT | Count of new customers acquired on eval date (acquisition date = eval date). COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date). Derived from customer360.customer_life_cycle_vw. | new_customers, acquired_customers |
| reactivate_customer_qty | fact | reactivate_customer_qty | BIGINT | Count of reactivated customers on eval date. COUNT_IF(customer_reactivate_mst_date IS NOT NULL). Derived from customer360.customer_life_cycle_vw.customer_reactivate_mst_date. | reactivated_customers, reactivation_count |
| beginning_customer_qty | fact | beginning_customer_qty | BIGINT | Beginning-of-day customer count (prior day's ending count). LAG(ending_customer_qty) OVER (PARTITION BY all dims ORDER BY partition_eval_mst_date); 0 if prior day is not contiguous. | beginning_customers, prior_day_ending |
| net_move_qty | fact | net_move_qty | BIGINT | Net customer movement: ending - beginning - new + (churn - reactivate) + merge. Derived within ETL from other metrics. | net_movement, net_move |
| net_add_qty | fact | net_add_qty | BIGINT | Net additions: ending_customer_qty - beginning_customer_qty. Derived within ETL. | net_additions, net_add |
| net_churn_qty | fact | net_churn_qty | BIGINT | Net churn: churn_customer_qty - reactivate_customer_qty. Derived within ETL. | net_churn |
| product_category_qty | fact | product_category_qty | INT | Number of product categories owned by customers in this dimension group. size(product_ownership_category_list). Derived from customer360.customer_life_cycle_vw.product_pnl_category_list. | num_product_categories, product_category_count |

---

### B8. Metrics Table

| Name | Expression | Description | Evidence |
|------|-----------|-------------|---------|
| total_ending_customers | SUM(ending_customer_qty) | Total active customers at end of day across selected dimensions | COUNT_IF in PySpark lines 234-235 |
| total_new_customers | SUM(new_customer_qty) | Total new customers acquired on selected date(s) | COUNT_IF in PySpark line 237 |
| total_churned_customers | SUM(churn_customer_qty) | Total customers who churned | COUNT_IF in PySpark line 235 |
| total_reactivated_customers | SUM(reactivate_customer_qty) | Total reactivated customers | COUNT_IF in PySpark line 238 |
| total_merged_customers | SUM(merge_customer_qty) | Total merged customers | COUNT_IF in PySpark line 236 |
| total_beginning_customers | SUM(beginning_customer_qty) | Total beginning-of-day customers | LAG window in PySpark lines 366-370 |
| total_net_add | SUM(net_add_qty) | Net customer additions (ending - beginning) | PySpark lines 383-384 |
| total_net_churn | SUM(net_churn_qty) | Net churn (churned - reactivated) | PySpark lines 385-386 |
| total_net_move | SUM(net_move_qty) | Net customer movement (ending - beginning - new + net_churn + merge) | PySpark lines 382-385 |
| total_ttm_gcr_usd_amt | SUM(ttm_gcr_usd_amt) | Total TTM GCR USD across selected dimension slice | SUM in PySpark line 233 |

---

### B9. Verified Queries Table

*Alation returned 5 queries for this table (IDs: 1, 27, 130, 226, 324) but all had empty titles and empty SQL content. No usable Alation verified queries available.*

Candidate queries derived from PySpark aggregation patterns and business context (Confluence):

| Name | Question | SQL | Source |
|------|---------|-----|--------|
| ending_customers_by_type_and_date | How many active customers were there by customer type on a given date? | SELECT partition_eval_mst_date, customer_type_name, SUM(ending_customer_qty) AS total_ending_customers FROM customer360_customer_metric_daily_agg WHERE partition_eval_mst_date = :date GROUP BY 1, 2 ORDER BY 3 DESC | PySpark COUNT_IF pattern |
| new_vs_churn_by_country | What was the balance of new customers vs churned customers by country? | SELECT partition_eval_mst_date, customer_country_name, SUM(new_customer_qty) AS new_customers, SUM(churn_customer_qty) AS churned_customers, SUM(net_add_qty) AS net_add FROM customer360_customer_metric_daily_agg GROUP BY 1, 2 ORDER BY 1, 5 DESC | PySpark net_add logic |
| ttm_gcr_by_segment | What is the total TTM GCR by GCR segment and region? | SELECT customer_region_1_name, ttm_gcr_segment_enum, SUM(ttm_gcr_usd_amt) AS total_ttm_gcr FROM customer360_customer_metric_daily_agg WHERE partition_eval_mst_date = :date GROUP BY 1, 2 ORDER BY 3 DESC | SUM aggregation pattern |

---

### B10. Semantic View Metadata

| Field | Value |
|-------|-------|
| **View name** | `customer360_customer_metric_daily_agg` |
| **Description** | "Daily aggregated customer movement metrics for Customer360. One row per evaluation date × unique combination of 19 customer dimension attributes. Provides customer lifecycle KPIs including active count, new, churned, reactivated, merged, and net movement by customer segment, geography, channel, product ownership, and tenure. Built daily at 7:30 AM MST from customer360.customer_life_cycle_vw. SLA: 8:00 AM MST." |
| **base_table database** | MARKETING_CORE_DEV |
| **base_table schema** | customer360 |
| **base_table table** | customer_metric_daily_agg_vw |

**custom_instructions draft:**
```
This semantic view represents pre-aggregated customer movement metrics. One row = one unique combination of 19 dimension attributes + partition_eval_mst_date.

REQUIRED: Always filter on partition_eval_mst_date — unfiltered queries will scan all partitions.

GRAIN: Row-level metric quantities (ending_customer_qty, new_customer_qty, etc.) are already aggregated counts for the dimension combination. Use SUM() to roll up across dimension groups.

ARRAY COLUMNS: product_ownership_category_list, product_ownership_line_list, and brand_name_list are stored as string-encoded arrays (not native ARRAY type). Use LIKE or string parsing to filter.

COALESCE DEFAULTS: Dimension columns have COALESCE defaults applied in ETL — null values replaced with 'Not Classified', 'Unknown', 'International', etc.

COUNTRY CODE: customer_country_code has UK normalized to GB.

DATA SOURCE: data_source_enum='customer360' for all current daily data. 'legacy_dac' rows exist only for historical backfill dates from customer_mart.daily_active_customers.

BEGINNING CUSTOMERS: beginning_customer_qty = 0 when the prior day's dimension combination did not exist, even if customers existed on prior days under different combinations.
```

---

### B11. Do-Not-Claim Table

| Item | Reason |
|------|--------|
| `daily_metrics` Spark view | Session-scoped temp view; not a catalog table |
| `candidates_next_day` Spark view | Session-scoped temp view |
| `missing_next_day` Spark view | Session-scoped temp view |
| `daily_metrics_union` Spark view | Session-scoped temp view |
| `daily_metrics_last_day` Spark view | Session-scoped temp view |
| `customer_mart.daily_active_customers` | Used only by the separate backfill DAG (`customer_metric_daily_agg_backfill.py`); NOT used by primary `customer_metric_daily_agg.py` |
| `customer360.customer_metric_monthly_agg` | Downstream table — NOT a source for this view |
| `customer_metric_daily_agg_vw_stg` (Redshift) | Staging table in Redshift — intermediate only; not a lake table |


**The agent's final response to the user was:**
The research stage is complete. Here is a summary of what was accomplished:

---

## Research Stage Summary

### What was done

**Step 1–3: Code checkout and PySpark/DAG reading**
- Checked out `dof-dpaas-customer-feature` at `main` (already at HEAD)
- Read `customer_metric_daily_agg.py` — pure aggregation job reading from `customer_core_conformed.customer_life_cycle`, writing to `customer_core_conformed.customer_metric_daily_agg`
- Read `customer_metric_daily_agg_dag.py` — DAG schedules at 7:30 AM MST daily, registers lake table `customer360.customer_metric_daily_agg_vw` via `SuccessNotificationOperator`

**Step 4: Secondary sources**
- Read Hive DDL, lake DDL, policy YAML, DQ constraints, and data flow/model diagrams from the repo

**Step 5: Confluence**
- Fetched parent page 3779199819 (contacts/org chart) and child page 4387965088 (Business Context Structure with dataset grain documentation)

**Step 6: Alation**
- Located table 7038346 (`customer_metric_daily_agg_vw`) with brief description
- Fetched 5 saved queries — all had empty titles and SQL; not usable as verified queries

**Steps 7–16: Analysis**
- **Target lake table:** `customer360.customer_metric_daily_agg_vw` (high confidence, 7 independent evidence points)
- **Grain:** One row per `partition_eval_mst_date` × 19-column dimension combination; composite PK confirmed by DQ constraint
- **No joins:** Single aggregation source; no Snowflake `relationships:` needed
- **2 time dimensions**, **20 categorical/boolean dimensions**, **11 facts**, **10 metrics** catalogued with full lineage descriptions
- **3 key discrepancies** flagged (lake DDL missing PK annotations on 2 columns; staging Hive table vs. lake table duality)
- **3 array-encoded string columns** flagged for query guidance

**Steps 17–18: Output files written**
- `RESOLVED_TARGET.json` — target `MARKETING_CORE_DEV.customer360.customer_metric_daily_agg_vw`, confidence=high
- `PROVENANCE.json` — grain, PK notes, intermediate tables, array fields, legacy source, do-not-claim list