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

## Step 2b: C1 Column Lineage validation (CRITICAL)
Scan the C1 "Column Lineage" column in TABLE_METADATA.md. For EACH entry:
- If it references a local/intermediate/staging table (look for patterns like `*_stg`,
  `*_conformed.*`, `*_driver`, `analytic_local.*`, or any table NOT in the lake registry),
  this is a FAILURE. Replace it with:
  - Descriptive transformation text referencing the actual lake table.column if analyze.md resolved it
  - `UNRESOLVED - requires manual input` if analyze.md could not resolve it
- Only lake tables (those in `repos/lake/`) or external systems are acceptable as sources.
- Verify C1 uses EXACTLY these columns: #, Name, Data Type, Description, Column Lineage,
  Category, Sample Values, Key Statistics. Remove any extra columns (e.g., "Source Table(s)",
  "Transformation / Notes").
- Verify each row has a Category value from: Identifier, Categorical, Date, Numeric,
  Boolean, Text, Amount, Timestamp, Array.
- Verify Sample Values and Key Statistics are empty (not fabricated) if gather.md had no
  Alation profiling data.

## Step 2c: Structure validation (sample format)
- Verify A1 includes Table ID, Type, Description, Lake Database, Lake Alation ID when
  available in gather.md.
- Verify D1 uses multi-depth upstream/downstream tables when analyze.md provides them.
- Verify D4 has sub-sections: ETL Processes, Data Processing Steps, Error Handling and
  Logging, Data Validation.
- Verify a REFERENCES section exists at the end of the document.

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

## Validation Stage Report — customer360.customer_life_cycle_vw

**Validated:** 2026-06-10  
**Validator Agent:** validate stage  
**Target Table:** `customer360.customer_life_cycle_vw`

---

### Overall Result

| Check | Result |
|---|---|
| Accuracy | **PASS** (3 unverified claims fixed) |
| Completeness | **PASS** (21 sections present; exceeds required 20) |

---

### Step 2: Accuracy Validation

#### Claims Verified ✓

| Claim | Evidence Source |
|---|---|
| Grain: one row per `shopper_id + partition_eval_mst_date` | DQ constraint `isPrimaryKey("partition_eval_mst_date", "shopper_id")` in `customer_life_cycle.json`; gather.md |
| Partition key: `partition_eval_mst_date` (STRING in Hive, DATE in Redshift) | Hive DDL and Redshift DDL; gather.md §5 |
| Storage format: Parquet | Hive DDL; gather.md §5 |
| SLA delivery target: 08:00 AM MST daily | Lake registry `table.yaml`; gather.md §5 |
| DAG schedule: `20 7 * * *` (7:20 AM MST daily) | `customer_life_cycle_dag.py`; gather.md §2 |
| EMR: `emr-7.10.0`, `m6g.16xlarge × 15` nodes | DAG file; gather.md §2 |
| Max pipeline duration: 120 min, TIER_4 severity | Policy YAML; gather.md §5 |
| Lake Alation ID: 7038345 | Alation search result; gather.md §7 |
| Redshift Dev Alation ID: 7038917 | Alation search result; gather.md §7 |
| Data Tier: 4 | Policy YAML; gather.md §5 |
| `customer_state_enum` valid values: intraday, merged, churned, reactivated, new, active | PySpark CASE statement; analyze.md do-not-claim list |
| No 'fraud' value in `customer_state_enum` | PySpark code; analyze.md §Do Not Claim List item 2 |
| 123 Reg override: `private_label_id = 587240` | PySpark source code; gather.md §4 |
| UK→GB country code normalization | PySpark source code; gather.md §4 |
| Internal shopper exclusion via `internal_shopper_flag` | PySpark source code; gather.md §4 |
| Composite PK `(partition_eval_mst_date, shopper_id)` (not `customer_id` alone) | DQ constraint; gather.md §5 conflict note |
| DAG SLA doc field = "N/A" is stale; authoritative SLA is lake registry | gather.md §11 conflict item |
| Tenure computed via `datediff/365`; `shopper_tenure` table is NOT a source | PySpark code; analyze.md do-not-claim list item 6 |
| 16 direct PySpark sources, 3 of which are intermediate tables | analyze.md Lineage Resolution Table |
| 21 depth-1 lake boundary sources enumerated in D1 | analyze.md Multi-Depth Lineage section |
| `customer_life_cycle_vw` is the lake-facing table; `customer_core_conformed.customer_life_cycle` is the internal Hive table | RESOLVED_TARGET.json evidence items 1–3 |
| A1 Database = "Redshift - Serverless - Dev" and Alation URL pointing to ID 7038917 | gather.md §7; BY DESIGN per validation instructions — not changed |

#### Issues Found and Fixed ✗→✓

| # | Location | Issue | Fix Applied |
|---|---|---|---|
| 1 | A3 `Initial Author` | Value `aghosh (2025-10-31)` is not present in gather.md, analyze.md, or any other source artifact. Claim is unverifiable and potentially fabricated. | Replaced with `REQUIRES_MANUAL_INPUT` |
| 2 | D2 `PySpark Script S3` | Path `s3://gd-{team}-{env}-dof-customers-pipeline-code/pyspark/...` uses placeholder tokens `{team}` and `{env}` that are not present in any source document. gather.md provides the output S3 path but not the script deployment path. | Replaced with `REQUIRES_MANUAL_INPUT` |
| 3 | D1 Downstream table `customer_life_cycle_vw_stg` Database column | Value `customer_core_conformed_prod` is not confirmed in any source. gather.md records the table as `customer_core_conformed.customer_life_cycle_vw_stg` (schema-qualified); the production Redshift database name is unverified. | Replaced with `REQUIRES_MANUAL_INPUT` |

---

### Step 2b: C1 Column Lineage Validation

**Result: PASS — No violations found.**

All 35 column lineage entries were inspected:

- **No `*_stg` references:** `customer_core_conformed.active_customer_stg` is NOT referenced in any C1 lineage entry. ✓
- **No `*_driver` references:** `customer_ttm_payment_driver` and `customer_active_subscription_detail_driver` are NOT referenced in any C1 lineage entry. ✓
- **No `*_conformed.*` intermediate references:** All lineage entries trace through to first lake boundary tables. ✓
- **No `analytic_local.*` references.** ✓
- All lineage entries reference: `analytic_feature.*`, `enterprise.*`, `finance360.*`, `ecomm_mart.*`, `dp_enterprise.*`, `customer360.*` (lake views), `customers.*`, `finance_cln.*` — all confirmed lake tables per analyze.md Lineage Resolution Table.
- Computed-only columns (`etl_build_mst_ts`, `partition_eval_mst_date`, `customer_state_enum`, `customer_acquisition_mst_month`) correctly describe transformation logic without referencing non-lake tables.

**C1 Column Structure:**
- Exactly 8 columns present: `#`, `Name`, `Data Type`, `Description`, `Column Lineage`, `Category`, `Sample Values`, `Key Statistics` — **PASS**
- No extra columns (`Source Table(s)`, `Transformation / Notes`, etc.) — **PASS**
- All 35 rows have a `Category` value from the allowed set (Identifier, Categorical, Date, Numeric, Boolean, Text, Amount, Timestamp, Array) — **PASS**
- `Sample Values` and `Key Statistics` columns are empty throughout — consistent with gather.md confirming "No column profiling data available" — **PASS**

---

### Step 2c: Structure Validation

| Check | Result |
|---|---|
| A1 includes Table ID | ✓ PASS (7038917) |
| A1 includes Type | ✓ PASS (TABLE) |
| A1 includes Description | ✓ PASS |
| A1 includes Lake Database | ✓ PASS (GoDaddy Central Data Lake (Prod)) |
| A1 includes Lake Alation ID | ✓ PASS (7038345) |
| A1 Redshift Serverless Dev fields preserved | ✓ PASS (BY DESIGN — not modified) |
| D1 multi-depth upstream tables | ✓ PASS (21 depth-1 lake boundary sources; depth-2 not derivable — documented) |
| D1 downstream tables present | ✓ PASS (2 managed + ad-hoc consumers) |
| D4 sub-section: ETL Processes | ✓ PASS |
| D4 sub-section: Data Processing Steps | ✓ PASS |
| D4 sub-section: Error Handling and Logging | ✓ PASS |
| D4 sub-section: Data Validation | ✓ PASS |
| REFERENCES section at end of document | ✓ PASS (20 URLs listed) |

---

### Step 3: Completeness Validation

**Total sections in document: 21** (A1–A3, B1–B3, C1–C8, D1–D4, E1–E3) plus REFERENCES — exceeds required 20.

| Section | Present | Notes |
|---|---|---|
| A1. Table Overview | ✓ | |
| A2. What This Table Is About | ✓ | |
| A3. Organizational Context & Ownership | ✓ | `Initial Author` fixed to REQUIRES_MANUAL_INPUT |
| B1. Key Business Value | ✓ | |
| B2. Primary Use Cases | ✓ | 10 Alation queries documented per gather.md §8 |
| B3. Advanced Analytics Use Cases | ✓ | |
| C1. Complete Column Reference | ✓ | 35 columns; all lineage validated |
| C2. Primary Key & Performance | ✓ | |
| C3. Key Features, Capabilities & Limitations | ✓ | |
| C4. Important Notes & Pitfalls | ✓ | |
| C5. Always-On Column Filters | ✓ | |
| C6. Common Business Metrics | ✓ | |
| C7. Glossary & Term Definitions | ✓ | |
| C8. Example Queries & Patterns | ✓ | 5 patterns |
| D1. Data Source Reference | ✓ | |
| D2. Data Pipeline & Infrastructure | ✓ | `PySpark Script S3` fixed to REQUIRES_MANUAL_INPUT |
| D3. SLA & Refresh Schedule | ✓ | |
| D4. Table Creation & ETL Implementation | ✓ | All 4 sub-sections present |
| E1. Data Quality Checks | ✓ | |
| E2. Best Practices & Tips | ✓ | |
| E3. Related Articles & Documentation | ✓ | |
| REFERENCES | ✓ | |

---

### Final Manual Input Required

The following fields in the published document are marked `REQUIRES_MANUAL_INPUT` and must be completed by a human with direct system access:

| # | Section | Field | Reason |
|---|---|---|---|
| 1 | A3 | Initial Author | Author identity not present in any gathered source artifact |
| 2 | D2 | PySpark Script S3 | Deployed script S3 bucket path not confirmed in source documents |
| 3 | D1 | `customer_life_cycle_vw_stg` Downstream Database | Production Redshift database name not confirmed (only schema `customer_core_conformed` is known) |


**The agent's final response to the user was:**
Validation complete. Here is a summary of what was done:

---

## Validation Summary — `customer360.customer_life_cycle_vw`

### Overall: PASS (accuracy) / PASS (completeness)

**Accuracy validation:** All non-trivial claims were cross-checked against `gather.md`, `analyze.md`, and `RESOLVED_TARGET.json`. Three unverified claims were found and fixed:

| # | Location | Issue | Fix |
|---|---|---|---|
| 1 | A3 `Initial Author` | `aghosh (2025-10-31)` not present in any source document | → `REQUIRES_MANUAL_INPUT` |
| 2 | D2 `PySpark Script S3` | Placeholder-format S3 path unverified in source docs | → `REQUIRES_MANUAL_INPUT` |
| 3 | D1 downstream `customer_life_cycle_vw_stg` Database | `customer_core_conformed_prod` not confirmed; gather.md only records schema | → `REQUIRES_MANUAL_INPUT` |

**C1 Column Lineage (critical check):** All 35 column lineage entries verified. Zero references to intermediate tables (`*_stg`, `*_driver`, `*_conformed.*`, `analytic_local.*`). All entries correctly trace to first lake boundary tables. Column structure is exactly the 8 required columns; all categories are from the allowed set; Sample Values and Key Statistics correctly empty (no Alation profiling data available).

**Structure:** All 21 sections present (A1–A3, B1–B3, C1–C8, D1–D4, E1–E3) plus REFERENCES — exceeds the required 20. D4 contains all 4 required sub-sections. A1 Redshift Serverless Dev fields preserved as designed.

**A1 Redshift Dev fields:** Not touched — `Database = "Redshift - Serverless - Dev"`, `Alation URL = /table/7038917/` preserved as BY DESIGN.

**Manual input required (3 fields):** A3 Initial Author, D2 PySpark Script S3, D1 downstream staging database name.