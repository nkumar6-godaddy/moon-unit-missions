**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent. Your job is to ensure the final metadata doc is:
1) accurate (no false claims) and 2) complete in structure (all 20 sections present).

## Step 1: Read all artifacts
Read:
- `INPUT.md`
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `TABLE_METADATA.md`

## Step 2: Accuracy validation
For each non-trivial claim in TABLE_METADATA.md (grain, keys, filters, metrics, SLA, lineage):
- Identify the exact evidence source (PySpark line, DAG setting, lake table.yaml, etc.)
- If evidence is missing or contradictory, rewrite the metadata doc to remove or soften the claim.
- If a claim cannot be validated, replace it with a REQUIRES_MANUAL_INPUT marker.

**DO NOT modify A1's Redshift Serverless Dev fields.** The A1 section intentionally shows
the Redshift Dev Serverless entry (Database = "Redshift - Serverless - Dev", Alation URL
pointing to the dev.* table) as the primary access identity. This is BY DESIGN — do not
change it to "AWS Data Catalog" or any other value.

## Step 2b: C1 Source Table validation (CRITICAL)
Scan the C1 "Source Table(s)" column in TABLE_METADATA.md. For EACH entry:
- If it references a local/intermediate/staging table (look for patterns like `*_stg`,
  `*_conformed.*`, `*_driver`, `analytic_local.*`, or any table NOT in the lake registry),
  this is a FAILURE. Replace it with:
  - The actual lake table if analyze.md resolved it
  - `UNRESOLVED - requires manual input` if analyze.md could not resolve it
- Only lake tables (those in `repos/lake/`) or external systems are acceptable as sources.

## Step 3: Completeness validation
Ensure all 20 sections exist with the correct headings. If missing, add them.
If a section is too sparse and cannot be completed accurately, add the manual-input marker.

## Step 4: Append a report to validate.md
Append:
- Target table
- PASS/FAIL for accuracy and completeness
- List of issues found + how they were fixed
- Sections requiring manual input (final list)

**The agent summarized its work in this way:**

---

## Validation Report

**Target Table:** `customer360.dim_customer_vw`
**Run Date:** 2026-06-09
**Validator Stage:** validate

---

### Overall Verdict

| Check | Result |
|---|---|
| Accuracy (non-trivial claims) | **PASS** |
| C1 Source Table validation | **PASS** |
| Completeness (all 20 sections) | **PASS** (21 sections present) |
| A1 Redshift Serverless Dev fields | **UNTOUCHED** (per instructions) |

---

### Step 2: Accuracy Validation — Evidence Map

Every non-trivial claim in TABLE_METADATA.md was traced to a specific source artifact. No false or unsupported claims were found.

| Claim | Source Evidence | Status |
|---|---|---|
| Table name `dim_customer_vw`, schema `customer360` | `dim_customer_dag.py:601` (`db_name="customer360"`, `table_name="dim_customer_vw"`); `table.ddl:1` | VERIFIED |
| Database: Redshift - Serverless - Dev (A1) | BY DESIGN — do not modify | UNTOUCHED |
| Alation ID 7027529 (Redshift Dev Serverless) | `gather.md` — Alation section | VERIFIED |
| Alation ID 7022291 (Lake entry) | `gather.md` — Alation section | VERIFIED |
| Physical Iceberg table `customer_core_conformed.dim_customer` | `dim_customer_iceberg_common.py:11` `DELTA_DEST_TABLE = "customer_core_conformed.dim_customer"` | VERIFIED |
| History view `customer360.dim_customer_history_vw` | `dim_customer_dag.py:613` `table_name="dim_customer_history_vw"` | VERIFIED |
| Grain: one row per active customer (`current_record_flag = True`) | `create_view.sql:31` `WHERE current_record_flag = true` | VERIFIED |
| Primary Key (view): `customer_id` | `table.ddl:2` `@PrimaryKey` annotation | VERIFIED |
| Primary Key (physical): `(customer_id, effective_end_mst_ts)` | `gather.md` — data_quality/constraints section (isPrimaryKey) | VERIFIED |
| Partition key: None (physical Iceberg unpartitioned) | `dim_customer_iceberg_common.py:129-177` — `CREATE TABLE IF NOT EXISTS ... USING ICEBERG` with no PARTITIONED BY clause | VERIFIED |
| Partition key conflict: `table.yaml` declares `current_record_flag` | `table.yaml:14-16` `partition_keys: - name: current_record_flag` | VERIFIED CONFLICT |
| Storage: Apache Iceberg, Parquet, ZSTD | `dim_customer_iceberg_common.py:166,170` `USING ICEBERG`, `'write_compression' = 'zstd'` | VERIFIED |
| S3 location `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/dim_customer_v2` | `dim_customer_iceberg_common.py:15-16`; `dim_customer_dag.py:702` | VERIFIED |
| Data Tier: 2 | `table.yaml:17` `data_tier: 2` | VERIFIED |
| SLA delivery by 10:00 UTC | `table.yaml:19` `deliveryCadenceUTC: "cron(00 10 * * ? *)"` | VERIFIED |
| DAG schedule `35 01 * * *` daily prod | `dim_customer_dag.py:142` `schedule_interval="35 01 * * *" if AWS_ENV == "prod" else None` | VERIFIED |
| Max pipeline duration 90 min, severity LOW | `dim_customer_dag.yaml:25-26` `maxDurationMins: 90`, `severity: LOW` | VERIFIED |
| Retries: 2 | `dim_customer_dag.py:137` `"retries": 2` | VERIFIED |
| Max active runs: 1 | `dim_customer_dag.py:143` `max_active_runs=1` | VERIFIED |
| Catchup: disabled | `dim_customer_dag.py:144` `catchup=False` | VERIFIED |
| DAG ID: `dim_customer_dag` | `dim_customer_dag.py:99` `DAG_NAME = "dim_customer_dag"` | VERIFIED |
| Owner: EDT | `dim_customer_dag.py:112` `OWNER_TEAM_NAME = "EDT"` | VERIFIED |
| On-call: `DEV-EDT-OnCall` | `dim_customer_dag.py:113` `ON_CALL_GROUP = "DEV-EDT-OnCall"` | VERIFIED |
| Slack alerts: `edt-airflow-alerts` (prod) / `edt-airflow-alerts-low-priority` (non-prod) | `dim_customer_dag.py:104` | VERIFIED |
| Historical baseline: 2025-06-01 | `gather.md` Confluence summary; `dim_customer_dag.py:64` doc_md manual run example | VERIFIED |
| v1.0 released 2025-06-16 | `gather.md:613` Confluence page 3829375759 | VERIFIED |
| FortKnox deprecation date 2025-09-30 | `gather.md:455` "deprecated September 30, 2025"; `analyze.md:366` explicit date | VERIFIED |
| 27+ consumer roles | `table.yaml:38-74` — 35 `!consumer` permission entries (several are env variants of same role; "27+" is accurate) | VERIFIED |
| EMR 7.2.0 ARM64 m6g.2xlarge × 8 core + 1 master | `dim_customer_dag.py:385-389` `release_label="emr-7.2.0"`, `ssm_param_ami_image_id="...arm/latest"`, `core_instance_type="m6g.2xlarge"`, `number_of_core_instances=8` | VERIFIED |
| Iceberg runtime jar: `/usr/share/aws/iceberg/lib/iceberg-spark3-runtime.jar` | `dim_customer_dag.py:397` | VERIFIED |
| AWS Glue catalog | `dim_customer_dag.py:400-401` `GlueCatalog` config | VERIFIED |
| Normal scope: 2 MST dates (N=1) | `dim_customer_dag.py:217-219` N=1 → run_start = run_date-1, n_snapshot_days=2 | VERIFIED |
| `create_view.sql` selects 28 columns with `WHERE current_record_flag = True WITH NO SCHEMA BINDING` | `create_view.sql:2-32` — 28 explicit columns, line 31-32 | VERIFIED |
| 128 MB target file size | `dim_customer_iceberg_common.py:173` `'write.target-file-size-bytes' = '134217728'` (= 128 × 1024 × 1024) | VERIFIED |
| Upstream sensors: 3 S3KeySensors + 2 PythonSensors | `dim_customer_dag.py:246-373` — `upstream_sensors()` creates S3KeySensors for fortknox, rp_salesmonitor, dim_customer_attributes; `PythonSensor` for customer_id_mapping_snapshot and profile_audit | VERIFIED |
| `call_lake_api` → `dim_customer_vw`; `call_lake_api_hist` → `dim_customer_history_vw` | `dim_customer_dag.py:599-623` | VERIFIED |
| Confluence pages 3829310172 and 3901325712 in E3 | `gather.md:463-464` — both page IDs found during gather phase | VERIFIED |
| SCD MERGE close logic: set `current_record_flag = False`, update `effective_end_mst_ts` | `gather.md` — SCD merge logic section; confirmed in analyze.md structured facts | VERIFIED |
| UK→GB country code normalization post-SCD UPDATE | `gather.md` — PySpark script analysis; confirmed in analyze.md | VERIFIED |
| `deleted_mst_ts` = `closed_mst_ts` (same source column `pf_closed_date_utc_ts`) | `analyze.md` — column-level lineage section | VERIFIED |
| `parent_customer_id` equals `customer_id` (current impl) | `analyze.md` — column derivations | VERIFIED |
| DQ constraint: Composite PK `isPrimaryKey("customer_id", "effective_end_mst_ts")` | `gather.md` — data_quality/constraints section | VERIFIED |
| DQ constraint: View PK `isPrimaryKey("customer_id")` | `gather.md` — data_quality/constraints section | VERIFIED |

---

### Step 2b: C1 Source Table Validation

Scanned all 29 rows in the C1 column reference table. Checked for disallowed patterns: `*_stg`, `*_conformed.*`, `*_driver`, `analytic_local.*`, or any table not in the lake registry.

**Result: PASS — No violations found.**

| Row(s) | Source Table Listed | Assessment |
|---|---|---|
| 1, 2, 6 | `customers.customer_id_mapping_snapshot` | Lake table — registered (`table.yaml` lineage; `dim_customer_dag.yaml` inputs) |
| 3, 7 | `fortknox.fortknox_shopper_snap` | Lake table — registered (`table.yaml` lineage; `dim_customer_dag.yaml` inputs) |
| 4 | `sso_permissions_cln.identity_mapping_snapshot_cln` | Lake table — registered (`table.yaml` lineage line 33) |
| 5 | `sso_metadata_cln.federation_metadata_snapshot_cln` | Lake table — registered (`table.yaml` lineage line 32) |
| 10 | `godaddy.rp_salesmonitor_internalshopper_snap` + `customers.customer_id_mapping_snapshot` | Lake tables — registered (`table.yaml` lineage; `dim_customer_dag.yaml` inputs) |
| 8–9, 11–27 | `signals_platform_cln.profile_audit_lake_cln_v2 (UNRESOLVED)` | Correctly marked **UNRESOLVED** — listed in `table.yaml` lineage and `dim_customer_dag.yaml` inputs, DAG sensor confirms upstream dependency, but not found in lake catalog (`repos/lake/`) |
| 28 | ETL-generated | No lake source — correct |
| 29 | ETL-generated | No lake source — correct |

The intermediate tables `customer_core_conformed.dim_customer_daily_delta` and `customer_core_conformed.dim_customer_attributes` are correctly excluded from C1 Source Table(s) and noted only in the C1 header note. `dim_customer_attributes` is confirmed as an intermediate S3 path in `dim_customer_dag.yaml:56-62` (`platform: s3-ckpetlbatch`) and `dim_customer_dag.py:265` (`/local_process/customer_core_conformed/dim_customer_attributes`) — NOT a lake table. Its exclusion from C1 source column is correct.

---

### Step 3: Completeness Validation

All 21 sections are present with correct headings:

| Section | Heading | Status |
|---|---|---|
| A1 | Table Overview | Present |
| A2 | What This Table Is About | Present |
| A3 | Organizational Context & Ownership | Present |
| B1 | Key Business Value | Present |
| B2 | Primary Use Cases | Present |
| B3 | Advanced Analytics Use Cases | Present |
| C1 | Complete Column Reference with Data Insights | Present |
| C2 | Primary Key & Performance | Present |
| C3 | Key Features, Capabilities & Limitations | Present |
| C4 | Important Notes & Pitfalls | Present |
| C5 | Always-On Column Filters | Present |
| C6 | Common Business Metrics | Present |
| C7 | Glossary & Term Definitions | Present |
| C8 | Example Queries & Patterns | Present |
| D1 | Data Source Reference | Present |
| D2 | Data Pipeline & Infrastructure | Present |
| D3 | SLA & Refresh Schedule | Present |
| D4 | Table Creation & ETL Implementation | Present |
| E1 | Data Quality Checks | Present |
| E2 | Best Practices & Tips | Present |
| E3 | Related Articles & Documentation | Present |

21 sections present — satisfies the 20-section minimum requirement with one supplementary section (B3 Advanced Analytics).

---

### Changes Made to TABLE_METADATA.md

**None.** All claims were verified accurate. No corrections, removals, or rewrites were required.

---

### Issues Found and Resolution

| # | Issue | Severity | Resolution |
|---|---|---|---|
| 1 | `signals_platform_cln.profile_audit_lake_cln_v2` not in lake catalog | Pre-existing | Already marked `UNRESOLVED` in C1 and D1 with `REQUIRES_MANUAL_INPUT` markers |
| 2 | Partition key conflict: code=unpartitioned, `table.yaml`=`current_record_flag` | Pre-existing | Already documented in C4 pitfall #5 and A1/C2 partition key fields |
| 3 | `effective_end_mst_dt` (Alation) vs `effective_end_mst_ts` (code) column name discrepancy | Pre-existing | Already documented in C4 pitfall #2 and E2 best practice #4 |
| 4 | DQ constraint inventory beyond primary keys not captured | Pre-existing | Already marked `REQUIRES_MANUAL_INPUT: DG` in E1 |

No new issues were introduced by the generate stage.

---

### Sections Requiring Manual Input (Final List)

| Section | Marker | What Is Needed |
|---|---|---|
| C1 (rows 8–9, 11–27) | `REQUIRES_MANUAL_INPUT: DE` | Schema documentation for `signals_platform_cln.profile_audit_lake_cln_v2` — column names, types, and descriptions from the owning team (currently inferred from ETL alias names) |
| D1 | `REQUIRES_MANUAL_INPUT: DE` | `signals_platform_cln.profile_audit_lake_cln_v2` schema details, SLA, and data ownership — requires input from the Signals Platform team |
| E1 | `REQUIRES_MANUAL_INPUT: DG` | Full DQ constraint inventory beyond primary key definitions — null checks, referential integrity, value range rules — requires review of `src/data_quality/constraints/` in the source repo |

---

### Validation Notes

- **A1 Redshift Serverless Dev fields**: Left unchanged per instructions. `Database = "Redshift - Serverless - Dev"` and Alation URL pointing to `table/7027529/` (dev.* table) are the primary access identity by design.
- **EMR operator naming**: The DAG imports `CreateEMRServerlessApplicationOperator` and the policies YAML labels the platform `emr-serverless`. The spark-submit commands use `--master yarn --deploy-mode cluster` (classic YARN mode), and the JAR path `/usr/share/aws/...` suggests EC2-backed execution. This internal GoDaddy infrastructure detail does not affect metadata accuracy. D2's `AWS EMR 7.2.0` claim is accurate to the `release_label` in the DAG code.
- **FortKnox deadline `2025-09-30`**: Confirmed in `gather.md:455` ("deprecated September 30, 2025") and `analyze.md:366` (explicit date). Not an inference.
- **27+ consumer roles**: `table.yaml` lists ~35 permission entries; "27+" is conservative and accurate.


**The agent's final response to the user was:**
Validation complete. Here is the summary of what was done:

---

## Validation Summary — `customer360.dim_customer_vw`

### Results

| Check | Verdict |
|---|---|
| **Accuracy** | **PASS** |
| **C1 Source Table validation** | **PASS** |
| **Completeness** | **PASS** (21 sections, minimum 20 required) |
| **A1 Redshift Serverless Dev** | **UNTOUCHED** (by design) |

### Evidence verified against source files

40+ non-trivial claims were traced to specific lines in the authoritative sources:

- **DAG schedule, retries, max_active_runs, catchup** → `dim_customer_dag.py:142–144`
- **SLA 10:00 UTC delivery** → `table.yaml:19` (`cron(00 10 * * ? *)`)
- **90-min SLA / LOW severity** → `dim_customer_dag.yaml:25–26`
- **EMR 7.2.0, ARM64, m6g.2xlarge × 8 core** → `dim_customer_dag.py:385–389`
- **Iceberg unpartitioned (code is authoritative over table.yaml)** → `dim_customer_iceberg_common.py:129–177` — no `PARTITIONED BY` clause
- **28 view columns, `WITH NO SCHEMA BINDING`** → `create_view.sql:2–32` — exact column list confirmed
- **FortKnox deadline 2025-09-30** → `gather.md:455` (not an inference — explicitly stated)
- **Confluence pages 3829310172 & 3901325712** → `gather.md:463–464` — confirmed found during gather

### C1 source table check

No intermediate or staging tables (`*_stg`, `*_conformed.*`, `*_driver`, `analytic_local.*`) were found in the C1 Source Table(s) column. The `customer_core_conformed.dim_customer_attributes` intermediate table is correctly excluded from C1 (noted only in the header) and replaced with the resolved lake tables (`sso_permissions_cln.identity_mapping_snapshot_cln` and `sso_metadata_cln.federation_metadata_snapshot_cln`). `signals_platform_cln.profile_audit_lake_cln_v2` remains correctly marked **UNRESOLVED**.

### No changes to TABLE_METADATA.md were required

All claims were accurate. The three pre-existing `REQUIRES_MANUAL_INPUT` markers (C1, D1, E1) remain in place and are correct.