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

# analyze.md — OSI Semantic Model Analysis
**Target:** `marketing_mart.customer_suppression`
**Mission:** marketing-mart / customer-suppression
**Analysis date:** 2026-06-29
**Analyst stage:** analyze

---

## Step 2: Target Table Resolution

| Field | Value | Evidence |
|---|---|---|
| Schema | `marketing_mart` | lake DDL path `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.ddl` |
| Table (hyphenated) | `customer-suppression` | lake catalog directory name |
| Table (underscore) | `customer_suppression` | PySpark `-t customer_suppression` arg; DDL `CREATE TABLE customer_suppression` |
| Lake table path | `marketing-mart/customer-suppression` | lake catalog |
| Write mechanism | `transform_stg()` in PySpark | `customer_suppression.py` (gather.md §1) |
| Grain | One row per `customer_id` | DQ constraint: `customer_id` is primary key; LATEST_SNAPSHOT full replacement |
| Table type | LATEST_SNAPSHOT | `table.yaml: table_type: "LATEST_SNAPSHOT"` |
| S3 location | `s3://gd-ckpetlbatch-prod-mktgdata-eds/marketing_mart_local/customer_suppression` | `table.yaml` |
| Note on `-d marketing_mart_local` | DAG passes `marketing_mart_local` as DB arg to PySpark for staging; lake publishes as `marketing_mart` | Conflict #4 in gather.md |

**Secondary write target (history):** `marketing_mart_local.customer_suppression_history` via `main_to_history_ckpetl_eds_ss.py`. This is an in-repo staging/history table — NOT a lake-registered table. Do not claim as OSI dataset.

---

## Step 3: Lineage Resolution

| Source Table | Lake Found? | Lake Path | Notes |
|---|---|---|---|
| `marketing_mart.customer_suppression` | YES | `us-west-2/marketing-mart/customer-suppression/` | **TARGET** — written by this job |
| `marketing_mart.customer` | YES | `us-west-2/marketing-mart/customer/` | Base customer list (READ) |
| `customer360.dim_customer_vw` | YES | `dlms-api/us-west-2/customer360/dim-customer-vw/` | Customer profile (READ); ICEBERG table |
| `cust_customertracking.shopper_crossover_cln` | YES | `us-west-2/cust-customertracking/shopper-crossover-cln/` | Pool-13 active flag (READ) |
| `ecomm_cln.gdshop_blocked_country_region_cln` | YES | `us-west-2/ecomm-cln/gdshop-blocked-country-region-cln/` | Blocked country regions (READ) |
| `ecomm_cln.gdshop_blocked_country_cln` | YES | `us-west-2/ecomm-cln/gdshop-blocked-country-cln/` | Blocked countries (READ) |
| `marketing_bouncesystem.bouncesystem_bounced_email_snap` | YES | `us-west-2/marketing-bouncesystem/bouncesystem-bounced-email-snap/` | Bounce email records (READ) |
| `marketing_bouncesystem.bouncesystem_bounced_email_log_snap` | YES | `us-west-2/marketing-bouncesystem/bouncesystem-bounced-email-log-snap/` | Bounce log (READ) |
| `marketing_bouncesystem.bouncesystem_bounce_type_snap` | YES | `us-west-2/marketing-bouncesystem/bouncesystem-bounce-type-snap/` | Bounce type codes HB/SB/GB (READ) |
| `sfmc_email_events_cln.sfmc_email_events_bounce_cln` | YES | `us-west-2/sfmc-email-events/sfmc-email-events-bounce-cln/` | SFMC bounce events (READ); catalog folder is `sfmc-email-events` |
| `sfmc_email_events_cln.sfmc_email_events_send_log_cln` | YES | `us-west-2/sfmc-email-events/sfmc-email-events-send-log-cln/` | SFMC send log (READ) |
| `sfmc_email_events_cln.sfmc_email_events_open_cln` | YES | `us-west-2/sfmc-email-events/sfmc-email-events-open-cln/` | SFMC open events (READ) |
| `sfmc_email_events_cln.sfmc_email_events_click_cln` | YES | `us-west-2/sfmc-email-events/sfmc-email-events-click-cln/` | SFMC click events (READ) |
| `emailsystem.oc_emailqueuesuccesstrackingclick_snap` | YES | `us-west-2/emailsystem/oc-emailqueuesuccesstrackingclick-snap/` | OCM click tracking (READ) |
| `emailsystem.oc_emailqueuesuccesstracking_snap` | YES | `us-west-2/emailsystem/oc-emailqueuesuccesstracking-snap/` | OCM tracking codes (READ) |
| `emailsystem.oc_emailqueuesuccess_snap` | YES | `us-west-2/emailsystem/oc-emailqueuesuccess-snap/` | OCM email success queue (READ) |
| `emailsystem.oc_emailqueuedetail_snap` | YES | `us-west-2/emailsystem/oc-emailqueuedetail-snap/` | OCM email queue detail (READ) |
| `signals_platform_cln.oeg_email_event_send_cln` | **UNRESOLVED** | — | Not found in lake catalog (checked `us-west-2/signals-platform-cln/` and `dlms-api/us-west-2/signals-platform-cln/`); used for bounce re-engagement reset logic |
| `signals_platform_cln.oeg_email_event_open_cln` | **UNRESOLVED** | — | Not found in lake catalog; used for re-engagement reset logic |
| `signals_platform_cln.profile_audit_lake_cln_v2` | **UNRESOLVED** | — | Not found in lake catalog; used to detect email address changes for bounce reset |
| `marketing_mart_local.customer_suppression_history` | NOT A LAKE TABLE | — | In-repo history staging table; written by secondary history script; not in lake catalog |

**UNRESOLVED summary:**
- `signals_platform_cln.oeg_email_event_send_cln` — UNRESOLVED: not in lake catalog; used for OEG send re-engagement in bounce reset
- `signals_platform_cln.oeg_email_event_open_cln` — UNRESOLVED: not in lake catalog; used for OEG open re-engagement in bounce reset
- `signals_platform_cln.profile_audit_lake_cln_v2` — UNRESOLVED: not in lake catalog; used to detect email changes to nullify bounces

---

## Step 4: Dataset Classification

| Lake Table | OSI Dataset Name | Role | source | primary_key |
|---|---|---|---|---|
| `marketing_mart.customer_suppression` | `customer_suppression` | **fact** | `marketing_mart.customer_suppression` | `[customer_id]` |
| `marketing_mart.customer` | `customer` | **dimension** | `marketing_mart.customer` | `[customer_id]` |
| `customer360.dim_customer_vw` | `dim_customer_vw` | **dimension** | `customer360.dim_customer_vw` | `[customer_id]` (shopper_id is a UK) |

**Classification evidence:**
- `customer_suppression` is the PySpark write target; grain is one row per customer_id
- `marketing_mart.customer` is the base table driving the final assembly (`source_df`); joined on `customer_id` from fact — provides customer attributes for analytics context
- `customer360.dim_customer_vw` is joined on `shopper_id` from fact — provides internal_shopper_flag and profile data; shopper_id is present on the fact table as FK

---

## Step 5: Materialized Direct-Reads

| Lake Table | materialized_in_fields | evidence |
|---|---|---|
| `ecomm_cln.gdshop_blocked_country_cln` | `restricted_country_flag` | Join #22 in gather.md: `LOWER(cust.country_code) = LOWER(gbc.country_code)`; country_code is NOT on fact table |
| `ecomm_cln.gdshop_blocked_country_region_cln` | `restricted_country_flag` | Join #21 in gather.md: `LOWER(cust.country_code) = LOWER(gbcr.country_code) AND LOWER(cust.city_name) = LOWER(gbcr.region_name)`; join keys NOT on fact table |

---

## Step 6: Excluded Dimensions

| Lake Table | reason | fields_on_fact |
|---|---|---|
| `cust_customertracking.shopper_crossover_cln` | `data_fully_materialized_on_fact` — shopper_id FK is on fact but pool_13_active_flag is fully captured as private_label_13_suppression_flag | `private_label_13_suppression_flag` |
| `marketing_bouncesystem.bouncesystem_bounced_email_snap` | `no_join_key_in_fact` — bounce tables joined via internal bounced_email_id / bounce_type_id chain; no FK on fact | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `marketing_bouncesystem.bouncesystem_bounced_email_log_snap` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `marketing_bouncesystem.bouncesystem_bounce_type_snap` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `sfmc_email_events_cln.sfmc_email_events_bounce_cln` | `no_join_key_in_fact` — SFMC composite key (job_id/list_id/batch_id/subscriber_id) not on fact | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `sfmc_email_events_cln.sfmc_email_events_send_log_cln` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `sfmc_email_events_cln.sfmc_email_events_open_cln` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `sfmc_email_events_cln.sfmc_email_events_click_cln` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `emailsystem.oc_emailqueuesuccesstrackingclick_snap` | `no_join_key_in_fact` — OCM tracking keys not on fact | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `emailsystem.oc_emailqueuesuccesstracking_snap` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `emailsystem.oc_emailqueuesuccess_snap` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |
| `emailsystem.oc_emailqueuedetail_snap` | `no_join_key_in_fact` | `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag` |

---

## Step 7: Relationships

| name | from | to | from_columns | to_columns | evidence |
|---|---|---|---|---|---|
| `customer_suppression_to_customer` | `customer_suppression` | `customer` | `[customer_id]` | `[customer_id]` | Join #18: `cust.customer_id = cef.customer_id`; final assembly source_df is customer-driven |
| `customer_suppression_to_dim_customer_vw` | `customer_suppression` | `dim_customer_vw` | `[shopper_id]` | `[shopper_id]` | Join #19: `cust.shopper_id = dim.shopper_id AND cust.temporary_shopper_flag = FALSE`; dim_customer_vw.shopper_id is @UniqueKey |

**Relationship notes:**
- `customer_suppression → customer`: One-to-one on customer_id (both tables grain per customer_id); customer is "reference" dimension.
- `customer_suppression → dim_customer_vw`: Many-to-one on shopper_id (one shopper may have multiple customer_ids in customer_suppression; dim_customer_vw.shopper_id is unique). Relationship uses the unique-key join path, not the PK join.
- No relationship modeled to `cust_customertracking.shopper_crossover_cln` — excluded (data materialized on fact).

---

## Step 8: Field Inventory

### Dataset: customer_suppression (fact) — source: marketing_mart.customer_suppression

| column | type | is_time | description | ai_context synonyms |
|---|---|---|---|---|
| customer_id | string | | Primary key; unique UUID customer identifier | customer UUID, cust_id |
| shopper_id | string | | GoDaddy numeric shopper identifier | shopper, shopper number |
| internal_account_flag | boolean | | TRUE if customer is an internal GoDaddy account (from dim_customer_vw.internal_shopper_flag where current_record_flag=TRUE) | internal shopper, GoDaddy employee |
| private_label_13_suppression_flag | boolean | | TRUE if the customer's email is tied to a GoDaddy reseller and they purchased from that reseller within the last 12 months | PL13, reseller suppression, pool 13 |
| restricted_country_flag | boolean | | TRUE if customer's country or city+country is on GoDaddy's blocked country/region list | sanctioned country, blocked country, restricted region |
| excluded_email_flag | boolean | | **Always NULL in current code** — intended for excluded email logic (FortKnox source not yet wired) | excluded email |
| competitor_email_flag | boolean | | TRUE if customer's email domain matches a known competitor domain token | competitor email, rival email domain |
| bad_email_address_format_flag | boolean | | **Always NULL in current code** — intended for bad email format detection (FortKnox source not yet wired) | bad email format, invalid email |
| email_address_hard_bounced_flag | boolean | | TRUE if customer has a hard bounce from bouncesystem (bounce_code=HB) or SFMC (bounce_category='Hard bounce'), with no subsequent re-engagement or email address change | hard bounce, undeliverable email |
| email_address_soft_bounced_flag | boolean | | TRUE if customer has ≥3 qualifying soft bounce events in the last 180 days (after most recent email change and before any re-engagement) | soft bounce, temporary email failure |
| etl_build_mst_ts | timestamp | **true** | ETL pipeline build timestamp in Mountain Standard Time | load time, build time |

### Dataset: customer (dimension) — source: marketing_mart.customer

| column | type | is_time | description |
|---|---|---|---|
| customer_id | string | | Primary key; unique UUID customer identifier |
| shopper_id | string | | GoDaddy numeric shopper identifier |
| private_label_id | int | | Private label identifier |
| account_create_mst_ts | timestamp | **true** | Account creation timestamp in MST |
| temporary_shopper_flag | boolean | | TRUE if customer is a temporary/guest shopper |
| city_name | string | | Customer city name |
| state | string | | Customer state |
| zip_code | string | | Customer postal code |
| country_code | string | | Customer country code (ISO) |
| parent_shopper_id | string | | Parent shopper identifier (for sub-accounts) |
| parent_customer_id | string | | Parent customer identifier |
| shopper_payment_type_id | int | | Payment type identifier |
| email_address_hash | string | | Hashed email address |
| email_domain | string | | Email domain of the customer |
| catalog_market_id | string | | Catalog market identifier |
| currency_code | string | | Default currency code |
| business_flag | boolean | | TRUE if customer is a business account |
| web_pro_flag | boolean | | TRUE if customer is a Web Pro |
| client_of_web_pro_flag | boolean | | TRUE if customer is a client of a Web Pro |
| delegated_shopper_flag | boolean | | TRUE if customer has delegated account access |
| federation_partner_id | string | | Federation partner identifier |
| federation_partner_name | string | | Federation partner name |
| etl_build_mst_ts | timestamp | **true** | ETL build timestamp in MST |

### Dataset: dim_customer_vw (dimension) — source: customer360.dim_customer_vw

| column | type | is_time | description |
|---|---|---|---|
| customer_id | string | | Primary key (@PrimaryKey); unique UUID customer identifier |
| shopper_id | string | | Unique key (@UniqueKey); numeric shopper identifier |
| external_reseller_customer_id | int | | External reseller customer identifier |
| federation_partner_id | string | | Federation partner identifier |
| federation_partner_name | string | | Federation partner name |
| parent_customer_id | string | | Parent customer identifier |
| parent_shopper_id | string | | Parent shopper identifier |
| private_label_id | int | | Private label identifier |
| company_flag | boolean | | TRUE if account is a company |
| internal_shopper_flag | boolean | | TRUE if customer is an internal GoDaddy shopper (drives internal_account_flag on fact) |
| temporary_shopper_flag | boolean | | TRUE if temporary/guest shopper |
| closed_shopper_flag | boolean | | TRUE if shopper account is closed |
| city_name | string | | Customer city name |
| state_code | string | | Customer state code |
| zip_code | string | | Customer postal code |
| country_code | string | | Customer country code |
| email_domain_name | string | | Email domain name |
| email_hash | string | | Hashed email address |
| primary_phone_flag | boolean | | TRUE if primary phone is on file |
| mobile_phone_flag | boolean | | TRUE if mobile phone is on file |
| secondary_phone_flag | boolean | | TRUE if secondary phone is on file |
| default_currency_code | string | | Default currency code |
| market_code | string | | Market code |
| created_mst_ts | timestamp | **true** | Account creation timestamp in MST |
| updated_mst_ts | timestamp | **true** | Last updated timestamp in MST |
| closed_mst_ts | timestamp | **true** | Account closure timestamp in MST |
| deleted_mst_ts | timestamp | **true** | Account deletion timestamp in MST |
| current_record_flag | boolean | | TRUE if this is the most recent record for the shopper (used as filter in PySpark join) |
| etl_build_mst_ts | timestamp | **true** | ETL build timestamp in MST |

---

## Step 9: Metrics

**Result: No metrics included.**

Evidence reviewed:
- Alation: 0 saved queries found for this table (gather.md §9)
- Confluence: Describes business meaning and flag definitions; no explicit metric formulas
- PySpark aggregations (gather.md §5): All aggregations are **internal ETL computations** (intermediate CTEs to produce boolean flags), not user-facing analytical metrics

Without evidence of defined analytical metrics, none are included per spec instructions. Metrics may be added in future iterations if Alation queries or downstream BI usage is discovered.

---

## Step 10: Semantic Model Metadata

| Field | Value |
|---|---|
| **Model name** | `marketing_mart_customer_suppression` (derived: schema=marketing_mart, table=customer_suppression; no override in INPUT.md) |
| **Description** | "Daily snapshot of GoDaddy customer marketing suppression flags. Defines which customers should be excluded from marketing communications based on email deliverability, account type, geographic restrictions, and competitive email domain detection." |
| **Grain** | One row per `customer_id` (LATEST_SNAPSHOT; full replacement each run) |
| **Refresh cadence** | Daily at 04:00 America/Phoenix (= 11:00 UTC) |
| **SLA** | 06:00 AM MST daily (`cron(0 13 * * ? *)`) |
| **Data tier** | 3 |
| **Owner** | emerald-data-team-org@godaddy.com / DEV-EDT-OnCall / #edt-airflow-alerts |

**ai_context draft:**

```
instructions: >
  Use this model to determine which GoDaddy customers are suppressed from marketing
  communications. Suppression is GoDaddy-driven (distinct from customer consent/opt-out).
  Each row represents one customer (identified by customer_id). Join to 'customer' for
  demographic attributes or 'dim_customer_vw' for profile data.
  Note: excluded_email_flag and bad_email_address_format_flag are always NULL in the
  current implementation and should not be used for filtering.
synonyms:
  - "marketing suppression"
  - "customer suppression"
  - "do not contact"
  - "email suppression list"
  - "marketing eligibility"
examples:
  - "How many customers are currently suppressed from marketing emails?"
  - "Which customers have a hard bounce flag set?"
  - "How many customers are suppressed due to restricted country?"
  - "Show me suppression breakdown by flag type"
  - "Is customer X eligible to receive marketing emails?"
```

---

## Step 11: Do-Not-Claim Table

| item | reason | preserve_as |
|---|---|---|
| `signals_platform_cln.oeg_email_event_send_cln` as OSI dataset | Not found in lake catalog (UNRESOLVED); used in PySpark for bounce re-engagement reset | `custom_extensions` |
| `signals_platform_cln.oeg_email_event_open_cln` as OSI dataset | Not found in lake catalog (UNRESOLVED); used in PySpark for OEG open re-engagement | `custom_extensions` |
| `signals_platform_cln.profile_audit_lake_cln_v2` as OSI dataset | Not found in lake catalog (UNRESOLVED); used in PySpark to detect email address changes | `custom_extensions` |
| `marketing_mart_local.customer_suppression_history` as OSI dataset | In-repo staging/history table; not registered in lake catalog | `custom_extensions` |
| `excluded_email_flag` as reliable field or metric | Always NULL in current PySpark (`NULL AS excluded_email_flag`); FortKnox source not yet wired | `field_description` |
| `bad_email_address_format_flag` as reliable field or metric | Always NULL in current PySpark (`NULL AS bad_email_address_format_flag`); FortKnox source not yet wired | `field_description` |
| `cust_customertracking.shopper_crossover_cln` as OSI dimension dataset | `pool_13_active_flag` is fully materialized on fact as `private_label_13_suppression_flag`; including as dimension would duplicate data | `custom_extensions` |
| All `marketing_bouncesystem.*`, `sfmc_email_events_cln.*`, `emailsystem.*` tables as OSI dimension datasets | Source event/transaction logs; no join key from fact to these tables; values aggregated into `email_address_hard_bounced_flag` / `email_address_soft_bounced_flag` via complex multi-table ETL chain | `custom_extensions` |
| `terrorist_country_flag` as OSI field | Appears in Confluence legacy design; not in current DDL or code — merged into `restricted_country_flag` | `ai_context` |
| Bounce data sources (FortKnox `tdaemailattributes_snap`) as OSI dataset | Confluence documents this as a bounce source; code uses bouncesystem/SFMC instead; not currently in ETL | `ai_context` |


**The agent's final response to the user was:**
All analysis is complete. Here's a summary of what was produced:

---

## Analysis Summary

### Target Table
**`marketing_mart.customer_suppression`** — confirmed high confidence via lake DDL, table.yaml, PySpark `transform_stg()`, and DAG args. Grain: one row per `customer_id` (LATEST_SNAPSHOT, full daily replacement).

### Lineage Resolution (20 source tables)
- **17 lake tables found** in catalog
- **3 UNRESOLVED** (not in lake catalog): `signals_platform_cln.oeg_email_event_send_cln`, `.oeg_email_event_open_cln`, `.profile_audit_lake_cln_v2`
- `marketing_mart_local.customer_suppression_history` is an in-repo staging table, not a lake table

### OSI Datasets (3)
| Dataset | Role | Source |
|---|---|---|
| `customer_suppression` | **fact** | `marketing_mart.customer_suppression` |
| `customer` | dimension | `marketing_mart.customer` |
| `dim_customer_vw` | dimension | `customer360.dim_customer_vw` |

### OSI Relationships (2)
- `customer_suppression_to_customer`: on `customer_id`
- `customer_suppression_to_dim_customer_vw`: on `shopper_id`

### Excluded/Materialized (12 tables excluded from OSI)
- **Materialized direct reads** (no FK on fact): `gdshop_blocked_country_cln`, `gdshop_blocked_country_region_cln` → `restricted_country_flag`
- **Excluded dimensions** (no FK on fact): all bounce/SFMC/emailsystem tables → `email_address_hard_bounced_flag`, `email_address_soft_bounced_flag`
- **Excluded** (FK present but fully materialized): `shopper_crossover_cln` → `private_label_13_suppression_flag`

### Metrics
None — no Alation saved queries, no Confluence metric definitions. All PySpark aggregations are internal ETL computations.

### Outputs Written
- `analyze.md` — full analysis appended
- `RESOLVED_TARGET.json` — target table coordinates
- `PROVENANCE.json` — machine-readable lineage contract for OSI YAML generation