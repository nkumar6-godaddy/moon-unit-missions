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

## Validation Report — 2026-06-17

**Target table:** `customer360.customer_metric_daily_agg_vw`

---

### Accuracy: PASS (after 2 fixes)
### Completeness: PASS

---

### Issues Found & Fixed

#### Issue 1 — A1: Unconfirmed ZSTD compression (FALSE CLAIM → FIXED)
- **Location:** A1 Table Overview, `Storage Format` row
- **Original value:** `Parquet (ZSTD compression)`
- **Problem:** No source artifact (gather.md, analyze.md, Hive DDL, lake registry table.yaml, PySpark code) mentions ZSTD compression. The Hive DDL says `STORED AS PARQUET` with no compression clause. Lake registry says "Parquet, PARTITIONED" with no compression qualifier.
- **Fix applied:** Changed to `Parquet` (compression qualifier removed).
- **Evidence:** gather.md — "Storage | Parquet, PARTITIONED"; Hive DDL — "STORED AS PARQUET".

#### Issue 2 — C2: Inaccurate PK annotation count (INACCURATE COUNT → FIXED)
- **Location:** C2 Primary Key & Performance, note about lake registry DDL
- **Original text:** `annotates only 16 of these 19 columns as @PrimaryKey — it is missing point_of_purchase_name and customer_acquisition_bill_fraud_flag`
- **Problem:** The evidence confirms exactly 2 columns are missing annotations (`point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`), meaning 17 of 19 are annotated — not 16. The "only 16" count was not supported by any source artifact.
- **Fix applied:** Replaced with `is missing @PrimaryKey annotations for point_of_purchase_name and customer_acquisition_bill_fraud_flag` (removed unsupported numeric count).
- **Evidence:** gather.md Conflicts table, row #3 — "Lake table.ddl does NOT annotate point_of_purchase_name or customer_acquisition_bill_fraud_flag as @PrimaryKey".

---

### Validation Checks — All Passed

| Check | Result | Evidence |
|---|---|---|
| A1 Redshift Serverless Dev fields preserved (BY DESIGN) | PASS | Database = "Redshift - Serverless - Dev", ID = 7038918, URL /table/7038918/ — unchanged |
| A1 Table ID, Type, Description, Lake Database, Lake Alation ID present | PASS | All present; sourced from gather.md Alation section |
| Grain claim accurate | PASS | "One row per evaluation date × 18 reporting dimensions" — confirmed by 19-column DQ constraint (partition_eval_mst_date + 18 dims) in data_quality/constraints/customer_metric_daily_agg.json |
| 19-column composite PK | PASS | Confirmed by gather.md DQ constraints JSON listing all 19 column names |
| C1 column lineage — no staging/conformed/local table references | PASS | All 32 C1 entries reference `customer_life_cycle_vw` (a registered lake table in repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/) or are derived from intermediate computations |
| C1 column headers: exactly #, Name, Data Type, Description, Column Lineage, Category, Sample Values, Key Statistics | PASS | Header row confirmed; no extra columns (no "Source Table(s)" or "Transformation / Notes") |
| C1 Category values from allowed set | PASS | All 32 rows use one of: Categorical, Date, Numeric, Boolean, Text, Amount, Timestamp, Array |
| C1 Sample Values and Key Statistics empty | PASS | All empty — consistent with gather.md: "Column profiling data: Not retrieved (v1/table API returned permission error)" |
| SLA claim sourced | PASS | "Delivery by 08:00 AM MST daily" — lake registry table.yaml: "SLA delivery | By 08:00 AM MST daily (cron(00 15 * * ? *) UTC)" |
| Schedule claim sourced | PASS | `30 7 * * *` — DAG: "Schedule | 30 7 * * * (7:30 AM MST daily)" |
| Data Tier 4 sourced | PASS | lake registry table.yaml: "Data tier | 4" |
| UK→GB normalization documented | PASS | gather.md Conflict #5: "PySpark applies WHEN UPPER(customer_country_code) = 'UK' THEN 'GB'" |
| data_source_enum = 'customer360' sourced | PASS | gather.md: "outputs data_source_enum string ('customer360' hardcoded)" |
| Legacy DAC replacement claim sourced | PASS | USER NOTES (highest priority) |
| D1 multi-depth upstream/downstream tables present | PASS | Depth-1 (1 upstream), Depth-2 (20 upstream), Depth-1 (4 downstream) — all present; sourced from analyze.md lineage resolution |
| D4 sub-sections: ETL Processes, Data Processing Steps, Error Handling and Logging, Data Validation | PASS | All 4 sub-sections present with substantive content |
| REFERENCES section present at end | PASS | Present; includes table identifiers, Confluence, Alation tables+queries, GitHub links |
| All 21 sections present (A1–A3, B1–B3, C1–C8, D1–D4, E1–E3) | PASS | 21 named sections confirmed; all exceed minimum content threshold |
| Column lineage claims reference only lake tables or derived computations | PASS | `customer360.customer_life_cycle_vw` is the sole external source; confirmed in repos/lake/ |
| Metric computations accurate | PASS | ending=COUNT_IF(active_status_flag), churn=COUNT_IF(churn_date IS NOT NULL), net_move formula — all confirmed by analyze.md column mapping |
| Downstream tables appropriately caveated as analyst-created, not confirmed lake tables | PASS | D1 downstream section includes "(Analyst-created materialized/sandbox tables observed in Alation queries; not confirmed lake-registered tables)" |

---

### Sections Requiring Manual Input (Final List)

| Location | Marker | Description |
|---|---|---|
| D3 / C4 note #7 | `REQUIRES_MANUAL_INPUT: DE` | **SLA discrepancy:** DAG `documentation_markdown` states `SLA: N/A`, but lake registry specifies delivery by 08:00 AM MST and policies.yaml defines `maxDurationMins: 120, severity: TIER_4`. A Data Engineering owner should update the DAG documentation to reconcile and confirm the operative SLA. |
| C3 Limitations | (soft claim) | `legacyLookBackEnabled: true` is set in the lake registry but the depth of available historical backfill is not specified in any source artifact. |

---

### Notes on A1 (By Design)

The A1 primary entry intentionally uses the Redshift Serverless Dev identity (`Database = "Redshift - Serverless - Dev"`, `Table ID = 7038918`, `Alation URL = /table/7038918/`) as the primary access identity per stage instructions. The Lake table identity is captured in the Lake Table Name / Lake Database / Lake Alation URL / Lake Alation ID rows immediately below. This structure was preserved without modification.


**The agent's final response to the user was:**
Validation complete. Here is a summary of what was done:

---

## Validation Summary

**Target:** `customer360.customer_metric_daily_agg_vw`
**Accuracy:** PASS (after 2 fixes)
**Completeness:** PASS (21 sections present, all populated)

### Fixes Applied to TABLE_METADATA.md

**Fix 1 — A1 Storage Format (false claim removed)**
- `Parquet (ZSTD compression)` → `Parquet`
- ZSTD is not mentioned in any source: not in the Hive DDL, not in the lake registry `table.yaml`, not in gather.md, not in analyze.md.

**Fix 2 — C2 PK annotation count (inaccurate number corrected)**
- `annotates only 16 of these 19 columns as @PrimaryKey` → `is missing @PrimaryKey annotations for point_of_purchase_name and customer_acquisition_bill_fraud_flag`
- Evidence confirms exactly 2 columns are missing from the lake DDL annotations (19 − 2 = 17 annotated, not 16).

### All Other Claims: Verified

- Grain, 19-column PK, SLA, schedule, data tier, UK→GB normalization, metric computations, legacy DAC replacement — all sourced to PySpark/DAG/lake registry artifacts.
- All 32 C1 column lineage entries reference `customer360.customer_life_cycle_vw` (a confirmed lake table) or are derived — no staging/conformed/local table references.
- C1 structure: exact 8-column header, valid categories, empty Sample Values/Key Statistics.
- D4 has all 4 required sub-sections; D1 has multi-depth upstream/downstream tables; REFERENCES section present.

### Sections Requiring Manual Input

1. **D3/C4 (marked `REQUIRES_MANUAL_INPUT: DE`)** — SLA discrepancy: DAG says "N/A" vs. lake registry/policies.yaml specifying 08:00 AM MST / 120 min / TIER_4.
2. **C3** (soft) — `legacyLookBackEnabled: true` historical backfill depth unspecified in source artifacts.