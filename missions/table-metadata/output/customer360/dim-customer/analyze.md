**Stage name:** analyze
**The coding agent was given these instructions:** You are a Data Engineering + Data Governance analyst. Your job is to resolve lineage
from the PySpark job to the authoritative Data Lake table, and extract only accurate,
evidence-backed metadata.

## Step 1: Read INPUT.md and gather.md
- Read `INPUT.md` and the previous stage output `gather.md`.
- If INPUT.md contains USER NOTES, factor them into your facts blocks where relevant
  (they are expert-provided and take priority over Confluence/Alation text).

## Step 2: Identify the target table
Determine the final output lake table populated by this PySpark job.
- Prefer direct evidence in code: table write targets, create/insert statements,
  saveAsTable targets, Glue catalog writes, Athena CTAS, etc.
- If `lake_table_override` is provided in INPUT.md, use it only if it does not
  contradict the code; otherwise flag the conflict.
- If multiple outputs exist, list them. Identify the “primary” one if possible.

## Step 3: Deep lineage resolution — MANDATORY for EVERY source table

The PySpark script references upstream tables. Some are lake tables (in `repos/lake/`),
but many are **local/intermediate tables** (e.g., `customer_core_conformed.*`,
`analytic_local.*`, `*_stg`) that are built by OTHER PySpark scripts in the SAME repo.

**You MUST recursively trace EACH source table to its lake origin. Do NOT stop at
intermediate tables. They are implementation details, not authoritative sources.**

For EACH table referenced in the target PySpark:

1. **Check if it exists as a lake table**: search `repos/lake/catalog/config/prod/` for it.
   Try both `us-west-2/<schema>/<table-hyphenated>/` and `dlms-api/us-west-2/<schema>/<table-hyphenated>/`.
   Convert underscores to hyphens when searching lake paths.

2. **If it IS a lake table** -> STOP. Record it as the authoritative source. Read its
   `table.yaml` and `table.ddl`. Do NOT traverse further into that lake table's own
   upstream sources. The lineage for THIS table ends at its first upstream lake table.

3. **If it is NOT a lake table** (local/intermediate) — you MUST trace upstream:
   a. Search the source repo for the PySpark script that BUILDS this intermediate table.
      Use `grep -r "<table_name>" repos/<source-repo>/` to find references.
      Look for `insertInto`, `saveAsTable`, `CREATE TABLE`, or write operations targeting it.
   b. Read that upstream PySpark script.
   c. Identify what tables IT reads from.
   d. For each of THOSE tables, repeat from step 1 (recursive traversal).
   e. Continue until you reach a lake table or an external system (S3 direct read, API, etc.).
   f. **STOP as soon as you reach a lake table.** Do NOT traverse into a lake table's
      own sources. A lake table is a boundary — it is the authoritative source.

4. **If traversal fails** (cannot find the upstream script, or it reads from an unknown source):
   Record: `UNRESOLVED: <table_name> — <what you searched and why it failed>`

**CRITICAL RULE FOR C1 (Column Reference):**
The "Source Table(s)" column in C1 must show the FIRST lake table encountered in the
lineage chain — NOT the lake table's own upstream sources. For example, if the PySpark
reads from `customer_core_conformed.customer_life_cycle` which resolves to lake table
`customer360.customer_life_cycle_vw`, then ALL columns sourced from it must show
`customer360.customer_life_cycle_vw` — NOT the tables that feed customer_life_cycle_vw.
- BAD:  `enterprise.dim_subscription` (this is a source of the UPSTREAM lake table, not this table)
- BAD:  `customer_core_conformed.active_customer_stg` (this is an intermediate table)
- GOOD: `customer360.customer_life_cycle_vw` (the first lake table in the chain)
- GOOD: `UNRESOLVED — requires manual input` (if traversal failed)

Only trace THROUGH a lake table if the PySpark directly reads from multiple tables and
one of those is NOT a lake table. In that case, trace only the non-lake sources.

## Step 4: Read lake registry artifacts for the direct upstream lake tables
For EACH lake table that is a DIRECT source of the target (i.e., the first lake table
reached during traversal — not deeper ancestors), read:
- `table.ddl` — authoritative schema with column names and types
- `table.yaml` — lineage metadata, consumer groups, SLA info

Also read the target table's own lake registry artifacts (table.ddl, table.yaml).

Build a column-level mapping: `target_column -> source_lake_table.column`
(If intermediates exist between the target and the lake source, note the chain but
the final C1 mapping must reference only the first lake table reached.)

## Step 5: Derive analysis outputs (no guessing)
Derive the following, strictly from code + resolved lake artifacts:
- Grain: what one row represents
- Keys: primary key / unique key strategy (or explicitly "no PK" + dedup guidance)
- Partitions and recommended always-filter columns
- Always-on filters embedded in ETL (non-overridable scope restrictions)
- Common business metrics computed in the ETL (name + definition + grain)
- **Column-level lineage** (CRITICAL): for EACH column in the target table, trace it
  to the FIRST upstream lake table and column. Do NOT trace further into that lake
  table's own sources. If the column is computed/derived, note the formula AND the
  direct lake source columns feeding it. If lineage cannot be resolved, mark as UNRESOLVED.
- SLA/refresh schedule from the DAG (cron, dependencies, expected latency)

## Step 6: Output (append to analyze.md)
Append:
- Target table resolution (with evidence and any overrides)
- **Lineage resolution table** showing for each source table referenced in code:
  | Source Table (from code) | Resolved To (First Lake Table) | Resolution Method |
  Include UNRESOLVED entries with explanation of what was searched.
  Do NOT list a lake table's own upstream sources — stop at the lake boundary.
- Column-level lineage mapping (target_column -> first_lake_table.column) for all columns
- A structured "facts" block for each of the 20 sections (A1..E3) listing
  what can be filled and what is missing
- A "Do not claim" list: items that are tempting but not proven

## Step 7: Write resolved-target machine output (required)
Create a JSON file in the workspace root named `RESOLVED_TARGET.json` with:
- schema: string (e.g., "enterprise")
- table_hyphen: string (e.g., "payment-cogs-audit")
- table_underscore: string (e.g., "payment_cogs_audit")
- lake_table_path: string|null (e.g., "enterprise/payment-cogs-audit")
- confidence: "high"|"medium"|"low"
- evidence: array of short strings (file/line references)
If the target cannot be resolved, still write the file with nulls and a clear explanation in evidence.

**The agent summarized its work in this way:**

---

# Analyze Report: customer360 / dim-customer-vw

**Date analyzed:** 2026-06-09  
**Analyst stage:** analyze  
**Source of truth:** PySpark script + calling DAG (code overrides all other sources)

---

## Target Table Resolution

### Primary target: `customer360.dim_customer_vw`

| Evidence Item | Detail |
|---|---|
| `lake_table_override` in INPUT.md | `customer360/dim-customer-vw` |
| DAG `call_lake_api` task | Posts completion notification for `customer360.dim_customer_vw` |
| DAG `call_lake_api_hist` task | Posts completion notification for `customer360.dim_customer_history_vw` |
| `create_view.sql` template | `CREATE OR REPLACE VIEW {view_database}.dim_customer_vw AS SELECT ... FROM {table_database}.dim_customer WHERE current_record_flag = true` |
| Lake registry path | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/` |
| Code write target | `customer_core_conformed.dim_customer` (Iceberg physical table; view `dim_customer_vw` is registered over it) |

**Assessment:** The override `customer360/dim-customer-vw` is **consistent** with code. The PySpark physically writes to `customer_core_conformed.dim_customer` (Iceberg); the DAG then creates the Redshift view and registers the lake table `customer360.dim_customer_vw` as the published surface. No conflict.

### Secondary outputs also produced by the same DAG
| Table | Platform | Description |
|---|---|---|
| `customer360.dim_customer_history_vw` | Lake Iceberg + Redshift | Same physical Iceberg table, no `current_record_flag` filter; all SCD rows |
| `customer_core_conformed.dim_customer` | Iceberg (internal) | Physical SCD Type 2 table; not a published lake output |

---

## Lineage Resolution Table

### Step 1: Tables directly referenced in `dim_customer.py`

| Source Table (from code) | Intermediate or Lake? | Resolution Method |
|---|---|---|
| `customer_core_conformed.dim_customer_daily_delta` | **INTERMEDIATE** | Not found in `repos/lake/catalog/config/prod/` (searched `us-west-2/customer-core-conformed/dim-customer-daily-delta/` and `dlms-api/us-west-2/customer-core-conformed/dim-customer-daily-delta/`). Built by `dim_customer_daily_delta.py` in same repo. |
| `customer_core_conformed.dim_customer_attributes` | **INTERMEDIATE** | Not found in lake catalog. Built by `dim_customer_attributes.py` in same repo at `customer/dim-customer-attributes/src/pyspark/dim_customer_attributes.py`. |
| `customer_core_conformed.dim_customer` | Target table (self-reference for SCD merge) | Physical Iceberg write target. Not a separate lake source. |

### Step 2: Tables read by `dim_customer_daily_delta.py` (resolving the first intermediate)

| Source Table (from code) | Resolved To (First Lake Table) | Resolution Method |
|---|---|---|
| `customers.customer_id_mapping_snapshot` | **`customers.customer_id_mapping_snapshot`** (LAKE — STOP) | Found at `repos/lake/catalog/config/prod/us-west-2/customers/customer-id-mapping-snapshot/`. DDL + YAML read. |
| `fortknox.fortknox_shopper_snap` | **`fortknox.fortknox_shopper_snap`** (LAKE — STOP) | Found at `repos/lake/catalog/config/prod/us-west-2/fortknox/fortknox-shopper-snap/`. DDL + YAML read. |
| `godaddy.rp_salesmonitor_internalshopper_snap` | **`godaddy.rp_salesmonitor_internalshopper_snap`** (LAKE — STOP) | Found at `repos/lake/catalog/config/prod/us-west-2/godaddy/rp-salesmonitor-internalshopper-snap/`. DDL + YAML read. |
| `signals_platform_cln.profile_audit_lake_cln_v2` | **UNRESOLVED** — confirmed upstream lake table (DAG sensor present), but NOT registered in `repos/lake/catalog/` (searched `us-west-2/signals-platform-cln/profile-audit-lake-cln-v2/`; schema `signals-platform-cln` does not exist in catalog; only `signals-platform` and `signals-platform-business-event-cln` found). | DAG S3KeySensor confirms it exists as a lake table. No `table.yaml` or `table.ddl` available. |
| `global_profile_service_cln.profile_snapshot` | **UNRESOLVED** — only used in bootstrap path (`run_date == '2025-06-01'` special case). Not found in lake catalog. | Not a daily incremental source. No `table.yaml` or `table.ddl` available. |

### Step 3: Tables read by `dim_customer_attributes.py` (resolving the second intermediate)

| Source Table (from code) | Resolved To (First Lake Table) | Resolution Method |
|---|---|---|
| `customers.customer_id_mapping_snapshot` | **`customers.customer_id_mapping_snapshot`** (LAKE — STOP) | Already confirmed above. Used for customer_id ↔ shopper_id join. |
| `sso_permissions_cln.identity_mapping_snapshot_cln` | **`sso_permissions_cln.identity_mapping_snapshot_cln`** (LAKE — STOP) | Found at `repos/lake/catalog/config/prod/us-west-2/sso-permissions-cln/identity-mapping-snapshot-cln/`. DDL + YAML read. Description: "sso aliases table". |
| `sso_metadata_cln.federation_metadata_snapshot_cln` | **`sso_metadata_cln.federation_metadata_snapshot_cln`** (LAKE — STOP) | Found at `repos/lake/catalog/config/prod/us-west-2/sso-metadata-cln/federation-metadata-snapshot-cln/`. DDL + YAML read. Description: "Federation Metadata Snapshot table". |

### Consolidated: Authoritative lake sources for `customer360.dim_customer_vw`

| Lake Table | Schema | Lake Path | Registered in Catalog |
|---|---|---|---|
| `customers.customer_id_mapping_snapshot` | customers | `us-west-2/customers/customer-id-mapping-snapshot/` | Yes |
| `fortknox.fortknox_shopper_snap` | fortknox | `us-west-2/fortknox/fortknox-shopper-snap/` | Yes |
| `godaddy.rp_salesmonitor_internalshopper_snap` | godaddy | `us-west-2/godaddy/rp-salesmonitor-internalshopper-snap/` | Yes |
| `signals_platform_cln.profile_audit_lake_cln_v2` | signals_platform_cln | NOT in catalog | No (DAG sensor confirms existence) |
| `sso_permissions_cln.identity_mapping_snapshot_cln` | sso_permissions_cln | `us-west-2/sso-permissions-cln/identity-mapping-snapshot-cln/` | Yes |
| `sso_metadata_cln.federation_metadata_snapshot_cln` | sso_metadata_cln | `us-west-2/sso-metadata-cln/federation-metadata-snapshot-cln/` | Yes |

**NOTE on bootstrap source:** `global_profile_service_cln.profile_snapshot` is used ONLY in the one-time 2025-06-01 initial load path in `dim_customer_daily_delta.py`. It is NOT part of the daily incremental lineage. Not tracked further.

---

## Column-Level Lineage Mapping (C1)

Target table: `customer360.dim_customer_vw` (30 columns per lake DDL + view SQL)

Intermediate chain for most columns:
- `dim_customer.py` ← `customer_core_conformed.dim_customer_daily_delta` ← `dim_customer_daily_delta.py` ← first lake source

For `federation_partner_id` / `federation_partner_name`:
- `dim_customer.py` ← `customer_core_conformed.dim_customer_attributes` ← `dim_customer_attributes.py` ← SSO lake sources

| # | Target Column | Type | First Lake Table Source | Source Column | Transformation / Notes |
|---|---|---|---|---|---|
| 1 | `customer_id` | string | `customers.customer_id_mapping_snapshot` | `customerid` | `lower(cs_customerid)` — lowercased UUID |
| 2 | `shopper_id` | string | `customers.customer_id_mapping_snapshot` | `id` | Direct pass-through (`cs_id AS shopper_id`) |
| 3 | `external_reseller_customer_id` | int | `fortknox.fortknox_shopper_snap` | `externalid` | Direct (`ft_externalid AS external_reseller_customer_id`) |
| 4 | `federation_partner_id` | string | `sso_permissions_cln.identity_mapping_snapshot_cln` | `namespace_id` | Via `dim_customer_attributes` → `federal_partner_id_name` view; latest active FPID for this customer_id |
| 5 | `federation_partner_name` | string | `sso_metadata_cln.federation_metadata_snapshot_cln` | `brand_name` | Via `dim_customer_attributes` → INNER JOIN federation metadata on `federation_partner_id` |
| 6 | `parent_customer_id` | string | `customers.customer_id_mapping_snapshot` | `customerid` | `lower(cs_customerid)` — same value as `customer_id` (self-reference in current model) |
| 7 | `parent_shopper_id` | string | `fortknox.fortknox_shopper_snap` | `parent_shopper_id` | Direct (`ft_parent_shopper_id AS parent_shopper_id`) |
| 8 | `private_label_id` | int | `signals_platform_cln.profile_audit_lake_cln_v2` | `private_label_id` | `CAST(pf_private_label_id AS INT)` — UNRESOLVED: source table not in lake catalog |
| 9 | `company_flag` | boolean | `signals_platform_cln.profile_audit_lake_cln_v2` | `organization_name` | `CASE WHEN pf_organization_name != '' AND pf_organization_name != 'DELETED' THEN True ELSE False` — UNRESOLVED: source table not in lake catalog |
| 10 | `internal_shopper_flag` | boolean | `godaddy.rp_salesmonitor_internalshopper_snap` + `customers.customer_id_mapping_snapshot` | `shopper_id` + `id` | `CASE WHEN int_shopper_id IS NOT NULL THEN True WHEN len(cs_id) < 4 THEN True ELSE False` |
| 11 | `temporary_shopper_flag` | boolean | `signals_platform_cln.profile_audit_lake_cln_v2` | `email_hash` | `CASE WHEN pf_email_hash IS NULL THEN True ELSE False` — UNRESOLVED: source table not in lake catalog |
| 12 | `closed_shopper_flag` | boolean | `signals_platform_cln.profile_audit_lake_cln_v2` | `closed_date_utc_ts`, `deleted_flag` | `CASE WHEN (from_utc_timestamp(pf_closed_date_utc_ts) IS NOT NULL OR pf_deleted_flag = True) THEN True ELSE False` — UNRESOLVED |
| 13 | `city_name` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `city` | `pf_city AS city_name` — UNRESOLVED: source table not in lake catalog |
| 14 | `state_code` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `state_name` | `pf_state AS state_code` — UNRESOLVED |
| 15 | `zip_code` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `zip_code` | `pf_zipcode AS zip_code` — UNRESOLVED |
| 16 | `country_code` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `country_code` | `pf_country AS country_code`; also: `UPDATE ... SET country_code = 'GB' WHERE UPPER(country_code) = 'UK'` post-processing — UNRESOLVED |
| 17 | `email_domain_name` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `email_domain` | `pf_email_domain AS email_domain_name` — UNRESOLVED |
| 18 | `email_hash` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `email_hash` | `pf_email_hash AS email_hash` — UNRESOLVED |
| 19 | `primary_phone_flag` | boolean | `signals_platform_cln.profile_audit_lake_cln_v2` | `primary_phone_flag` | Direct (`pf_primary_phone_flag`) — UNRESOLVED |
| 20 | `mobile_phone_flag` | boolean | `signals_platform_cln.profile_audit_lake_cln_v2` | `mobile_phone_flag` | Direct (`pf_mobile_phone_flag`) — UNRESOLVED |
| 21 | `secondary_phone_flag` | boolean | `signals_platform_cln.profile_audit_lake_cln_v2` | `home_phone_flag` | `pf_home_phone_flag AS secondary_phone_flag` (note: rename from home to secondary) — UNRESOLVED |
| 22 | `default_currency_code` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `gdshop_currency_type` | `pf_gdshop_currency_type AS default_currency_code` — UNRESOLVED |
| 23 | `market_code` | string | `signals_platform_cln.profile_audit_lake_cln_v2` | `catalog_market_id` | `pf_catalog_market_id AS market_code` — UNRESOLVED |
| 24 | `created_mst_ts` | timestamp | `signals_platform_cln.profile_audit_lake_cln_v2` | `date_created_utc_ts` | `from_utc_timestamp(pf_date_created_utc_ts, 'MST')` — UNRESOLVED |
| 25 | `updated_mst_ts` | timestamp | `signals_platform_cln.profile_audit_lake_cln_v2` | `last_changed_date_utc_ts` | `from_utc_timestamp(pf_last_changed_date_utc_ts, 'MST')` — UNRESOLVED |
| 26 | `closed_mst_ts` | timestamp | `signals_platform_cln.profile_audit_lake_cln_v2` | `closed_date_utc_ts` | `from_utc_timestamp(pf_closed_date_utc_ts, 'MST')` — UNRESOLVED |
| 27 | `deleted_mst_ts` | timestamp | `signals_platform_cln.profile_audit_lake_cln_v2` | `closed_date_utc_ts` | `from_utc_timestamp(pf_closed_date_utc_ts, 'MST')` — same source column as `closed_mst_ts`; UNRESOLVED |
| 28 | `current_record_flag` | boolean | ETL-generated | — | Set to `True` on INSERT; set to `False` on SCD close (MERGE when `row_hash` changes or closed shopper); present in lake DDL but NOT projected in Redshift view |
| 29 | `etl_build_mst_ts` | timestamp | ETL-generated | — | `from_utc_timestamp(current_timestamp(), 'MST')` at INSERT time; not updated on SCD close |

**Note:** The Redshift view (`create_view.sql`) projects 30 columns: the 27 business columns (rows 1–27 above) + `current_record_flag` (row 28) is in the lake DDL but NOT in the Redshift view SELECT list + `etl_build_mst_ts` (row 29).

SCD-internal columns present in physical Iceberg table but **excluded from the published view** (`dim_customer_vw`): `row_hash`, `key_hash`, `effective_start_mst_ts`, `effective_end_mst_ts`, `etl_insert_mst_ts`, `etl_update_mst_ts` — these are ETL-generated and not sourced from upstream tables.

---

## Structured Facts Blocks (A1–E3)

### A — Table Identity

**A1 — Fully-qualified table name**
- FILL: `customer360.dim_customer_vw`
- Evidence: DAG `call_lake_api` task; lake registry `dlms-api/us-west-2/customer360/dim-customer-vw/table.yaml`

**A2 — Friendly name and purpose**
- FILL: "Customer Master Dimension — current record view. Provides one authoritative row per active GoDaddy customer, combining identity (FortKnox shopper), profile (audit events), federation partner (SSO), and internal account classification."
- Evidence: Confluence release notes (page 3829375759); Alation description ("Customer Master Data table"); `dim_customer_dag.py` policies description: "generates the customer eds dataset"

**A3 — Physical storage location**
- FILL: S3 `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/dim_customer_v2` (Iceberg format, ZSTD compression, target file size 128 MB)
- Evidence: `dim_customer_iceberg_common.py` `get_delta_dest_s3_path()` + `TBLPROPERTIES`

**A4 — Table type and format**
- FILL: Iceberg (Apache Iceberg via AWS Glue catalog; spark_catalog). Published as a Redshift view (`dim_customer_vw`) and Lake notification table.
- Evidence: `USING ICEBERG` in `create_dim_customer_iceberg_table_if_not_exists()`; lake `table.yaml` `table_type: ICEBERG`; DAG `dim_customer_rs_load` Redshift staging→promote→refresh workflow

**A5 — Data tier**
- FILL: Tier 2
- Evidence: `table.yaml` `data_tier: 2`

---

### B — Grain & Keys

**B1 — Grain (physical Iceberg table `customer_core_conformed.dim_customer`)**
- FILL: One row per (customer_id, SCD Type 2 period). A customer may have multiple rows; only one has `current_record_flag = True`.
- Evidence: SCD merge+insert logic in `dim_customer.py`; DQ constraint `.isPrimaryKey("customer_id", "effective_end_mst_ts")` in `dim_customer.json`

**B2 — Grain (published view `customer360.dim_customer_vw`)**
- FILL: One row per active customer. `current_record_flag = True` filter makes the view effectively customer_id-unique.
- Evidence: `create_view.sql` `WHERE current_record_flag = true`; DQ constraint `.isPrimaryKey("customer_id")` in `dim_customer_vw.json`

**B3 — Primary key**
- Physical Iceberg: `(customer_id, effective_end_mst_ts)` — composite
- Published view: `customer_id` — single column
- Evidence: `src/data_quality/constraints/dim_customer.json` and `dim_customer_vw.json`
- **Alation discrepancy:** Alation documents PK as `(customer_id, effective_end_mst_dt)` with `_dt` suffix (date type). Code uses `effective_end_mst_ts` (timestamp). Alation has a typo; code is authoritative.

**B4 — Unique keys**
- `shopper_id` is annotated `@UniqueKey` in lake `table.ddl` comment. NOT enforced as a hard constraint. A customer_id:shopper_id relationship is 1:1 in the current model.
- Evidence: `table.ddl` COMMENT `'@UniqueKey Unique numeric ID for the shopper profile'`
- MISSING: formal uniqueness enforcement evidence; treat as soft annotation only.

---

### C — Column Lineage

**C1 — Column-level lineage** ← See full table above.

**C2 — Computed / derived columns**
| Column | Formula | Inputs |
|---|---|---|
| `customer_id` | `lower(cs_customerid)` | `customers.customer_id_mapping_snapshot.customerid` |
| `parent_customer_id` | `lower(cs_customerid)` (same as customer_id in current model) | Same as above |
| `company_flag` | `CASE WHEN pf_organization_name NOT IN ('','DELETED') THEN True ELSE False END` | `profile_audit.organization_name` |
| `internal_shopper_flag` | `CASE WHEN int_shopper_id IS NOT NULL OR len(cs_id) < 4 THEN True ELSE False END` | Internal shopper list + customer mapping |
| `temporary_shopper_flag` | `CASE WHEN pf_email_hash IS NULL THEN True ELSE False END` | `profile_audit.email_hash` |
| `closed_shopper_flag` | `CASE WHEN pf_closed_date_utc_ts IS NOT NULL OR pf_deleted_flag = True THEN True ELSE False END` | `profile_audit.{closed_date_utc_ts, deleted_flag}` |
| `created_mst_ts` | `from_utc_timestamp(pf_date_created_utc_ts, 'MST')` | UTC→MST timezone conversion |
| `updated_mst_ts` | `from_utc_timestamp(pf_last_changed_date_utc_ts, 'MST')` | UTC→MST timezone conversion |
| `closed_mst_ts` | `from_utc_timestamp(pf_closed_date_utc_ts, 'MST')` | UTC→MST timezone conversion |
| `deleted_mst_ts` | `from_utc_timestamp(pf_closed_date_utc_ts, 'MST')` | Same as closed_mst_ts — uses same source column |
| `country_code` | Profile source + `UPDATE SET 'GB' WHERE UPPER(country_code) = 'UK'` | UK→GB normalization applied after SCD insert |
| `secondary_phone_flag` | `pf_home_phone_flag AS secondary_phone_flag` | Renamed from home to secondary |

**C3 — ETL-generated columns (no upstream source)**
| Column | Value | Notes |
|---|---|---|
| `effective_start_mst_ts` | `to_timestamp(snapshot_mst_date + ' 07:00:00')` | 07:00 MST = midnight UTC on snapshot date |
| `effective_end_mst_ts` | `to_utc_timestamp('9999-12-31 23:59:59', 'UTC')` | High date for open records |
| `current_record_flag` | `True` on insert; `False` set by SCD MERGE on change or closed shopper | SCD lifecycle flag |
| `row_hash` | SHA2-256 of 22 pipe-delimited attribute columns | Change detection hash |
| `key_hash` | SHA2-256 of `customer_id` | Iceberg merge join key |
| `etl_build_mst_ts` | `from_utc_timestamp(current_timestamp(), 'MST')` | Build timestamp; not updated on SCD close |
| `etl_insert_mst_ts` | `from_utc_timestamp(current_timestamp(), 'MST')` | Insert timestamp; not updated |
| `etl_update_mst_ts` | `from_utc_timestamp(current_timestamp(), 'MST')` at insert; updated on SCD MERGE close | Last update timestamp |

---

### D — Filters, Partitions & Scope

**D1 — Always-on filter (view layer)**
- FILL: `WHERE current_record_flag = True`
- Effect: The published view `dim_customer_vw` shows only the most recent active record per customer. Historical SCD records are only visible via `dim_customer_history_vw` (no filter).
- Evidence: `create_view.sql` template, `table.yaml` `data_filters.expression: current_record_flag = true`

**D2 — Partition specification**
- **Physical Iceberg table:** No partition spec defined. The `CREATE TABLE IF NOT EXISTS` in `dim_customer_iceberg_common.py` has no `PARTITIONED BY` clause.
- **CONFLICT:** `table.yaml` in lake registry declares `partition_keys: [{name: current_record_flag, type: boolean}]`. Code is authoritative — this is likely aspirational/stale metadata.
- Evidence: `dim_customer_iceberg_common.py` lines 128–177; `dlms-api/us-west-2/customer360/dim-customer-vw/table.yaml`

**D3 — Recommended always-filter (for Lake/EMR consumers)**
- FILL: `WHERE current_record_flag = True` — must be added **explicitly** by EMR/Lake consumers; the Lake Formation data_filter applies at Redshift/Glue level but is NOT functional on EMR jobs (confirmed in Alation documentation).
- Evidence: Alation entry 7022291 note: "lake filter `current_record_flag = true` is NOT functional on EMR jobs"

**D4 — Incremental scope restriction**
- FILL: `dim_customer.py` processes one `snapshot_mst_date` per invocation. The daily DAG dynamically maps across dates (typically 2 MST days: `run_date - 1` and `run_date`). Backfill mode can be triggered with `ice_rollback_calendar_days=N`.
- Evidence: DAG `load_customer_iceberg_emr_steps` dynamic mapping; `dim_customer.py:164–170` `WHERE partition_snap_mst_date = snapshot_mst_date`

**D5 — Universe / coverage**
- FILL: All GoDaddy customers with a `customer_id` in `customers.customer_id_mapping_snapshot`. Internal shoppers included (flagged). Temporary (guest) shoppers included but flagged. Private label (non-GoDaddy brand) customers included.
- Evidence: `get_tables()` and join logic in `dim_customer_daily_delta.py`; `internal_shopper_flag` / `temporary_shopper_flag` flags in DDL

---

### E — Operations, SLA & Consumers

**E1 — Schedule**
- FILL: `35 01 * * *` — daily at 01:35 UTC (18:35 MST the previous evening)
- Non-prod: manual trigger only (`None` schedule)
- Evidence: `dim_customer_dag.py` line 142

**E2 — SLA delivery target**
- FILL: Data delivered by 10:00 UTC (03:00 MST) daily
- Pipeline max duration: 90 minutes (severity: LOW)
- Evidence: `table.yaml` `deliveryCadenceUTC: cron(00 10 * * ? *)`; `dim_customer_dag.yaml` `maxDurationMins: 90`

**E3 — Team, ownership & contacts**
- Owner team: EDT
- On-call group: `DEV-EDT-OnCall`
- Slack alerts: `edt-airflow-alerts` (prod), `edt-airflow-alerts-low-priority` (non-prod)
- DAG ID: `dim_customer_dag`
- Historical baseline: data starts 2025-06-01 (no reconstructed history before this date)
- FortKnox deprecation deadline: 2025-09-30 (all consumers must migrate from `fortknox.fortknox_shopper_snap` to Customer360 by this date)
- Evidence: `dim_customer_dag.py`; Confluence page 3829375759 (release notes)

---

## Consumer Evidence (from Alation queries)

The 10 most recently saved Alation queries referencing `dim_customer_vw` indicate these active use patterns:

| Use Case Category | Joins Used | Example Query ID |
|---|---|---|
| OLS/Nemo vs. Bruce GMV/orders analysis | `customer_id` join to order tables | 136716 |
| Google migration C3 renewal attribution | `customer_id` join to `renewal_360` | 138294, 138854, 138761, 138773, 138967 |
| OLA onboarding + OLS seller sizing | `customer_id` join to commerce datasets | 139371, 133392, 135108 |
| COA fallback patches (test) | `customer_id` | 139445, 138773 |

**Dominant join pattern:** `JOIN dev.customer360.dim_customer_vw ON a.customer_id = b.customer_id`

**Consumer roles (27+ from `table.yaml`):** `ckpetlbatch`, `finance_data_mart`, `martech_data`, `analytics`, `data_platform`, `revenue_and_relevance`, `dri_data`, `cetinsights`, `feeddb`, `data_lab`, `ecomm_unified_query_store`, and others.

---

## Do Not Claim

The following items are tempting to document but are NOT proven by code evidence:

| Item | Why not claimable |
|---|---|
| `signals_platform_cln.profile_audit_lake_cln_v2` schema details (column types, SLA) | Table is NOT registered in `repos/lake/` catalog. No `table.yaml` or `table.ddl` found. Column names are inferred from `dim_customer_daily_delta.py` aliasing but the source table schema is unverified. |
| `global_profile_service_cln.profile_snapshot` is a daily upstream source | Only used in the 2025-06-01 bootstrap special case. Not a recurring daily dependency. |
| Two SSO tables (`sso_metadata_cln.federation_metadata_snapshot_cln`, `sso_permissions_cln.identity_mapping_snapshot_cln`) appear in `dim_customer_vw` lake lineage yaml | Lake `table.yaml` upstream_table_dependencies does NOT include these (only lists 5 older entries including two that are NOT confirmed in code). The SSO tables are correct sources of `dim_customer_attributes` but are not directly referenced in `dim_customer.py`. |
| `current_record_flag` is a partition key | Lake `table.yaml` claims this but code creates an unpartitioned Iceberg table. Cannot claim as true; conflict recorded. |
| `effective_end_mst_dt` (date type) is the PK companion column | Alation uses `_dt` suffix; DDL and code use `_ts` (timestamp). Do NOT use Alation's notation. |
| Row counts or approximate data volumes | No evidence in code or artifacts. |
| FortKnox deprecation is complete | Confluence release notes set deadline as Q3 2025 (Sept 30, 2025). As of analysis date (2026-06-09), the deprecation deadline has passed but no code change confirming removal is in scope of this analysis. |
| `parent_customer_id` is a true hierarchy field | In current code, `parent_customer_id = lower(cs_customerid)` — it's set to the same value as `customer_id`. No hierarchy traversal. May be intended for future use. |
| `deleted_mst_ts` represents a separate deletion event from `closed_mst_ts` | Both map to the same source column `pf_closed_date_utc_ts`. They are identical values in every row. |

---

---

## Analyst Summary (Stage: analyze)

### What was researched and done

**Files read:**
- `INPUT.md` — confirmed target identifier, lake override, source repo
- `gather.md` — consumed all gathered facts (PySpark identity, DAG workflow, DDL, conflicts, Alation, Confluence)
- `customer/dim-customer/src/pyspark/dim_customer.py` — primary ETL script; SCD merge+insert logic; source table references
- `customer/dim-customer/src/pyspark/dim_customer_iceberg_common.py` — Iceberg DDL, S3 path, DELTA_DEST_TABLE constant
- `customer/dim-customer/src/pyspark/dim_customer_daily_delta.py` — intermediate table builder; reads 5 lake sources
- `customer/dim-customer-attributes/src/pyspark/dim_customer_attributes.py` — intermediate table builder; reads 3 SSO lake sources

**Lake catalog files read (8 tables):**
- `dlms-api/us-west-2/customer360/dim-customer-vw/table.yaml` + `table.ddl` (target)
- `us-west-2/customers/customer-id-mapping-snapshot/table.yaml` + `table.ddl`
- `us-west-2/fortknox/fortknox-shopper-snap/table.yaml` + `table.ddl`
- `us-west-2/godaddy/rp-salesmonitor-internalshopper-snap/table.yaml` + `table.ddl`
- `us-west-2/sso-permissions-cln/identity-mapping-snapshot-cln/table.yaml` + `table.ddl`
- `us-west-2/sso-metadata-cln/federation-metadata-snapshot-cln/table.yaml` + `table.ddl`

**Unresolved:**
- `signals_platform_cln.profile_audit_lake_cln_v2` — confirmed upstream via DAG sensor but not found in lake catalog (schema `signals-platform-cln` does not exist; only `signals-platform` found). 17 of 27 target columns depend on this source.
- `global_profile_service_cln.profile_snapshot` — bootstrap-only (2025-06-01 special case); not found in catalog; not a daily lineage dependency.

**Key findings:**
1. Target confirmed as `customer360.dim_customer_vw` (high confidence — code + lake registry + DAG all consistent with override)
2. Two intermediate tables (`dim_customer_daily_delta`, `dim_customer_attributes`) fully resolved to 5 lake sources via recursive traversal
3. Two previously undocumented lake sources discovered: `sso_permissions_cln.identity_mapping_snapshot_cln` and `sso_metadata_cln.federation_metadata_snapshot_cln` (feed federation_partner_id/name via dim_customer_attributes)
4. Column `secondary_phone_flag` is mapped from `home_phone_flag` in source (renamed in ETL)
5. `deleted_mst_ts` and `closed_mst_ts` are identical values (same source column)
6. Lake yaml partition claim (`current_record_flag`) contradicts code (unpartitioned Iceberg table) — conflict logged

**RESOLVED_TARGET.json written** at `/tmp/moonunit-workspace/RESOLVED_TARGET.json`


**The agent's final response to the user was:**
Here is a summary of the research and work done for this analysis stage:

---

## Analysis Complete: `customer360.dim_customer_vw`

### Target Resolution
**High confidence.** The `lake_table_override` (`customer360/dim-customer-vw`) is fully consistent with code — the PySpark physically writes to `customer_core_conformed.dim_customer` (Iceberg), the DAG then registers `customer360.dim_customer_vw` as the published lake surface via `call_lake_api`. Lake registry entry confirmed at `dlms-api/us-west-2/customer360/dim-customer-vw/`.

### Deep Lineage Resolution (recursive traversal)

Two intermediate tables from `dim_customer.py` were fully traced:

1. **`customer_core_conformed.dim_customer_daily_delta`** → built by `dim_customer_daily_delta.py` → resolves to 5 lake sources:
   - `customers.customer_id_mapping_snapshot` ✅ (catalog found)
   - `fortknox.fortknox_shopper_snap` ✅ (catalog found)
   - `godaddy.rp_salesmonitor_internalshopper_snap` ✅ (catalog found)
   - `signals_platform_cln.profile_audit_lake_cln_v2` ⚠️ (UNRESOLVED — not in catalog, but DAG sensor confirms it exists; 17 of 29 target columns depend on it)
   - `global_profile_service_cln.profile_snapshot` ⚠️ (bootstrap-only, 2025-06-01 special case only)

2. **`customer_core_conformed.dim_customer_attributes`** → built by `dim_customer_attributes.py` → resolves to 3 lake sources:
   - `customers.customer_id_mapping_snapshot` ✅
   - `sso_permissions_cln.identity_mapping_snapshot_cln` ✅ (catalog found — feeds `federation_partner_id`)
   - `sso_metadata_cln.federation_metadata_snapshot_cln` ✅ (catalog found — feeds `federation_partner_name`)

### Key Findings
- **29 columns mapped** with source tracing; 17 depend on `signals_platform_cln.profile_audit_lake_cln_v2` (UNRESOLVED in catalog)
- `secondary_phone_flag` ← renamed from `home_phone_flag` in source
- `deleted_mst_ts` and `closed_mst_ts` are **identical** (same source column `pf_closed_date_utc_ts`)
- `parent_customer_id` = same value as `customer_id` in current model
- Lake registry `partition_keys: [current_record_flag]` **contradicts** code (Iceberg table is unpartitioned)
- `RESOLVED_TARGET.json` written with `confidence: "high"`