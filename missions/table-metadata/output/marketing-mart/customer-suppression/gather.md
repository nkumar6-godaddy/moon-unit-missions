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
- Optional lake table override
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
# Example: if source repo URL is https://github.com/gdcorp-dna/my-repo.git
# then folder is repos/my-repo/
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

## Step 4: Collect nearby repo context (secondary sources)
- Read relevant files under sibling folders:
  - `ddl/` (table DDLs) — helpful but may be stale
  - `policies/` — helpful but may be stale
  - `data_quality/` — checks and expectations (treat as evidence, not truth)
Record any conflicts with code explicitly.

## Step 5: Fetch Confluence pages (if provided)
For each URL in INPUT.md under CONFLUENCE PAGES, fetch page content via Atlassian REST API.
The page ID is the numeric part of the URL path.

**IMPORTANT: Parent pages may link to child pages.** A provided URL might be a parent/hub
page (e.g., "Customer360") containing links to multiple child pages for individual tables.
You MUST:
1. Fetch the provided page first.
2. List its child pages using:
   ```bash
   curl -s -u "$ATLASSIAN_CREDS" \
     "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}/child/page?limit=50"
   ```
3. From the child pages, identify which ones are relevant to the target table
   (match by table name, job name, or domain keywords).
4. Fetch ONLY the relevant child pages (not all of them).
5. If the provided page itself has useful content, use it too.

Credentials:
- Prefer `MOONUNIT_JIRA` env var (JSON: {"url","email","api_token"}) OR
- `MOONUNIT_ATLASSIAN` env var (JSON: {"email","api_token"})

Example:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA || process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Extract only content relevant to business meaning, grain, metrics, filters, SLAs, ownership.

## Step 6: Alation lookup (if enabled)
If INPUT.md says Alation is enabled:
1. First check if `MOONUNIT_ALATION` env var is available:
```bash
node -e "if(!process.env.MOONUNIT_ALATION){console.log('MOONUNIT_ALATION not set');process.exit(1)}else{console.log('OK')}"
```
If it's not available, skip Alation and note this in gather.md under "Alation: skipped (credentials not available)".

2. If available, create API token:
```bash
ALATION_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ALATION); console.log(JSON.stringify({refresh_token:j.refresh_token, user_id:j.user_id||j.ALATION_USER_ID}))")
TOKEN=$(curl -s -X POST "https://godaddy.alationcloud.com/integration/v1/createAPIAccessToken/" \
  -H "Content-Type: application/json" \
  -d "$ALATION_CREDS" | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).api_access_token))")
```

3. **Fetch table entries for the target table name** (once you know it from code analysis).
   Search Alation for the table by name to find BOTH the Redshift Serverless and Lake entries:
```bash
curl -s -H "Token: $TOKEN" \
  "https://godaddy.alationcloud.com/integration/v2/table/?name=<TABLE_NAME>&limit=50"
```
   From the results, identify:
   - **Redshift Serverless Dev entry**: look for entries where the Alation key
     starts with `dev.` (e.g., `63.dev.customer360.table_name`). This is the
     Dev Serverless environment. ALWAYS use the `dev.*` entry, NOT the `bi.*`
     (prod) entry. Record its Alation table ID.
   - **Lake entry**: look for entries where the key matches the Hive/Glue catalog
     (often contains the schema directly like `<schema>.<table>`). Record its Alation table ID.

   Construct Alation URLs as: `https://godaddy.alationcloud.com/table/<ID>/`

4. Record in gather.md under "## Alation" a structured block:
   - Redshift Dev Serverless table (dev.* key): name, database ("Redshift - Serverless - Dev"), schema, Alation URL
   - Lake table: name, schema, Alation URL
   - Any descriptions or custom fields found

## Step 6b: Fetch Alation queries referencing this table

After you know the target table name (from PySpark/DAG), fetch saved queries in Alation
that reference it. Use `Max queries` from INPUT.md (default 10).

```bash
TABLE_NAME=<table_name_only e.g. customer_metric_daily_agg_vw>
MAX_QUERIES=<from INPUT.md>
curl -s -H "Token: $TOKEN" \
  "https://godaddy.alationcloud.com/integration/v1/query/?content__icontains=${TABLE_NAME}&order_by=-last_saved_at&limit=${MAX_QUERIES}"
```

For EACH query in the response, record under "## Alation Queries" in gather.md:

| Field | Source |
|---|---|
| Query ID | `id` |
| Title | `title` |
| Author | `author.display_name` or `author.username` or empty |
| Description | `description` if present; else one-line summary from SQL |
| Schedule | `schedule_cron`, `schedule_name`, or "Not scheduled" |
| Last Saved | `last_saved_at` |
| Last Run | `schedule_db_ts_last_execution` or latest execution event if available |
| Datasource | map `datasource_id` to name if possible; else empty |
| Alation Query URL | `https://godaddy.alationcloud.com/query/<id>/` |
| SQL | `content` field — copy verbatim, do not modify |

If the query API returns no results, try `content__icontains=<schema>.<table>` as well.
If still none, note "No Alation queries found" under ## Alation Queries.

## Step 7: Output (append to gather.md)
Append a structured, evidence-oriented report including:
- PySpark job identity (repo/ref/path), and the exact output write target(s) found (if any)
- DAG identity (path, schedule, params calling the PySpark)
- Enumerated upstream/local tables referenced in the PySpark
- Any DDL/policy/DQ files consulted and what they claim
- Confluence summaries (if any)
- Alation section with:
  - Redshift Dev Serverless table info (dev.* entry: table name, database, schema, Alation URL)
  - Lake table Alation URL
  - Any descriptions or custom fields retrieved
- Alation Queries section (full query details per Step 6b)
- A "Conflicts / discrepancies" section listing any contradictions with the code

**The agent summarized its work in this way:**

---

## gather stage — customer_suppression (marketing-mart)

**Gathered:** 2026-06-29  
**Source repo:** `repos/dps-customermarketing` @ `main`  
**PySpark file:** `customer/eds-customer-suppression/src/pyspark/customer_suppression.py`  
**DAG file:** `customer/eds-customer-suppression/src/dag/customer_suppression_dag.py`

---

## PySpark Job Identity

| Field | Value |
|---|---|
| Repo | `gdcorp-dna/dps-customermarketing` |
| Git ref | `main` |
| Script path | `customer/eds-customer-suppression/src/pyspark/customer_suppression.py` |
| Write target (local) | `marketing_mart_local.customer_suppression` (via `transform_stg()`) |
| Write target (lake) | `marketing_mart.customer_suppression` (via `SuccessNotificationOperator` in DAG) |
| S3 location (prod) | `s3://gd-ckpetlbatch-prod-mktgdata-eds/marketing_mart_local/customer_suppression` (from policies YAML) |
| History table | `marketing_mart_local.customer_suppression_history` (via `main_to_history_ckpetl_eds_ss.py`) |

---

## DAG Identity

| Field | Value |
|---|---|
| DAG ID | `customer_suppression` |
| DAG path | `customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` |
| Schedule (prod) | `0 4 * * *` — 4:00 AM daily (America/Phoenix / MST) |
| Schedule (dev/stage) | `None` (not scheduled) |
| Start date | 2024-04-25 (America/Phoenix) |
| Catchup | False |
| Max active runs | 1 |
| Owner | `mdpe` |
| Retries | 1, delay 3 minutes |
| SLA (DAG doc_md) | 6:00 AM MST |
| SLA (lake table.yaml) | `cron(0 13 * * ? *)` — 6:00 AM MST / 1:00 PM UTC |
| Data Tier | 3 |
| EMR release | EMR 7.2.0 |
| Airflow tags | `domain:customer`, `sub-domain:customer`, `layer:enterprise`, `team:edt` |
| Failure alert channel | `#edt-airflow-alerts` |
| On-call group Slack | `#marketing-data-product-engineering` |
| On-call email | `dl-bi-enterprise-data@godaddy.com` |

**DAG task flow (authoritative):**
```
start_task
  ├─► [dependency waiters × 19 S3KeySensors] ──► end_dependency_check ──► create_emr
  └─► dag_config ─────────────────────────────────────────────────────────────────────►─┐
                                                                                          │
create_emr + dag_config ──► emr_ingest_main ──► main_to_hist ──► remove_emr
                                                    │
                                                    ▼
                                                  dq_cs ──► local_success_file_cs
                                                    │
                                                    ▼
                                        conditional_lake_api_branch
                                        (prod only) ──► dummy_success ──► datalake_success_cs
                                                                               │
                                                                               ▼
                                                                     success_api_complete
                                                                               │
                                                                               ▼
                                                                   check_for_failure_branch
```

**PySpark command args (from DAG `ingest_main`):**
```
-d marketing_mart_local
-t customer_suppression
-e {AWS_ENV}
--sb_app_id  {xcom: dag_config.sb_app_id}
--sb_setting_id {xcom: dag_config.sb_setting_id}
--run_emr_task_id emr_ingest_main
--local_spark_config_b64 <base64 of CUSTOMER_SUPPRESSION_SPARK_CONFIG>
```

---

## Upstream Dependencies (from code + DAG sensors)

All 19 tables are S3-sensor-gated in the DAG. All are Data Lake parquet tables.

| # | Table (database.table) | Role in PySpark |
|---|---|---|
| 1 | `marketing_mart.customer` | Base driver table; provides `customer_id`, `shopper_id`, `country_code`, `city_name`, `email_domain`, `temporary_shopper_flag` |
| 2 | `marketing_bouncesystem.bouncesystem_bounced_email_snap` | Hard/soft bounce data — bounce records |
| 3 | `marketing_bouncesystem.bouncesystem_bounced_email_log_snap` | Bounce log events; `date_created`, `bounce_type_id`, `template_id`, `message_id` |
| 4 | `marketing_bouncesystem.bouncesystem_bounce_type_snap` | Bounce type codes (SB=Soft, GB=Soft, HB=Hard) |
| 5 | `signals_platform_cln.oeg_email_event_send_cln` | OCM (OEG) email send events; resolves `customer_id` from `template_id`/`message_id`; also used as engagement reset signal |
| 6 | `signals_platform_cln.oeg_email_event_open_cln` | OCM (OEG) email open events; engagement reset signal |
| 7 | `signals_platform_cln.profile_audit_lake_cln_v2` | Customer email change audit; determines if bounce occurred after email address change |
| 8 | `sfmc_email_events_cln.sfmc_email_events_bounce_cln` | SFMC bounce events; `bounce_category`, `event_utc_ts` |
| 9 | `sfmc_email_events_cln.sfmc_email_events_send_log_cln` | SFMC send log; resolves `customer_id`; also used as engagement reset signal |
| 10 | `sfmc_email_events_cln.sfmc_email_events_open_cln` | SFMC open events; engagement reset signal |
| 11 | `sfmc_email_events_cln.sfmc_email_events_click_cln` | SFMC click events; engagement reset signal |
| 12 | `emailsystem.oc_emailqueuesuccesstrackingclick_snap` | OCM click tracking (~30B rows); pre-materialized/cached; filtered to 365-day window |
| 13 | `emailsystem.oc_emailqueuesuccesstracking_snap` | OCM click tracking chain (~3.7B rows) |
| 14 | `emailsystem.oc_emailqueuesuccess_snap` | OCM email queue success records |
| 15 | `emailsystem.oc_emailqueuedetail_snap` | OCM email queue detail; carries `messageguid` |
| 16 | `customer360.dim_customer_vw` | `internal_shopper_flag` (filter: `current_record_flag = true`); joined on `shopper_id` |
| 17 | `cust_customertracking.shopper_crossover_cln` | `pool_13_active_flag` → private label 13 suppression; joined on `shopper_id` |
| 18 | `ecomm_cln.gdshop_blocked_country_region_cln` | Restricted country-region lookup |
| 19 | `ecomm_cln.gdshop_blocked_country_cln` | Restricted country lookup |

---

## Output Schema (authoritative: code + DDL)

Database: `marketing_mart` (lake) / `marketing_mart_local` (write target)  
Table: `customer_suppression`  
Format: Parquet  
Table type: `LATEST_SNAPSHOT` (full overwrite, not partitioned)  
Grain: **One row per `customer_id`** (enforced by DQ constraint: isPrimaryKey)

| Column | Type | Code Source | Business Logic |
|---|---|---|---|
| `customer_id` | STRING | `marketing_mart.customer.customer_id` | Primary key; unique GoDaddy customer identifier |
| `shopper_id` | STRING | `marketing_mart.customer.shopper_id` | GoDaddy shopper identifier |
| `internal_account_flag` | BOOLEAN | `customer360.dim_customer_vw.internal_shopper_flag` | TRUE if the shopper is an internal GoDaddy account (joined on `shopper_id` where `current_record_flag = true` and `temporary_shopper_flag = FALSE`); COALESCE to FALSE if no match |
| `private_label_13_suppression_flag` | BOOLEAN | `cust_customertracking.shopper_crossover_cln.pool_13_active_flag` | TRUE if the shopper's email is shared with a Private Label 13 reseller and they have purchased from that reseller within the last 12 months |
| `restricted_country_flag` | BOOLEAN | `ecomm_cln.gdshop_blocked_country_region_cln` + `ecomm_cln.gdshop_blocked_country_cln` | TRUE if customer's `country_code` matches a blocked country-region combination OR a blocked country outright |
| `excluded_email_flag` | BOOLEAN | **NULL (hard-coded)** | Not currently populated; field reserved |
| `competitor_email_flag` | BOOLEAN | `marketing_mart.customer.email_domain` vs hard-coded competitor list | TRUE if email domain tokens overlap with a ~40-item competitor list (e.g., bluehost, wix, ionos, squarespace, namecheap, etc.) |
| `bad_email_address_format_flag` | BOOLEAN | **NULL (hard-coded)** | Not currently populated; field reserved |
| `email_address_hard_bounced_flag` | BOOLEAN | `marketing_bouncesystem` + `sfmc_email_events_cln` | TRUE if customer's email hard-bounced AND no engagement (send/open/click) occurred on a later calendar date AND email address has not changed since bounce |
| `email_address_soft_bounced_flag` | BOOLEAN | `marketing_bouncesystem` + `sfmc_email_events_cln` | TRUE if customer had ≥3 soft bounce events within last 180 days, occurring after any email address change, AND no engagement occurred on a later calendar date |
| `etl_build_mst_ts` | TIMESTAMP | `FROM_UTC_TIMESTAMP(CURRENT_TIMESTAMP(), 'MST')` | Pipeline execution timestamp in MST |

---

## Business Logic — Key Rules (from code comments + SQL)

### Hard Bounce Flag
- Sources: Marketing Bounce System (codes HB) + SFMC (`bounce_category = 'Hard bounce'`)
- **Reset Rule 1 (Email Change):** If bounce occurred *before* the customer's last email address change (`signals_platform_cln.profile_audit_lake_cln_v2`), the bounce is discarded (treated as belonging to the old address).
- **Reset Rule 2 (Re-engagement):** If any engagement signal (send, open, or click from OEG or SFMC) occurred on a *later calendar date* than the most recent hard bounce, flag is reset to FALSE.

### Soft Bounce Flag — 180-Day Rolling Window with 3-Bounce Threshold
- Sources: Marketing Bounce System (codes SB, GB) + SFMC (`bounce_category = 'Soft bounce'`)
- **Threshold:** ≥3 qualifying soft bounce events within the last 180 days → TRUE; fewer → FALSE
- **Email Change Filter:** Only bounces that occurred *after* the customer's most recent email address change are counted. If no email change recorded, all 180-day bounces count (filter defaults to 1900-01-01).
- **Reset Rule 2 (Re-engagement):** Same as hard bounce — latest engagement after latest soft bounce → flag reset to FALSE.

### Competitor Email Flag
Hard-coded competitor list (~40 tokens):
`bluehost, zoho, 1and1, name, domain, ovh, wix, register, ionos, squarespace, networksolutions, hostinger, gmo, dreamhost, namecheap, dynadot, siteground, xinnet, gandi, tucows, above, weebly, gname, enom, sav, moniker, mydomain, fabulous, key-systems, ascio, inww, joker, dotster, hichina, netfirms, porkbun, directnic, namesilo, onlinenic, edomains, schlund, resellerclub, cronon, namebright, psi-usa, fastdomain, publicdomainregistry, domaindiscover, newfolddigital`

---

## DDL Files Consulted

### `ddls/customer_suppression.ddl` (local)
- Database: `marketing_mart_local.customer_suppression`
- Stored as PARQUET
- All columns match PySpark output
- `TBLPROPERTIES: processing_dag_name = customer_suppression`

### `ddls/customer_suppression_history.ddl` (local)
- Database: `marketing_mart_local.customer_suppression_history`
- Same columns + `hist_mst_ts TIMESTAMP`
- Partitioned by `load_mst_date date`
- History populated by `main_to_history_ckpetl_eds_ss.py` (common utility)

### `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.ddl`
- Database: `customer_suppression` (without schema prefix; lake catalog)
- Matches all columns from PySpark
- Adds comment on `private_label_13_suppression_flag`: *"Private Label suppression, the same email address is tied to a Reseller and they have purchased from that Reseller in the last 12 months"*

### `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.yaml`
- Description: `"EDS for marketing customer suppression data"`
- Table type: `LATEST_SNAPSHOT`
- Storage format: Parquet
- Data tier: 3
- SLA: `cron(0 13 * * ? *)` (6 AM MST)
- Permissions: dri_analytics, edt, martech_data, analytics, mktgdata, data_platform, data_cards, cetinsights
- Lineage lists 19 upstream tables (matches code **except**: does not list `marketing_mart.customer` separately; see Conflicts)

---

## Policies Files Consulted

### `policies/customer_suppression_dag.yaml`
- Schema URN: `urn:dna:pipeline:metadata:/v1`
- Pipeline version: 1.0.0
- Description: "Customer Suppression workflow"
- SLA max duration: 300 minutes, severity TIER_3
- Outputs: `marketing_mart.customer_suppression`, `marketing_mart_local.customer_suppression_history`, `marketing_mart_local.customer_suppression`
- Inputs: Lists all 19 upstream tables (consistent with code)

### `policies/environment.prod.yaml`
- Team: EDT, OnCall: DEV-EDT-OnCall
- Contact: `edt-airflow-alerts` Slack, `emerald-data-team-org@godaddy.com`
- MWAA environment: `dps-custmktg`
- AWS accounts: mktgdata prod (`664289052486`), datalake (`028140660016`), ckpetlbatch (`688051721285`)

---

## Data Quality Files Consulted

### `data_quality/constraints/customer_suppression.json`
- Database: `marketing_mart`, Table: `customer_suppression`
- One constraint: `customer_id` is primary key (`isPrimaryKey("customer_id")`, enabled: true, type: USER_DEFINED)

---

## Confluence

### Page 10370826 — "Customer - Customer Suppression"
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10370826/Customer+-+Customer+Suppression

**Summary of relevant content:**
- Documents the migration from the legacy MDM/Teradata `ShopAcctSuprs_V2` system to the Data Lake EDS
- **Current logic (legacy):** Suppression flags were: TrrstCtryFlg, RstkCtryFlg, XcldEmlFlg, CmptEmlFlg, BadCharInNmFlg, VlgrFstNmFlg, VlgrLastNmFlg, IntrnlShopAcctFlg, FrdFlg, BadEmlFmtFlg, DontCntctFlg, SftBncFlg, HardBncFlg, PL13Flag
- **New EDS logic:** Removes deprecated flags (DontCntctFlg, FrdFlg, BadCharInNmFlg, VlgrFstNmFlg, VlgrLastNmFlg, MktgEmlFlg, MktgNonPromEmlFlg, DontCallFlg)
- **Column mapping documented (section 6):** customer_id → shopper identity; internal_account_flag (was IntrnlShopAcctFlg); private_label_13_suppression_flag (was PL13Flag); restricted_country_flag; excluded_email_flag; competitor_email_flag; bad_email_address_format_flag; email_address_hard_bounced_flag; email_address_soft_bounced_flag
- **SLA:** Daily
- **Data sources tracked** for migration from SQL Server / Teradata to Data Lake

### Child Page 3114766874 — "Analysis and Design of Customer Suppression"
URL: https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3114766874/Analysis+and+Design+of+Customer+Suppression

**Summary of relevant content:**
- Technical design document consolidating suppression flags from MdmCustomer and MdmCustomerSuppression
- Provides original Teradata column lineage (from FortKnox attributes, MDM, CustomerTracking, eComm blocked country tables)
- Maps legacy `fortknox.tdaemailattributes_snap` fields to EDS fields (see Conflicts section — current code does not use FortKnox; it derives bounce flags from live event data)
- Original data flow diagrams and ETL references (Teradata/MDM era, now superseded)

---

## Alation

### Redshift Dev Serverless Table (dev.* entry)
| Field | Value |
|---|---|
| Name | `customer_suppression` |
| Database | Redshift - Serverless - Dev |
| Schema | `dev.marketing_mart` |
| Alation Key | `132.dev.marketing_mart.customer_suppression` |
| Alation Table ID | 6987832 |
| Alation URL | https://godaddy.alationcloud.com/table/6987832/ |

### Lake Table
| Field | Value |
|---|---|
| Name | `customer_suppression` |
| Schema | `AwsDataCatalog.marketing_mart` |
| Alation Key | `81.AwsDataCatalog.marketing_mart.customer_suppression` |
| Alation Table ID | 6619866 |
| Title | Customer Suppression |
| Alation URL | https://godaddy.alationcloud.com/table/6619866/ |

**Alation description (from lake entry):**
> EDS for marketing customer suppression data  
> **Primary Key(s):** customer_id  
> **Common Use Cases:** Identify if the customer should be excluded from marketing campaigns  
> **Usage Notes:** Daily snapshot data  
> **Workflow — Airflow Dag Name:** customer_suppression  
> **Success Flag Location:** s3://gd-mktgdata-{ENV}-eds/marketing_mart_local/customer_suppression

*(Note: GitHub repo referenced in Alation description as `de-marketing-mart-eds` is stale — actual repo is `dps-customermarketing`)*

### Other Alation Entries Found (not primary)
| Key | ID | Notes |
|---|---|---|
| `63.bi.marketing_mart_spectrum.customer_suppression` | 6619874 | Redshift Prod-BI (bi.*) — NOT the dev entry |
| `147.cet.marketing_mart.customer_suppression` | 7044320 | CET environment |
| `147.cet.marketing_egress_mart.customer_suppression` | 7044260 | CET egress |
| `147.cet.marketing_mart_spectrum.customer_suppression` | 7043711 | CET spectrum |

---

## Alation Queries

10 most recently saved queries containing "customer_suppression" (ordered by `ts_last_saved` descending):

| # | Query ID | Title | Datasource | Last Saved | Schedule | Alation URL |
|---|---|---|---|---|---|---|
| 1 | 127671 | SMS Campaigns (WDS) | Redshift - Serverless - Dev | 2025-11-20 | Not scheduled | https://godaddy.alationcloud.com/query/127671/ |
| 2 | 113896 | Sam Campaign Code | Redshift - Prod-BI | 2025-08-19 | Not scheduled | https://godaddy.alationcloud.com/query/113896/ |
| 3 | 126796 | Ongoing SF Loss Emails | Redshift - Serverless - Dev | 2025-08-18 | Not scheduled | https://godaddy.alationcloud.com/query/126796/ |
| 4 | 127407 | DATAGOV_WhatsApp_StandardSuppression | Redshift - Prod-BI | 2025-07-28 | Not scheduled | https://godaddy.alationcloud.com/query/127407/ |
| 5 | 124303 | Ongoing SF Loss Emails | Redshift - Serverless - Dev | 2025-05-19 | Not scheduled | https://godaddy.alationcloud.com/query/124303/ |
| 6 | 118630 | Large SEO Campaign Pull | Redshift - Prod-BI | 2025-01-31 | Not scheduled | https://godaddy.alationcloud.com/query/118630/ |
| 7 | 118595 | SEO Campaign - Google and Meta Code | Redshift - Prod-BI | 2025-01-31 | Not scheduled | https://godaddy.alationcloud.com/query/118595/ |
| 8 | 118535 | WDS Seed Rerun V2 | Redshift - Prod-BI | 2025-01-31 | Not scheduled | https://godaddy.alationcloud.com/query/118535/ |
| 9 | 117784 | Ongoing SF Loss Emails | Redshift - Prod-BI | 2025-01-28 | Not scheduled (disabled; was `0 7 * * *`) | https://godaddy.alationcloud.com/query/117784/ |
| 10 | 101385 | Tbl - CM Sizing Gen | Redshift - Prod-BI | 2025-01-24 | Not scheduled (disabled; was `0 13 * * *`) | https://godaddy.alationcloud.com/query/101385/ |

**Query 127407 — DATAGOV_WhatsApp_StandardSuppression** (directly JOINs `marketing_mart.customer_suppression`):
```sql
WITH whatsapp_welcome_message_receivers AS (
    SELECT mc.customer_id
    FROM messaging_delivery_platform_cln.delivery_status_cln ds
        JOIN messaging_delivery_platform_cln.message_context_cln mc ON ds.message_id = mc.message_id
        JOIN sfmc_metadata_cln.sfmc_metadata_channel_cln mch ON CAST(mch.cms_omni_channel_id AS VARCHAR) = mc.channel_id
        JOIN marketing_mart.customer_consent cc ON cc.customer_id = mc.customer_id
    WHERE ds.delivery_channel = 'WhatsApp'
        AND ds.status = 'Delivered'
        AND LOWER(mch.internal_source_code) IN ('sfwawelc','sfwawelcad','sfwawlinkb','sfwawlinka', 'wawelc')
        AND mc.sent_utc_ts >= COALESCE(cc.whats_app_marketing_update_utc_ts, DATE '2022-01-01')
        AND cc.whats_app_marketing_opted_in_flag = TRUE
    GROUP BY mc.customer_id
)
SELECT customer_id, is_in_whatsapp_standard_suppression AS in_whatsapp_standard_suppression_flag
FROM (
    SELECT mc.customer_id,
        CASE
            WHEN COALESCE(cs.restricted_country_flag, false) = TRUE
                OR COALESCE(cs.internal_account_flag, false) = TRUE
                OR COALESCE(cs.private_label_13_suppression_flag, false) = TRUE
                OR (cc.whats_app_marketing_opted_in_flag = TRUE AND wsr.customer_id IS NULL)
            THEN 'TRUE' ELSE 'FALSE'
        END AS is_in_whatsapp_standard_suppression
    FROM user_data_mart.customer mc
    JOIN marketing_mart.customer_consent cc ON mc.customer_id = cc.customer_id
    JOIN marketing_mart.customer_suppression cs ON mc.customer_id = cs.customer_id
    LEFT JOIN whatsapp_welcome_message_receivers wsr ON mc.customer_id = wsr.customer_id
) as i
WHERE is_in_whatsapp_standard_suppression = 'TRUE'
```

*Remaining 9 queries reference `customer_suppression` in campaign audience-building logic (variable counts of occurrences); see Alation URLs above for full SQL.*

---

## Conflicts / Discrepancies

| # | Field/Area | What Docs Say | What Code Says | Resolution |
|---|---|---|---|---|
| 1 | `excluded_email_flag` | DDL defines as BOOLEAN NOT NULL (lake DDL has no comment); Confluence section 4.3 says "if email address flagged as excluded — fortknox.tdaemailattributes_snap.excludedemailflag" | Code sets to `NULL AS excluded_email_flag` always | **Code is authoritative.** Flag is not currently populated. |
| 2 | `bad_email_address_format_flag` | DDL defines as BOOLEAN; Confluence section 4.5 says "fortknox.tdaemailattributes_snap.bademailformatflag" | Code sets to `NULL AS bad_email_address_format_flag` always | **Code is authoritative.** Flag is not currently populated. |
| 3 | `email_address_hard_bounced_flag` source | Confluence section 4.6: sourced from `fortknox.tdaemailattributes_snap.hardbounceflag` | Code derives from `marketing_bouncesystem` + `sfmc_email_events_cln` with re-engagement reset logic | **Code is authoritative.** FortKnox no longer used; direct event sourcing with 2 reset rules. |
| 4 | `email_address_soft_bounced_flag` source | Confluence section 4.7: sourced from `fortknox.tdaemailattributes_snap.softbounceflag` | Code uses 180-day rolling window with ≥3 bounce threshold from live event data | **Code is authoritative.** Significantly more complex logic than Confluence documents. |
| 5 | `competitor_email_flag` source | Confluence section 4.4: sourced from `fortknox.tdaemailattributes_snap.competitoremailflag` | Code uses hard-coded list of ~40 competitor domain tokens applied to `marketing_mart.customer.email_domain` | **Code is authoritative.** No FortKnox dependency. |
| 6 | Lake table.yaml lineage | Does not list `marketing_mart.customer` as upstream | PySpark uses `marketing_mart.customer` as the base driver table; DAG has S3 sensor for it | **Code+DAG authoritative.** Missing from lake lineage YAML; needs update. |
| 7 | Alation GitHub repo link | Points to `de-marketing-mart-eds/blob/main/customer/customer_suppression/src/dag/customer_suppression.py` | Actual repo is `dps-customermarketing`, path is `customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` | **Code is authoritative.** Alation description has stale repo reference. |
| 8 | Alation success flag location | `s3://gd-mktgdata-{ENV}-eds/marketing_mart_local/customer_suppression` | `policies/customer_suppression_dag.yaml` output location: `s3://gd-ckpetlbatch-prod-mktgdata-eds/marketing_mart_local/customer_suppression` | Minor discrepancy in env var substitution pattern; bucket account difference (mktgdata vs ckpetlbatch). Policies YAML is more specific. |


**The agent's final response to the user was:**
Here is a summary of what was researched and documented:

---

## Research Summary — `marketing_mart.customer_suppression`

### Sources consulted
1. **PySpark script** (`customer/eds-customer-suppression/src/pyspark/customer_suppression.py`) — authoritative source of truth for all logic
2. **DAG** (`customer_suppression_dag.py`) — authoritative for schedule, dependencies, job params
3. **DDL files** — `customer_suppression.ddl`, `customer_suppression_history.ddl` (local) + `repos/lake/catalog/.../table.ddl` and `table.yaml`
4. **Policies YAML** — `customer_suppression_dag.yaml`, `environment.prod.yaml`
5. **Data quality** — `constraints/customer_suppression.json`
6. **Confluence** — Page 10370826 + child page 3114766874 (design doc)
7. **Alation** — Table search (6 entries found) + 10 saved queries

### Key findings

| Area | Value |
|---|---|
| **Output table** | `marketing_mart.customer_suppression` (lake) |
| **Grain** | One row per `customer_id` (DQ-enforced primary key) |
| **Schedule** | Daily, 4:00 AM MST (prod); SLA 6:00 AM MST |
| **Upstream tables** | 19 tables across 8 databases (all S3-sensor-gated) |
| **Bounce logic** | Complex: 2-source (bouncesystem + SFMC), 2-reset-rules (email change + re-engagement); soft bounce has 180-day/3-event rolling window |
| **Notable nulls** | `excluded_email_flag` and `bad_email_address_format_flag` are always NULL in code (reserved fields) |
| **Alation Lake entry** | ID 6619866 — https://godaddy.alationcloud.com/table/6619866/ |
| **Alation Dev Serverless** | ID 6987832 — https://godaddy.alationcloud.com/table/6987832/ |
| **Key downstream use** | WhatsApp suppression logic (Alation query 127407) joins this table to determine standard suppression |
| **Conflicts found** | 8 discrepancies — most significant: Confluence documents FortKnox as the bounce flag source, but code derives directly from event tables; `excluded_email_flag` and `bad_email_address_format_flag` are not populated despite DDL defining them |