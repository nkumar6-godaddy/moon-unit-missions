**Stage name:** gather
**The coding agent was given these instructions:** You are a Data Governance analyst. Your job is to gather ONLY verifiable facts
about a Data Lake table from the authoritative ETL code and supporting sources.
Do not guess. If something is unknown, say "Unknown" and explain what you checked.

## Source-of-truth rule
The PySpark script and the DAG that calls it are the source of truth. If Alation,
Confluence, DDL, policies, or other docs conflict with code, treat the code as
correct and record the discrepancy for validation.

## Step 1: Read INPUT.md
Read `INPUT.md` in your workspace. It contains:
- PySpark GitHub URL + parsed repo/ref/path
- Repository folder names inside the container (under `repos/`)
- Optional lake table override and semantic model name
- Supporting docs (Confluence URLs, other URLs)
- Alation configuration

Use INPUT.md as the contract for what to fetch and where to look.

## Step 2: Check out the exact Git ref for the source repo
INPUT.md includes the desired git ref (branch/tag/SHA) and the source repo URL.
The Moon Units framework clones repos into `repos/<repo-name>/` where repo-name is
derived from the git URL (e.g., `https://github.com/org/my-repo.git` → `repos/my-repo/`).

Determine the source repo folder name from the URL in INPUT.md (strip org and .git).
Then checkout the desired ref:

```bash
git -C repos/<repo-name> fetch --all --tags
git -C repos/<repo-name> checkout <ref_from_INPUT_md>
```

## Step 3: Read the PySpark script and the calling DAG
- Read the PySpark file at the path from INPUT.md.
- Locate and read the DAG file that calls it. Per repo convention, from the parent
  folder of the pyspark folder you should find sibling folders: `dag/`, `policies/`,
  `data_quality/`, `ddl/`.
- The DAG must be treated as authoritative for schedule/cadence, dependencies, and
  which job/version is run.
- **Extract all join conditions** (explicit `on=` keys, join predicates) — these
  will become OSI relationships in later stages.

## Step 4: Collect nearby repo context (secondary sources)
- Read relevant files under sibling folders:
  - `ddl/` (table DDLs) — helpful but may be stale
  - `policies/` — helpful but may be stale
  - `data_quality/` — checks and expectations (treat as evidence, not truth)
Record any conflicts with code explicitly.

## Step 5: Fetch Confluence pages (if provided)
For each URL in INPUT.md under CONFLUENCE PAGES, fetch page content via Atlassian REST API.
The page ID is the numeric part of the URL path.

**IMPORTANT: Parent pages may link to child pages.** Fetch the provided page first,
list child pages, identify relevant ones, fetch only those.

Credentials:
- Prefer `MOONUNIT_JIRA` env var (JSON: {"url","email","api_token"}) OR
- `MOONUNIT_ATLASSIAN` env var (JSON: {"email","api_token"})

Example:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA || process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Extract content relevant to business meaning, grain, metrics, filters, SLAs, ownership.

## Step 6: Alation lookup (if enabled)
If INPUT.md says Alation is enabled:
1. Check if `MOONUNIT_ALATION` env var is available; skip if not set.
2. Create API token via Alation integration API.
3. Search for the target table (Lake entry) and record descriptions/custom fields.
4. Fetch saved queries referencing the table (use Max queries from INPUT.md).

For each Alation query, record: Query ID, Title, Author, Description, SQL (verbatim).

## Step 7: Enumerate tables and column schemas
For EVERY table referenced in the PySpark (read and write targets):
- Record table name (schema.table form)
- Record whether it is read, written, or both
- If a lake DDL exists in `repos/lake/`, read `table.ddl` and list columns with types
- If only in-repo DDL exists, read that instead (note it may be stale)
- Record any join keys used with this table

## Step 8: Output (append to gather.md)
Append a structured, evidence-oriented report including:
- PySpark job identity (repo/ref/path), output write target(s)
- DAG identity (path, schedule, params)
- **Table inventory** — all referenced tables with read/write role and column schemas
- **Join conditions** — explicit join keys extracted from PySpark
- **Aggregation expressions** — SUM/COUNT/AVG/GROUP BY patterns found in PySpark
- DDL/policy/DQ files consulted
- Confluence summaries (if any)
- Alation section (table info + queries if fetched)
- Conflicts / discrepancies section

**The agent summarized its work in this way:**

---

# gather.md — Data Governance Research Report
**Target:** `marketing_mart.customer_suppression`
**Mission:** marketing-mart / customer-suppression
**Research date:** 2026-06-29
**Git ref verified:** `main` (confirmed already on main, up to date with origin)

---

## 1. PySpark Job Identity

| Field | Value |
|---|---|
| Repo URL | https://github.com/gdcorp-dna/dps-customermarketing.git |
| Repo folder | `repos/dps-customermarketing/` |
| Git ref | `main` |
| PySpark path | `customer/eds-customer-suppression/src/pyspark/customer_suppression.py` |
| Primary write target | `marketing_mart.customer_suppression` (via `transform_stg()`) |
| Secondary write target | `marketing_mart_local.customer_suppression_history` (via `main_to_history_ckpetl_eds_ss.py`) |
| DB arg passed to script | `-d marketing_mart_local` (local staging DB name; lake publishes to `marketing_mart`) |
| Table arg passed to script | `-t customer_suppression` |

---

## 2. DAG Identity

| Field | Value |
|---|---|
| DAG file path | `customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` |
| DAG ID | `customer_suppression` |
| Schedule (prod) | `0 4 * * *` — daily at 04:00 America/Phoenix (= 11:00 UTC) |
| Schedule (non-prod) | `None` (manual only) |
| Start date | 2024-04-25 (America/Phoenix timezone) |
| Catchup | `False` |
| Max active runs | 1 |
| Retries | 1 (retry delay: 3 min) |
| EMR release | `emr-7.2.0` |
| EMR type | EMR Serverless |
| Master instance type | `m6g.xlarge` |
| Core instance type | `r6g.4xlarge` |
| Core instances | 4 |
| Owner tag | `mdpe` |
| Slack alert channel | `#edt-airflow-alerts` |
| SLA (DAG doc) | 6:00 AM MST |
| Data Tier | Tier 3 |
| Domain tags | `domain:customer`, `sub-domain:customer`, `layer:enterprise`, `team:edt` |
| On-call email | dl-bi-enterprise-data@godaddy.com |
| Stakeholders Slack | `#marketing-data-products-help` |

### DAG Task Flow
```
start_task → [table_dependency_waiters...] → end_dependency_check → create_emr
start_task → dag_config
[create_emr, dag_config] → emr_ingest_main → main_to_hist → remove_emr → check_for_failure_branch
main_to_hist → dq_cs → local_success_file_cs → check_for_failure_branch
dq_cs → conditional_lake_api_branch → [dummy_success | datalake_success_api_skipped]
dummy_success → datalake_success_cs → success_api_complete → check_for_failure_branch
check_for_failure_branch → [succeed_dag_run | fail_dag_run]
```

### Upstream Table Dependencies (S3 success-file sensors)
The DAG waits for these tables' daily success files before running:
- `marketing_mart.customer`
- `marketing_bouncesystem.bouncesystem_bounced_email_log_snap`
- `marketing_bouncesystem.bouncesystem_bounced_email_snap`
- `marketing_bouncesystem.bouncesystem_bounce_type_snap`
- `customer360.dim_customer_vw`
- `cust_customertracking.shopper_crossover_cln`
- `ecomm_cln.gdshop_blocked_country_region_cln`
- `ecomm_cln.gdshop_blocked_country_cln`
- `signals_platform_cln.oeg_email_event_send_cln`
- `signals_platform_cln.oeg_email_event_open_cln`
- `sfmc_email_events_cln.sfmc_email_events_bounce_cln`
- `sfmc_email_events_cln.sfmc_email_events_send_log_cln`
- `sfmc_email_events_cln.sfmc_email_events_open_cln`
- `sfmc_email_events_cln.sfmc_email_events_click_cln`
- `signals_platform_cln.profile_audit_lake_cln_v2`
- `emailsystem.oc_emailqueuesuccesstrackingclick_snap`
- `emailsystem.oc_emailqueuesuccesstracking_snap`
- `emailsystem.oc_emailqueuesuccess_snap`
- `emailsystem.oc_emailqueuedetail_snap`

---

## 3. Table Inventory

### 3.1 Output Table: marketing_mart.customer_suppression (WRITTEN)

**Lake DDL source:** `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.ddl`

| Column | Type | Notes |
|---|---|---|
| `customer_id` | string | Primary key (per DQ constraints) |
| `shopper_id` | string | |
| `internal_account_flag` | boolean | |
| `private_label_13_suppression_flag` | boolean | "Private Label suppression, same email tied to Reseller with purchases in last 12 months" |
| `restricted_country_flag` | boolean | |
| `excluded_email_flag` | boolean | Always NULL in current code — see conflicts |
| `competitor_email_flag` | boolean | |
| `bad_email_address_format_flag` | boolean | Always NULL in current code — see conflicts |
| `email_address_hard_bounced_flag` | boolean | |
| `email_address_soft_bounced_flag` | boolean | |
| `etl_build_mst_ts` | timestamp | ETL build time in MST: `FROM_UTC_TIMESTAMP(CURRENT_TIMESTAMP(), 'MST')` |

**Storage format:** Parquet  
**Table type:** LATEST_SNAPSHOT (full replacement each run)  
**S3 location:** `s3://gd-ckpetlbatch-prod-mktgdata-eds/marketing_mart_local/customer_suppression`  
**Data tier:** 3  
**SLA:** `cron(0 13 * * ? *)` → delivered by 6:00 AM MST daily  

### 3.2 Output Table: marketing_mart_local.customer_suppression_history (WRITTEN)

**In-repo DDL source:** `customer/eds-customer-suppression/src/ddls/customer_suppression_history.ddl`

Same columns as main table plus:
| Column | Type | Notes |
|---|---|---|
| `hist_mst_ts` | timestamp | History load timestamp |
| `load_mst_date` | date | **Partition key** |

**S3 location:** `s3://gd-ckpetlbatch-prod-mktgdata-eds/marketing_mart_local/customer_suppression_history`

### 3.3 Input Tables (READ)

| Table | Role | Columns Used | Join Keys |
|---|---|---|---|
| `marketing_mart.customer` | READ (base) | customer_id, shopper_id, country_code, city_name, email_domain, temporary_shopper_flag | Joined by customer_id (to bounce flags, cef) and shopper_id (to dim, sc) |
| `marketing_bouncesystem.bouncesystem_bounced_email_snap` | READ | bounced_email_id | es.bounced_email_id = el.bounced_email_id |
| `marketing_bouncesystem.bouncesystem_bounced_email_log_snap` | READ | bounced_email_id, bounce_type_id, template_id, message_id, date_created | el.bounce_type_id = bts.bounce_type_id; el.template_id = ees.template_id AND UPPER(el.message_id) = UPPER(ees.message_id) |
| `marketing_bouncesystem.bouncesystem_bounce_type_snap` | READ | bounce_type_id, bounce_code | bts.bounce_type_id = el.bounce_type_id |
| `signals_platform_cln.oeg_email_event_send_cln` | READ | customer_id, template_id, message_id, error_code_id, event_utc_ts | ees.template_id = el.template_id AND UPPER(ees.message_id) = UPPER(el.message_id); suc.templateid = ees.template_id AND UPPER(dtl.messageguid) = UPPER(ees.message_id) |
| `signals_platform_cln.oeg_email_event_open_cln` | READ | customer_id, event_utc_ts | (no join; filtered by customer_id IS NOT NULL) |
| `signals_platform_cln.profile_audit_lake_cln_v2` | READ | customer_id, email_domain, email_hash, field_changed_json, last_changed_date_utc_ts | sbr.customer_id = ec.customer_id; lb.customer_id = ec.customer_id |
| `sfmc_email_events_cln.sfmc_email_events_bounce_cln` | READ | sfmc_job_id, sfmc_list_id, sfmc_batch_id, sfmc_subscriber_id, bounce_category, event_utc_ts, event_unique_flag | eb.sfmc_job_id/list_id/batch_id/subscriber_id = es.sfmc_job_id/list_id/batch_id/subscriber_id |
| `sfmc_email_events_cln.sfmc_email_events_send_log_cln` | READ | sfmc_job_id, sfmc_list_id, sfmc_batch_id, sfmc_subscriber_id, customer_id, event_utc_ts | (joined by SFMC composite key for bounce, open, click resolution) |
| `sfmc_email_events_cln.sfmc_email_events_open_cln` | READ | sfmc_job_id, sfmc_list_id, sfmc_batch_id, sfmc_subscriber_id, event_utc_ts, event_unique_flag | eo.sfmc_job_id/list_id/batch_id/subscriber_id = es.sfmc_job_id/list_id/batch_id/subscriber_id |
| `sfmc_email_events_cln.sfmc_email_events_click_cln` | READ | sfmc_job_id, sfmc_list_id, sfmc_batch_id, sfmc_subscriber_id, event_utc_ts, event_unique_flag | ec.sfmc_job_id/list_id/batch_id/subscriber_id = es.sfmc_job_id/list_id/batch_id/subscriber_id |
| `emailsystem.oc_emailqueuesuccesstrackingclick_snap` | READ | trackingcode, createdate | clk.trackingcode = trk.trackingcode |
| `emailsystem.oc_emailqueuesuccesstracking_snap` | READ | trackingcode, emailqueuesuccessid | trk.emailqueuesuccessid = suc.emailqueuesuccessid |
| `emailsystem.oc_emailqueuesuccess_snap` | READ | emailqueuesuccessid, emailqueueid, templateid, emailqueuecreatedate | suc.emailqueueid = dtl.emailqueueid; suc.templateid = ees.template_id |
| `emailsystem.oc_emailqueuedetail_snap` | READ | emailqueueid, messageguid | dtl.emailqueueid = suc.emailqueueid; UPPER(dtl.messageguid) = UPPER(ees.message_id) |
| `customer360.dim_customer_vw` | READ | shopper_id, internal_shopper_flag, current_record_flag | cust.shopper_id = dim.shopper_id AND cust.temporary_shopper_flag = FALSE |
| `cust_customertracking.shopper_crossover_cln` | READ | shopper_id, pool_13_active_flag | cust.shopper_id = sc.shopper_id |
| `ecomm_cln.gdshop_blocked_country_region_cln` | READ | country_code, region_name | LOWER(cust.country_code) = LOWER(gbcr.country_code) AND LOWER(cust.city_name) = LOWER(gbcr.region_name) |
| `ecomm_cln.gdshop_blocked_country_cln` | READ | country_code | LOWER(cust.country_code) = LOWER(gbc.country_code) |

---

## 4. Join Conditions (Complete Extract from PySpark)

### bounce_data_df (bouncesystem source)
1. `es.bounced_email_id = el.bounced_email_id` (LEFT JOIN bouncesystem_bounced_email_snap → bouncesystem_bounced_email_log_snap)
2. `bts.bounce_type_id = el.bounce_type_id` (LEFT JOIN bouncesystem_bounced_email_log_snap → bouncesystem_bounce_type_snap)
3. `ees.template_id = el.template_id AND UPPER(el.message_id) = UPPER(ees.message_id)` (LEFT JOIN bouncesystem_bounced_email_log_snap → oeg_email_event_send_cln)

### bounce_data_df (SFMC source)
4. `eb.sfmc_job_id = es.sfmc_job_id AND eb.sfmc_list_id = es.sfmc_list_id AND eb.sfmc_batch_id = es.sfmc_batch_id AND eb.sfmc_subscriber_id = es.sfmc_subscriber_id` (INNER JOIN sfmc_email_events_bounce_cln → sfmc_email_events_send_log_cln)

### email_change_df
5. No external join — window function PARTITION BY customer_id on `signals_platform_cln.profile_audit_lake_cln_v2`

### final_bounce_events_df
6. `lb.customer_id = ec.customer_id` (LEFT JOIN latest_bounce → email_change temp view)

### soft_bounce_window_df
7. `sbr.customer_id = ec.customer_id` (LEFT JOIN soft_bounce_raw → email_change temp view)

### ocm_clicks_df (5-table chain)
8. `clk.trackingcode = trk.trackingcode` (INNER JOIN oc_emailqueuesuccesstrackingclick_snap → oc_emailqueuesuccesstracking_snap)
9. `trk.emailqueuesuccessid = suc.emailqueuesuccessid` (INNER JOIN oc_emailqueuesuccesstracking_snap → oc_emailqueuesuccess_snap)
10. `suc.emailqueueid = dtl.emailqueueid` (INNER JOIN oc_emailqueuesuccess_snap → oc_emailqueuedetail_snap)
11. `suc.templateid = ees.template_id AND UPPER(dtl.messageguid) = UPPER(ees.message_id)` (INNER JOIN oc_emailqueuedetail_snap → oeg_email_event_send_cln)

### final_flags_df (engagement events)
12. `eo.sfmc_job_id = es.sfmc_job_id AND eo.sfmc_list_id = es.sfmc_list_id AND eo.sfmc_batch_id = es.sfmc_batch_id AND eo.sfmc_subscriber_id = es.sfmc_subscriber_id` (INNER JOIN sfmc_email_events_open_cln → sfmc_email_events_send_log_cln)
13. `ec.sfmc_job_id = es.sfmc_job_id AND ec.sfmc_list_id = es.sfmc_list_id AND ec.sfmc_batch_id = es.sfmc_batch_id AND ec.sfmc_subscriber_id = es.sfmc_subscriber_id` (INNER JOIN sfmc_email_events_click_cln → sfmc_email_events_send_log_cln)

### final_flags_df (combined_flags CTE)
14. `fbf.customer_id = sbw.customer_id` (LEFT JOIN final_bounce_flag → soft_bounce_window)
15. `fbf.customer_id = lep.customer_id` (LEFT JOIN final_bounce_flag → latest_engagement_per_cust)
16. `fbf.customer_id = lhb.customer_id` (LEFT JOIN final_bounce_flag → latest_hard_bounce)
17. `fbf.customer_id = lsb.customer_id` (LEFT JOIN final_bounce_flag → latest_soft_bounce)

### source_df (final assembly)
18. `cust.customer_id = cef.customer_id` (LEFT JOIN marketing_mart.customer → competitor_email_flag)
19. `cust.shopper_id = dim.shopper_id AND cust.temporary_shopper_flag = FALSE` (LEFT JOIN marketing_mart.customer → cte_internal_shopper/customer360.dim_customer_vw)
20. `cust.shopper_id = sc.shopper_id` (LEFT JOIN marketing_mart.customer → cust_customertracking.shopper_crossover_cln)
21. `LOWER(cust.country_code) = LOWER(gbcr.country_code) AND LOWER(cust.city_name) = LOWER(gbcr.region_name)` (LEFT JOIN marketing_mart.customer → ecomm_cln.gdshop_blocked_country_region_cln)
22. `LOWER(cust.country_code) = LOWER(gbc.country_code)` (LEFT JOIN marketing_mart.customer → ecomm_cln.gdshop_blocked_country_cln)
23. `cust.customer_id = eas.customer_id` (LEFT JOIN marketing_mart.customer → final_bounce_flag)

---

## 5. Aggregation Expressions

| Expression | Context | Purpose |
|---|---|---|
| `MAX(el.date_created) AS bounce_ts` GROUP BY customer_id, bounce_flag | bounce_data_df (bouncesystem) | Latest bounce timestamp per customer per flag type |
| `MAX(eb.event_utc_ts) AS bounce_ts` GROUP BY customer_id, bounce_category | bounce_data_df (SFMC) | Latest bounce timestamp per customer per flag type |
| `ROW_NUMBER() OVER (PARTITION BY customer_id, bounce_flag ORDER BY bounce_ts DESC)` | latest_bounce_df | Deduplicate to one row per customer per bounce type |
| `ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY last_changed_date_utc_ts DESC)` | email_change_df | Latest email change per customer |
| `COUNT(*) AS soft_bounce_count_180d` GROUP BY customer_id | soft_bounce_180d_count CTE | Count qualifying soft bounces in 180-day rolling window |
| `MAX(CASE WHEN bounce_flag='Hard bounce' THEN TRUE ELSE FALSE END) AS email_address_hard_bounced_flag` GROUP BY customer_id | final_bounce_flag_df | Boolean hard bounce flag per customer |
| `MAX(CASE WHEN bounce_flag='Soft bounce' THEN TRUE ELSE FALSE END) AS email_address_soft_bounced_flag` GROUP BY customer_id | final_bounce_flag_df | Boolean soft bounce flag per customer |
| `MAX(engagement_ts) AS latest_engagement_ts` GROUP BY customer_id | latest_engagement_per_cust CTE | Most recent engagement across all channels |
| `MAX(bounce_ts) AS latest_soft_bounce_ts` GROUP BY customer_id | latest_soft_bounce CTE | Most recent soft bounce timestamp |
| `MAX(clk.createdate) AS engagement_ts` GROUP BY ees.customer_id | ocm_clicks_df | Most recent OCM click per customer (365-day filter) |
| `CASE WHEN size(array_intersect(domain_tokens, competitors)) > 0 THEN true ELSE false END` | competitor_email_flag_df | Boolean competitor flag via domain token intersection |

---

## 6. Key Business Rules (from PySpark code)

### Bounce Classification
- **Hard bounce:** bounce_code = 'HB' (bouncesystem) OR sfmc `bounce_category = 'Hard bounce'`
- **Soft bounce:** bounce_code IN ('SB','GB') (bouncesystem) OR sfmc `bounce_category = 'Soft bounce'`
- Only rows where `ees.customer_id IS NOT NULL AND ees.error_code_id IS NULL` are counted (bouncesystem source)
- Only rows where `eb.event_unique_flag = TRUE` are counted (SFMC source)

### Soft Bounce 180-Day Rolling Window Rule
- Soft bounce flag = TRUE **only if** customer has ≥ 3 qualifying soft bounce events in the last 180 days
- Qualifying bounce: occurred within 180 days AND after customer's last email address change
- If no email change: all bounces within 180 days count (defaults to 1900-01-01)

### Bounce Reset Rules
- **Rule 1 — Email address change:** If customer updated email after last bounce → bounce nullified (applied per bounce type)
- **Rule 2 — Re-engagement:** If any send/open/click on a LATER CALENDAR DAY than the most recent bounce → both hard and soft flags reset to FALSE
  - Comparison is DATE-level (not timestamp) to avoid same-day pipeline artifacts
  - Re-engagement sources: OEG sends, SFMC sends, OEG opens, SFMC opens, SFMC clicks, OCM clicks (365-day filtered)

### Competitor Email Rule
- `email_domain` from `marketing_mart.customer` is split into tokens
- Flag = TRUE if any token matches hardcoded list of ~40 competitor domain names

### Restricted Country Rule
- TRUE if customer's `country_code` matches `ecomm_cln.gdshop_blocked_country_cln.country_code` (country-level block)
- OR if `country_code` + `city_name` matches `ecomm_cln.gdshop_blocked_country_region_cln.country_code` + `region_name` (region-level block)
- Both comparisons use `LOWER()` for case-insensitive matching

### Internal Account Rule
- From `customer360.dim_customer_vw` where `current_record_flag = TRUE`
- Applied only when `cust.temporary_shopper_flag = FALSE`
- COALESCE to FALSE if no match

### Private Label 13 Suppression Rule
- `cust_customertracking.shopper_crossover_cln.pool_13_active_flag` joined on shopper_id

---

## 7. Files Consulted

| File | Path | Role |
|---|---|---|
| PySpark (source of truth) | `customer/eds-customer-suppression/src/pyspark/customer_suppression.py` | Primary ETL logic |
| DAG (source of truth) | `customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` | Schedule, params, dependencies |
| In-repo DDL (main table) | `customer/eds-customer-suppression/src/ddls/customer_suppression.ddl` | Schema reference (may be stale) |
| In-repo DDL (history table) | `customer/eds-customer-suppression/src/ddls/customer_suppression_history.ddl` | Schema reference (may be stale) |
| Pipeline policy | `customer/eds-customer-suppression/src/policies/customer_suppression_dag.yaml` | Inputs/outputs metadata |
| Environment policy (prod) | `customer/eds-customer-suppression/src/policies/environment.prod.yaml` | Team/contact/platform info |
| Data quality constraints | `customer/eds-customer-suppression/src/data_quality/constraints/customer_suppression.json` | PK constraint: customer_id |
| Lake DDL | `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.ddl` | Authoritative lake schema |
| Lake metadata YAML | `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.yaml` | SLA, tier, permissions, lineage |

---

## 8. Confluence Summary

**Page:** https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10370826/Customer+-+Customer+Suppression  
**Child page fetched:** Analysis and Design of Customer Suppression (ID: 3114766874)

### Key Business Context (from Confluence)
- **Business meaning:** Dataset defines which GoDaddy customers should be **suppressed from marketing communications**. Suppressions are GoDaddy-driven blocks (distinct from customer-driven consents).
- **Grain:** One row per customer (customer_id / shopper_id)
- **SLA:** Daily refresh
- **Owner/team:** EDT (Emerald Data Team); contact emerald-data-team-org@godaddy.com
- **OnCall group:** DEV-EDT-OnCall

### Legacy vs. Current Suppression Flags
The Confluence page documents the legacy Teradata design and the migration plan to the EDS (Enterprise Data Store). Many flags present in legacy `vtShopAcctSuprs_V2` were removed or deprecated:
- Removed (PII): `BadCharInNmFlg`, `VlgrFstNmFlg`, `VlgrLastNmFlg`, `NoFstAndLastNmFlg`
- Removed (deprecated): `FrdFlg` (FortKnox), `DontCntctFlg` (stale since 2012)
- Moved to Customer Consents: `MktgEmlFlg`, `MktgNonPromEmlFlg`, `DontCallFlg`
- Composite flags `IsGlobalStandardSuppression` / `IsNotificationSuppressionFlg` no longer needed downstream

---

## 9. Alation Section

**Instance:** https://godaddy.alationcloud.com  
**Table ID:** 6619866  
**Qualified name:** `81.AwsDataCatalog.marketing_mart.customer_suppression`  
**Data source:** GoDaddy Central Data Lake (Prod) — ds_id: 81  
**Table type:** EXTERNAL_TABLE  
**Created in Alation:** 2023-04-28  
**Last updated:** 2025-11-26  

### Alation Description
"EDS for marketing customer suppression data"

**Primary key:** customer_id  
**Common use:** Identify if the customer should be excluded from marketing campaigns  
**Usage notes:** Daily snapshot data  

### Alation Custom Fields
| Field | Value |
|---|---|
| Data Lake Table Type | LATEST_SNAPSHOT |
| Data Lake Tier | 3.0 |
| Data Lake SLA | `cron(0 13 * * ? *)` — Daily by 6:00 AM MST |
| Data Lake Owner | mktgdata / emerald-data-team-org@godaddy.com / DEV-EDT-OnCall / #edt-airflow-alerts |

### Alation Stewards
- Franchise: Customer Marketing (group)
- Roopa Bojja (Eng - Software Development III)
- Ashish Pokharel (Director - Data Engineering)
- Yonghui Li (Senior Software Engineer - Data Engineering, suspended)
- Paul Fagbamila (Software Engineer)

### Alation Saved Queries
**None found.** `num_queries = 0` on the table record. Multiple search approaches were exhausted (table_id filter, ds_id filter, full-text search). No saved or published queries reference this table in Alation.

---

## 10. Conflicts / Discrepancies

| # | Conflict | Source A (Code — authoritative) | Source B (Doc/DDL — discrepant) | Action Required |
|---|---|---|---|---|
| 1 | `excluded_email_flag` and `bad_email_address_format_flag` are always `NULL` in the PySpark code | PySpark: `NULL AS excluded_email_flag`, `NULL AS bad_email_address_format_flag` | DDL: columns defined as `BOOLEAN`; Confluence: intended to come from `fortknox.tdaemailattributes_snap` | Validate with team: these columns are incomplete / placeholder. FortKnox source not yet wired. |
| 2 | Bounce flag data sources differ from Confluence design | PySpark uses: `marketing_bouncesystem.*`, `sfmc_email_events_cln.*`, `signals_platform_cln.*` | Confluence Section 6 / Design doc says: `fortknox.tdaemailattributes_snap.hardbounceflag` / `.softbounceflag` | Confluence documents a prior/alternate design. Code uses direct source tables, not FortKnox. Code is authoritative. |
| 3 | `terrorist_country_flag` mentioned in Confluence but absent from DDL and code | PySpark: single `restricted_country_flag` combining both country-level and region-level blocks | Confluence: separate `terrorist_country_flag` (country-level) and `restricted_country_flag` (region-level) | Code merges both into one flag. Confluence reflects legacy schema. |
| 4 | `-d marketing_mart_local` passed to PySpark; lake entry is `marketing_mart` | DAG: `-d marketing_mart_local` (staging DB argument) | Policies yaml: output `marketing_mart.customer_suppression` | `transform_stg()` likely routes data to the lake-exposed `marketing_mart` DB; `marketing_mart_local` is the job-local staging namespace. Confirm with `sparkutils_eds` library behavior. |
| 5 | Alation GitHub repo link points to a different repo | Alation: `https://github.com/gdcorp-dna/de-marketing-mart-eds/blob/main/customer/customer_suppression/src/dag/customer_suppression.py` | INPUT.md / actual code: `https://github.com/gdcorp-dna/dps-customermarketing/blob/main/customer/eds-customer-suppression/src/pyspark/customer_suppression.py` | Alation link is stale. Current authoritative repo is `dps-customermarketing`. |
| 6 | Lake `table.yaml` lineage missing `marketing_bouncesystem.bouncesystem_bounce_type_snap` | PySpark: reads this table | `table.yaml` upstream_table_dependencies: omits `bouncesystem_bounce_type_snap` | Lake lineage is incomplete. Code is authoritative. |
| 7 | `internal_account_flag` source differs | PySpark: from `customer360.dim_customer_vw.internal_shopper_flag` | Confluence design: from `is_number(shopper_id) = 0` OR `godaddy.rp_salesmonitor_internalshopper_snap` | Code uses `dim_customer_vw` exclusively, which may internally incorporate both logic paths. |


**The agent's final response to the user was:**
The `gather.md` has been appended with the full research report. Here's a summary of what was gathered:

---

## Research Summary

**Target table:** `marketing_mart.customer_suppression`

### Sources consulted
- **PySpark** (`customer_suppression.py`, ref: `main`) — source of truth
- **DAG** (`customer_suppression_dag.py`) — schedule, dependencies, params
- **In-repo DDLs** — main table + history table schemas
- **Policies YAML** — I/O lineage declarations, team/contact info
- **Data quality constraints** — primary key: `customer_id`
- **Lake DDL + table.yaml** — authoritative lake schema, SLA, tier, permissions
- **Confluence** (pages 10370826 + 3114766874) — business context, legacy design, column mapping
- **Alation** (table ID 6619866) — metadata, stewards, custom fields; 0 saved queries found

### Key findings

**DAG:** Daily at 04:00 America/Phoenix (prod only), EMR Serverless, 20 upstream S3 sensors, Data Tier 3, SLA 6:00 AM MST.

**Grain:** One row per `customer_id` (full replacement / LATEST_SNAPSHOT).

**Output columns (11):** customer_id (PK), shopper_id, internal_account_flag, private_label_13_suppression_flag, restricted_country_flag, excluded_email_flag, competitor_email_flag, bad_email_address_format_flag, email_address_hard_bounced_flag, email_address_soft_bounced_flag, etl_build_mst_ts.

**Critical business rules in code:** hard/soft bounce classification from 2 systems (bouncesystem + SFMC), 180-day rolling window with ≥3-event threshold for soft bounce, email-change reset, re-engagement reset, competitor domain token matching, restricted country (city+country region OR country-level).

**7 conflicts recorded**, most notable:
1. `excluded_email_flag` and `bad_email_address_format_flag` are always `NULL` in current code (FortKnox source not wired)
2. Confluence documents bounce flags sourcing from FortKnox; code pulls directly from bouncesystem/SFMC/signals tables
3. Alation GitHub link points to a stale/different repo
4. `terrorist_country_flag` in Confluence is merged into `restricted_country_flag` in the actual implementation