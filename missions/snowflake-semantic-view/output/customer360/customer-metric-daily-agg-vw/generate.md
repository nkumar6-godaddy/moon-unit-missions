**Stage name:** generate
**The coding agent was given these instructions:** You are generating a **Snowflake Semantic View YAML** for a Data Lake table.
Your output must be 100% accurate. Never fabricate fields, relationships, or metrics.

Read `docs/snowflake-spec-reference.md` for the complete Snowflake schema contract.

## Step 1: Read all prior artifacts
Read:
- `INPUT.md` — includes USER NOTES (HIGHEST PRIORITY after code) if provided
- `research.md` — contains gathered facts (Part A) and analysis (Part B)
- `RESOLVED_TARGET.json`
- `PROVENANCE.json` — lineage preservation contract

USER NOTES override Confluence/Alation — but NEVER override PySpark/DAG code.

## Step 2: Create SNOWFLAKE_SEMANTIC_VIEW.yaml
Create `SNOWFLAKE_SEMANTIC_VIEW.yaml` in the workspace root following this structure:

```yaml
name: <from RESOLVED_TARGET.json semantic_view_name>
description: <business description>

tables:
  - name: <logical_table_name>
    description: <text>
    base_table:
      database: <from RESOLVED_TARGET.json snowflake_database>
      schema: <schema>
      table: <table_name>
    dimensions:
      - name: <column_name>
        description: "<business meaning>. <lineage + transformation details>"
        expr: <scalar_sql_expression>
        data_type: <SNOWFLAKE_TYPE>
        synonyms: [<terms>]
    time_dimensions:
      - name: <column_name>
        description: "<business meaning>. <lineage + transformation details>"
        expr: <scalar_sql_expression>
        data_type: <SNOWFLAKE_TYPE>
    facts:
      - name: <column_name>
        description: "<business meaning>. <lineage + transformation details>"
        expr: <scalar_sql_expression>
        data_type: <SNOWFLAKE_TYPE>
    metrics:
      - name: <metric_name>
        description: <text>
        expr: <aggregate_sql_expression>

relationships:
  - name: <rel_name>
    left_table: <logical_table_name>
    right_table: <logical_table_name>
    relationship_columns:
      - left_column: <column>
        right_column: <column>

verified_queries:
  - name: <query_name>
    question: <natural_language_question>
    sql: |
      <sql_query>

custom_instructions: |
  <grain, partition filter, PK caveats, array-field warnings, excluded joins>
```

## Generation rules (non-negotiable)
1. `expr` is a plain SQL expression string — no dialect wrappers
2. Dimension/time_dimension/fact `expr` values are **scalar** (no SUM/COUNT/AVG)
3. Metric `expr` values use **aggregates** (SUM/COUNT/AVG/MIN/MAX)
4. `base_table` uses the `snowflake_database` from RESOLVED_TARGET.json
5. Include the target table AND all resolved upstream dimension tables
6. Every dimension/time_dimension/fact `description` MUST include:
   - Business meaning of the column
   - Source lake table.column it is derived from
   - Transformation logic (joins, CASE, COALESCE, casts, etc.)
   This is the DETAILED INLINE format (C1-style). Example:
   "Country code where customer was acquired. From
   enterprise.dim_new_acquisition_shopper.bill_country_code, uppercased with
   UK→GB normalization applied in ETL"
7. Relationships must reference existing table names
8. Only include metrics with evidence from research.md
9. `verified_queries` sourced from Alation saved queries in research.md
10. `custom_instructions` must include: grain, required partition filter,
    primary-key caveats, array-field warnings, and excluded join targets
11. Omit fields/relationships/metrics you cannot support with evidence
12. For every field listed in `PROVENANCE.json` → `transitive_sources` or
    `materialized_direct_reads`, append upstream provenance to the field
    `description` (e.g. "Derived from enterprise.dim_subscription_history via
    customer_active_subscription_detail_driver; not directly joinable")
13. For every entry in `PROVENANCE.json` → `array_fields`, document in the
    field `description` and mention in `custom_instructions` — do not define
    metrics that unnest or aggregate arrays
14. Every item in `PROVENANCE.json` → `do_not_claim` must NOT appear as a
    table, relationship, or metric — preserve info in `custom_instructions`
15. `data_type` values must be valid Snowflake types (VARCHAR, NUMBER, DATE, etc.)

## Step 3: Append summary to generate.md
Append:
- Semantic view name
- Table count (fact + dimensions)
- Column count per table (dimensions + time_dimensions + facts)
- Relationship count
- Metric count
- Verified query count
- Provenance fields enriched (count and list)
- Do-not-claim items preserved in custom_instructions
- Items omitted due to insufficient evidence
- Key sources used

**The agent summarized its work in this way:**

---

## Generate Stage Summary

### Output: SNOWFLAKE_SEMANTIC_VIEW.yaml

**Semantic view name:** `customer360_customer_metric_daily_agg`

**Table count:** 1 logical table (`customer_metric_daily_agg`)
- Base table: `MARKETING_CORE_DEV.customer360.customer_metric_daily_agg_vw`
- No upstream dimension lookup tables (single-source aggregation pipeline; no joins)

**Column count for `customer_metric_daily_agg`:**
- Dimensions: 20
  (`customer_type_reason_desc`, `customer_acquisition_mst_month`,
  `customer_domestic_international_name`, `customer_region_1_name`,
  `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`,
  `customer_country_code`, `customer_type_name`, `acquisition_channel_name`,
  `customer_tenure_year_count`, `product_ownership_category_list`,
  `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`,
  `brand_name_list`, `ttm_gcr_segment_enum`, `point_of_purchase_name`,
  `customer_acquisition_bill_fraud_flag`, `data_source_enum`)
- Time dimensions: 2 (`partition_eval_mst_date`, `etl_build_mst_ts`)
- Facts: 11
  (`product_category_qty`, `ttm_gcr_usd_amt`, `ending_customer_qty`,
  `churn_customer_qty`, `merge_customer_qty`, `new_customer_qty`,
  `reactivate_customer_qty`, `beginning_customer_qty`, `net_move_qty`,
  `net_add_qty`, `net_churn_qty`)
- **Total columns: 33**

**Relationship count:** 0
- Source pipeline reads from a single table with no joins; no Snowflake
  relationships defined.

**Metric count:** 11
(`total_ending_customer_qty`, `total_new_customer_qty`,
`total_churn_customer_qty`, `total_reactivate_customer_qty`,
`total_merge_customer_qty`, `total_beginning_customer_qty`,
`total_net_move_qty`, `total_net_add_qty`, `total_net_churn_qty`,
`total_ttm_gcr_usd_amt`, `total_product_category_qty`)
- Evidence: all metrics are direct SUM() aggregations of pre-aggregated fact
  columns whose computation is visible in PySpark `get_customer_metrics_daily_agg()`
  and `get_local_spark_config_dict()` SQL.

**Verified query count:** 0
- Alation returned 5 saved queries (table ID 7038346) but all had empty titles
  and SQL bodies. No usable queries available per research.md B5. Section
  omitted per rule 11.

**Provenance fields enriched:** 33 / 33 (100%)
- All 33 fields include upstream provenance statement referencing
  `customer360.customer_life_cycle_vw` (materialized via
  `customer_core_conformed.customer_life_cycle` staging; not directly joinable).
- Source per PROVENANCE.json `transitive_sources` and `materialized_direct_reads`.
- Array fields `product_ownership_category_list`, `product_ownership_line_list`,
  `brand_name_list` have extended ARRAY WARNING documentation per rule 13.

**Do-not-claim items preserved in custom_instructions (8 items):**
1. `daily_metrics` — Spark session-scoped temp view
2. `candidates_next_day` — Spark session-scoped temp view
3. `missing_next_day` — Spark session-scoped temp view
4. `daily_metrics_union` — Spark session-scoped temp view
5. `daily_metrics_last_day` — Spark session-scoped temp view
6. `customer360.customer_metric_monthly_agg` — downstream consumer, not a source
7. `customer_metric_daily_agg_vw_stg` (Redshift) — Redshift intermediate; not a lake table
8. `customer_mart.daily_active_customers` — backfill DAG only; not in primary pipeline

**Items omitted due to insufficient evidence:**
- `verified_queries` section: Alation queries had empty SQL (confirmed in research.md B5)
- `relationships` section: No joins in primary pipeline (confirmed by PySpark code inspection)
- No array-unnesting or array-aggregation metrics (per rule 13; array fields
  are string-encoded in the output table)

**Key sources used:**
- `repos/dof-dpaas-customer-feature/customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py`
  — authoritative source for column definitions, transformation logic, GROUP BY
  grain, metric computation expressions, carry-forward logic, and UK→GB normalization
- `repos/dof-dpaas-customer-feature/customer360/customer-metrics/dags/customer_metric_daily_agg_dag.py`
  — lake table name confirmation, DAG schedule, SuccessNotificationOperator
- `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl`
  — Snowflake-compatible column list, data types, DDL comments (@PrimaryKey annotations)
- `RESOLVED_TARGET.json` — Snowflake database (MARKETING_CORE_DEV), schema (customer360),
  table (customer_metric_daily_agg_vw), semantic view name
- `PROVENANCE.json` — grain definition, composite PK notes, array field list,
  do-not-claim list, transitive sources, intermediate tables
- `research.md` Part B — grain, column analysis, DDL discrepancy notes,
  Alation query status, Confluence business context

**Key decisions:**
- `partition_eval_mst_date` stored as VARCHAR in lake; expr uses
  `TRY_TO_DATE(partition_eval_mst_date)` with `data_type: DATE` for time
  dimension semantics in Cortex Analyst.
- `customer_tenure_year_count` classified as dimension (not fact): used as
  GROUP BY key in PySpark; integer categorical cohort grouping.
- `ttm_gcr_segment_enum` included as dimension (GROUP BY position 20 in PySpark
  SQL confirms it is a grouping key, not a derived-only field).
- `data_source_enum` included as dimension: hardcoded literal in primary pipeline;
  meaningful for filtering legacy vs. current data.
- `fraud_flag` and `customer_acquisition_bill_fraud_flag` marked with
  `labels: [filter]` (BOOLEAN dimensions usable as WHERE clause filters).
- DDL discrepancy (point_of_purchase_name and customer_acquisition_bill_fraud_flag
  not @PrimaryKey in DDL but PK per DQ constraint) documented in both column
  descriptions and custom_instructions; DQ constraint treated as authoritative.

**The agent's final response to the user was:**
`SNOWFLAKE_SEMANTIC_VIEW.yaml` has been written and `generate.md` has been updated. Here is a summary of what was produced:

---

## SNOWFLAKE_SEMANTIC_VIEW.yaml — Generation Summary

**Semantic view name:** `customer360_customer_metric_daily_agg`

**Base table:** `MARKETING_CORE_DEV.customer360.customer_metric_daily_agg_vw`

### Column inventory (1 logical table, 33 total columns)

| Category | Count | Notes |
|---|---|---|
| Dimensions | 20 | 19 PK segment dimensions + `data_source_enum` |
| Time dimensions | 2 | `partition_eval_mst_date` (partition key), `etl_build_mst_ts` |
| Facts | 11 | Pre-aggregated customer movement counts + GCR amount |
| Metrics | 11 | All `SUM()` aggregations of facts; evidenced from PySpark code |
| Relationships | 0 | Single-source pipeline; no joins |
| Verified queries | 0 | Alation queries had empty SQL (documented in research.md B5) |

### Key decisions

- **`partition_eval_mst_date`** stored as VARCHAR in lake; `expr: TRY_TO_DATE(partition_eval_mst_date)` used to give it DATE semantics for Cortex Analyst time-based filtering
- **Array fields** (`product_ownership_category_list`, `product_ownership_line_list`, `brand_name_list`): documented as string-encoded sorted arrays in every field description and in `custom_instructions` with LIKE-based query guidance; no array-unnesting metrics defined per rule 13
- **DDL discrepancy**: `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag` are not annotated `@PrimaryKey` in lake DDL but ARE part of the composite PK per DQ constraint — documented in descriptions and `custom_instructions`
- **8 do-not-claim items** (temp Spark views, downstream table, Redshift staging, legacy backfill source) all preserved in `custom_instructions`
- **UK→GB normalization** for `customer_country_code` documented in description
- Every field description includes source column reference, COALESCE/CASE transformation, and transitive provenance to `customer360.customer_life_cycle_vw`