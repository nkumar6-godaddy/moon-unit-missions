**Stage name:** analyze
**The coding agent was given these instructions:** You are a Data Engineering analyst mapping a PySpark ETL job to an OSI semantic model.
Your job is to resolve lineage, classify tables, extract relationships and metrics,
and produce a structured analysis for OSI YAML generation.

Read `docs/osi-spec-reference.md` in the workspace for the OSI schema contract.

## Step 1: Read INPUT.md and gather.md
- Read `INPUT.md` and `gather.md`.
- If INPUT.md contains USER NOTES, factor them into your analysis (expert-provided,
  priority over Confluence/Alation text).

## Step 2: Identify the target table
Determine the final output lake table populated by this PySpark job.
- Prefer direct evidence in code: write targets, insertInto, saveAsTable, etc.
- If `lake_table_override` is provided, use it only if it does not contradict code.
- Record grain (what one row represents) with evidence.

## Step 3: Deep lineage resolution — MANDATORY for EVERY source table
For EACH table referenced in the PySpark:
1. Check if it exists as a lake table in `repos/lake/catalog/config/prod/`.
   Try both `us-west-2/<schema>/<table-hyphenated>/` and
   `dlms-api/us-west-2/<schema>/<table-hyphenated>/`.
2. If NOT a lake table, recursively trace upstream PySpark scripts until you reach
   a lake table or external system.
3. If traversal fails: record `UNRESOLVED: <table> — <reason>`

**CRITICAL:** OSI dataset `source` values must be lake tables only (schema.table form).
Never use intermediate/staging tables as dataset sources.

## Step 4: Classify datasets (fact vs dimension)
For each resolved lake table included in the semantic model:
- **Target table** = primary fact dataset (the table this PySpark populates)
- **Upstream tables joined TO** = dimension datasets
- Record classification with evidence (join direction in PySpark)

## Step 5: Extract relationships
From PySpark join conditions in gather.md:
- Map each join to an OSI relationship: `from` (many side) → `to` (one side)
- Record `from_columns` and `to_columns` with matching order
- Name relationships descriptively (e.g., `orders_to_customers`)

## Step 6: Map fields for each dataset
For each dataset, list fields from lake `table.ddl`:
- Column name → OSI field name (use snake_case)
- Scalar expression (column reference or computed scalar)
- `dimension.is_time: true` for date/timestamp/partition date columns
- Description from DDL comments, Alation, or Confluence (if available)
- Candidate synonyms for `ai_context` from business docs

## Step 7: Identify metrics
From PySpark aggregations, Alation queries, and Confluence docs:
- Name each metric (snake_case)
- ANSI_SQL aggregate expression (may reference `dataset.column`)
- Description and synonyms
- Only include metrics with evidence — do not invent

## Step 8: Determine semantic model metadata
- Model name: use `semantic_model_name` from INPUT.md if provided, else derive from
  schema + table (e.g., `customer360_customer_life_cycle_analytics`)
- Model description: from Confluence, Alation, or code comments
- ai_context: instructions, synonyms, example questions the model answers

## Step 9: Output (append to analyze.md)
Append:
- Target table resolution with evidence
- Lineage resolution table (intermediate → lake)
- **Dataset classification table**: | Lake Table | OSI Dataset Name | Role (fact/dim) | source | primary_key |
- **Materialized direct-reads table**: | Lake Table | materialized_in_fields | evidence | — lake tables read by the PySpark job whose values are fully denormalized onto the fact (no join key back to source)
- **Excluded dimensions table**: | Lake Table | reason | fields_on_fact | — direct-read lake tables NOT included as OSI datasets (e.g. no FK in fact)
- **Relationship table**: | name | from | to | from_columns | to_columns | evidence |
- **Field inventory per dataset**: columns, types, is_time, descriptions
- **Metrics table**: | name | expression | description | evidence |
- **Semantic model metadata**: name, description, ai_context draft
- **Do-not-claim table**: | item | reason | preserve_as | — items that must NOT become OSI datasets, relationships, or metrics; `preserve_as` is one or more of: `field_description`, `ai_context`, `custom_extensions`

## Step 10: Write RESOLVED_TARGET.json (required)
Create `RESOLVED_TARGET.json` in workspace root:
```json
{
  "schema": "customer360",
  "table_hyphen": "customer-life-cycle-vw",
  "table_underscore": "customer_life_cycle_vw",
  "lake_table_path": "customer360/customer-life-cycle-vw",
  "semantic_model_name": "customer360_customer_life_cycle_analytics",
  "confidence": "high",
  "evidence": ["file/line references"]
}
```

## Step 11: Write PROVENANCE.json (required)
Create `PROVENANCE.json` in workspace root. This is the machine-readable contract for
preserving do-not-claim lineage in the OSI YAML without adding non-joinable datasets.
See `docs/osi-spec-reference.md` for the GODADDY custom_extensions schema.

```json
{
  "grain": "one row per (shopper_id, partition_eval_mst_date)",
  "primary_key_notes": "Composite PK; customer_id is not unique and may be null",
  "partition_filter": "partition_eval_mst_date",
  "intermediate_tables": [
    {
      "table": "customer_core_conformed.active_customer_stg",
      "role": "staging",
      "upstream_pyspark": "customer360/active-customer/src/pyspark/active_customer_stg.py"
    }
  ],
  "transitive_sources": [
    {
      "table": "enterprise.dim_subscription_history",
      "via": "customer_core_conformed.customer_active_subscription_detail_driver",
      "materialized_in_fields": ["active_paid_subscription_list"]
    }
  ],
  "materialized_direct_reads": [
    {
      "table": "analytic_feature.customer_type_history",
      "materialized_in_fields": ["customer_type_name", "customer_type_reason_desc"]
    }
  ],
  "excluded_dimensions": [
    {
      "table": "analytic_feature.customer_fraud",
      "reason": "no_join_key_in_fact",
      "fields_on_fact": ["customer_fraud_flag", "customer_fraud_mst_date"]
    }
  ],
  "array_fields": [
    {
      "field": "active_paid_subscription_list",
      "scalar_proxy": "product_pnl_category_qty",
      "note": "not suitable for OSI aggregate metrics; use scalar proxy fields instead"
    }
  ],
  "legacy_sources": [
    {
      "path": "s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/",
      "equivalent": "ecomm_mart.bill_line_traffic_ext",
      "condition": "pre-2022-08 partitions only"
    }
  ],
  "do_not_claim": [
    {
      "item": "customer_core_conformed.active_customer_stg as OSI dataset",
      "reason": "intermediate staging table not in lake catalog",
      "preserve_as": "custom_extensions"
    }
  ]
}
```

Use empty arrays `[]` for sections with no entries. Every do-not-claim item from Step 9
must appear in `do_not_claim` with a `preserve_as` value.

**The agent summarized its work in this way:**

---

## Analyze Stage — customer360_customer_life_cycle_analytics

**Analyzed:** 2026-06-10
**Analyst:** OSI Semantic Model Mapping (analyze stage)

---

### Step 2: Target Table Resolution

| Field | Value | Evidence |
|---|---|---|
| Hive write target | `customer_core_conformed.customer_life_cycle` | gather.md §1: `insertInto` with `overwrite=True`; PySpark `TABLE_NAME = "customer_life_cycle"`, `DATABASE_NAME = "customer_core_conformed"` |
| Lake notification target | `customer360.customer_life_cycle_vw` | gather.md §1: `SuccessNotificationOperator` triggers lake API for `customer360.customer_life_cycle_vw` |
| **OSI source (lake table)** | **`customer360.customer_life_cycle_vw`** | Lake catalog confirmed at `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/` |
| Grain | One row per `(shopper_id, partition_eval_mst_date)` | gather.md §4 (DDL), §8 (DQ constraint): PK check on `(partition_eval_mst_date, shopper_id)` |
| Partition key | `partition_eval_mst_date` (string) | Lake table.yaml; PySpark `repartition(30)` + dynamic overwrite |
| No `lake_table_override` provided | — | INPUT.md: `Lake table override (optional):` is blank |

**Note on lake DDL conflict:** The lake `table.ddl` marks `customer_id` as `@PrimaryKey` and `shopper_id` as `@UniqueKey`, but the DQ constraint file confirms the actual enforced PK is `(partition_eval_mst_date, shopper_id)`. Using DQ-confirmed PK for OSI.

---

### Step 3: Lineage Resolution

| Source Table | Lake Catalog Found | Path | Classification |
|---|---|---|---|
| `customer_core_conformed.active_customer_stg` | NO | — | Intermediate staging table |
| `customer_core_conformed.customer_ttm_payment_driver` | NO | — | Driver/intermediate table |
| `customer_core_conformed.customer_active_subscription_detail_driver` | NO | — | Driver/intermediate table |
| `analytic_feature.shopper_acquisition` | YES | `us-west-2/analytic-feature/shopper-acquisition/` | Lake table |
| `analytic_feature.customer_type_history` | YES | `us-west-2/analytic-feature/customer-type-history/` | Lake table |
| `analytic_feature.customer_fraud` | YES | `us-west-2/analytic-feature/customer-fraud/` | Lake table |
| `analytic_feature.shopper_merge` | YES | `us-west-2/analytic-feature/shopper-merge/` | Lake table |
| `customer360.dim_customer_history_vw` | YES | `dlms-api/us-west-2/customer360/dim-customer-history-vw/` | Lake table (Iceberg SCD2) |
| `finance360.dim_country_vw` | YES | `dlms-api/us-west-2/finance360/dim-country-vw/` | Lake table (SCD2) |
| `finance360.dim_bill_fraud_history_vw` | YES | `dlms-api/us-west-2/finance360/dim-bill-fraud-history-vw/` | Lake table |
| `dp_enterprise.dim_reseller` | YES | `us-west-2/dp-enterprise/dim-reseller/` | Lake table |
| `enterprise.dim_new_acquisition_shopper` | YES | `us-west-2/enterprise/dim-new-acquisition-shopper/` | Lake table |
| `enterprise.dim_subscription_history` | YES | `us-west-2/enterprise/dim-subscription-history/` | Lake table |
| `ecomm_mart.bill_line_traffic_ext` | YES | `us-west-2/ecomm-mart/bill-line-traffic-ext/` | Lake table |
| `ecomm_mart.dim_bill_line_purchase_attribution` | YES | `us-west-2/ecomm-mart/dim-bill-line-purchase-attribution/` | Lake table |
| `analytic_local.ads_bill_line_ext` | UNRESOLVED | — | Legacy S3 hardcoded path (`s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/`); no lake catalog entry; treated as pre-2022-08 equivalent of `ecomm_mart.bill_line_traffic_ext` |

---

### Step 4: Dataset Classification

| Lake Table | OSI Dataset Name | Role | source | primary_key |
|---|---|---|---|---|
| `customer360.customer_life_cycle_vw` | `customer_life_cycle_vw` | **fact** | `customer360.customer_life_cycle_vw` | `[shopper_id, partition_eval_mst_date]` |
| `customer360.dim_customer_history_vw` | `dim_customer_history` | **dimension** | `customer360.dim_customer_history_vw` | `[customer_id]` (surrogate); joined via `shopper_id` |
| `finance360.dim_country_vw` | `dim_country` | **dimension** | `finance360.dim_country_vw` | `[country_code]` |

**Evidence for dim inclusion:**
- `dim_customer_history_vw`: joined via `shopper_id` (SCD2 with effective_start/end date range); provides rich customer profile attributes (location, federation, account flags) NOT on the fact. Join key `shopper_id` is present on the fact.
- `dim_country_vw`: joined via `customer_acquisition_country_code` → `country_code`; provides additional attributes (ISO codes, EU flag, marketing/finance regions, tier) beyond what is materialized onto the fact. Dedicated FK column `customer_acquisition_country_code` exists on the fact.

---

### Step 4b: Materialized Direct-Reads Table

Lake tables read by PySpark whose values are **fully denormalized** onto the fact (no usable FK back to source PK in the fact).

| Lake Table | materialized_in_fields | evidence |
|---|---|---|
| `analytic_feature.customer_type_history` | `customer_type_name`, `customer_type_reason_desc` | gather.md §6: `combined_customer_base ac LEFT JOIN customer_type_history ct ON ac.shopper_id = ct.shopper_id`; all outputs materialized |
| `analytic_feature.shopper_merge` | `customer_merge_mst_date` | gather.md §6: `combined_customer_base ac LEFT JOIN shopper_merge sm ON ac.shopper_id = sm.original_shopper_id`; only date field taken |
| `analytic_feature.shopper_acquisition` | `customer_acquisition_bill_id`, `customer_acquisition_mst_date`, `customer_acquisition_mst_month` | gather.md §6: JOIN on `shopper_id`; acquisition bill/date data materialized |
| `enterprise.dim_new_acquisition_shopper` | `customer_acquisition_country_code`, `customer_acquisition_country_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_domestic_international_name` | gather.md §6: `acq LEFT JOIN finance360.dim_country_vw ON acq.bill_country_code = geo.country_code`; country data from acquisition bill |
| `ecomm_mart.bill_line_traffic_ext` | `customer_acquisition_channel_name` | gather.md §6: JOIN on `original_shopper_id = shopper_id`; channel name materialized; fact PK (`shopper_id`) is the only join key |
| `ecomm_mart.dim_bill_line_purchase_attribution` | `point_of_purchase_name` | gather.md §6: `ROW_NUMBER OVER(PARTITION BY bill_id ORDER BY bill_line_num DESC)` JOIN; `point_of_purchase_name` materialized; no `bill_id` FK on fact |
| `finance360.dim_bill_fraud_history_vw` | `customer_acquisition_bill_fraud_flag` | gather.md §6: DISTINCT `bill_id` lookup; fraud flag materialized; `customer_acquisition_bill_id` not a proper FK to this table's PK |
| `dp_enterprise.dim_reseller` | `reseller_type_id`, `reseller_type_name` | gather.md §6: `MIN(reseller_type_id)`, `MIN(reseller_type_name)` from `dim_reseller` joined via `private_label_id`; `private_label_id` (dim PK) is NOT stored on the fact |

---

### Step 4c: Excluded Dimensions Table

Lake tables read by PySpark but **NOT included as OSI datasets** (data materialized; no dedicated FK in fact).

| Lake Table | reason | fields_on_fact |
|---|---|---|
| `analytic_feature.customer_fraud` | `no_join_key_in_fact` — join uses `(shopper_id, customer_id)` which are PK columns of the fact itself, not a dedicated FK; data fully materialized | `customer_fraud_flag`, `customer_fraud_mst_date` |

---

### Step 5: Relationship Table

| name | from | to | from_columns | to_columns | evidence |
|---|---|---|---|---|---|
| `customer_life_cycle_to_dim_customer_history` | `customer_life_cycle_vw` | `dim_customer_history` | `[shopper_id]` | `[shopper_id]` | gather.md §6: `combined_customer_base ac LEFT JOIN customer360.dim_customer_history_vw ON ac.shopper_id`; fact.shopper_id → dim.shopper_id (SCD2 natural key) |
| `customer_life_cycle_to_dim_country` | `customer_life_cycle_vw` | `dim_country` | `[customer_acquisition_country_code]` | `[country_code]` | gather.md §6: `enterprise.dim_new_acquisition_shopper acq LEFT JOIN finance360.dim_country_vw geo ON acq.bill_country_code = geo.country_code AND geo.current_record_flag = true`; bill_country_code materialized as `customer_acquisition_country_code` |

**SCD2 note for `customer_life_cycle_to_dim_customer_history`:** `dim_customer_history_vw` is SCD2; `shopper_id` is the natural key (not the surrogate PK `customer_id`). A point-in-time join requires additional filter on `effective_start_mst_ts` and `effective_end_mst_ts`. OSI relationship uses the natural key only; date-range guard must be expressed in `ai_context`.

---

### Step 6: Field Inventory

#### Dataset: `customer_life_cycle_vw` (fact)
Source: `customer360.customer_life_cycle_vw` | lake DDL: `dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl`

| OSI field name | Column | Type | is_time | description |
|---|---|---|---|---|
| `shopper_id` | shopper_id | string | false | Unique numeric ID for the shopper profile used in eCommerce transactions (part of composite PK) |
| `customer_id` | customer_id | string | false | UUID representing the customer entity across GoDaddy systems |
| `partition_eval_mst_date` | partition_eval_mst_date | string | **true** | Partition key. All facts are as of end of this day (MST). Required filter for point-in-time queries. |
| `customer_acquisition_bill_id` | customer_acquisition_bill_id | string | false | Bill ID that triggered first net positive status for customer |
| `customer_acquisition_mst_date` | customer_acquisition_mst_date | date | **true** | Date of bill that triggered first net positive status for customer (MST) |
| `customer_acquisition_mst_month` | customer_acquisition_mst_month | string | **true** | Month of customer acquisition (MST), truncated to month |
| `customer_acquisition_country_code` | customer_acquisition_country_code | string | false | Country code where customer was acquired (FK → dim_country.country_code) |
| `customer_acquisition_channel_name` | customer_acquisition_channel_name | string | false | Channel through which customer was acquired |
| `customer_tenure_year_count` | customer_tenure_year_count | int | false | Tenure of the customer in years (computed: DATEDIFF / 365) |
| `customer_acquisition_country_name` | customer_acquisition_country_name | string | false | Country name where customer was acquired |
| `customer_region_1_name` | customer_region_1_name | string | false | Geographic region 1 for the customer |
| `customer_region_2_name` | customer_region_2_name | string | false | Geographic region 2 for the customer |
| `customer_region_3_name` | customer_region_3_name | string | false | Geographic region 3 for the customer |
| `customer_domestic_international_name` | customer_domestic_international_name | string | false | Whether customer is Domestic or International |
| `reseller_type_id` | reseller_type_id | int | false | Type ID of reseller organization (FK to dp_enterprise.dim_reseller; note: private_label_id is dim PK) |
| `reseller_type_name` | reseller_type_name | string | false | Name of the reseller type |
| `customer_type_name` | customer_type_name | string | false | Customer type label at evaluation date (e.g. SMB, Enterprise, Consumer) |
| `customer_type_reason_desc` | customer_type_reason_desc | string | false | Reason for customer type classification at evaluation date |
| `customer_fraud_flag` | customer_fraud_flag | boolean | false | True if customer is flagged as fraud at evaluation date |
| `active_paid_subscription_list` | active_paid_subscription_list | array<string> | false | Array of active paid subscription_ids; not aggregatable via SQL scalar — use product_pnl_category_qty for metrics |
| `product_pnl_category_list` | product_pnl_category_list | array<string> | false | Array of product PNL categories owned by customer |
| `product_pnl_category_qty` | product_pnl_category_qty | int | false | Count of distinct product PNL categories owned by customer |
| `product_pnl_line_list` | product_pnl_line_list | array<string> | false | Array of product PNL lines owned by customer |
| `ttm_all_bill_list` | ttm_all_bill_list | array<string> | false | Array of all bill IDs from trailing twelve months |
| `brand_name_list` | brand_name_list | array<string> | false | Array of all brands associated with the customer |
| `ttm_gcr_usd_amt` | ttm_gcr_usd_amt | decimal(18,2) | false | Total gross cash received (GCR) in USD over the trailing twelve months |
| `customer_churn_mst_date` | customer_churn_mst_date | date | **true** | MST date when customer most recently churned; null if not churned |
| `customer_reactivate_mst_date` | customer_reactivate_mst_date | date | **true** | MST date when customer was most recently reactivated after churn; null if not reactivated |
| `customer_merge_mst_date` | customer_merge_mst_date | date | **true** | MST date when customer account was merged into another account |
| `customer_fraud_mst_date` | customer_fraud_mst_date | date | **true** | MST date when fraud flag was set on customer |
| `customer_state_enum` | customer_state_enum | string | false | Customer lifecycle state as of evaluation date: active, new, churned, merged, reactivated, intraday |
| `active_status_flag` | active_status_flag | boolean | false | True if customer is currently active at evaluation date |
| `point_of_purchase_name` | point_of_purchase_name | string | false | Point of purchase name from the customer acquisition bill |
| `customer_acquisition_bill_fraud_flag` | customer_acquisition_bill_fraud_flag | boolean | false | True if acquisition bill has a fraud record in dim_bill_fraud_history_vw |
| `etl_build_mst_ts` | etl_build_mst_ts | timestamp | **true** | Timestamp when this record was built by the ETL system (MST) |

#### Dataset: `dim_customer_history` (dimension)
Source: `customer360.dim_customer_history_vw` | lake DDL: `dlms-api/us-west-2/customer360/dim-customer-history-vw/table.ddl`

| OSI field name | Column | Type | is_time | description |
|---|---|---|---|---|
| `customer_id` | customer_id | string | false | Surrogate primary key for the customer history record |
| `shopper_id` | shopper_id | string | false | Natural key: unique numeric ID for shopper profile (join key to fact) |
| `external_reseller_customer_id` | external_reseller_customer_id | int | false | External reseller customer ID |
| `federation_partner_id` | federation_partner_id | string | false | Federation partner ID (FPID) scoping authorization for acquired brand-to-GoDaddy federation |
| `federation_partner_name` | federation_partner_name | string | false | Brand name associated with a federation partner ID |
| `parent_customer_id` | parent_customer_id | string | false | Parent customer UUID (for hierarchical accounts) |
| `parent_shopper_id` | parent_shopper_id | string | false | Parent shopper ID |
| `private_label_id` | private_label_id | int | false | Private label / reseller program identifier |
| `company_flag` | company_flag | boolean | false | True if the customer account is a company (not individual) |
| `internal_shopper_flag` | internal_shopper_flag | boolean | false | True if this is an internal GoDaddy shopper account |
| `temporary_shopper_flag` | temporary_shopper_flag | boolean | false | True if the shopper account is temporary |
| `closed_shopper_flag` | closed_shopper_flag | boolean | false | True if the shopper account has been closed |
| `city_name` | city_name | string | false | City of the customer's registered address |
| `state_code` | state_code | string | false | State code of the customer's registered address |
| `zip_code` | zip_code | string | false | ZIP/postal code of the customer's registered address |
| `country_code` | country_code | string | false | Country code of the customer's registered address |
| `email_domain_name` | email_domain_name | string | false | Email domain of the customer's registered email address |
| `email_hash` | email_hash | string | false | SHA hash of customer email address (PII-safe) |
| `primary_phone_flag` | primary_phone_flag | boolean | false | True if customer has a primary phone on record |
| `mobile_phone_flag` | mobile_phone_flag | boolean | false | True if customer has a mobile phone on record |
| `secondary_phone_flag` | secondary_phone_flag | boolean | false | True if customer has a secondary phone on record |
| `default_currency_code` | default_currency_code | string | false | Customer's default billing currency code |
| `market_code` | market_code | string | false | Market code for the customer |
| `created_mst_ts` | created_mst_ts | timestamp | **true** | Timestamp when the customer account was created (MST) |
| `updated_mst_ts` | updated_mst_ts | timestamp | **true** | Timestamp when the customer record was last updated (MST) |
| `closed_mst_ts` | closed_mst_ts | timestamp | **true** | Timestamp when the customer account was closed (MST) |
| `deleted_mst_ts` | deleted_mst_ts | timestamp | **true** | Timestamp when the customer record was deleted (MST) |
| `effective_start_mst_ts` | effective_start_mst_ts | timestamp | **true** | SCD2 effective start timestamp (MST) — use for point-in-time join to fact |
| `effective_end_mst_ts` | effective_end_mst_ts | timestamp | **true** | SCD2 effective end timestamp (MST) — use for point-in-time join to fact |
| `current_record_flag` | current_record_flag | boolean | false | True if this is the current (latest) SCD2 row for this shopper |
| `etl_build_mst_ts` | etl_build_mst_ts | timestamp | **true** | ETL build timestamp (MST) |
| `etl_insert_mst_ts` | etl_insert_mst_ts | timestamp | **true** | ETL insert timestamp (MST) |
| `etl_update_mst_ts` | etl_update_mst_ts | timestamp | **true** | ETL update timestamp (MST) |

#### Dataset: `dim_country` (dimension)
Source: `finance360.dim_country_vw` | lake DDL: `dlms-api/us-west-2/finance360/dim-country-vw/table.ddl`

| OSI field name | Column | Type | is_time | description |
|---|---|---|---|---|
| `country_code` | country_code | string | false | PK — Unique identifier for a country (may include GoDaddy-specific non-ISO codes) |
| `country_name` | country_name | string | false | Full name of the country |
| `iso_country_code` | iso_country_code | string | false | ISO 3166-1 alpha-2 code (2-character) |
| `iso_country3_code` | iso_country3_code | string | false | ISO 3166-1 alpha-3 code (3-character) |
| `iso_country_num` | iso_country_num | string | false | ISO 3166-1 numeric identifier |
| `region_name` | region_name | string | false | Broad region alignment (e.g. Europe, Asia) |
| `region_sort_id` | region_sort_id | string | false | Region sort order identifier |
| `primary_language_name` | primary_language_name | string | false | Primary language spoken in this country |
| `domestic_international_ind` | domestic_international_ind | string | false | Enum — Domestic or International |
| `tier_num` | tier_num | string | false | Country tier classification |
| `report_region_1_name` | report_region_1_name | string | false | Reporting region hierarchy level 1 |
| `report_region_2_name` | report_region_2_name | string | false | Reporting region hierarchy level 2 |
| `report_region_3_name` | report_region_3_name | string | false | Reporting region hierarchy level 3 |
| `report_focal_country_name` | report_focal_country_name | string | false | Reporting region hierarchy with country/language grouping |
| `report_sub_region_name` | report_sub_region_name | string | false | Additional reporting region hierarchy grain |
| `legacy_region_name` | legacy_region_name | string | false | Legacy region hierarchy name |
| `eu_flag` | eu_flag | boolean | false | True if country is part of the European Union |
| `active_flag` | active_flag | boolean | false | True if the country code is currently active |
| `fin_region_1_name` | fin_region_1_name | string | false | Finance region hierarchy level 1 |
| `fin_region_2_name` | fin_region_2_name | string | false | Finance region hierarchy level 2 |
| `marketing_region_name` | marketing_region_name | string | false | Marketing region name |
| `marketing_region_group_name` | marketing_region_group_name | string | false | Marketing region group name |
| `finance_region_name` | finance_region_name | string | false | Finance region name |
| `row_hash` | row_hash | string | false | SHA2 hash of all tracked SCD2 columns |
| `key_hash` | key_hash | string | false | SHA2 hash of all uniquely-identifying columns |
| `current_record_flag` | current_record_flag | boolean | false | True if this is the current active record (filter: current_record_flag = TRUE) |
| `etl_insert_utc_ts` | etl_insert_utc_ts | timestamp | **true** | Timestamp when record was initially inserted (UTC) |
| `etl_update_utc_ts` | etl_update_utc_ts | timestamp | **true** | Timestamp when record was last updated (UTC) |

---

### Step 7: Metrics

| name | expression | description | evidence |
|---|---|---|---|
| `total_ttm_gcr_usd_amt` | `SUM(customer_life_cycle_vw.ttm_gcr_usd_amt)` | Total trailing twelve-month gross cash received (GCR) in USD across all selected customers | gather.md §7: `SUM(ttm_total_gcr_usd_amt)` aggregated from `customer_ttm_payment_driver`; Alation: "Trailing twelve month (TTM) GCR" as key feature |
| `active_customer_count` | `COUNT(DISTINCT CASE WHEN customer_life_cycle_vw.active_status_flag = TRUE THEN customer_life_cycle_vw.shopper_id END)` | Number of distinct active customers at evaluation date | gather.md §7: `active_status_flag` derived from `active_prev`/`active_curr` MAX flags; Alation: "Active subscription product tracking"; Confluence: SSOT for active customers |
| `avg_product_pnl_category_qty` | `AVG(customer_life_cycle_vw.product_pnl_category_qty)` | Average number of distinct product PNL categories per customer (proxy for product breadth) | gather.md §7: `COUNT(DISTINCT product_pnl_category)` aggregated from subscription driver |
| `avg_customer_tenure_years` | `AVG(customer_life_cycle_vw.customer_tenure_year_count)` | Average customer tenure in years across all selected customers | gather.md §7: computed as `CAST(DATEDIFF(partition_eval_mst_date, customer_acquisition_mst_date) / 365 AS INT)` |
| `churned_customer_count` | `COUNT(DISTINCT CASE WHEN customer_life_cycle_vw.customer_state_enum = 'churned' THEN customer_life_cycle_vw.shopper_id END)` | Number of distinct churned customers at evaluation date | gather.md §7: `customer_state_enum` produced with state='churned'; Alation: "lifecycle tracking (acquisition, churn, reactivation, merge, fraud)" |

---

### Step 8: Semantic Model Metadata

| Field | Value |
|---|---|
| **Model name** | `customer360_customer_life_cycle_analytics` |
| **Description** | Comprehensive daily snapshot of GoDaddy customer lifecycle states, acquisition metrics, and trailing twelve-month revenue analytics. Single source of truth (SSOT) for customer churn, reactivation, fraud, and product portfolio analysis across ALL customers. |
| **ai_context instructions** | Always filter on `partition_eval_mst_date` for point-in-time queries. `customer_state_enum` values: `active`, `new`, `churned`, `merged`, `reactivated`, `intraday`. When joining to `dim_customer_history`, add `current_record_flag = TRUE` or date-range filter on `effective_start_mst_ts`/`effective_end_mst_ts` for SCD2 correctness. `ttm_gcr_usd_amt` represents trailing-12-month revenue at the evaluation date, not the current period only. Array columns (`active_paid_subscription_list`, etc.) are not suitable for SQL aggregation — use `product_pnl_category_qty` as a scalar proxy. |
| **ai_context synonyms** | customer lifecycle, customer life cycle, churn analysis, customer acquisition, active customers, customer state, TTM GCR, customer tenure, customer revenue, customer portfolio |
| **ai_context examples** | "How many active customers do we have today?"; "What is the total TTM GCR for US customers?"; "Show me churn rate by acquisition channel"; "Which customers have been with us for more than 5 years?"; "What percentage of customers are international?"; "Show average product categories per customer by region" |

---

### Step 9: Do-Not-Claim Table

| item | reason | preserve_as |
|---|---|---|
| `customer_core_conformed.active_customer_stg` as OSI dataset | Intermediate staging table; not in lake catalog under any path | `custom_extensions` |
| `customer_core_conformed.customer_ttm_payment_driver` as OSI dataset | Driver/intermediate table; not in lake catalog | `custom_extensions` |
| `customer_core_conformed.customer_active_subscription_detail_driver` as OSI dataset | Driver/intermediate table; not in lake catalog | `custom_extensions` |
| `analytic_feature.shopper_acquisition` as OSI dataset | Values (acquisition bill/date) fully materialized onto fact; join is via `shopper_id` (fact PK); no independent FK | `field_description`, `custom_extensions` |
| `enterprise.dim_new_acquisition_shopper` as OSI dataset | Country and acquisition data fully materialized onto fact; no FK back to this table from fact | `field_description`, `custom_extensions` |
| `analytic_feature.customer_type_history` as OSI dataset | `customer_type_name`/`customer_type_reason_desc` materialized on fact; join only via `shopper_id` (fact PK) | `field_description`, `custom_extensions` |
| `analytic_feature.customer_fraud` as OSI dataset | `customer_fraud_flag`/`customer_fraud_mst_date` materialized on fact; no dedicated FK column; join composite on PK columns | `field_description`, `custom_extensions` |
| `analytic_feature.shopper_merge` as OSI dataset | `customer_merge_mst_date` materialized on fact; join via `original_shopper_id = shopper_id` (fact PK mapping) | `field_description`, `custom_extensions` |
| `dp_enterprise.dim_reseller` as OSI dataset | `reseller_type_id`/`reseller_type_name` materialized on fact via MIN aggregation; dim PK is `private_label_id` (not on fact); no valid FK | `field_description`, `custom_extensions` |
| `ecomm_mart.bill_line_traffic_ext` as OSI dataset | `customer_acquisition_channel_name` materialized on fact; join via `shopper_id` (fact PK); legacy S3 path counterpart also unresolved | `custom_extensions` |
| `ecomm_mart.dim_bill_line_purchase_attribution` as OSI dataset | `point_of_purchase_name` materialized on fact; `bill_id` (join key) not a standalone FK column on fact | `field_description`, `custom_extensions` |
| `finance360.dim_bill_fraud_history_vw` as OSI dataset | `customer_acquisition_bill_fraud_flag` materialized on fact; no `bill_id` FK column on fact | `field_description`, `custom_extensions` |
| `enterprise.dim_subscription_history` as OSI dataset | Transitive source via `customer_active_subscription_detail_driver`; data in array fields (`active_paid_subscription_list`) not suitable for OSI FK | `custom_extensions` |
| `active_paid_subscription_list` / `product_pnl_category_list` / `product_pnl_line_list` / `ttm_all_bill_list` / `brand_name_list` as OSI metric sources | Array<string> columns; not suitable for ANSI SQL scalar aggregation in OSI metrics; use scalar proxy `product_pnl_category_qty` instead | `field_description`, `ai_context` |
| `analytic_local.ads_bill_line_ext` as OSI dataset or lineage source | Legacy S3 hardcoded path (`s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/`); no lake catalog entry; treated as pre-2022-08 equivalent of `ecomm_mart.bill_line_traffic_ext` | `custom_extensions` |
| Lake `table.yaml` lineage tables not in PySpark code (`customers.customer_id_mapping_snapshot`, `enterprise.dim_bill_shopper_id_xref`, `enterprise.fact_bill_line`, `enterprise.fact_entitlement_bill`, `ecomm_mart.entitlement_bill_type`, `finance360.dim_product_vw`, `finance_cln.manual_paid_subscription`, `enterprise.dim_entitlement_history`) | Not present in current PySpark code; may be from prior architecture; treat code as authoritative | `ai_context` |


**The agent's final response to the user was:**
Both JSON files parse cleanly. Here is a summary of the analysis performed and outputs produced:

---

## Analyze Stage — Summary

### Step 2: Target Table
- **OSI source**: `customer360.customer_life_cycle_vw` (lake catalog at `dlms-api/us-west-2/customer360/customer-life-cycle-vw/`)
- **Grain**: one row per `(shopper_id, partition_eval_mst_date)` — confirmed by DQ constraint

### Step 3: Lineage Resolution (16 source tables)
- **13 lake tables confirmed** (in `us-west-2/` or `dlms-api/us-west-2/`)
- **3 intermediate tables NOT in lake catalog**: `active_customer_stg`, `customer_ttm_payment_driver`, `customer_active_subscription_detail_driver`
- **1 unresolved legacy source**: `analytic_local.ads_bill_line_ext` (hardcoded S3 path)

### Step 4: Dataset Classification (3 OSI datasets)
| Dataset | Role | Source |
|---|---|---|
| `customer_life_cycle_vw` | fact | `customer360.customer_life_cycle_vw` |
| `dim_customer_history` | dimension | `customer360.dim_customer_history_vw` |
| `dim_country` | dimension | `finance360.dim_country_vw` |

- **8 lake tables** classified as materialized direct-reads (values denormalized onto fact, no FK back)
- **1 excluded dimension**: `analytic_feature.customer_fraud` (no dedicated FK in fact)

### Step 5: Relationships (2)
1. `customer_life_cycle_to_dim_customer_history`: `shopper_id → shopper_id` (SCD2; ai_context note on date-range filter)
2. `customer_life_cycle_to_dim_country`: `customer_acquisition_country_code → country_code`

### Step 7: Metrics (5 evidenced)
`total_ttm_gcr_usd_amt`, `active_customer_count`, `avg_product_pnl_category_qty`, `avg_customer_tenure_years`, `churned_customer_count`

### Outputs Written
- **`analyze.md`** — full analysis appended (Steps 2–9)
- **`RESOLVED_TARGET.json`** — high-confidence target resolution
- **`PROVENANCE.json`** — 3 intermediate tables, 8 materialized direct-reads, 1 excluded dimension, 5 array fields, 1 legacy source, 16 do-not-claim entries