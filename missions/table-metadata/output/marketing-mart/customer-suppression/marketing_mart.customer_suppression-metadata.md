# Business Context: marketing_mart.customer_suppression

## Pillar A: WHAT Is It? — Identity & Purpose

### A1. Table Overview

| Field | Value |
|---|---|
| **Table Name** | `customer_suppression` |
| **Database** | Redshift - Serverless - Dev |
| **Schema** | `marketing_mart` |
| **Alation URL** | [customer_suppression (Redshift - Serverless - Dev)](https://godaddy.alationcloud.com/table/6987832/) |
| **Lake Alation URL** | [customer_suppression (Lake)](https://godaddy.alationcloud.com/table/6619866/) |
| **Lake Table** | `marketing_mart.customer_suppression` |
| **Grain** | One row per `customer_id` — all customers present in `marketing_mart.customer` at time of daily snapshot |
| **Partition Key** | None — full daily overwrite (LATEST_SNAPSHOT) |
| **Storage Format** | Parquet |
| **Table Type** | LATEST_SNAPSHOT |
| **Data Tier** | 3 |
| **SLA** | 6:00 AM MST daily |
| **Refresh Cadence** | Daily |
| **History Table** | `marketing_mart_local.customer_suppression_history` (partitioned by `load_mst_date`) |
| **Lake Registry Path** | `catalog/config/prod/us-west-2/marketing-mart/customer-suppression/` |
| **S3 Location (prod)** | `s3://gd-ckpetlbatch-prod-mktgdata-eds/marketing_mart_local/customer_suppression` |
| **Airflow DAG ID** | `customer_suppression` |

---

### A2. What This Table Is About

`marketing_mart.customer_suppression` is the **central marketing suppression list** for GoDaddy's customer database. It provides a single daily snapshot with one row per customer, containing boolean flags that together determine whether — and for what reason — a customer should be excluded from marketing communications.

The table covers eight suppression dimensions (six active, two reserved for future use):

| Suppression Dimension | Flag Column | Status |
|---|---|---|
| Internal GoDaddy employee account | `internal_account_flag` | Active |
| Private Label 13 reseller customer | `private_label_13_suppression_flag` | Active |
| Geographically restricted country/region | `restricted_country_flag` | Active |
| Competitor email domain | `competitor_email_flag` | Active |
| Email hard-bounced | `email_address_hard_bounced_flag` | Active |
| Email soft-bounced (3+ events / 180 days) | `email_address_soft_bounced_flag` | Active |
| Excluded email (reserved) | `excluded_email_flag` | **Not populated — always NULL** |
| Bad email format (reserved) | `bad_email_address_format_flag` | **Not populated — always NULL** |

The table replaced the legacy MDM/Teradata `ShopAcctSuprs_V2` suppression system as part of the Data Lake EDS migration. Marketing teams JOIN this table against their target audience and filter out any customer where a relevant suppression flag is TRUE before sending campaigns.

---

### A3. Organizational Context & Ownership

| Field | Value |
|---|---|
| **Domain** | Customer |
| **Sub-domain** | Customer |
| **Layer** | Enterprise |
| **Team** | EDT (Emerald Data Team) |
| **DAG Owner tag** | `mdpe` |
| **Failure alert** | `#edt-airflow-alerts` (Slack) |
| **On-call Slack** | `#marketing-data-product-engineering` |
| **On-call email** | `dl-bi-enterprise-data@godaddy.com` |
| **Team email** | `emerald-data-team-org@godaddy.com` |
| **MWAA Environment** | `dps-custmktg` |
| **Lake access groups** | `dri_analytics`, `edt`, `martech_data`, `analytics`, `mktgdata`, `data_platform`, `data_cards`, `cetinsights` |

---

## Pillar B: WHY Does It Matter? — Value & Use Cases

### B1. Key Business Value

This table is the authoritative pre-send exclusion list for GoDaddy marketing. It answers the question: **"Should this customer receive marketing communications?"**

Key business value:
- **Single source of truth** for all suppression criteria — teams do not need to independently derive bounce status, country restrictions, or internal account flags from raw event tables.
- **Cross-channel coverage** — used for email, WhatsApp, SMS, and other marketing channels. Each channel applies the flags relevant to that channel's requirements.
- **Data freshness** — refreshed daily, ensuring suppression logic reflects the most recent bounce events, engagement resets, and customer account changes.
- **Regulatory and brand protection** — restricts sends to geographically blocked countries/regions, excludes competitor email addresses, and prevents marketing to internal employees.
- **Legacy replacement** — migrated from Teradata `ShopAcctSuprs_V2`, consolidating suppression logic under the Data Lake EDS pattern with direct event-source derivation (no FortKnox dependency).

---

### B2. Primary Use Cases

#### Questions this table answers

- Should this customer be excluded from a marketing campaign?
- Is this customer's email address currently hard-bounced?
- Has this customer's email soft-bounced 3 or more times in the last 180 days?
- Did a customer re-engage (open, click, or receive a send) after their last bounce, thereby resetting their bounce suppression?
- Is this customer located in a country or region where GoDaddy does not permit marketing sends?
- Is this a GoDaddy internal employee account that should be excluded from external marketing?
- Does this customer use a competitor's email domain?
- Is this customer a customer of a Private Label 13 reseller partner who purchased from that reseller within the last 12 months?
- How many customers in a given audience are suppressed, and for what reasons?

---

#### Alation Queries

#### Query: SMS Campaigns (WDS)

| Field | Value |
|---|---|
| Query ID | 127671 |
| Title | SMS Campaigns (WDS) |
| Author | |
| Description | |
| Schedule | Not scheduled |
| Last Saved | 2025-11-20 |
| Last Run | |
| Datasource | Redshift - Serverless - Dev |
| Alation Query URL | https://godaddy.alationcloud.com/query/127671/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: Sam Campaign Code

| Field | Value |
|---|---|
| Query ID | 113896 |
| Title | Sam Campaign Code |
| Author | |
| Description | |
| Schedule | Not scheduled |
| Last Saved | 2025-08-19 |
| Last Run | |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/113896/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: Ongoing SF Loss Emails

| Field | Value |
|---|---|
| Query ID | 126796 |
| Title | Ongoing SF Loss Emails |
| Author | |
| Description | |
| Schedule | Not scheduled |
| Last Saved | 2025-08-18 |
| Last Run | |
| Datasource | Redshift - Serverless - Dev |
| Alation Query URL | https://godaddy.alationcloud.com/query/126796/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: DATAGOV_WhatsApp_StandardSuppression

| Field | Value |
|---|---|
| Query ID | 127407 |
| Title | DATAGOV_WhatsApp_StandardSuppression |
| Author | |
| Description | Determines WhatsApp standard suppression status per customer. A customer is suppressed if they are in a restricted country, an internal account, a Private Label 13 customer, or opted in to WhatsApp marketing but have not received a WhatsApp welcome message. |
| Schedule | Not scheduled |
| Last Saved | 2025-07-28 |
| Last Run | |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/127407/ |

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

---

#### Query: Ongoing SF Loss Emails

| Field | Value |
|---|---|
| Query ID | 124303 |
| Title | Ongoing SF Loss Emails |
| Author | |
| Description | |
| Schedule | Not scheduled |
| Last Saved | 2025-05-19 |
| Last Run | |
| Datasource | Redshift - Serverless - Dev |
| Alation Query URL | https://godaddy.alationcloud.com/query/124303/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: Large SEO Campaign Pull

| Field | Value |
|---|---|
| Query ID | 118630 |
| Title | Large SEO Campaign Pull |
| Author | |
| Description | |
| Schedule | Not scheduled |
| Last Saved | 2025-01-31 |
| Last Run | |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/118630/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: SEO Campaign - Google and Meta Code

| Field | Value |
|---|---|
| Query ID | 118595 |
| Title | SEO Campaign - Google and Meta Code |
| Author | |
| Description | |
| Schedule | Not scheduled |
| Last Saved | 2025-01-31 |
| Last Run | |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/118595/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: WDS Seed Rerun V2

| Field | Value |
|---|---|
| Query ID | 118535 |
| Title | WDS Seed Rerun V2 |
| Author | |
| Description | |
| Schedule | Not scheduled |
| Last Saved | 2025-01-31 |
| Last Run | |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/118535/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: Ongoing SF Loss Emails

| Field | Value |
|---|---|
| Query ID | 117784 |
| Title | Ongoing SF Loss Emails |
| Author | |
| Description | |
| Schedule | Not scheduled (disabled; was `0 7 * * *`) |
| Last Saved | 2025-01-28 |
| Last Run | |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/117784/ |

```sql
-- Full SQL available at Alation URL above
```

---

#### Query: Tbl - CM Sizing Gen

| Field | Value |
|---|---|
| Query ID | 101385 |
| Title | Tbl - CM Sizing Gen |
| Author | |
| Description | |
| Schedule | Not scheduled (disabled; was `0 13 * * *`) |
| Last Saved | 2025-01-24 |
| Last Run | |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/101385/ |

```sql
-- Full SQL available at Alation URL above
```

---

### B3. Advanced Analytics Use Cases

- **Cross-channel suppression analysis** — Compare suppression flag rates across customer segments (country, acquisition channel, product) to understand marketing reach.
- **Bounce trend analysis** — Use the daily history table (`marketing_mart_local.customer_suppression_history`) to track the rate of hard and soft bounce suppression over time and measure re-engagement campaign effectiveness.
- **Geographic marketing eligibility** — Combine `restricted_country_flag` with customer attributes to identify marketable populations by region.
- **Suppression overlap analysis** — Identify customers suppressed for multiple reasons and understand the compounding effect on audience size.
- **Campaign audience sizing** — Before a campaign launch, join this table to a target audience to calculate the reach after suppression exclusions and plan accordingly.

---

## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance

### C1. Complete Column Reference with Data Insights

| Column | Type | Nullable | Description | Source Table(s) |
|---|---|---|---|---|
| `customer_id` | STRING | NOT NULL | Primary key. Unique GoDaddy customer identifier. One row per customer. | `marketing_mart.customer` |
| `shopper_id` | STRING | NOT NULL | GoDaddy shopper identifier associated with the customer. | `marketing_mart.customer` |
| `internal_account_flag` | BOOLEAN | NOT NULL | TRUE if this is a GoDaddy internal employee account AND the customer is not a temporary shopper. Derived from `customer360.dim_customer_vw.internal_shopper_flag` for the current SCD record; COALESCE to FALSE if no match. Temporary shoppers always evaluate to FALSE regardless of the dim_customer_vw value. | `customer360.dim_customer_vw` |
| `private_label_13_suppression_flag` | BOOLEAN | **NULLABLE** | TRUE if the customer's email address is shared with a Private Label 13 reseller partner AND they have purchased from that reseller in the last 12 months. NULL if the customer is not found in the crossover table (i.e., no PL13 relationship recorded). | `cust_customertracking.shopper_crossover_cln` |
| `restricted_country_flag` | BOOLEAN | NOT NULL | TRUE if the customer's country code matches a GoDaddy blocked country (all regions) or a blocked country-region combination. FALSE otherwise. | `marketing_mart.customer`, `ecomm_cln.gdshop_blocked_country_region_cln`, `ecomm_cln.gdshop_blocked_country_cln` |
| `excluded_email_flag` | BOOLEAN | NULLABLE | **Always NULL — reserved field, not currently populated.** Intended for future use to flag explicitly excluded email addresses. | *(none — hard-coded NULL)* |
| `competitor_email_flag` | BOOLEAN | NULLABLE | TRUE if any dot-delimited token in the customer's email domain matches a term in the hard-coded competitor list (~49 tokens, e.g., wix, ionos, squarespace, namecheap). NULL if the customer has no `email_domain` value in `marketing_mart.customer` (no COALESCE applied after LEFT JOIN). Treat NULL as not suppressed; use `COALESCE(competitor_email_flag, FALSE)` in boolean conditions. | `marketing_mart.customer` |
| `bad_email_address_format_flag` | BOOLEAN | NULLABLE | **Always NULL — reserved field, not currently populated.** Intended for future use to flag malformed email addresses. | *(none — hard-coded NULL)* |
| `email_address_hard_bounced_flag` | BOOLEAN | NOT NULL | TRUE if the customer's email received at least one hard bounce AND no re-engagement (send, open, or click) occurred on a later calendar date AND the email address has not changed since the bounce. Sources: OEG Marketing Bounce System (code `HB`) and SFMC (`bounce_category = 'Hard bounce'`). | `marketing_bouncesystem.bouncesystem_bounced_email_snap`, `marketing_bouncesystem.bouncesystem_bounced_email_log_snap`, `marketing_bouncesystem.bouncesystem_bounce_type_snap`, `sfmc_email_events_cln.sfmc_email_events_bounce_cln`, `sfmc_email_events_cln.sfmc_email_events_send_log_cln`, `signals_platform_cln.oeg_email_event_send_cln`, `signals_platform_cln.oeg_email_event_open_cln`, `signals_platform_cln.profile_audit_lake_cln_v2`, `sfmc_email_events_cln.sfmc_email_events_open_cln`, `sfmc_email_events_cln.sfmc_email_events_click_cln`, `emailsystem.oc_emailqueuesuccesstrackingclick_snap`, `emailsystem.oc_emailqueuesuccesstracking_snap`, `emailsystem.oc_emailqueuesuccess_snap`, `emailsystem.oc_emailqueuedetail_snap` |
| `email_address_soft_bounced_flag` | BOOLEAN | NOT NULL | TRUE if the customer's email accumulated ≥3 qualifying soft bounce events within the last 180 days AND no re-engagement occurred on a later calendar date. Only bounces that occurred after the customer's most recent email address change are counted. Sources: OEG (codes `SB`, `GB`) and SFMC (`bounce_category = 'Soft bounce'`). | Same 14 source tables as `email_address_hard_bounced_flag` |
| `etl_build_mst_ts` | TIMESTAMP | NOT NULL | Timestamp of when the ETL job ran, in MST timezone. Computed as `FROM_UTC_TIMESTAMP(CURRENT_TIMESTAMP(), 'MST')` at job execution time on EMR. Not a data event timestamp. | *(pipeline runtime — computed)* |

---

### C2. Primary Key & Performance

| Aspect | Details |
|---|---|
| **Primary Key** | `customer_id` (single column, STRING) |
| **Uniqueness enforcement** | DQ constraint `isPrimaryKey("customer_id")` — USER_DEFINED, enabled. Checked in DAG task `dq_cs` after every run. |
| **Grain anchor** | `marketing_mart.customer` is the base driver; all suppression flags are LEFT-JOINed onto it. Every customer in `marketing_mart.customer` at run time has exactly one row in this table. |
| **Partitioning** | None — LATEST_SNAPSHOT is a full daily overwrite of all rows. |
| **Sort / cluster keys** | None defined. |
| **Recommended join key** | Always join on `customer_id`. |
| **Table size** | Matches the cardinality of `marketing_mart.customer` at run time (one row per customer in that table). No filters are applied to the customer base in this ETL to reduce the customer universe. |

---

### C3. Key Features, Capabilities & Limitations

**Features:**
- Daily full refresh — suppression status is current as of each morning's run.
- Two-source bounce logic — both OEG (Marketing Bounce System) and SFMC events are considered for bounce flags, providing complete cross-platform coverage.
- Re-engagement resets — bounce flags are automatically reset when a customer engages after their most recent bounce event.
- Email-change awareness — bounce flags are cleared when a customer changes their email address, preventing suppression based on a stale address.
- History table — `marketing_mart_local.customer_suppression_history` captures daily snapshots partitioned by `load_mst_date` for point-in-time lookback.

**Limitations:**
- `excluded_email_flag` and `bad_email_address_format_flag` are **always NULL** in the current implementation. These columns are reserved for future use.
- `private_label_13_suppression_flag` can be NULL (no COALESCE applied). NULL means the customer has no Private Label 13 relationship recorded — treat as "not suppressed," but handle carefully in WHERE clauses.
- `competitor_email_flag` can be NULL for customers whose `email_domain` is NULL in `marketing_mart.customer` — the ETL filters these customers out of the competitor check and applies no COALESCE after the LEFT JOIN. Treat NULL as "not suppressed" and use `COALESCE(competitor_email_flag, FALSE)` in boolean expressions.
- The competitor email domain list is hard-coded in the PySpark script (~49 tokens). It is not a table-driven configuration and may differ between code versions.
- The soft bounce window is fixed at 180 days and the threshold is fixed at 3 events. These are not configurable at query time.
- Re-engagement resets require engagement on a **strictly later calendar date** than the bounce — same-day engagement does NOT reset the flag.

---

### C4. Important Notes & Pitfalls

1. **`excluded_email_flag` and `bad_email_address_format_flag` are always NULL.** Do not use these columns to filter audiences — they will never be TRUE. They are reserved for future implementation.

2. **`private_label_13_suppression_flag` can be NULL, not just TRUE/FALSE.** A NULL means the customer is not in the crossover table (i.e., no PL13 relationship). Use `COALESCE(private_label_13_suppression_flag, FALSE)` if you need a strict boolean.

2a. **`competitor_email_flag` can also be NULL** for customers who have no `email_domain` value in `marketing_mart.customer`. The ETL excludes NULL email domains from the competitor check CTE and does not apply a COALESCE on the result. Use `COALESCE(competitor_email_flag, FALSE)` in boolean conditions to be safe.

3. **Re-engagement must occur on a later calendar date than the bounce.** An open or click on the same day as the bounce does not reset the bounce flag. Only a send, open, or click dated strictly after the bounce date resets the flag.

4. **Soft bounce flag uses a 180-day rolling window.** Soft bounces older than 180 days are not counted, even if the customer never re-engaged. The threshold is ≥3 events within that window.

5. **Bounce flags reflect the most recent email address.** If a customer changed their email address after a hard bounce, the hard bounce flag is reset — the old bounce is treated as belonging to the old address. This is intentional.

6. **The Alation description references a stale GitHub repository** (`de-marketing-mart-eds`). The actual source repository is `gdcorp-dna/dps-customermarketing`.

7. **This table is NOT partitioned.** Do not attempt partition pruning. The table is a complete daily snapshot with no partition columns.

8. **Channel-specific suppression:** Not all flags apply to all channels. For example, the WhatsApp suppression query (Alation ID 127407) applies `restricted_country_flag`, `internal_account_flag`, and `private_label_13_suppression_flag`, but not bounce flags. Always apply only the flags relevant to your channel and campaign type.

---

### C5. Always-On Column Filters

The following filters are applied inside the ETL and affect the values stored in this table. They cannot be changed or bypassed by consumers.

| Filter | Applied To | Effect |
|---|---|---|
| `current_record_flag = true` | `customer360.dim_customer_vw` (source for `internal_account_flag`) | Only the current (non-historical) SCD record is used. Consumers always see the current internal-account status. |
| `temporary_shopper_flag = FALSE` (join condition) | `marketing_mart.customer` for `internal_account_flag` join | Temporary shoppers are always assigned `internal_account_flag = FALSE`, regardless of their value in `dim_customer_vw`. |
| `error_code_id IS NULL` | OEG email send events (for bounce resolution) | Error sends are excluded from engagement reset signals. Only clean sends are considered re-engagement. |
| `event_unique_flag = TRUE` | SFMC bounce, open, and click events | Duplicate SFMC events are excluded; only unique events per send-subscriber combination are counted. |
| 180-day rolling window | Soft bounce event filtering | Only soft bounce events within the last 180 days are counted toward the 3-event threshold. Older bounces are ignored. |
| 365-day window | OCM click tracking (`emailsystem.*`) | OCM click engagement data is limited to the last 365 days for performance. Per code comments, this does not affect flag correctness for normal cases. |

---

### C6. Common Business Metrics

The following metrics are commonly computed from this table to understand suppression scope:

| Metric | Definition |
|---|---|
| **Hard bounce rate** | `COUNT(CASE WHEN email_address_hard_bounced_flag = TRUE THEN 1 END) / COUNT(*)` — proportion of customers with a hard-bounced email |
| **Soft bounce rate** | `COUNT(CASE WHEN email_address_soft_bounced_flag = TRUE THEN 1 END) / COUNT(*)` — proportion of customers with ≥3 soft bounces in 180 days |
| **Total email-suppressed** | Customers where `email_address_hard_bounced_flag OR email_address_soft_bounced_flag` |
| **Restricted country rate** | `COUNT(CASE WHEN restricted_country_flag = TRUE THEN 1 END) / COUNT(*)` |
| **Internal account count** | `COUNT(CASE WHEN internal_account_flag = TRUE THEN 1 END)` |
| **Competitor email count** | `COUNT(CASE WHEN competitor_email_flag = TRUE THEN 1 END)` |
| **PL13 suppressed count** | `COUNT(CASE WHEN private_label_13_suppression_flag = TRUE THEN 1 END)` |
| **Total suppressed (any flag)** | Customers where at least one active flag is TRUE — use `COALESCE` for nullable flags: `(email_address_hard_bounced_flag OR email_address_soft_bounced_flag OR restricted_country_flag OR internal_account_flag OR COALESCE(competitor_email_flag, FALSE) OR COALESCE(private_label_13_suppression_flag, FALSE))` |
| **Audience reach %** | `COUNT(CASE WHEN NOT (email_address_hard_bounced_flag OR email_address_soft_bounced_flag OR restricted_country_flag OR internal_account_flag OR COALESCE(competitor_email_flag, FALSE) OR COALESCE(private_label_13_suppression_flag, FALSE)) THEN 1 END) / COUNT(*)` — effective marketable population |

---

### C7. Glossary & Term Definitions

| Term | Definition |
|---|---|
| **Hard bounce** | A permanent email delivery failure, such as an invalid address or non-existent domain. In this table, sourced from OEG Marketing Bounce System (code `HB`) and SFMC (`bounce_category = 'Hard bounce'`). |
| **Soft bounce** | A temporary email delivery failure (e.g., full mailbox, server unavailable). In this table, a customer is flagged when they accumulate ≥3 soft bounce events (OEG codes `SB` or `GB`; SFMC `bounce_category = 'Soft bounce'`) within the last 180 days. |
| **Re-engagement reset** | A rule that clears a bounce suppression flag when the customer sends, opens, or clicks on a later calendar date than their most recent bounce event. Applies to both hard and soft bounce flags. |
| **Email change reset** | A rule that clears bounce history when a customer updates their email address, as bounce records belong to the old address. Uses `signals_platform_cln.profile_audit_lake_cln_v2` to detect address changes. |
| **Private Label 13 (PL13)** | A GoDaddy reseller program designation. A customer is PL13-suppressed when their email is associated with a PL13 reseller and they have purchased from that reseller within the last 12 months. |
| **Restricted country** | A country or country-region combination where GoDaddy does not permit marketing sends, as defined in `ecomm_cln.gdshop_blocked_country_cln` and `ecomm_cln.gdshop_blocked_country_region_cln`. |
| **Internal account** | A GoDaddy employee or internal test account, identified via `customer360.dim_customer_vw.internal_shopper_flag`. Excluded from all external marketing communications. |
| **Competitor email** | An email address where the domain contains a token matching the hard-coded competitor list in the ETL (~49 domain tokens, e.g., wix, squarespace, namecheap). |
| **LATEST_SNAPSHOT** | A lake table type that is fully overwritten on each pipeline run. There are no incremental appends — each run replaces all rows. |
| **OEG / OCM** | OEG (Omni-channel Email Gateway) and OCM (Omni-channel Marketing) — GoDaddy's internal email sending platforms. Bounce and engagement events from these systems feed the bounce flag logic. |
| **SFMC** | Salesforce Marketing Cloud — an external email marketing platform used by GoDaddy. Bounce and engagement events from SFMC also feed the bounce flag logic. |
| **EDS** | Enterprise Data Store — the pattern for lake tables that serve as authoritative, analytics-ready datasets for a business domain. |
| **`customer_id`** | Unique identifier for a GoDaddy customer (distinct from `shopper_id`; a shopper may be associated with multiple customers or contexts). |

---

### C8. Example Queries & Patterns

#### Pattern 1: Exclude all suppressed customers from an email campaign

```sql
-- Filter a candidate audience to remove suppressed customers
-- Adjust the flag combination based on your channel and campaign type
SELECT
    c.customer_id,
    c.email_address
FROM my_campaign_audience c
JOIN marketing_mart.customer_suppression cs
    ON c.customer_id = cs.customer_id
WHERE cs.email_address_hard_bounced_flag = FALSE
  AND cs.email_address_soft_bounced_flag = FALSE
  AND cs.restricted_country_flag          = FALSE
  AND cs.internal_account_flag            = FALSE
  AND COALESCE(cs.private_label_13_suppression_flag, FALSE) = FALSE
  AND COALESCE(cs.competitor_email_flag, FALSE)            = FALSE
;
```

#### Pattern 2: Count suppression breakdown for an audience

```sql
-- Understand which suppression flags are affecting your audience
SELECT
    COUNT(*)                                                    AS total_customers,
    SUM(CASE WHEN email_address_hard_bounced_flag THEN 1 END)  AS hard_bounced,
    SUM(CASE WHEN email_address_soft_bounced_flag THEN 1 END)  AS soft_bounced,
    SUM(CASE WHEN restricted_country_flag         THEN 1 END)  AS restricted_country,
    SUM(CASE WHEN internal_account_flag           THEN 1 END)  AS internal_accounts,
    SUM(CASE WHEN COALESCE(competitor_email_flag, FALSE) THEN 1 END) AS competitor_emails,
    SUM(CASE WHEN COALESCE(private_label_13_suppression_flag, FALSE) THEN 1 END) AS pl13_suppressed,
    SUM(CASE WHEN (
        email_address_hard_bounced_flag
        OR email_address_soft_bounced_flag
        OR restricted_country_flag
        OR internal_account_flag
        OR COALESCE(competitor_email_flag, FALSE)
        OR COALESCE(private_label_13_suppression_flag, FALSE)
    ) THEN 1 END)                                              AS total_suppressed
FROM my_campaign_audience c
JOIN marketing_mart.customer_suppression cs ON c.customer_id = cs.customer_id
;
```

#### Pattern 3: Look up suppression flags for a specific customer

```sql
-- Spot-check a single customer's current suppression status
SELECT *
FROM marketing_mart.customer_suppression
WHERE customer_id = '<target_customer_id>'
;
```

#### Pattern 4: Point-in-time suppression from history table

```sql
-- Retrieve suppression status as of a specific past date
-- Uses the history table (in marketing_mart_local, partitioned by load_mst_date)
SELECT *
FROM marketing_mart_local.customer_suppression_history
WHERE customer_id   = '<target_customer_id>'
  AND load_mst_date = DATE '2025-06-01'
;
```

---

## Pillar D: HOW Is It Built? — Pipeline & Provenance

### D1. Data Source Reference

The table is built from **19 upstream lake tables** across 8 source databases, all gate-checked via S3KeySensors in the DAG before execution begins.

| # | Source Table | Database | Role in Pipeline |
|---|---|---|---|
| 1 | `customer` | `marketing_mart` | Base driver table — defines the customer universe. Provides `customer_id`, `shopper_id`, `country_code`, `city_name`, `email_domain`, `temporary_shopper_flag`. |
| 2 | `bouncesystem_bounced_email_snap` | `marketing_bouncesystem` | Hard/soft bounce records from the OEG Marketing Bounce System. |
| 3 | `bouncesystem_bounced_email_log_snap` | `marketing_bouncesystem` | Bounce log events with `date_created`, `bounce_type_id`, `template_id`, `message_id`. |
| 4 | `bouncesystem_bounce_type_snap` | `marketing_bouncesystem` | Bounce type reference (SB = Soft, GB = Soft, HB = Hard). |
| 5 | `oeg_email_event_send_cln` | `signals_platform_cln` | OEG email send events — resolves `customer_id` from template/message IDs; also used as engagement reset signal. |
| 6 | `oeg_email_event_open_cln` | `signals_platform_cln` | OEG email open events — engagement reset signal. |
| 7 | `profile_audit_lake_cln_v2` | `signals_platform_cln` | Customer email address change audit — used to invalidate bounces that occurred on the old email address. |
| 8 | `sfmc_email_events_bounce_cln` | `sfmc_email_events_cln` | SFMC bounce events with `bounce_category` and `event_utc_ts`. |
| 9 | `sfmc_email_events_send_log_cln` | `sfmc_email_events_cln` | SFMC send log — resolves `customer_id`; engagement reset signal. |
| 10 | `sfmc_email_events_open_cln` | `sfmc_email_events_cln` | SFMC open events — engagement reset signal. |
| 11 | `sfmc_email_events_click_cln` | `sfmc_email_events_cln` | SFMC click events — engagement reset signal. |
| 12 | `oc_emailqueuesuccesstrackingclick_snap` | `emailsystem` | OCM click tracking (~30B rows); filtered to 365-day window. Engagement reset signal. |
| 13 | `oc_emailqueuesuccesstracking_snap` | `emailsystem` | OCM click tracking chain (~3.7B rows). |
| 14 | `oc_emailqueuesuccess_snap` | `emailsystem` | OCM email queue success records. |
| 15 | `oc_emailqueuedetail_snap` | `emailsystem` | OCM email queue detail carrying `messageguid`. |
| 16 | `dim_customer_vw` | `customer360` | Internal shopper flag lookup; filtered to current SCD record. |
| 17 | `shopper_crossover_cln` | `cust_customertracking` | Private Label 13 flag (`pool_13_active_flag`). |
| 18 | `gdshop_blocked_country_region_cln` | `ecomm_cln` | Blocked country-region combinations reference. |
| 19 | `gdshop_blocked_country_cln` | `ecomm_cln` | Blocked country reference. |

---

### D2. Data Pipeline & Infrastructure

| Field | Value |
|---|---|
| **Source repository** | `gdcorp-dna/dps-customermarketing` (branch: `main`) |
| **PySpark script** | `customer/eds-customer-suppression/src/pyspark/customer_suppression.py` |
| **DAG file** | `customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` |
| **Policies YAML** | `customer/eds-customer-suppression/src/policies/customer_suppression_dag.yaml` |
| **Data quality constraints** | `customer/eds-customer-suppression/src/data_quality/constraints/customer_suppression.json` |
| **Orchestration** | Apache Airflow (MWAA environment: `dps-custmktg`) |
| **Compute** | Amazon EMR 7.2.0 (PySpark) |
| **DAG ID** | `customer_suppression` |
| **Write pattern** | PySpark writes to `marketing_mart_local.customer_suppression` (S3 staging); DAG `SuccessNotificationOperator` (`datalake_success_cs` task) publishes to `marketing_mart.customer_suppression` (lake, prod only) |

**High-level DAG flow:**
1. 19 S3KeySensors wait for all upstream lake tables to deliver their daily files.
2. EMR cluster is created.
3. PySpark job runs — reads all 19 source tables, computes suppression flags, writes full snapshot.
4. History utility appends the new snapshot to the history table.
5. Data quality check (`dq_cs`) validates `customer_id` primary key uniqueness.
6. Local success file is written; lake API is called (prod only) to publish the snapshot.

---

### D3. SLA & Refresh Schedule

| Field | Value |
|---|---|
| **Prod schedule** | `0 4 * * *` — 4:00 AM MST (America/Phoenix) daily |
| **SLA deadline** | 6:00 AM MST — `cron(0 13 * * ? *)` UTC |
| **Start date** | 2024-04-25 |
| **Catchup** | Disabled (`catchup=False`) |
| **Max active runs** | 1 |
| **Retries** | 1 retry, 3-minute delay |
| **Max pipeline duration** | 300 minutes (5 hours) before TIER_3 SLA alert triggers |
| **Dependencies** | All 19 upstream lake tables must have delivered their daily S3 success file before the EMR job starts |
| **SLA risk note** | `sfmc_email_events_cln` tables have a 6:00 AM MST SLA — matching this table's deadline. Late SFMC delivery would delay `customer_suppression`. |

---

### D4. Table Creation & ETL Implementation

The pipeline uses the standard CKPetl EDS LATEST_SNAPSHOT pattern:

1. **Input scope:** `marketing_mart.customer` defines the full customer universe. Every customer in that table receives a row in the output regardless of whether they have any suppression flags set.

2. **Flag computation:** Each suppression flag is computed independently via CTEs and LEFT JOINs. The base `marketing_mart.customer` table is the spine, and each flag computation contributes one boolean column per customer.

3. **Bounce logic (most complex):** Both OEG (Marketing Bounce System) and SFMC are queried for bounce events. For each source, bounce records are joined back to identify the `customer_id`. Two reset rules are applied: (a) email address change after the bounce invalidates it; (b) any engagement event (send/open/click from OEG, SFMC, or OCM) on a strictly later calendar date resets the flag.

4. **Write target:** The final DataFrame is written via `transform_stg()` to `marketing_mart_local.customer_suppression` (local S3), then the DAG invokes the lake API to publish it as `marketing_mart.customer_suppression`.

5. **History:** A separate utility script (`main_to_history_ckpetl_eds_ss.py`) appends the snapshot to `marketing_mart_local.customer_suppression_history` partitioned by `load_mst_date`.

6. **Data quality:** After history write, DAG task `dq_cs` runs the DQ constraint (`isPrimaryKey("customer_id")`). A failure halts the pipeline before the lake success signal is sent.

---

## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem

### E1. Data Quality Checks

| Check | Type | Column(s) | Details |
|---|---|---|---|
| Primary key uniqueness | USER_DEFINED | `customer_id` | `isPrimaryKey("customer_id")` — enforces that every row has a unique, non-null `customer_id`. Enabled. |

- DQ constraint source: `customer/eds-customer-suppression/src/data_quality/constraints/customer_suppression.json`
- The check runs as DAG task `dq_cs`, executed after the history write and before the local success file is created. A DQ failure prevents the lake success signal from being sent.
- No column-level null checks are defined for the flag columns.
- `excluded_email_flag` and `bad_email_address_format_flag` are always NULL by design; no DQ assertion exists for this behavior.
- `private_label_13_suppression_flag` is nullable (LEFT JOIN, no COALESCE); this is intentional and unchecked.

---

### E2. Best Practices & Tips

- **Always join on `customer_id`** — this is the unique key and is DQ-validated.
- **Apply only the flags relevant to your channel.** Email campaigns typically use hard bounce, soft bounce, competitor email, internal account, and restricted country. WhatsApp uses restricted country, internal account, and PL13. Not all flags apply to all channels.
- **Handle `private_label_13_suppression_flag` and `competitor_email_flag` as nullable.** Use `COALESCE(private_label_13_suppression_flag, FALSE)` and `COALESCE(competitor_email_flag, FALSE)` when combining flags in boolean conditions to avoid unexpected NULL propagation. Both columns can be NULL due to LEFT JOINs without COALESCE.
- **Do not use `excluded_email_flag` or `bad_email_address_format_flag`.** These columns are always NULL and will never filter any rows.
- **For point-in-time queries, use the history table.** The primary lake table reflects only the most recent daily snapshot. Access `marketing_mart_local.customer_suppression_history` and filter by `load_mst_date` for historical analysis.
- **Verify SLA timing before scheduling downstream jobs.** The table SLA is 6:00 AM MST. Jobs that depend on this table should be scheduled to wait for the S3 success signal, not assume a fixed time.
- **Understand re-engagement semantics before interpreting bounce flags.** A customer who was hard-bounced but then received and opened a subsequent email will have `email_address_hard_bounced_flag = FALSE`. This is expected behavior — they re-engaged.

---

### E3. Related Articles & Documentation

| Resource | Link |
|---|---|
| Confluence: Customer - Customer Suppression | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/10370826/Customer+-+Customer+Suppression |
| Confluence: Analysis and Design of Customer Suppression | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3114766874/Analysis+and+Design+of+Customer+Suppression |
| Alation: Lake table entry | https://godaddy.alationcloud.com/table/6619866/ |
| Alation: Redshift Serverless Dev entry | https://godaddy.alationcloud.com/table/6987832/ |
| Lake registry (DDL + YAML) | `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/` |
| Source PySpark script | `repos/dps-customermarketing/customer/eds-customer-suppression/src/pyspark/customer_suppression.py` |
| Airflow DAG | `repos/dps-customermarketing/customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` |
