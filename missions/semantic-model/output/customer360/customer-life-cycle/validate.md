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

## Validation Report — customer360_customer_life_cycle_analytics

**Validated:** 2026-06-10
**Validator:** OSI Semantic Model Validation Agent (validate stage)
**SEMANTIC_MODEL.yaml lines:** 1196

---

### Validation Results

| Check | Result |
|---|---|
| Structural | **PASS** |
| Reference | **PASS** |
| Accuracy | **PASS** |
| Provenance | **PASS** |

---

### Step 2: Structural Validation — PASS

| Rule | Result | Notes |
|---|---|---|
| Root `version: "0.2.0.dev0"` | ✅ | Line 1 |
| Root `semantic_model` array | ✅ | Line 3, 1 model entry |
| Model has `name` | ✅ | `customer360_customer_life_cycle_analytics` |
| Model has `datasets` (min 1) | ✅ | 3 datasets |
| Each dataset has `name` and `source` | ✅ | All 3 datasets |
| Each field has `name` + `expression.dialects` (ANSI_SQL, min 1) | ✅ | All 96 fields pass |
| Each metric has `name` + `expression.dialects` (min 1) | ✅ | All 5 metrics pass |
| Each relationship has `name`, `from`, `to`, `from_columns`, `to_columns` | ✅ | Both relationships |
| `len(from_columns) == len(to_columns)` | ✅ | Both [1] == [1] |
| Field expressions are scalar (no SUM/COUNT/AVG/MIN/MAX) | ✅ | All 96 field expressions are bare column references |
| Metric expressions contain aggregates | ✅ | SUM, COUNT(DISTINCT), AVG used correctly |
| Names unique within scope | ✅ | Datasets, fields per dataset, metrics, relationships all unique |
| `custom_extensions.data` is valid JSON string | ✅ | Literal block scalar parses as valid JSON; all keys verified |

No structural issues found. No fixes required.

---

### Step 3: Reference Validation — PASS

| Check | Result | Details |
|---|---|---|
| `customer_life_cycle_to_dim_customer_history.from` = `customer_life_cycle_vw` | ✅ | Dataset exists |
| `customer_life_cycle_to_dim_customer_history.to` = `dim_customer_history` | ✅ | Dataset exists |
| `from_columns: [shopper_id]` exists in `customer_life_cycle_vw` | ✅ | Field confirmed |
| `to_columns: [shopper_id]` exists in `dim_customer_history` | ✅ | Field confirmed |
| `customer_life_cycle_to_dim_country.from` = `customer_life_cycle_vw` | ✅ | Dataset exists |
| `customer_life_cycle_to_dim_country.to` = `dim_country` | ✅ | Dataset exists |
| `from_columns: [customer_acquisition_country_code]` exists in `customer_life_cycle_vw` | ✅ | Field confirmed |
| `to_columns: [country_code]` exists in `dim_country` | ✅ | Field confirmed |
| Dataset sources are lake tables | ✅ | All 3 sources confirmed in `repos/lake/catalog/config/prod/` |
| `customer_life_cycle_vw` PK fields exist: `[shopper_id, partition_eval_mst_date]` | ✅ | Both fields present |
| `dim_customer_history` PK field exists: `[customer_id]` | ✅ | Field present |
| `dim_country` PK field exists: `[country_code]` | ✅ | Field present |
| No intermediate/staging tables as dataset sources | ✅ | `active_customer_stg`, `customer_ttm_payment_driver`, `customer_active_subscription_detail_driver` all absent from dataset sources |

No reference issues found. No fixes required.

---

### Step 4: Accuracy Validation — PASS

Evidence verified for all entries:

| Entry | Evidence Source |
|---|---|
| `customer_life_cycle_vw` dataset | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/` confirmed in analyze.md §Step 3 |
| `dim_customer_history` dataset | `dlms-api/us-west-2/customer360/dim-customer-history-vw/` confirmed in analyze.md §Step 3 |
| `dim_country` dataset | `dlms-api/us-west-2/finance360/dim-country-vw/` confirmed in analyze.md §Step 3 |
| All 35 `customer_life_cycle_vw` fields | Lake DDL `table.ddl` + Alation (35 columns); gather.md §4 |
| All 33 `dim_customer_history` fields | Lake DDL; analyze.md §Step 6 |
| All 28 `dim_country` fields | Lake DDL; analyze.md §Step 6 |
| Both relationships | gather.md §6 join conditions confirmed in analyze.md §Step 5 |
| `total_ttm_gcr_usd_amt` | gather.md §7: `SUM(ttm_total_gcr_usd_amt)` from `customer_ttm_payment_driver`; Alation TTM GCR feature |
| `active_customer_count` | gather.md §7: `active_status_flag` derived from `active_prev`/`active_curr` MAX flags; Confluence SSOT |
| `avg_product_pnl_category_qty` | gather.md §7: `COUNT(DISTINCT product_pnl_category)` from subscription driver |
| `avg_customer_tenure_years` | gather.md §7: `CAST(DATEDIFF(...) / 365 AS INT)` |
| `churned_customer_count` | gather.md §7: `customer_state_enum = 'churned'`; Alation lifecycle tracking |
| Model description (SSOT, replaces legacy datasets) | Confluence; gather.md §9 |
| `customer_state_enum` 6-value caveat (active, new, churned, merged, reactivated, intraday) | gather.md conflict note; PySpark code is authoritative |

No fabricated entries detected. No accuracy fixes required.

Items reviewed for evidence and retained:
- `customer_state_enum` description mentions 6 values (code-authoritative) vs 4 in DDL comment — correctly documented
- `customer_id` nullable PK caveat — confirmed by DQ constraint vs lake DDL conflict (gather.md conflict #1)
- UK→GB normalization note in `customer_life_cycle_to_dim_country` ai_context — confirmed in PySpark code (gather.md §1)

---

### Step 5: Completeness Check — PASS

| Check | Result |
|---|---|
| Target table `customer_life_cycle_vw` present | ✅ |
| `dim_customer_history` (key SCD2 dim) included | ✅ |
| `dim_country` (country enrichment dim) included | ✅ |
| Other lake tables correctly omitted (no FK) | ✅ — 8 tables classified as materialized direct-reads |
| `analytic_feature.customer_fraud` correctly excluded | ✅ — composite join on PK columns; no dedicated FK |
| Time dimensions have `is_time: true` | ✅ — 8 time fields in fact; 9 in dim_customer_history; 2 in dim_country |
| At least one metric | ✅ — 5 metrics |

---

### Step 5b: Provenance Validation — PASS

| Check | Result |
|---|---|
| `PROVENANCE.json` exists | ✅ |
| `custom_extensions.data` parses as valid JSON | ✅ |
| `pipeline_lineage` object present (intermediate tables exist) | ✅ |
| `pipeline_lineage.intermediate_tables` matches PROVENANCE.json | ✅ — all 3 tables present |
| `pipeline_lineage.transitive_sources` matches PROVENANCE.json | ✅ — `enterprise.dim_subscription_history` with all 5 materialized fields |
| `pipeline_lineage.materialized_direct_reads` matches PROVENANCE.json | ✅ — all 8 tables with correct field lists |
| All transitive/materialized fields have descriptions mentioning upstream source | ✅ — verified field-by-field (see list below) |
| No `do_not_claim` items appear as dataset sources | ✅ — all 16 do-not-claim entries verified absent from dataset sources |
| No `do_not_claim` items appear as relationship endpoints | ✅ |
| No `do_not_claim` items appear in metric expressions | ✅ |
| Array fields absent from metric expressions | ✅ — `active_paid_subscription_list`, `product_pnl_category_list`, `product_pnl_line_list`, `ttm_all_bill_list`, `brand_name_list` not referenced in any metric |
| `ai_context.instructions` includes grain from `query_guards` | ✅ — "GRAIN: one row per (shopper_id, partition_eval_mst_date)" |
| `ai_context.instructions` includes partition_filter from `query_guards` | ✅ — "PARTITION FILTER REQUIRED: always include a predicate on partition_eval_mst_date" |
| `ai_context.instructions` includes PK caveats from `query_guards` | ✅ — "PRIMARY KEY CAVEATS: enforced composite PK is (partition_eval_mst_date, shopper_id); customer_id may be null..." |

No provenance issues found. No in-place fixes required.

---

### Provenance Fields Enriched

All 26 fields below already had provenance descriptions in the generated YAML (no additional enrichment was required):

**Transitive source fields** (via `enterprise.dim_subscription_history` → `customer_active_subscription_detail_driver`):
1. `active_paid_subscription_list`
2. `product_pnl_category_list`
3. `product_pnl_category_qty`
4. `product_pnl_line_list`
5. `brand_name_list`

**Materialized direct-read fields**:
6. `customer_type_name` (analytic_feature.customer_type_history)
7. `customer_type_reason_desc` (analytic_feature.customer_type_history)
8. `customer_merge_mst_date` (analytic_feature.shopper_merge)
9. `customer_acquisition_bill_id` (analytic_feature.shopper_acquisition)
10. `customer_acquisition_mst_date` (analytic_feature.shopper_acquisition)
11. `customer_acquisition_mst_month` (analytic_feature.shopper_acquisition)
12. `customer_acquisition_country_code` (enterprise.dim_new_acquisition_shopper)
13. `customer_acquisition_country_name` (enterprise.dim_new_acquisition_shopper)
14. `customer_region_1_name` (enterprise.dim_new_acquisition_shopper)
15. `customer_region_2_name` (enterprise.dim_new_acquisition_shopper)
16. `customer_region_3_name` (enterprise.dim_new_acquisition_shopper)
17. `customer_domestic_international_name` (enterprise.dim_new_acquisition_shopper)
18. `customer_acquisition_channel_name` (ecomm_mart.bill_line_traffic_ext)
19. `point_of_purchase_name` (ecomm_mart.dim_bill_line_purchase_attribution)
20. `customer_acquisition_bill_fraud_flag` (finance360.dim_bill_fraud_history_vw)
21. `reseller_type_id` (dp_enterprise.dim_reseller)
22. `reseller_type_name` (dp_enterprise.dim_reseller)

**Intermediate driver-sourced fields**:
23. `ttm_all_bill_list` (customer_core_conformed.customer_ttm_payment_driver)
24. `ttm_gcr_usd_amt` (customer_core_conformed.customer_ttm_payment_driver)

**Excluded-dimension fields** (analytic_feature.customer_fraud — no FK):
25. `customer_fraud_flag`
26. `customer_fraud_mst_date`

---

### Issues Found and Fixed

**No issues requiring fixes were found.** The SEMANTIC_MODEL.yaml was structurally valid, internally consistent, and accurately represented by the source artifacts.

---

### Items Removed Due to Lack of Evidence

**None.** No items were removed. All datasets, fields, relationships, and metrics had clear evidence from lake DDL, PySpark code (gather.md), or Alation/Confluence documentation.

---

### Final Counts

| Category | Count |
|---|---|
| Semantic models | 1 |
| Datasets | 3 |
| Fields (total across all datasets) | 96 |
| — customer_life_cycle_vw (fact) | 35 |
| — dim_customer_history (dimension) | 33 |
| — dim_country (dimension) | 28 |
| Relationships | 2 |
| Metrics | 5 |
| Custom extension vendor blocks | 1 (GODADDY) |
| Provenance fields with upstream source in description | 26 |
| Do-not-claim items verified absent | 16 |


**The agent's final response to the user was:**
The validation is complete. Here is a summary of what was done:

---

## Validation Summary — `customer360_customer_life_cycle_analytics`

All four validation checks **PASSED**. No fixes were required to `SEMANTIC_MODEL.yaml`.

### Structural — PASS
- Root has `version: "0.2.0.dev0"` and `semantic_model` array ✅
- All 3 datasets have `name` + `source`; all 96 fields have `name` + `expression.dialects` (ANSI_SQL) ✅
- All 5 metrics have aggregate expressions; no field expression contains an aggregate ✅
- Both relationships have matching column counts ([1] == [1]); all required keys present ✅
- `custom_extensions.data` is a valid JSON literal block scalar ✅

### Reference — PASS
- Both relationship `from`/`to` names resolve to existing dataset names ✅
- All relationship columns (`shopper_id`, `customer_acquisition_country_code`, `country_code`) confirmed as fields on their respective datasets ✅
- All 3 dataset sources are confirmed lake tables (not staging/intermediate) ✅
- All declared primary keys exist as fields ✅

### Accuracy — PASS
- All fields traceable to lake DDL or PySpark evidence from gather.md/analyze.md ✅
- No fabricated descriptions or invented column names ✅
- All 5 metrics backed by gather.md §7 aggregation evidence ✅

### Provenance — PASS
- `PROVENANCE.json` exists and `custom_extensions.data` contains matching `pipeline_lineage` ✅
- All 26 provenance-tracked fields have descriptions mentioning their upstream source ✅
- All 16 `do_not_claim` items are absent from dataset sources, relationship endpoints, and metric expressions ✅
- All 5 array fields excluded from metric expressions ✅
- `ai_context.instructions` includes grain, partition filter, and PK caveats ✅

**Final counts: 3 datasets | 96 fields | 2 relationships | 5 metrics**