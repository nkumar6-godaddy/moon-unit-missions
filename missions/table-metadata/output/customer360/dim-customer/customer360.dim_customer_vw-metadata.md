# Business Context: customer360.dim_customer_vw

## Pillar A: WHAT Is It? — Identity & Purpose

### A1. Table Overview

| Attribute | Value |
|---|---|
| Table Name | `dim_customer_vw` |
| Database | Redshift - Serverless - Dev |
| Schema | `customer360` |
| Alation URL | [https://godaddy.alationcloud.com/table/7027529/](https://godaddy.alationcloud.com/table/7027529/) |
| Lake Alation URL | [https://godaddy.alationcloud.com/table/7022291/](https://godaddy.alationcloud.com/table/7022291/) |
| Lake Table | `customer360.dim_customer_vw` |
| Physical Iceberg Table | `customer_core_conformed.dim_customer` |
| History View | `customer360.dim_customer_history_vw` |
| Grain | One row per **active** GoDaddy customer (`current_record_flag = True`); physical table: one row per customer per SCD Type 2 period |
| Primary Key (view) | `customer_id` |
| Primary Key (physical table) | `(customer_id, effective_end_mst_ts)` |
| Partition Key | None — physical Iceberg table is unpartitioned (see C4 for conflict with lake registry) |
| Storage Format | Apache Iceberg · Parquet · ZSTD compression |
| S3 Location | `s3://gd-ckpetlbatch-{env}-customer-core-conformed/customer_core_conformed/dim_customer_v2` |
| Data Tier | 2 |
| SLA Delivery | By 10:00 UTC (03:00 MST) daily |
| Refresh Cadence | Daily — DAG starts 01:35 UTC; max pipeline duration 90 min |
| DAG ID | `dim_customer_dag` |
| Owner / Team | EDT |
| Historical Baseline | 2025-06-01 (no change history before this date) |

### A2. What This Table Is About

`customer360.dim_customer_vw` is GoDaddy's authoritative **Customer Master Dimension**. It provides one canonical row per active GoDaddy customer, combining:

- **Identity data** — customer UUID and shopper ID linkage from the customer mapping registry
- **Profile attributes** — location (city/state/zip/country), contact flags (primary/mobile/secondary phone), email domain, currency, and market from the Signals profile audit platform
- **Account classification** — boolean flags for internal employees, temporary/guest shoppers, closed/merged accounts, and company accounts
- **Federation partner data** — SSO reseller partner identifier and name
- **Lifecycle timestamps** — account creation, last update, closure, and deletion in MST

Launched as part of **Customer360 v1.0** (released 2025-06-16), this table is the first implementation of GoDaddy's 360 data product architecture and is the designated replacement for `fortknox.fortknox_shopper_snap`, which was deprecated in Q3 2025. The view exposes only the current (most recent) record per customer; full SCD history is available in `customer360.dim_customer_history_vw`.

### A3. Organizational Context & Ownership

| Attribute | Value |
|---|---|
| Owner / Team | EDT |
| On-call Group | `DEV-EDT-OnCall` |
| Slack Alerts (prod) | `edt-airflow-alerts` |
| Slack Alerts (non-prod) | `edt-airflow-alerts-low-priority` |
| Data Domain | Customer360 |
| Consumer Roles | 27+ registered roles (e.g., `finance_data_mart`, `martech_data`, `analytics`, `data_platform`, `revenue_and_relevance`, `dri_data`, `cetinsights`) |
| Release Version | v1.0.0 (2025-06-16) |
| Confluence | [Customer360 - v1.0 Dim Customer Release Notes](https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3829375759/Customer360+-+v1.0+Dim+Customer+Release+Notes) |

---

## Pillar B: WHY Does It Matter? — Value & Use Cases

### B1. Key Business Value

- **Single source of truth for customer identity.** Replaces fragmented lookups across FortKnox, Signals, and SSO systems with one governed, versioned dimension that every team uses the same way.
- **Current-record simplicity.** The view surfaces only active records (`current_record_flag = True`), making `customer_id` the unique key — no deduplication needed for most use cases.
- **Full change history preserved.** SCD Type 2 tracks attribute changes over time (since 2025-06-01). History is accessible via `customer360.dim_customer_history_vw`.
- **Built-in account segmentation.** Boolean flags for internal, temporary, closed, and company accounts enable fast, accurate population scoping without custom logic.
- **FortKnox migration enablement.** Designated replacement for `fortknox.fortknox_shopper_snap` (deprecated Q3 2025, deadline 2025-09-30). All downstream consumers must migrate to Customer360.
- **Enterprise reach.** Tier 2 data product consumed by 27+ role groups spanning finance, marketing, analytics, revenue, and commerce teams.

### B2. Primary Use Cases

**Questions this table answers:**

- Who is a GoDaddy customer and what are their current contact and demographic attributes (city, state, country, phone flags, email domain)?
- Which customers are active vs. closed or merged?
- Which customers belong to reseller / federation partner programs, and who are those partners?
- Which customers are internal GoDaddy employees or test shoppers?
- Which customers are temporary (guest) accounts without a verified email?
- What currency and market context does a customer operate in?
- What is the `shopper_id` for a given `customer_id` (or vice versa)?
- When was a customer account created, last updated, or closed?
- How many active customers exist by country, market, or federation partner?

**Alation Queries**

#### Query: OLS Monthly Summary

| Field | Value |
|---|---|
| Query ID | 136716 |
| Title | OLS Monthly Summary |
| Author | Unknown |
| Description | Compares online store (OLS/Nemo vs Bruce) monthly GMV, orders, and sellers; joins `dim_customer_vw` to `central_service_ols_order` on `customer_id` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/136716/ |

```sql
select
  b.shopper_id,
  order_num as order_number,
  to_date(order_utc_ts,'YYYY-MM') as order_date,
  sum(gmv_usd_amt) as gmv_in_usd
from ckp_analytic_share.dna_approved.central_service_ols_order a
inner join dev.customer360.dim_customer_vw b on a.customer_id = b.customer_id
where a.order_status != 'DRAFT'
```

#### Query: Google Migration Query -latest

| Field | Value |
|---|---|
| Query ID | 138294 |
| Title | Google Migration Query -latest |
| Author | Unknown |
| Description | PROD Google migration progressive C3 renewals via `renewal_360`; outputs to `dev.ba_dri.goog_migrations_final_progressive` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138294/ |

```sql
/*=====================================================================
  Google Migration -- PROD (PROGRESSIVE C3 RENEWALS via renewal_360)
  Output: dev.ba_dri.goog_migrations_final_progressive
  Schedule: 0 9,14,17 * * * America/New_York
...
-- Full SQL available at https://godaddy.alationcloud.com/query/138294/
```

#### Query: Google Migration — COA Fallback Patch TEST

| Field | Value |
|---|---|
| Query ID | 139445 |
| Title | Google Migration — COA Fallback Patch TEST |
| Author | Unknown |
| Description | TEST version of PROD Google migration query; COA fallback patch; references `dev.customer360.dim_customer_vw` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/139445/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

#### Query: Commerce Queries - Rishabh

| Field | Value |
|---|---|
| Query ID | 139371 |
| Title | Commerce Queries - Rishabh |
| Author | Unknown |
| Description | OLA onboarding and OLS combined seller analysis; references `dev.customer360.dim_customer_vw` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/139371/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

#### Query: OLA Sizing - M365

| Field | Value |
|---|---|
| Query ID | 133392 |
| Title | OLA Sizing - M365 |
| Author | Unknown |
| Description | Monthly bookings and order sizing for OLA (M365); joins `dim_customer_vw` for customer attributes |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/133392/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

#### Query: OLS Sizing Analysis

| Field | Value |
|---|---|
| Query ID | 135108 |
| Title | OLS Sizing Analysis |
| Author | Unknown |
| Description | OLS bookings sizing analysis by month; references `dev.customer360.dim_customer_vw` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/135108/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

#### Query: shopper merge all cohorts -google migration test

| Field | Value |
|---|---|
| Query ID | 138967 |
| Title | shopper merge all cohorts -google migration test |
| Author | Unknown |
| Description | TEST: Google migration with shopper merge applied to all cohorts; references `dev.customer360.dim_customer_vw` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138967/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

#### Query: renewals -google migration test version

| Field | Value |
|---|---|
| Query ID | 138854 |
| Title | renewals -google migration test version |
| Author | Unknown |
| Description | TEST: Google migration C3 renewals via `dev.dna_approved.renewal_360`; references `dev.customer360.dim_customer_vw` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138854/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

#### Query: Google Migration — TEST (COA fallback for missing domaininfo_snap)

| Field | Value |
|---|---|
| Query ID | 138773 |
| Title | Google Migration — TEST (COA fallback for missing domaininfo_snap) |
| Author | Unknown |
| Description | TEST: COA fallback built on top of query 138761; references `dev.customer360.dim_customer_vw` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138773/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

#### Query: Google Migration — TEST (shopper_merge metric for C3)

| Field | Value |
|---|---|
| Query ID | 138761 |
| Title | Google Migration — TEST (shopper_merge metric for C3) |
| Author | Unknown |
| Description | TEST PATCH: C3 shopper merge metric; output `goog_migrations_final_draft`; references `dev.customer360.dim_customer_vw` |
| Schedule | Not scheduled |
| Last Saved | Unknown |
| Last Run | Unknown |
| Datasource | Redshift Serverless Dev (datasource 132) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138761/ |

```sql
-- Full SQL available at Alation Query URL above (not captured in gather phase)
```

### B3. Advanced Analytics Use Cases

- **Google Ads / C3 renewal attribution.** Mapping GoDaddy customer segments to Google migration cohorts for progressive C3 renewal analysis. Joins `dim_customer_vw` with `renewal_360` on `customer_id` to attribute renewals by customer profile (Alation queries 138294, 138854, 138761, 138773, 138967).
- **OLS / OLA seller sizing.** Measuring GMV and order activity by customer segment for OLS (Online Store) and OLA (Online Listings) products. Joins `dim_customer_vw` to commerce order tables on `customer_id` (queries 136716, 135108, 133392, 139371).
- **Internal / temporary shopper exclusion.** Analytics teams use `internal_shopper_flag = False AND temporary_shopper_flag = False` to restrict analysis to external, permanent customer accounts.
- **Private label / reseller segmentation.** `private_label_id`, `federation_partner_id`, and `federation_partner_name` enable analysis scoped to specific GoDaddy reseller brands or SSO partner channels.
- **Customer lifecycle and cohort analysis.** Using `created_mst_ts`, `closed_mst_ts`, and SCD change history (via `dim_customer_history_vw`) to analyze cohort behavior over time (history available from 2025-06-01).

---

## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance

### C1. Complete Column Reference with Data Insights

> **Source Table(s) column** shows the first upstream lake table in the lineage chain. Intermediate tables (`customer_core_conformed.dim_customer_daily_delta`, `customer_core_conformed.dim_customer_attributes`) are internal implementation details and are not listed. `current_record_flag` appears in the lake DDL but is not projected in the Redshift view.

<!-- REQUIRES_MANUAL_INPUT: DE -->
Source table `signals_platform_cln.profile_audit_lake_cln_v2` is confirmed upstream (DAG sensor present) but is not registered in the lake catalog. Column descriptions for rows 8–27 are inferred from ETL alias names and cannot be verified against a registered DDL.

| # | Column | Type | Description | Source Table(s) | Transformation / Notes |
|---|---|---|---|---|---|
| 1 | `customer_id` | string | Primary key. GoDaddy-internal UUID identifying the customer account. `@PrimaryKey` annotation in lake DDL. | `customers.customer_id_mapping_snapshot` | `lower(cs_customerid)` — lowercased UUID |
| 2 | `shopper_id` | string | Legacy numeric shopper ID from FortKnox. `@UniqueKey` annotation in lake DDL (soft — not hard-enforced). 1:1 with `customer_id` in current model. | `customers.customer_id_mapping_snapshot` | Direct pass-through (`cs_id AS shopper_id`) |
| 3 | `external_reseller_customer_id` | int | External (non-GoDaddy) customer ID assigned by a reseller. Null for direct GoDaddy customers. | `fortknox.fortknox_shopper_snap` | `ft_externalid AS external_reseller_customer_id` |
| 4 | `federation_partner_id` | string | SSO / reseller federation partner namespace identifier. Null for standard GoDaddy customers. | `sso_permissions_cln.identity_mapping_snapshot_cln` | Most recent active `namespace_id` for this customer, via `dim_customer_attributes` |
| 5 | `federation_partner_name` | string | Human-readable name of the federation / reseller partner. | `sso_metadata_cln.federation_metadata_snapshot_cln` | `brand_name` joined on `federation_partner_id`, via `dim_customer_attributes` |
| 6 | `parent_customer_id` | string | In current model, always equals `customer_id`. Reserved for future account hierarchy use. | `customers.customer_id_mapping_snapshot` | `lower(cs_customerid)` — same value as `customer_id` |
| 7 | `parent_shopper_id` | string | Parent shopper ID from FortKnox; used for reseller / sub-account hierarchies. | `fortknox.fortknox_shopper_snap` | `ft_parent_shopper_id AS parent_shopper_id` |
| 8 | `private_label_id` | int | GoDaddy private-label (reseller brand) store identifier. Value `1` typically represents direct GoDaddy. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED** — not in lake catalog) | `CAST(pf_private_label_id AS INT)` |
| 9 | `company_flag` | boolean | True if the customer registered with a company / organization name. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `CASE WHEN pf_organization_name NOT IN ('','DELETED') THEN True ELSE False END` |
| 10 | `internal_shopper_flag` | boolean | True if the customer is a GoDaddy internal employee, test account, or has a short numeric shopper ID. | `godaddy.rp_salesmonitor_internalshopper_snap` + `customers.customer_id_mapping_snapshot` | `CASE WHEN int_shopper_id IS NOT NULL OR len(cs_id) < 4 THEN True ELSE False END` |
| 11 | `temporary_shopper_flag` | boolean | True if the account is a temporary / guest shopper with no verified email. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `CASE WHEN pf_email_hash IS NULL THEN True ELSE False END` |
| 12 | `closed_shopper_flag` | boolean | True if the account has been closed, deleted, or merged in the source system. Records with this flag True and `current_record_flag = True` are SCD-closed in the next run. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `CASE WHEN pf_closed_date_utc_ts IS NOT NULL OR pf_deleted_flag = True THEN True ELSE False END` |
| 13 | `city_name` | string | Customer city from profile. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_city AS city_name` |
| 14 | `state_code` | string | Customer state / province code from profile. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_state AS state_code` |
| 15 | `zip_code` | string | Customer postal / zip code from profile. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_zipcode AS zip_code` |
| 16 | `country_code` | string | ISO country code. UK values are normalized to `GB` post-SCD. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_country AS country_code`; post-insert `UPDATE SET country_code = 'GB' WHERE UPPER(country_code) = 'UK'` |
| 17 | `email_domain_name` | string | Domain portion of the customer's registered email (e.g., `gmail.com`). | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_email_domain AS email_domain_name` |
| 18 | `email_hash` | string | Hash of the customer's email address. Privacy-safe join key. Null for temporary shoppers. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_email_hash AS email_hash` |
| 19 | `primary_phone_flag` | boolean | True if a primary phone number is registered on the account. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | Direct (`pf_primary_phone_flag`) |
| 20 | `mobile_phone_flag` | boolean | True if a mobile phone number is registered on the account. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | Direct (`pf_mobile_phone_flag`) |
| 21 | `secondary_phone_flag` | boolean | True if a secondary (home) phone number is registered. **Renamed from `home_phone_flag` in the source system.** | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_home_phone_flag AS secondary_phone_flag` |
| 22 | `default_currency_code` | string | Customer's default currency code (e.g., `USD`, `GBP`). | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_gdshop_currency_type AS default_currency_code` |
| 23 | `market_code` | string | Customer's catalog market identifier. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `pf_catalog_market_id AS market_code` |
| 24 | `created_mst_ts` | timestamp | Account creation timestamp in MST. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `from_utc_timestamp(pf_date_created_utc_ts, 'MST')` |
| 25 | `updated_mst_ts` | timestamp | Last attribute update timestamp in MST. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `from_utc_timestamp(pf_last_changed_date_utc_ts, 'MST')` |
| 26 | `closed_mst_ts` | timestamp | Account closure timestamp in MST. Null for open accounts. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | `from_utc_timestamp(pf_closed_date_utc_ts, 'MST')` |
| 27 | `deleted_mst_ts` | timestamp | Deletion timestamp in MST. **Currently identical to `closed_mst_ts`** — both map to the same source column. | `signals_platform_cln.profile_audit_lake_cln_v2` (**UNRESOLVED**) | Same source column as `closed_mst_ts` (`pf_closed_date_utc_ts`) |
| 28 | `current_record_flag` | boolean | SCD Type 2 current-record indicator. `True` = most recent record for this customer. Present in lake DDL; **not projected in Redshift view** (used in WHERE clause only). | ETL-generated | `True` on INSERT; set to `False` by SCD MERGE on `row_hash` change or `closed_shopper_flag = True` |
| 29 | `etl_build_mst_ts` | timestamp | Timestamp when this record was inserted by the ETL job (MST). Not updated on SCD close. | ETL-generated | `from_utc_timestamp(current_timestamp(), 'MST')` at INSERT time |

### C2. Primary Key & Performance

| Attribute | Value |
|---|---|
| Primary Key (view — `dim_customer_vw`) | `customer_id` — single column; each active customer appears exactly once |
| Primary Key (physical — `customer_core_conformed.dim_customer`) | `(customer_id, effective_end_mst_ts)` — composite; supports multiple SCD periods per customer |
| Unique Key (soft annotation) | `shopper_id` — `@UniqueKey` in lake DDL; 1:1 with `customer_id` in current model; not hard-enforced |
| Redshift DISTKEY | `customer_id` (on Redshift staging table) |
| Iceberg Partition | None — physical Iceberg table is unpartitioned (see C4) |
| Recommended Filter | `WHERE current_record_flag = True` for any direct Lake / EMR access (built into Redshift view; must be added explicitly for Iceberg / Spark consumers) |

### C3. Key Features, Capabilities & Limitations

**Features:**

- **SCD Type 2 design.** Customer attribute changes are preserved as historical rows. Use `customer360.dim_customer_history_vw` to query full change history.
- **Current-record view.** `dim_customer_vw` always reflects the most recent state per customer. `customer_id` is unique — no deduplication required.
- **UK→GB country normalization.** `country_code = 'UK'` is normalized to `GB` as a post-SCD step. Consumers receive ISO-standard codes.
- **Account classification flags.** Built-in boolean flags for internal, temporary, closed, and company accounts allow fast, standardized population filtering.
- **Dual surface.** Available as a Redshift view (`dev.customer360.dim_customer_vw`) and a Lake Iceberg table — supporting SQL and Spark/EMR consumers from the same physical data.

**Limitations:**

- **Historical baseline starts 2025-06-01.** No SCD change history exists before this date. Audit data is available from 2025-04-01 but full reconstruction was deemed too costly.
- **Lake Formation filter not functional on EMR.** The data filter (`current_record_flag = True`) configured in Lake Formation does not apply automatically when accessing the table via EMR/Spark. Always add the filter explicitly.
- **`signals_platform_cln.profile_audit_lake_cln_v2` lineage unresolved.** Seventeen of 29 view columns originate from this source, which is not registered in the lake catalog. Column-level documentation relies on ETL alias inference.
- **FortKnox dependency.** `fortknox.fortknox_shopper_snap` (source of `external_reseller_customer_id` and `parent_shopper_id`) was scheduled for deprecation 2025-09-30.

### C4. Important Notes & Pitfalls

1. **Always filter `current_record_flag = True` for EMR / Lake access.** The Redshift view applies this automatically. The Lake Formation filter does not work on EMR jobs (confirmed in Alation). Failing to add this filter on the physical Iceberg table or history view returns all historical SCD rows.

2. **Column name discrepancy in Alation.** Alation documentation lists the composite PK companion column as `effective_end_mst_dt` (date suffix). The correct column name is `effective_end_mst_ts` (timestamp suffix). This is a documentation error in Alation; do not use `effective_end_mst_dt` in queries or code.

3. **`deleted_mst_ts` and `closed_mst_ts` are always identical.** Both map to the same source field (`pf_closed_date_utc_ts`). Do not treat them as independent events.

4. **`parent_customer_id` is not a hierarchy field.** In the current ETL implementation it is set to the same value as `customer_id`. Do not use it for parent–child account traversal — this may change in a future version.

5. **Partition key conflict in lake registry.** The lake `table.yaml` declares `current_record_flag` as a partition key. The PySpark code creates the Iceberg table with no partition specification. The code is authoritative — the table is unpartitioned. Do not rely on partition pruning for `current_record_flag`.

6. **`current_record_flag` availability by surface.** This column exists in the lake / Iceberg DDL but is **not projected** in the Redshift view SELECT list. It is used in the WHERE clause but consumers cannot SELECT it from the view. Access it only via the physical Iceberg table or history view.

### C5. Always-On Column Filters

| Surface | Filter Applied Automatically | Action Required |
|---|---|---|
| Redshift view (`dev.customer360.dim_customer_vw`) | `WHERE current_record_flag = True` — built into view DDL | None — view is pre-filtered |
| Lake / EMR (Iceberg physical table) | **Not automatic** — Lake Formation filter is not functional on EMR | Add `WHERE current_record_flag = True` explicitly |
| History view (`customer360.dim_customer_history_vw`) | None | Returns all SCD periods for all customers |

### C6. Common Business Metrics

| Metric | Definition | Recommended Filter |
|---|---|---|
| Active customer count | `COUNT(DISTINCT customer_id)` | Use view (filter built in) |
| External permanent customer count | `COUNT(DISTINCT customer_id) WHERE internal_shopper_flag = False AND temporary_shopper_flag = False` | Use view + flags |
| Customers by country | `COUNT(DISTINCT customer_id) GROUP BY country_code` | Use view |
| Reseller / partner customers | `COUNT(DISTINCT customer_id) WHERE federation_partner_id IS NOT NULL` | Use view |
| Closed accounts (pending SCD close) | `COUNT(DISTINCT customer_id) WHERE closed_shopper_flag = True` | Use view |
| Company / organization accounts | `COUNT(DISTINCT customer_id) WHERE company_flag = True` | Use view |

### C7. Glossary & Term Definitions

| Term | Definition |
|---|---|
| `customer_id` | GoDaddy-internal UUID identifying a customer account. Lowercased. Primary key of the view. |
| `shopper_id` | Legacy numeric identifier from the FortKnox shopper registry. Soft unique key; 1:1 with `customer_id` in current model. |
| `current_record_flag` | SCD Type 2 indicator. `True` = most recent row for this `customer_id`. `False` = a superseded historical row, or a closed account awaiting SCD close. |
| SCD Type 2 | Slowly Changing Dimension Type 2 — preserves historical rows when attribute values change, enabling point-in-time analysis. |
| `federation_partner_id` | SSO namespace identifier for a reseller or white-label partner through which a customer registered. |
| `private_label_id` | Integer identifier for a GoDaddy private-label (reseller brand) store. `1` typically represents direct GoDaddy. |
| `internal_shopper_flag` | True if the customer is a GoDaddy employee, test account, or has a short numeric `shopper_id` (length < 4). |
| `temporary_shopper_flag` | True if the account has no verified email (`email_hash IS NULL`) — typically a guest or checkout account. |
| `closed_shopper_flag` | True if the customer profile has been closed, deleted, or merged in the source system. |
| `row_hash` | SHA2-256 hash of 22 business attribute columns used to detect attribute changes between SCD periods. Present in physical Iceberg table only; excluded from published view. |
| `key_hash` | SHA2-256 hash of `customer_id` used as the MERGE key in the SCD operation. Physical table only. |
| `effective_start_mst_ts` | Start timestamp of this SCD period (07:00 MST = midnight UTC on the snapshot date). Physical table only. |
| `effective_end_mst_ts` | End timestamp of this SCD period. Value `9999-12-31 23:59:59` for the current (open) record. Physical table only. |
| `etl_build_mst_ts` | Timestamp when the ETL job inserted this row (MST). Not updated on SCD close. |
| Customer360 | GoDaddy's canonical customer data domain and first implementation of the 360 data product architecture. |

### C8. Example Queries & Patterns

**Pattern 1 — Look up a customer's current profile (Redshift)**

```sql
-- The view already filters to current_record_flag = True
SELECT *
FROM dev.customer360.dim_customer_vw
WHERE customer_id = '<uuid>';
```

**Pattern 2 — Count active external customers by country (Redshift)**

```sql
SELECT country_code,
       COUNT(DISTINCT customer_id) AS customer_count
FROM dev.customer360.dim_customer_vw
WHERE internal_shopper_flag = False
  AND temporary_shopper_flag = False
GROUP BY country_code
ORDER BY customer_count DESC;
```

**Pattern 3 — Join to an order / transaction table (Redshift)**

```sql
-- Standard join pattern used across Alation queries
SELECT o.order_id, c.customer_id, c.country_code, c.federation_partner_id
FROM <order_table> o
JOIN dev.customer360.dim_customer_vw c
  ON o.customer_id = c.customer_id;
```

**Pattern 4 — Access physical Iceberg table via Spark / EMR**

```python
# IMPORTANT: Lake Formation filter is NOT functional on EMR.
# Always add current_record_flag filter explicitly.
df = spark.table("customer_core_conformed.dim_customer") \
          .filter("current_record_flag = True")
```

**Pattern 5 — Historical attribute lookup across SCD periods**

```sql
-- Use dim_customer_history_vw for all SCD rows (no current_record_flag filter applied)
SELECT customer_id, country_code, effective_start_mst_ts, effective_end_mst_ts
FROM dev.customer360.dim_customer_history_vw
WHERE customer_id = '<uuid>'
ORDER BY effective_start_mst_ts;
```

---

## Pillar D: HOW Is It Built? — Pipeline & Provenance

### D1. Data Source Reference

| Lake Source Table | Schema | Role in Pipeline | Catalog Status |
|---|---|---|---|
| `customers.customer_id_mapping_snapshot` | customers | Customer UUID ↔ shopper_id mapping; anchor of the dimension | Registered |
| `fortknox.fortknox_shopper_snap` | fortknox | Provides `external_reseller_customer_id`, `parent_shopper_id`; deprecated Q3 2025 | Registered |
| `godaddy.rp_salesmonitor_internalshopper_snap` | godaddy | Internal shopper list used to derive `internal_shopper_flag` | Registered |
| `signals_platform_cln.profile_audit_lake_cln_v2` | signals_platform_cln | Profile attributes: location, email, phone, currency, market, timestamps — source of 17 of 29 columns | **UNRESOLVED — not in lake catalog** |
| `sso_permissions_cln.identity_mapping_snapshot_cln` | sso_permissions_cln | Federation partner ID (via intermediate `dim_customer_attributes`) | Registered |
| `sso_metadata_cln.federation_metadata_snapshot_cln` | sso_metadata_cln | Federation partner name (via intermediate `dim_customer_attributes`) | Registered |

<!-- REQUIRES_MANUAL_INPUT: DE -->
`signals_platform_cln.profile_audit_lake_cln_v2` is confirmed as an upstream dependency (DAG `wait_profile_audit` S3KeySensor monitors its success path) but is not registered in the lake catalog. Schema details, SLA, and ownership are unavailable and require input from the owning team.

### D2. Data Pipeline & Infrastructure

| Attribute | Value |
|---|---|
| Source Repo | `gdcorp-dna/dof-dpaas-customer-feature` (branch: `main`) |
| PySpark Script | `customer/dim-customer/src/pyspark/dim_customer.py` |
| Shared Module | `customer/dim-customer/src/pyspark/dim_customer_iceberg_common.py` |
| DAG File | `customer/dim-customer/src/dag/dim_customer_dag.py` |
| DAG ID | `dim_customer_dag` |
| Orchestration | Apache Airflow |
| Compute | AWS EMR 7.2.0 · ARM64 · m6g.2xlarge × 8 core + 1 master |
| Iceberg Runtime | `/usr/share/aws/iceberg/lib/iceberg-spark3-runtime.jar` |
| Glue Catalog | AWS Glue (`GlueCatalog`) |
| Redshift Load | S3 COPY from manifest → staging table → swap (`promote_to_prod.sql`) → view refresh |

**Pipeline flow (summary):**

1. DAG waits for 5 upstream S3 success signals (3 S3KeySensors, 2 PythonSensors)
2. EMR cluster is created (m6g.2xlarge, ARM64)
3. `dim_customer_daily_delta.py` runs to build the intermediate delta table
4. `dim_customer.py` runs per MST date (dynamically mapped; typically `run_date - 1` and `run_date`) — SCD MERGE + INSERT into Iceberg physical table
5. EMR cluster terminates
6. Redshift load: S3 COPY manifest → staging → promote → view refresh
7. Lake API called to register completion for `customer360.dim_customer_vw` and `customer360.dim_customer_history_vw`

### D3. SLA & Refresh Schedule

| Attribute | Value |
|---|---|
| Schedule (prod) | `35 01 * * *` — daily at 01:35 UTC (18:35 MST previous evening) |
| Schedule (non-prod) | Manual trigger only (`None`) |
| Max Pipeline Duration | 90 minutes (SLA severity: LOW) |
| SLA Delivery Target | By 10:00 UTC (03:00 MST) daily |
| Normal Scope per Run | 2 MST dates (`run_date - 1` and `run_date`; `ice_rollback_calendar_days = 1`) |
| Backfill Mode | `ice_rollback_calendar_days = N` loads N days ending at `run_date` |
| Retries | 2 |
| Max Active Runs | 1 |
| Catchup | Disabled |

### D4. Table Creation & ETL Implementation

**Physical Iceberg table creation:**
`dim_customer_iceberg_common.py` — `create_dim_customer_iceberg_table_if_not_exists()` issues `CREATE TABLE IF NOT EXISTS customer_core_conformed.dim_customer USING ICEBERG` with ZSTD compression (`write_compression = 'zstd'`), 128 MB target file size, and no partition specification.

**SCD Type 2 merge logic (`dim_customer.py`):**

1. **MERGE (SCD close):** For existing current records where `row_hash` has changed → set `current_record_flag = False`, `effective_end_mst_ts = effective_start_mst_ts - 1 second`
2. **INSERT (new / changed rows):** New `key_hash` values or changed `row_hash` values → insert with `current_record_flag = True`, `effective_end_mst_ts = '9999-12-31 23:59:59'`
3. **MERGE (closed shoppers):** Rows with `current_record_flag = True AND closed_shopper_flag = True` → set `current_record_flag = False`, `effective_end_mst_ts = snapshot_mst_date 07:00:00`
4. **UPDATE (UK→GB normalization):** `SET country_code = 'GB' WHERE UPPER(country_code) = 'UK'`

**Published view creation:**
DAG task `dim_customer_rs_load` runs a Redshift COPY from the S3 manifest, swaps the staging table into production (`promote_to_prod.sql`), then creates `customer360.dim_customer_vw` via `create_view.sql` — selecting 28 columns with `WHERE current_record_flag = True WITH NO SCHEMA BINDING`.

**Lake registration:**
DAG task `call_lake_api` posts completion for `customer360.dim_customer_vw`; `call_lake_api_hist` posts for `customer360.dim_customer_history_vw`.

---

## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem

### E1. Data Quality Checks

Data quality constraints are defined in `customer/dim-customer/src/data_quality/constraints/`:

| Constraint File | Target Table | Constraint | Definition |
|---|---|---|---|
| `dim_customer.json` | `customer_core_conformed.dim_customer` (physical) | Composite Primary Key | `.isPrimaryKey("customer_id", "effective_end_mst_ts")` — no duplicate `(customer_id, effective_end_mst_ts)` pairs |
| `dim_customer_vw.json` | `customer360.dim_customer_vw` (view) | Single-column Primary Key | `.isPrimaryKey("customer_id")` — each active customer appears exactly once |

<!-- REQUIRES_MANUAL_INPUT: DG -->
The complete DQ constraint inventory (null checks, referential integrity, value range rules) beyond primary key definitions was not captured. Review `src/data_quality/constraints/` in the source repo for the full list.

### E2. Best Practices & Tips

1. **Use the Redshift view for SQL analytics.** Access `dev.customer360.dim_customer_vw` — the `current_record_flag` filter is pre-applied and `customer_id` is unique. No additional filtering needed.

2. **Always add `WHERE current_record_flag = True` for EMR / Spark.** The Lake Formation filter is not functional on EMR. Accessing `customer_core_conformed.dim_customer` without this filter returns all historical SCD rows, which is likely a much larger dataset than intended.

3. **Use `dim_customer_history_vw` for time-series analysis.** For point-in-time or change-detection queries, use `customer360.dim_customer_history_vw` and filter on `effective_start_mst_ts <= <target_date> AND effective_end_mst_ts >= <target_date>`.

4. **Do not use `effective_end_mst_dt`.** This column name (with `_dt` suffix) appears in Alation documentation and is a documentation error. The correct column name is `effective_end_mst_ts`.

5. **Filter out internal and temporary shoppers** for external customer analytics: `WHERE internal_shopper_flag = False AND temporary_shopper_flag = False`.

6. **Do not treat `deleted_mst_ts` and `closed_mst_ts` as independent events.** They always contain the same value (same source column).

7. **`parent_customer_id` is not usable as a hierarchy join** — it equals `customer_id` in the current implementation.

8. **Account for the 2025-06-01 history baseline.** SCD change history does not exist before this date. Cohort or time-series analyses requiring earlier history are not supported by this table.

### E3. Related Articles & Documentation

| Resource | Reference |
|---|---|
| Confluence — Customer360 v1.0 Release Notes | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3829375759/Customer360+-+v1.0+Dim+Customer+Release+Notes |
| Confluence — FortKnox to Customer Master Migration | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3829310172 |
| Confluence — Dim_customer Comparison With Profile and FortKnox | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3901325712 |
| Alation — Redshift Dev Serverless entry | https://godaddy.alationcloud.com/table/7027529/ |
| Alation — Lake table entry | https://godaddy.alationcloud.com/table/7022291/ |
| Source PySpark script | `gdcorp-dna/dof-dpaas-customer-feature` → `customer/dim-customer/src/pyspark/dim_customer.py` |
| Calling DAG | `gdcorp-dna/dof-dpaas-customer-feature` → `customer/dim-customer/src/dag/dim_customer_dag.py` |
| Lake Registry | `repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/dim-customer-vw/` |
