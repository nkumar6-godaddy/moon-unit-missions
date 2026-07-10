**Stage name:** generate
**The coding agent was given these instructions:** You are generating an **OSI-compliant semantic model** YAML file for a Data Lake table.
Your output must be 100% accurate. Never fabricate fields, relationships, or metrics.

Read `docs/osi-spec-reference.md` for the complete schema contract.

## Step 1: Read all prior artifacts
Read:
- `INPUT.md` — includes USER NOTES (HIGHEST PRIORITY after code) if provided
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `PROVENANCE.json` — machine-readable lineage and do-not-claim preservation contract

USER NOTES override Confluence/Alation — but NEVER override PySpark/DAG code.

## Step 2: Create SEMANTIC_MODEL.yaml
Create `SEMANTIC_MODEL.yaml` in the workspace root with this exact structure:

```yaml
version: "0.2.0.dev0"

semantic_model:
  - name: <from analyze.md or RESOLVED_TARGET.json>
    description: <business description>
    ai_context:
      instructions: <how AI should use this model>
      synonyms: [<terms>]
      examples: [<sample questions>]

    datasets:
      - name: <snake_case dataset name>
        source: <schema.table>
        primary_key: [<col(s)>]
        unique_keys:
          - [<col(s)>]
        description: <text>
        ai_context:
          synonyms: [<terms>]
        fields:
          - name: <field_name>
            expression:
              dialects:
                - dialect: ANSI_SQL
                  expression: <scalar_sql>
            dimension:
              is_time: true|false
            description: <text>
            ai_context:
              synonyms: [<terms>]

    relationships:
      - name: <rel_name>
        from: <many_side_dataset>
        to: <one_side_dataset>
        from_columns: [<fk_cols>]
        to_columns: [<pk_cols>]

    metrics:
      - name: <metric_name>
        expression:
          dialects:
            - dialect: ANSI_SQL
              expression: <aggregate_sql>
        description: <text>
        ai_context:
          synonyms: [<terms>]

    custom_extensions:
      - vendor_name: GODADDY
        data: |
          {
            "lake_table_path": "<path>",
            "pyspark_path": "<path>",
            "dag_name": "<name>",
            "refresh_cadence": "<cadence>",
            "pipeline_lineage": {
              "intermediate_tables": [],
              "transitive_sources": [],
              "materialized_direct_reads": [],
              "legacy_sources": []
            },
            "query_guards": {
              "grain": "<grain>",
              "partition_filter": "<col>",
              "primary_key_notes": "<notes>"
            }
          }
```

## Generation rules (non-negotiable)
1. Root must have `version: "0.2.0.dev0"` and `semantic_model` array
2. Use **ANSI_SQL** dialect only for all expressions
3. Field expressions are **scalar** (no SUM/COUNT/AVG)
4. Metric expressions use **aggregates** and may reference `dataset.column`
5. Dataset `source` values must be **lake tables only** (schema.table)
6. Include the target table AND all resolved upstream dimension tables
7. Every field needs `name`, `expression.dialects`, and `description` (if known)
8. Set `dimension.is_time: true` on date/timestamp/partition columns
9. Relationships must have matching column counts in from/to
10. Only include metrics with evidence from analyze.md
11. `custom_extensions.data` must be a JSON **string**, not nested YAML — use a
    YAML literal block scalar (`data: |`) with pretty-printed JSON at 2-space indent
    (not a single-line minified string)
12. Omit fields/relationships/metrics you cannot support with evidence
13. For every field listed in `PROVENANCE.json` → `transitive_sources` or
    `materialized_direct_reads`, append upstream provenance to the fact field
    `description` (e.g. "Derived from enterprise.dim_subscription_history via
    customer_active_subscription_detail_driver; not directly joinable")
14. For every entry in `PROVENANCE.json` → `array_fields`, document in the field
    `description` and mention the field (and any `scalar_proxy`) in
    `ai_context.instructions` — do not define metrics that unnest or aggregate arrays
15. Expand `custom_extensions.data` to include `pipeline_lineage` (intermediate_tables,
    transitive_sources, materialized_direct_reads, legacy_sources) and `query_guards`
    (grain, partition_filter, primary_key_notes) sourced from `PROVENANCE.json`
16. `ai_context.instructions` must include: grain, required partition filter,
    primary-key caveats, array-field warnings, and excluded join targets with guidance
    to use denormalized fact columns instead
17. Every item in `PROVENANCE.json` → `do_not_claim` must appear in at least one of:
    field `description`, `ai_context`, or `custom_extensions` — never as a dataset,
    relationship, or metric

## Step 3: Append summary to generate.md
Append:
- Semantic model name
- Dataset count (fact + dimensions)
- Field count per dataset
- Relationship count
- Metric count
- Provenance fields enriched (count and list)
- Do-not-claim items preserved (and where: description / ai_context / custom_extensions)
- Items omitted due to insufficient evidence
- Key sources used

**The agent summarized its work in this way:**

---

## Stage: generate — SEMANTIC_MODEL.yaml

**Generated:** 2026-06-10
**Model name:** `customer360_customer_life_cycle_analytics`
**Output file:** `SEMANTIC_MODEL.yaml`

---

### Dataset count: 3 (1 fact + 2 dimensions)

| Dataset | Role | Source | Field count |
|---|---|---|---|
| `customer_life_cycle_vw` | fact | `customer360.customer_life_cycle_vw` | 35 |
| `dim_customer_history` | dimension | `customer360.dim_customer_history_vw` | 33 |
| `dim_country` | dimension | `finance360.dim_country_vw` | 28 |

**Total fields across all datasets: 96**

---

### Relationship count: 2

| Name | From | To | From columns | To columns |
|---|---|---|---|---|
| `customer_life_cycle_to_dim_customer_history` | `customer_life_cycle_vw` | `dim_customer_history` | `[shopper_id]` | `[shopper_id]` |
| `customer_life_cycle_to_dim_country` | `customer_life_cycle_vw` | `dim_country` | `[customer_acquisition_country_code]` | `[country_code]` |

---

### Metric count: 5

| Metric | Expression |
|---|---|
| `total_ttm_gcr_usd_amt` | `SUM(customer_life_cycle_vw.ttm_gcr_usd_amt)` |
| `active_customer_count` | `COUNT(DISTINCT CASE WHEN active_status_flag = TRUE THEN shopper_id END)` |
| `avg_product_pnl_category_qty` | `AVG(customer_life_cycle_vw.product_pnl_category_qty)` |
| `avg_customer_tenure_years` | `AVG(customer_life_cycle_vw.customer_tenure_year_count)` |
| `churned_customer_count` | `COUNT(DISTINCT CASE WHEN customer_state_enum = 'churned' THEN shopper_id END)` |

---

### Provenance fields enriched: 24 total

**From transitive_sources (enterprise.dim_subscription_history via customer_active_subscription_detail_driver) — 5 fields:**
`active_paid_subscription_list`, `product_pnl_category_list`, `product_pnl_category_qty`, `product_pnl_line_list`, `brand_name_list`

**From materialized_direct_reads — 17 fields:**
- `analytic_feature.customer_type_history`: `customer_type_name`, `customer_type_reason_desc`
- `analytic_feature.shopper_merge`: `customer_merge_mst_date`
- `analytic_feature.shopper_acquisition`: `customer_acquisition_bill_id`, `customer_acquisition_mst_date`, `customer_acquisition_mst_month`
- `enterprise.dim_new_acquisition_shopper`: `customer_acquisition_country_code`, `customer_acquisition_country_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_domestic_international_name`
- `ecomm_mart.bill_line_traffic_ext`: `customer_acquisition_channel_name`
- `ecomm_mart.dim_bill_line_purchase_attribution`: `point_of_purchase_name`
- `finance360.dim_bill_fraud_history_vw`: `customer_acquisition_bill_fraud_flag`
- `dp_enterprise.dim_reseller`: `reseller_type_id`, `reseller_type_name`

**From excluded_dimensions (analytic_feature.customer_fraud) — 2 fields:**
`customer_fraud_flag`, `customer_fraud_mst_date`

---

### Do-not-claim items preserved: 16 total

| Item | Preserved as |
|---|---|
| `customer_core_conformed.active_customer_stg as OSI dataset` | `custom_extensions` (pipeline_lineage.intermediate_tables) |
| `customer_core_conformed.customer_ttm_payment_driver as OSI dataset` | `custom_extensions` (pipeline_lineage.intermediate_tables) |
| `customer_core_conformed.customer_active_subscription_detail_driver as OSI dataset` | `custom_extensions` (pipeline_lineage.intermediate_tables) |
| `analytic_feature.shopper_acquisition as OSI dataset` | `field_description` (customer_acquisition_bill_id, customer_acquisition_mst_date, customer_acquisition_mst_month) + `custom_extensions` (materialized_direct_reads) |
| `enterprise.dim_new_acquisition_shopper as OSI dataset` | `field_description` (country/region fields) + `custom_extensions` (materialized_direct_reads) |
| `analytic_feature.customer_type_history as OSI dataset` | `field_description` (customer_type_name, customer_type_reason_desc) + `custom_extensions` (materialized_direct_reads) |
| `analytic_feature.customer_fraud as OSI dataset` | `field_description` (customer_fraud_flag, customer_fraud_mst_date) + `custom_extensions` (excluded_dimensions) |
| `analytic_feature.shopper_merge as OSI dataset` | `field_description` (customer_merge_mst_date) + `custom_extensions` (materialized_direct_reads) |
| `dp_enterprise.dim_reseller as OSI dataset` | `field_description` (reseller_type_id, reseller_type_name) + `custom_extensions` (materialized_direct_reads) |
| `ecomm_mart.bill_line_traffic_ext as OSI dataset` | `custom_extensions` (materialized_direct_reads) |
| `ecomm_mart.dim_bill_line_purchase_attribution as OSI dataset` | `field_description` (point_of_purchase_name) + `custom_extensions` (materialized_direct_reads) |
| `finance360.dim_bill_fraud_history_vw as OSI dataset` | `field_description` (customer_acquisition_bill_fraud_flag) + `custom_extensions` (materialized_direct_reads) |
| `enterprise.dim_subscription_history as OSI dataset` | `custom_extensions` (pipeline_lineage.transitive_sources) |
| `array columns as OSI metric sources` | `field_description` (each array field documents Array<string> warning and scalar proxy) + `ai_context.instructions` (model-level) |
| `analytic_local.ads_bill_line_ext as OSI dataset or lineage source` | `custom_extensions` (pipeline_lineage.legacy_sources) |
| `lake table.yaml lineage tables absent from PySpark code (8 tables)` | `ai_context.instructions` (HISTORICAL NOTE section at model level) |

---

### Items omitted due to insufficient evidence

- No OSI relationship added for `analytic_feature.shopper_acquisition`, `enterprise.dim_new_acquisition_shopper`, `analytic_feature.customer_type_history`, `analytic_feature.customer_fraud`, `analytic_feature.shopper_merge`, `dp_enterprise.dim_reseller`, `ecomm_mart.bill_line_traffic_ext`, `ecomm_mart.dim_bill_line_purchase_attribution`, `finance360.dim_bill_fraud_history_vw` — all are materialized direct-reads or excluded dimensions with no dedicated FK column on the fact.
- `enterprise.dim_subscription_history` not included as OSI dataset — transitive source via unresolved intermediate driver; data in array fields unsuitable for OSI FK relationships.
- No metrics defined for array fields (`active_paid_subscription_list`, `product_pnl_category_list`, `product_pnl_line_list`, `ttm_all_bill_list`, `brand_name_list`) — array<string> type not compatible with ANSI SQL scalar aggregation.
- Lake `table.yaml` lineage tables not present in current PySpark code (`customers.customer_id_mapping_snapshot`, `enterprise.dim_bill_shopper_id_xref`, `enterprise.fact_bill_line`, `enterprise.fact_entitlement_bill`, `ecomm_mart.entitlement_bill_type`, `finance360.dim_product_vw`, `finance_cln.manual_paid_subscription`, `enterprise.dim_entitlement_history`) — excluded per source-of-truth rule; preserved in `ai_context.instructions`.

---

### Key sources used

| Source | Usage |
|---|---|
| `customer360/customer-metrics/src/pyspark/customer_life_cycle.py` | Primary source of truth for all fields, joins, aggregations, write target |
| `customer360/customer-metrics/src/dag/customer_life_cycle_dag.py` | DAG schedule, EMR config, task flow |
| `customer360/customer-metrics/src/ddls/customer_life_cycle.ddl` | Column names and types for fact table |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl` | Lake view schema (OSI source) |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml` | SLA, data tier, partition key, permissions |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl` | dim_customer_history field schema |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/finance360/dim-country-vw/table.ddl` | dim_country field schema |
| `src/data_quality/constraints/customer_life_cycle.json` | Authoritative PK: (partition_eval_mst_date, shopper_id) |
| `PROVENANCE.json` | Lineage contracts: intermediate tables, transitive sources, materialized direct reads, excluded dimensions, array fields, legacy sources, do_not_claim |
| `RESOLVED_TARGET.json` | OSI source confirmation: customer360.customer_life_cycle_vw |
| Alation (table ID 7038345) | Column confirmation, SLA, business description |
| Confluence (BI/pages/3779199819) | Business context, deprecated datasets list |

**The agent's final response to the user was:**
`SEMANTIC_MODEL.yaml` has been written and `generate.md` has been updated.

Here is a summary of what was produced:

---

## SEMANTIC_MODEL.yaml — Summary

**Model:** `customer360_customer_life_cycle_analytics`

### Datasets: 3
| Dataset | Role | Source | Fields |
|---|---|---|---|
| `customer_life_cycle_vw` | fact | `customer360.customer_life_cycle_vw` | 35 |
| `dim_customer_history` | dimension | `customer360.dim_customer_history_vw` | 33 |
| `dim_country` | dimension | `finance360.dim_country_vw` | 28 |

**96 fields total** across all datasets, all with scalar ANSI_SQL expressions.

### Relationships: 2
1. `customer_life_cycle_to_dim_customer_history` — `shopper_id → shopper_id` (SCD2; ai_context notes point-in-time filter requirement)
2. `customer_life_cycle_to_dim_country` — `customer_acquisition_country_code → country_code`

### Metrics: 5 (all evidence-backed)
`total_ttm_gcr_usd_amt`, `active_customer_count`, `avg_product_pnl_category_qty`, `avg_customer_tenure_years`, `churned_customer_count`

### Provenance fields enriched: 24
All fields derived from materialized direct-reads, transitive sources, and excluded dimensions have upstream provenance noted in their `description`.

### Do-not-claim items preserved: 16/16
Every item from `PROVENANCE.json → do_not_claim` appears in at least one of `field_description`, `ai_context.instructions`, or `custom_extensions` — none appear as OSI datasets, relationships, or metrics.

### Key design decisions
- **3 intermediate tables** (`active_customer_stg`, `customer_ttm_payment_driver`, `customer_active_subscription_detail_driver`) recorded in `custom_extensions.pipeline_lineage.intermediate_tables` only — not as OSI datasets
- **5 array fields** documented with Array<string> warnings and scalar proxy guidance in both field descriptions and model-level `ai_context.instructions`
- **Legacy S3 path** (`analytic_local.ads_bill_line_ext`) recorded in `custom_extensions.pipeline_lineage.legacy_sources`
- **`custom_extensions.data`** is a JSON literal block scalar (`|`) with full provenance from `PROVENANCE.json` including `pipeline_lineage` and `query_guards`