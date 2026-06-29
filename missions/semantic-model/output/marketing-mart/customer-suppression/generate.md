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

## Stage: generate — SEMANTIC_MODEL.yaml Summary
**Date:** 2026-06-29
**Output file:** `SEMANTIC_MODEL.yaml`

### Semantic Model
- **Name:** `marketing_mart_customer_suppression`
- **OSI spec version:** `0.2.0.dev0`
- **Description:** Daily snapshot of GoDaddy customer marketing suppression flags

### Dataset Count: 3 (1 fact + 2 dimensions)

| Dataset | Role | Source | Field Count |
|---|---|---|---|
| `customer_suppression` | fact | `marketing_mart.customer_suppression` | 11 |
| `customer` | dimension | `marketing_mart.customer` | 23 |
| `dim_customer_vw` | dimension | `customer360.dim_customer_vw` | 29 |

**Total fields:** 63

### Relationship Count: 2

| Name | From | To | Join Columns |
|---|---|---|---|
| `customer_suppression_to_customer` | `customer_suppression` | `customer` | `customer_id` → `customer_id` |
| `customer_suppression_to_dim_customer_vw` | `customer_suppression` | `dim_customer_vw` | `shopper_id` → `shopper_id` |

### Metric Count: 0
No metrics included. Evidence reviewed:
- Alation: 0 saved queries found (num_queries = 0)
- Confluence: Business descriptions only; no metric formulas
- PySpark aggregations: All are internal ETL computations (intermediate CTEs) to produce boolean flags, not user-facing analytical metrics

### Provenance Fields Enriched: 5

| Field | Enrichment |
|---|---|
| `restricted_country_flag` | Upstream provenance from `ecomm_cln.gdshop_blocked_country_cln` + `ecomm_cln.gdshop_blocked_country_region_cln` documented; join path via `marketing_mart.customer`; not directly joinable from fact |
| `internal_account_flag` | Source documented as `customer360.dim_customer_vw.internal_shopper_flag`; join path and filter conditions (current_record_flag=TRUE, temporary_shopper_flag=FALSE) noted |
| `private_label_13_suppression_flag` | Source documented as `cust_customertracking.shopper_crossover_cln.pool_13_active_flag`; do-not-join warning added |
| `email_address_hard_bounced_flag` | All contributing source tables listed; UNRESOLVED signals_platform_cln tables explicitly called out in description |
| `email_address_soft_bounced_flag` | All contributing source tables listed; UNRESOLVED signals_platform_cln tables explicitly called out; 180-day/3-event thresholds documented |

### Do-Not-Claim Items: 10 (all preserved)

| Item | Preserved In |
|---|---|
| `signals_platform_cln.oeg_email_event_send_cln as OSI dataset` | `custom_extensions`, `email_address_hard_bounced_flag.description`, `email_address_soft_bounced_flag.description`, `ai_context.instructions` |
| `signals_platform_cln.oeg_email_event_open_cln as OSI dataset` | `custom_extensions`, `email_address_hard_bounced_flag.description`, `email_address_soft_bounced_flag.description`, `ai_context.instructions` |
| `signals_platform_cln.profile_audit_lake_cln_v2 as OSI dataset` | `custom_extensions`, `email_address_hard_bounced_flag.description`, `email_address_soft_bounced_flag.description`, `ai_context.instructions` |
| `marketing_mart_local.customer_suppression_history as OSI dataset` | `custom_extensions` |
| `excluded_email_flag as reliable boolean indicator` | `excluded_email_flag.description` (marked ALWAYS NULL; FortKnox not wired) |
| `bad_email_address_format_flag as reliable boolean indicator` | `bad_email_address_format_flag.description` (marked ALWAYS NULL; FortKnox not wired) |
| `cust_customertracking.shopper_crossover_cln as OSI dimension dataset` | `custom_extensions`, `private_label_13_suppression_flag.description` |
| `marketing_bouncesystem.*, sfmc_email_events_cln.*, emailsystem.oc_* as OSI dimension datasets` | `custom_extensions`, bounce flag `field_description`, `ai_context.instructions` |
| `terrorist_country_flag as OSI field` | `ai_context.instructions`, `restricted_country_flag.description` |
| `fortknox.tdaemailattributes_snap as OSI dataset or bounce source` | `ai_context.instructions`, `excluded_email_flag.description`, `bad_email_address_format_flag.description` |

### Items Omitted Due to Insufficient Evidence
- **Metrics:** None included — no Alation saved queries, no Confluence metric formulas; all PySpark aggregations are internal ETL computations
- **No fields fabricated** — all fields sourced from lake DDL (`table.ddl`) and verified against PySpark output columns

### Key Sources Used
| Source | Role |
|---|---|
| `repos/dps-customermarketing/customer/eds-customer-suppression/src/pyspark/customer_suppression.py` | Source of truth for ETL logic, field definitions, business rules |
| `repos/dps-customermarketing/customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` | DAG schedule, dependencies, cadence |
| `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.ddl` | Authoritative lake schema |
| `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.yaml` | SLA, tier, table type |
| `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer/table.ddl` | customer dimension schema |
| `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/table.ddl` | dim_customer_vw schema (Iceberg) |
| `RESOLVED_TARGET.json` | Confirmed target coordinates |
| `PROVENANCE.json` | Materialized direct reads, do-not-claim contract, query guards |
| `analyze.md` | Dataset classification, relationships, field inventory |
| Confluence pages 10370826 + 3114766874 | Business context, legacy design reference |
| Alation table ID 6619866 | Table metadata, stewards; 0 saved queries |

**The agent's final response to the user was:**
`SEMANTIC_MODEL.yaml` has been written and `generate.md` has been updated. Here is a summary of what was produced:

---

## SEMANTIC_MODEL.yaml — Complete

**Spec version:** `0.2.0.dev0`
**Model name:** `marketing_mart_customer_suppression`

### Datasets (3)
| Dataset | Role | Source | Fields |
|---|---|---|---|
| `customer_suppression` | fact | `marketing_mart.customer_suppression` | 11 |
| `customer` | dimension | `marketing_mart.customer` | 23 |
| `dim_customer_vw` | dimension | `customer360.dim_customer_vw` | 29 |

### Relationships (2)
- `customer_suppression_to_customer` — on `customer_id`
- `customer_suppression_to_dim_customer_vw` — on `shopper_id`

### Metrics: 0
No evidence from Alation (0 saved queries) or Confluence; all PySpark aggregations are internal ETL computations.

### Provenance enrichment (5 fields)
`restricted_country_flag`, `internal_account_flag`, `private_label_13_suppression_flag`, `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` — all have upstream source tables, materialization paths, and join-guard notes in their descriptions.

### Do-not-claim preservation (all 10 items)
- 3 UNRESOLVED signals_platform_cln tables → `custom_extensions` + bounce flag `field_description` + `ai_context.instructions`
- `customer_suppression_history` → `custom_extensions`
- `excluded_email_flag` / `bad_email_address_format_flag` as reliable indicators → `field_description` (marked **ALWAYS NULL**, FortKnox not wired)
- `shopper_crossover_cln` as OSI dimension → `custom_extensions` + `private_label_13_suppression_flag.description`
- bouncesystem/SFMC/emailsystem tables as OSI dimensions → `custom_extensions` + bounce flag descriptions + `ai_context.instructions`
- `terrorist_country_flag` → `ai_context.instructions` + `restricted_country_flag.description`
- `fortknox.tdaemailattributes_snap` → `ai_context.instructions` + null-flag descriptions