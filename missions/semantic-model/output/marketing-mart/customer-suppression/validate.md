**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent for an OSI semantic model. Your job is to ensure
`SEMANTIC_MODEL.yaml` is:
1) structurally valid per OSI spec v0.2.0.dev0
2) accurate (no fabricated content)
3) internally consistent (relationships, names, column references)

Read `docs/osi-spec-reference.md` for the validation checklist.

## Step 1: Read all artifacts
Read:
- `INPUT.md`
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `PROVENANCE.json`
- `SEMANTIC_MODEL.yaml`

## Step 2: Structural validation
Verify against OSI spec:
- Root has `version: "0.2.0.dev0"` and `semantic_model` array
- Each model has `name` and `datasets` (min 1)
- Each dataset has `name` and `source`
- Each field has `name` and `expression.dialects` (min 1, dialect ANSI_SQL)
- Each metric has `name` and `expression.dialects` (min 1)
- Each relationship has `name`, `from`, `to`, `from_columns`, `to_columns`
- `len(from_columns) == len(to_columns)` for each relationship
- Field expressions contain no aggregates (SUM/COUNT/AVG/MIN/MAX)
- Metric expressions contain aggregates
- All names unique within scope
- `custom_extensions.data` values are valid JSON strings

Fix any structural issues in-place in `SEMANTIC_MODEL.yaml`.

## Step 3: Reference validation
- Relationship `from`/`to` must reference existing dataset names
- Relationship columns should exist as fields in the respective datasets
- Dataset sources must be lake tables (not intermediate/staging tables)
- Primary keys should exist as fields in the dataset

## Step 4: Accuracy validation
For each dataset, field, relationship, and metric:
- Identify evidence source (PySpark line, DDL, analyze.md)
- Remove or fix any entry without evidence
- Ensure descriptions match source material (not invented)

## Step 5: Completeness check
- Target table must be present as a dataset
- Key dimension tables from analyze.md should be included (or noted as omitted)
- Time dimensions should have `is_time: true`
- At least one metric if analyze.md identified any

## Step 5b: Provenance validation
Using `PROVENANCE.json` and `docs/osi-spec-reference.md`:
- `PROVENANCE.json` exists; `custom_extensions.data` parses as valid JSON
- When `PROVENANCE.json` lists intermediate or transitive tables,
  `custom_extensions.data` must contain a `pipeline_lineage` object
- Every field in `transitive_sources[].materialized_in_fields` and
  `materialized_direct_reads[].materialized_in_fields` has a matching fact field
  whose `description` mentions the upstream table or pipeline (fix in-place if missing)
- No item from `do_not_claim` appears as a dataset `source`, relationship endpoint,
  or metric expression
- Fields listed in `array_fields` are not referenced in metric expressions
- `ai_context.instructions` includes grain, partition filter, and PK caveats from
  `query_guards`
Fix any missing provenance in-place in `SEMANTIC_MODEL.yaml`.

## Step 6: Append report to validate.md
Append:
- Semantic model name
- PASS/FAIL for structural, reference, accuracy, and **provenance** validation
- Provenance fields enriched (list)
- Issues found and how they were fixed
- Items removed due to lack of evidence
- Final counts: datasets, fields, relationships, metrics

**The agent summarized its work in this way:**

---

## Validation Report — marketing_mart_customer_suppression

**Date:** 2026-06-29
**Semantic model name:** `marketing_mart_customer_suppression`

### Validation Results

| Check | Result |
|-------|--------|
| Structural validation | **PASS** |
| Reference validation | **PASS** |
| Accuracy validation | **PASS** |
| Provenance validation | **PASS** |

---

### Step 2: Structural Validation Detail

- `version: "0.2.0.dev0"` — present at root ✅
- `semantic_model` array with one model (`marketing_mart_customer_suppression`) ✅
- Model has `name` and `datasets` (3 datasets, all with `name` and `source`) ✅
- All 63 fields have `name` and `expression.dialects` with at least one `ANSI_SQL` entry ✅
- No metrics present (analyze.md found none; no aggregate expressions to check) ✅
- Two relationships each have `name`, `from`, `to`, `from_columns`, `to_columns` ✅
- `len(from_columns) == len(to_columns)` = 1 == 1 for both relationships ✅
- All field expressions are scalar (no SUM/COUNT/AVG/MIN/MAX) ✅
- Dataset names unique within model: customer_suppression, customer, dim_customer_vw ✅
- Field names unique within each dataset ✅
- Relationship names unique within model ✅
- `custom_extensions.data` is a YAML literal block scalar (`|`) containing valid JSON (all keys/values confirmed syntactically correct; `null`, integer, array, and object values all valid) ✅

---

### Step 3: Reference Validation Detail

- `customer_suppression_to_customer`: `from=customer_suppression` ✅, `to=customer` ✅, `from_columns=[customer_id]` exists on fact ✅, `to_columns=[customer_id]` exists on customer dataset ✅
- `customer_suppression_to_dim_customer_vw`: `from=customer_suppression` ✅, `to=dim_customer_vw` ✅, `from_columns=[shopper_id]` exists on fact ✅, `to_columns=[shopper_id]` exists on dim_customer_vw ✅
- Dataset sources verified against lake catalog:
  - `marketing_mart.customer_suppression` → `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.ddl` ✅
  - `marketing_mart.customer` → `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer/table.ddl` ✅
  - `customer360.dim_customer_vw` → `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/table.ddl` ✅
- No intermediate/staging table sources ✅
- Primary keys exist as fields in all datasets: `customer_id` in customer_suppression ✅, `customer_id` in customer ✅, `customer_id` in dim_customer_vw ✅

---

### Step 4: Accuracy Validation Detail

DDL column counts cross-checked against semantic model field counts:
- `customer_suppression`: 11 DDL columns = 11 semantic model fields (exact match) ✅
- `customer`: 23 DDL columns = 23 semantic model fields (exact match) ✅
- `dim_customer_vw`: 29 DDL columns = 29 semantic model fields (exact match) ✅

Key field descriptions verified against evidence:
- `internal_account_flag` — sourced from `customer360.dim_customer_vw.internal_shopper_flag` via shopper_id join (PySpark ETL confirmed) ✅
- `private_label_13_suppression_flag` — sourced from `cust_customertracking.shopper_crossover_cln.pool_13_active_flag` (PySpark + PROVENANCE.json) ✅
- `restricted_country_flag` — sourced from `ecomm_cln.gdshop_blocked_country_cln` + `gdshop_blocked_country_region_cln` (PySpark + PROVENANCE.json) ✅
- `excluded_email_flag` — ALWAYS NULL (NULL AS excluded_email_flag in PySpark; FortKnox not wired), accurately documented ✅
- `bad_email_address_format_flag` — ALWAYS NULL (same reason), accurately documented ✅
- `email_address_hard_bounced_flag` / `email_address_soft_bounced_flag` — multi-source ETL derivation from bouncesystem/SFMC/OEG/OCM chain, accurately documented with unresolved upstream sources noted ✅
- `competitor_email_flag` — email domain tokenization logic from PySpark, accurately documented ✅
- `etl_build_mst_ts` — `FROM_UTC_TIMESTAMP(CURRENT_TIMESTAMP(), 'MST')` at ETL run time ✅
- No fabricated field names, descriptions, or sources found

---

### Step 5: Completeness Check

- Target table `marketing_mart.customer_suppression` is present as the fact dataset ✅
- Both key dimension tables identified in analyze.md are included: `customer` (fact driving list) and `dim_customer_vw` (internal_account_flag source) ✅
- Time dimensions with `is_time: true`:
  - `customer_suppression.etl_build_mst_ts` ✅
  - `customer.account_create_mst_ts`, `customer.etl_build_mst_ts` ✅
  - `dim_customer_vw.created_mst_ts`, `.updated_mst_ts`, `.closed_mst_ts`, `.deleted_mst_ts`, `.etl_build_mst_ts` ✅
- No metrics needed — analyze.md found zero aggregation metrics; no COUNT/SUM/AVG expressions to add ✅

---

### Step 5b: Provenance Validation Detail

- `PROVENANCE.json` exists ✅
- `custom_extensions.data` is valid JSON ✅
- `PROVENANCE.json.intermediate_tables = []` and `transitive_sources = []` → no transitive pipeline lineage required; `pipeline_lineage` object is present in custom_extensions with correct empty arrays ✅
- `materialized_direct_reads` fields confirmed:
  - `ecomm_cln.gdshop_blocked_country_cln` → `restricted_country_flag.description` contains "ecomm_cln.gdshop_blocked_country_cln" ✅
  - `ecomm_cln.gdshop_blocked_country_region_cln` → `restricted_country_flag.description` contains "ecomm_cln.gdshop_blocked_country_region_cln" ✅
- `do_not_claim` items — none appear as dataset `source`, relationship endpoint, or metric expression:
  - `signals_platform_cln.oeg_email_event_send_cln` — not a dataset source ✅
  - `signals_platform_cln.oeg_email_event_open_cln` — not a dataset source ✅
  - `signals_platform_cln.profile_audit_lake_cln_v2` — not a dataset source ✅
  - `marketing_mart_local.customer_suppression_history` — not a dataset source ✅
  - `cust_customertracking.shopper_crossover_cln` — not a dataset source ✅
  - `marketing_bouncesystem.*`, `sfmc_email_events_cln.*`, `emailsystem.oc_*` — not dataset sources ✅
  - `terrorist_country_flag` — not an OSI field ✅
  - `fortknox.tdaemailattributes_snap` — not a dataset or metric expression ✅
- `array_fields = []` → no array field constraints to verify ✅
- `ai_context.instructions` contains all three `query_guards` caveats:
  - GRAIN: "One row per customer_id (LATEST_SNAPSHOT; full replacement each daily run)" ✅
  - PARTITION FILTER: "This table has no partition column. No partition filter is required or available." ✅
  - PRIMARY KEY: "customer_id (UUID string) is the unique key on the fact. shopper_id is also present on the fact but is NOT unique — one shopper may have multiple customer_ids." ✅

---

### Provenance Fields Enriched (in-place fixes)

None required — all `materialized_direct_reads[].materialized_in_fields` already had matching fact field descriptions mentioning the upstream table. No provenance gaps found.

---

### Issues Found and Fixed

None. The SEMANTIC_MODEL.yaml was valid as generated.

---

### Items Removed Due to Lack of Evidence

None removed. All datasets, fields, relationships, and descriptions had verifiable evidence from DDL, PySpark ETL code, PROVENANCE.json, and/or analyze.md.

---

### Final Counts

| Object | Count |
|--------|-------|
| Datasets | 3 (customer_suppression, customer, dim_customer_vw) |
| Fields — customer_suppression | 11 |
| Fields — customer | 23 |
| Fields — dim_customer_vw | 29 |
| Fields — total | 63 |
| Relationships | 2 |
| Metrics | 0 |


**The agent's final response to the user was:**
The validation is complete. Here is a summary of what was done and found:

---

## Validation Summary — `marketing_mart_customer_suppression`

All four validation categories **PASS** with no fixes required.

### Structural Validation — PASS
- Root has `version: "0.2.0.dev0"` and `semantic_model` array ✅
- All 3 datasets have `name` and `source`; all 63 fields have `name` + `expression.dialects` (ANSI_SQL) ✅
- All field expressions are scalar (no aggregates) ✅
- Both relationships have `name`, `from`, `to`, `from_columns`, `to_columns` with matching column-count ✅
- `custom_extensions.data` is valid JSON (YAML `|` literal block) ✅
- All names unique within scope ✅

### Reference Validation — PASS
- Both relationship `from`/`to` reference existing dataset names ✅
- Relationship join columns (`customer_id`, `shopper_id`) exist as fields on both sides ✅
- All 3 dataset sources confirmed as registered lake tables in `repos/lake/` ✅
- Primary keys exist as fields in each dataset ✅

### Accuracy Validation — PASS
- DDL column counts exactly match semantic model field counts: 11/11 (fact), 23/23 (`customer`), 29/29 (`dim_customer_vw`) ✅
- All field descriptions match evidence from DDL, PySpark ETL, and PROVENANCE.json — no fabricated content found ✅

### Provenance Validation — PASS
- `materialized_direct_reads` fields (`restricted_country_flag`) already mention both upstream tables in their description ✅
- All `do_not_claim` items absent from dataset sources, relationships, and metric expressions ✅
- `ai_context.instructions` covers grain, partition filter, and PK caveats per `query_guards` ✅

**No changes were made to `SEMANTIC_MODEL.yaml`** — it was already fully valid.