**Stage name:** research
**The coding agent was given these instructions:** You are a Data Governance analyst enriching column descriptions for a Data Lake table.

## Step 1: Read INPUT.md
Read `INPUT.md` in your workspace. It contains:
- The TARGET TABLE (database, table name, DDL path, YAML path)
- CONFLUENCE PAGES to fetch
- REFERENCE TABLES for Alation lookup
- ALATION configuration

Use these details for all subsequent steps.

## Step 2: Read the Table DDL and Metadata
From INPUT.md, determine the DDL and YAML paths. Read those EXACT files
from the cloned repository under `repos/lake/`.

## Step 3: Fetch Confluence Pages
For each URL listed in INPUT.md under CONFLUENCE PAGES, use the Atlassian
REST API to fetch page content. The page ID is the numeric part of the URL path.
For example, from URL `.../pages/10371978/Fact_Bill_Line`, the page ID is `10371978`.

**Credentials:** Confluence credentials are in the `MOONUNIT_JIRA` env var (JSON).
Extract them first:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_JIRA); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Alternatively, if `MOONUNIT_ATLASSIAN` is set:
```bash
ATLASSIAN_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ATLASSIAN); console.log(j.email + ':' + j.api_token)")
curl -s -u "$ATLASSIAN_CREDS" \
  "https://godaddy-corp.atlassian.net/wiki/rest/api/content/{PAGE_ID}?expand=body.storage"
```

Fetch ALL pages listed in INPUT.md. Extract and summarize content relevant to
understanding what each column represents.

## Step 4: Alation Lookup (if enabled)
Check INPUT.md for ALATION configuration. If enabled:

First, extract Alation credentials and get an API access token:
```bash
ALATION_CREDS=$(node -e "const j=JSON.parse(process.env.MOONUNIT_ALATION); console.log(JSON.stringify({refresh_token:j.refresh_token, user_id:j.user_id}))")
curl -s -X POST "https://godaddy.alationcloud.com/integration/v1/createAPIAccessToken/" \
  -H "Content-Type: application/json" \
  -d "$ALATION_CREDS"
```
This returns a JSON with `api_access_token`. Use it as `TOKEN` header for subsequent calls.

Then search for the table (use the table name from INPUT.md, with underscores):
```
curl "https://godaddy.alationcloud.com/integration/v2/table/?name={table_name_underscored}&limit=5" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Look for the entry with ds_id=81 (AwsDataCatalog) and matching schema. Note the table `id`.

Then fetch column metadata:
```
curl "https://godaddy.alationcloud.com/integration/v2/column/?table_id={table_id}&limit=200" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Each column object contains these important fields:
- `name` — column name
- `description` — user-authored description in Alation (may be empty)
- `column_comment` — **Source Comment** propagated from the DDL COMMENT clause
  in the Data Lake Registry (GitHub). This is the existing inline comment from
  the table's DDL file. It may contain valuable annotations like 'Employee PII',
  business definitions, or enum descriptions that MUST be preserved or incorporated.
- `title` — display title in Alation

Extract BOTH `description` and `column_comment` for each column. When writing
enriched descriptions:
- If `column_comment` contains important annotations (e.g., 'Employee PII',
  enum values, business rules), these MUST be preserved in the enriched comment.
- If `column_comment` already has a meaningful description, use it as a strong
  starting point and enhance it to meet the Column Description Standard.
- If both `description` and `column_comment` exist, merge the information.

Also capture the table-level description from the search result, which contains
rich context about primary keys, use cases, and data quirks.

## Step 4a: Reference/Successor Tables
Check INPUT.md for REFERENCE TABLES. If any are listed, look up each table's
columns in Alation to extract existing column descriptions.

For each reference table, use the provided `alation_table_id`:
```
curl "https://godaddy.alationcloud.com/integration/v2/column/?table_id={alation_table_id}&limit=200" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Extract both `description` and `column_comment` (Source Comment) for each column.
The `column_comment` field contains the DDL inline comment from the reference table's
Data Lake Registry — these are existing descriptions written by data engineers and
are a primary source of truth for what columns mean.
Also fetch the table-level metadata:
```
curl "https://godaddy.alationcloud.com/integration/v2/table/?id={alation_table_id}" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Map columns from the reference table to the target table by name. Where column names
match, carry over the description as a strong candidate for the target column's comment.

## Step 4b: Certified Data Dictionary (Alation Document Folder 6) — MANDATORY
**CRITICAL:** You MUST fetch and use the official GoDaddy Certified Data Dictionary
definitions from Alation (Document Folder ID 6, URL: https://godaddy.alationcloud.com/doc-folder/6/).
These are GoDaddy's AUTHORITATIVE definitions. NEVER invent, guess, or fabricate
what an abbreviation stands for. If the dictionary says "GCR = Gross Cash Receipts",
you MUST use "Gross Cash Receipts" — not "Gross Customer Receipt" or any other variation.

**Procedure:**
1. Fetch ALL documents from the folder (paginate with skip):
```
curl "https://godaddy.alationcloud.com/integration/v2/document/?folder_id=6&limit=50&skip=0" \
  -H "TOKEN: $API_ACCESS_TOKEN"
curl "https://godaddy.alationcloud.com/integration/v2/document/?folder_id=6&limit=50&skip=50" \
  -H "TOKEN: $API_ACCESS_TOKEN"
curl "https://godaddy.alationcloud.com/integration/v2/document/?folder_id=6&limit=50&skip=100" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```

2. Build a lookup table mapping abbreviations/terms to their official names:
Each document has `id`, `title`, `description` (HTML body).
The `title` contains the official term, e.g.:
- "Gross Cash Receipts (GCR)" — GCR = Gross Cash Receipts
- "New Registered User (NRU) Count" — NRU = New Registered User
- "Monthly Recurring Revenue (MRR)" — MRR = Monthly Recurring Revenue

3. For EVERY abbreviation found in column names (e.g., gcr, mrr, nru, mau, aos),
look up its official expansion in the dictionary titles. If found, you MUST use
the exact official name — DO NOT paraphrase or invent alternative expansions.

4. For each matching document, fetch its full definition:
```
curl "https://godaddy.alationcloud.com/integration/v2/document/?id={doc_id}" \
  -H "TOKEN: $API_ACCESS_TOKEN"
```
Extract the official definition from the `description` field (HTML).

5. In your research output, create a section called "## Certified Data Dictionary Mappings"
that explicitly lists EVERY abbreviation → official name mapping you found.
Example:
```
| Abbreviation | Official Name | Document ID |
|---|---|---|
| GCR | Gross Cash Receipts | 6 |
| MSRP | Manufacturer's Suggested Retail Price | (not in dictionary) |
```

**RULE: If an abbreviation is in the Certified Data Dictionary, its official expansion
is the ONLY acceptable expansion. Never fabricate alternatives.**

## Step 5: Produce Research Output
The framework pre-created `research.md` in your workspace with a header.
Append — do not overwrite — a structured research document containing:
- The full current DDL
- Key metadata from table.yaml (description, lineage, upstream dependencies)
- Summarized knowledge from Confluence pages
- Alation catalog metadata (if available), including Source Comments (column_comment)
  from both the target table and reference tables
- Certified Data Dictionary Mappings (the mandatory table from Step 4b)
- For each column: current DDL comment (if any), Alation Source Comment (if any),
  Alation description (if any), inferred purpose, and relevant context from all sources

Environment variables available (all are JSON, parse with node):
- MOONUNIT_JIRA — {"url","email","api_token"} (use for Confluence access)
- MOONUNIT_ATLASSIAN — {"email","api_token"} (alternative Confluence creds)
- MOONUNIT_ALATION — {"url","refresh_token","user_id"} (Alation access)

**The agent summarized its work in this way:**

---

# Research Output: customer360.customer_life_cycle_vw

**Date:** 2026-06-10  
**Target Table:** customer360.customer_life_cycle_vw  
**DDL Path:** catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl  
**YAML Path:** catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml

---

## Table Overview (from table.yaml)

- **Description:** Analytic Dataset for Customer Life Cycle
- **Storage Format:** Parquet
- **Table Type:** PARTITIONED
- **Partition Key:** `partition_eval_mst_date` (string) — evaluation date partition (MST)
- **Data Tier:** 4
- **SLA:** Delivered by 08:00 AM MST every day (`cron(00 15 * * ? *)`)

### Upstream Dependencies (lineage)
- analytic_feature.customer_fraud
- analytic_feature.customer_type_history
- analytic_feature.shopper_acquisition
- analytic_feature.shopper_merge
- customer360.dim_customer_history_vw
- customers.customer_id_mapping_snapshot
- dp_enterprise.dim_reseller
- ecomm_mart.bill_line_traffic_ext
- ecomm_mart.dim_bill_line_purchase_attribution
- ecomm_mart.entitlement_bill_type
- enterprise.dim_bill_shopper_id_xref
- enterprise.dim_entitlement_history
- enterprise.dim_new_acquisition_shopper
- enterprise.dim_subscription_history
- enterprise.fact_bill_line
- enterprise.fact_entitlement_bill
- finance360.dim_bill_fraud_history_vw
- finance360.dim_country_vw
- finance360.dim_product_vw
- finance_cln.manual_paid_subscription

---

## Current DDL

```sql
CREATE TABLE customer_life_cycle_vw(
    customer_id                                         string          COMMENT '@PrimaryKey: Combination of Customer ID and partition_eval_mst_date. Customer_id is Unique UUID representing the customer entity across GoDaddy systems',
    shopper_id                                          string          COMMENT '@UniqueKey Unique numeric ID for the shopper profile used in eCommerce transactions',
    customer_acquisition_bill_id                        string          COMMENT '@ForeignKey (analytic_feature.shopper_acquisition) Bill ID that triggered first net positive status for customer',
    customer_acquisition_mst_date                       date            COMMENT 'Date of bill that triggered first net positive status for customer (MST)',
    customer_acquisition_mst_month                      string          COMMENT 'Month of customer acquisition (MST), truncated to month',
    customer_acquisition_country_code                   string          COMMENT 'Country code where customer was acquired',
    customer_acquisition_channel_name                   string          COMMENT 'Channel through which customer was acquired',
    customer_tenure_year_count                          int             COMMENT 'Tenure of the customer in years',
    customer_acquisition_country_name                   string          COMMENT 'Country name where customer was acquired',
    customer_region_1_name                              string          COMMENT 'Geographic region 1 for the customer',
    customer_region_2_name                              string          COMMENT 'Geographic region 2 for the customer',
    customer_region_3_name                              string          COMMENT 'Geographic region 3 for the customer',
    customer_domestic_international_name                string          COMMENT 'Whether customer is domestic or international',
    reseller_type_id                                    int             COMMENT '@ForeignKey (dp_enterprise.dim_reseller) Type ID of reseller organization',
    reseller_type_name                                  string          COMMENT 'Name of the reseller',
    customer_type_name                                  string          COMMENT 'Customer type label at evaluation date',
    customer_type_reason_desc                           string          COMMENT 'Customer type reason, e.g. why classified as this type',
    customer_fraud_flag                                 boolean         COMMENT 'True if customer is flagged as fraud at evaluation date',
    active_paid_subscription_list                       array<string>   COMMENT '@ForeignKey (enterprise.dim_subscription_history) List of active paid subscription_id for a specific customer',
    product_pnl_category_list                           array<string>   COMMENT 'List of product PNL categories owned by customer',
    product_pnl_category_qty                            int             COMMENT 'Number of distinct product PNL categories owned by customer',
    product_pnl_line_list                               array<string>   COMMENT 'List of product PNL lines owned by customer',
    ttm_all_bill_list                                   array<string>   COMMENT 'List of all bill IDs from trailing twelve months (TTM)',
    brand_name_list                                     array<string>   COMMENT 'List of all brands associated with the customer',
    ttm_gcr_usd_amt                                     decimal(18,2)   COMMENT 'Total gross cash received (GCR) USD in trailing twelve months',
    customer_churn_mst_date                             date            COMMENT 'MST date when customer most recently churned, null if not churned',
    customer_reactivate_mst_date                        date            COMMENT 'MST date when customer was most recently reactivated (after churn)',
    customer_merge_mst_date                             date            COMMENT 'MST date when the customer was merged into another account',
    customer_fraud_mst_date                             date            COMMENT 'MST date when a fraud flag was set on customer',
    customer_state_enum                                 string          COMMENT '@Enumerated(active, churned, merged, reactivated) customer states as of evaluation date ',
    active_status_flag                                  boolean         COMMENT 'True if customer is currently active at evaluation date',
    point_of_purchase_name                              string          COMMENT 'Point of purchase name from the customer acquisition bill',
    customer_acquisition_bill_fraud_flag                boolean         COMMENT 'True if acquisition bill has fraud record in dim_bill_fraud_history_vw',
    etl_build_mst_ts                                    timestamp       COMMENT 'Time when this record was build by ETL system'
)
```

---

## Confluence Page Summaries

### Page 1: Customer360 (ID: 3779199819)

**Key findings:**
- Customer360 is GoDaddy's single certified data product layer for the Customer domain, owned by FORGE (Foundational Data Products team).
- **customer_life_cycle_vw** is the "SSOT of customer's lifecycle holistically — compresses states and logic spread across 3 marts & built with SCD2 to understand change over time easily. Includes ALL customers (not just 'active') and opens up use cases outside of Finance."
- Replaces: `finance_cln.active_customer`, `finance_cln.active_customer_history`, `customer_mart.two_plus_active_customer`, `customer_mart.two_plus_active_customer_history`, `enterprise.dim_new_acquisition_shopper`, `enterprise.dim_new_registered_user`
- The table tracks lifecycle states: active, inactive, churned, and reactivated customers; new registered and lapsed users.
- Designed as an SCD2 model — partition_eval_mst_date enables historical analysis of customer lifecycle changes over time.
- Each record represents a customer's state on a specific evaluation date (partition_eval_mst_date).

### Page 2: Customer Lifecycle (ID: 3970861345)

**Key findings per column:**

| Column | Source Table(s) | Business Logic / Notes |
|---|---|---|
| customer_id | shopper_status_v2, customer_core_conformed, enterprise.dim_new_acquisition_shopper | Unique identifier across GoDaddy systems; Primary Key with partition_eval_mst_date |
| shopper_id | Multiple | Numeric ID for shopper profile in eCommerce |
| partition_eval_mst_date (partition) | — | Evaluation date partition |
| customer_acquisition_bill_id | enterprise.dim_new_acquisition_shopper, analytic_feature.shopper_acquisition | "The Day a user made a Payment"; joined on shopper_id/customer_id |
| customer_acquisition_mst_date | enterprise.dim_new_acquisition_shopper, enterprise.dim_subscription_history | Complex logic: if new customer with future acq date → set to subscription create date or eval date; if existing customer with non-past acq date → NULL |
| customer_acquisition_mst_month | enterprise.dim_new_acquisition_shopper, Date Dim | First Day of the Month of customer_acquisition_mst_date |
| customer_tenure_year_count | enterprise.dim_new_acquisition_shopper, analytic_feature.shopper_tenure | shopper_tenure_days_count / 365; joined on shopper_id/customer_id |
| customer_acquisition_country_code | analytic_feature.shopper_acquisition | bill_country_code = acq_country_code |
| customer_domestic_international_name | dim_geography | Joined on acq_country_code |
| customer_region_1/2/3_name | dim_geography | Geographic hierarchy joined on acq_country_code |
| customer_acquisition_country_name | dim_geography | Joined on acq_country_code |
| customer_acquisition_channel_name | ecomm_mart.bill_line_traffic_ext | channel_grouping_name; joined on new_acquisition_bill_id = acquisition_bill_id |
| reseller_type_id | analytic_feature.shopper_account_detail, dp_enterprise_linked.dim_reseller | Get private_label_id from shopper_account_detail for the shopper, then get reseller_type_id from dim_reseller via private_label_id join |
| customer_type_name | analytic_feature.customer_type_history | customer_type_name; joined on shopper_id |
| customer_type_reason_desc | analytic_feature.customer_type_history | customer_type_reason_desc; joined on shopper_id |
| active_paid_subscription_list | enterprise.fact_entitlement_last_payment (driver table) | List of subscription_ids for active paid customers |
| product_pnl_category_list | Driver table | List of product_pnl_category values |
| product_pnl_category_qty | Derived | Count of items in product_pnl_category_list |
| product_pnl_line_list | Driver table, customer_core_conformed.fact_active_entitlement_last_payment_detail | List of product_pnl_line values |
| ttm_all_bill_list | fact_customer_ttm_payment | All 12-month bill_ids for the shopper (originally audit-only column using last_net_positive_bill_id; future: full 12-month array) |
| ttm_gcr_usd_amt | fact_customer_ttm_payment | ttm_total_gcr_usd_amt; joined on shopper_id/customer_id |
| customer_churn_mst_date | Active customer table + shopper_churn_v2 | evaluation_mst_date when customer moved from active to churned (absent in active partition); null if not churned or if deactivated due to merge |
| customer_reactivate_mst_date | Active customer table | evaluation_mst_date when a previously-churned customer reappears (customer_acquisition_mst_date is in the past but customer is new to current partition) |
| customer_merge_mst_date | analytic_feature.shopper_merge | shopper_merge_end_mst_date; set only for the original/churned shopper_id, not the merged-into shopper_id |
| customer_fraud_mst_date | analytic_feature.customer_fraud | Join on customer_id / shopper_id |
| customer_state_enum | Derived | States: active, churned, merged, reactivated |
| active_status_flag | Derived | Boolean flag derived from customer_state_enum |
| point_of_purchase_name | ecomm_mart.bill_line_traffic_ext | From customer acquisition bill record |
| customer_acquisition_bill_fraud_flag | finance360.dim_bill_fraud_history_vw | Whether the acquisition bill has a fraud record |
| etl_build_mst_ts | ETL system | Build timestamp |

**Lifecycle state logic (from Confluence):**
- **Churned:** Customer was active on day-1 partition but absent from current day's active customer set → churn_mst_date = evaluation_mst_date. Metric columns are NULL; dimensional columns retain values.
- **Reactivated:** Customer appears in current day's active set, has no acquisition date = today, but has prior churn record → reactivate_mst_date = evaluation_mst_date.
- **Merged:** Customer was merged into another account → merge_mst_date = shopper_merge_end_mst_date (only the source/original shopper gets this date, not the surviving shopper_id).
- **Intra-day churn:** Subscriptions where subscription_create_mst_date = subscription_cancel_mst_date; captured via special driver table filter.

---

## Alation Lookup

**Status:** Alation credentials not available in this environment (MOONUNIT_ALATION env var not set; ALATION_REFRESH_TOKEN env var not set). Alation lookup could not be performed for:
- Target table: customer360.customer_life_cycle_vw
- Reference tables: shopper_acquisition (6300171), customer_type_history (6365364), shopper_account_detail (6555393), dim_new_acquisition_shopper (6332252), shopper_tenure (6300179), bill_line_traffic_ext (6951872), customer_fraud (6620297), shopper_merge (6295888)
- Certified Data Dictionary (Document Folder ID 6)

---

## Certified Data Dictionary Mappings

Alation access was unavailable. The following abbreviations appear in column names and are mapped based on existing DDL comments and Confluence documentation:

| Abbreviation | Official Name (source) | Document ID |
|---|---|---|
| GCR | Gross Cash Received (from existing DDL comment: "Total gross cash received (GCR) USD in trailing twelve months") — NOTE: Verify against Certified Data Dictionary; official GoDaddy term may be "Gross Cash Receipts" | (dictionary unavailable) |
| TTM | Trailing Twelve Months (contextually clear from column usage) | (dictionary unavailable) |
| MST | Mountain Standard Time (timezone; standard GoDaddy time zone for date/timestamp columns) | (dictionary unavailable) |
| PNL | Profit and Loss (P&L line / category from product hierarchy) | (dictionary unavailable) |
| ETL | Extract, Transform, Load (pipeline process) | (dictionary unavailable) |

**WARNING:** The Certified Data Dictionary could not be consulted. The GCR expansion used in the existing DDL comment ("gross cash received") may differ from the official GoDaddy Certified Data Dictionary definition. The next pipeline stage MUST verify and correct this if the dictionary is accessible.

---

## Per-Column Analysis

| Column | DDL Comment | Confluence Source | Recommended Enrichment Focus |
|---|---|---|---|
| `customer_id` | @PrimaryKey: Combination with partition_eval_mst_date. Unique UUID across GoDaddy systems | Primary key, UUID | Clarify that PK is composite with partition_eval_mst_date |
| `shopper_id` | @UniqueKey Unique numeric ID for shopper profile | Numeric legacy ID for eCommerce | Clarify relationship between customer_id and shopper_id |
| `customer_acquisition_bill_id` | @ForeignKey (shopper_acquisition) Bill ID for first net positive status | enterprise.dim_new_acquisition_shopper + shopper_acquisition | FK annotation preserved; note it is the first paid bill |
| `customer_acquisition_mst_date` | Date of bill triggering first net positive status (MST) | Complex logic: fallback to subscription create date or eval date for edge cases | Add edge case handling notes |
| `customer_acquisition_mst_month` | Month of acquisition (MST), truncated to month | First Day of the Month of acquisition date | Add precision: first day of month (YYYY-MM-01 format) |
| `customer_acquisition_country_code` | Country code where customer was acquired | From acq_country_code in shopper_acquisition | Good as-is |
| `customer_acquisition_channel_name` | Channel through which customer was acquired | channel_grouping_name from bill_line_traffic_ext | Good as-is |
| `customer_tenure_year_count` | Tenure of the customer in years | shopper_tenure_days_count / 365 | Clarify: integer years derived from daily tenure count |
| `customer_acquisition_country_name` | Country name where customer was acquired | dim_geography via acq_country_code | Good as-is |
| `customer_region_1_name` | Geographic region 1 for the customer | dim_geography geographic hierarchy level 1 | Clarify: highest-level geographic grouping (e.g., continent/super-region) |
| `customer_region_2_name` | Geographic region 2 for the customer | dim_geography geographic hierarchy level 2 | Clarify: mid-level geographic grouping |
| `customer_region_3_name` | Geographic region 3 for the customer | dim_geography geographic hierarchy level 3 | Clarify: sub-region geographic grouping |
| `customer_domestic_international_name` | Whether customer is domestic or international | dim_geography | Clarify: based on GoDaddy HQ vs. non-US classification |
| `reseller_type_id` | @ForeignKey (dp_enterprise.dim_reseller) Type ID of reseller | private_label_id → dim_reseller lookup | FK annotation preserved; note the indirect join via private_label_id |
| `reseller_type_name` | Name of the reseller | Derived from dim_reseller | Add note: display name for reseller_type_id |
| `customer_type_name` | Customer type label at evaluation date | analytic_feature.customer_type_history | Good; note it reflects the evaluation-date snapshot |
| `customer_type_reason_desc` | Customer type reason | analytic_feature.customer_type_history | Good as-is |
| `customer_fraud_flag` | True if customer flagged as fraud at evaluation date | analytic_feature.customer_fraud | Good as-is; note it is evaluation-date point-in-time |
| `active_paid_subscription_list` | @ForeignKey (dim_subscription_history) List of active paid subscription_ids | Driver table: fact_entitlement_last_payment | Good; note NULLed on churn |
| `product_pnl_category_list` | List of product PNL categories owned by customer | Driver table | Good as-is |
| `product_pnl_category_qty` | Number of distinct product PNL categories | Count of product_pnl_category_list | Good as-is |
| `product_pnl_line_list` | List of product PNL lines owned by customer | Driver table | Good as-is |
| `ttm_all_bill_list` | List of all bill IDs from trailing twelve months (TTM) | All 12-month bill_ids; audit-purpose column | Note: currently audit-only; full 12-month history is planned |
| `brand_name_list` | List of all brands associated with the customer | Brands derived from products/subscriptions | Good as-is |
| `ttm_gcr_usd_amt` | Total gross cash received (GCR) USD in trailing twelve months | ttm_total_gcr_usd_amt from fact_customer_ttm_payment | **VERIFY GCR abbreviation against Certified Data Dictionary** |
| `customer_churn_mst_date` | MST date when customer most recently churned, null if not churned | evaluation_mst_date when customer absent from active set | Good; note null for merged customers |
| `customer_reactivate_mst_date` | MST date when customer was most recently reactivated (after churn) | evaluation_mst_date when previously-churned customer reappears | Good as-is |
| `customer_merge_mst_date` | MST date when the customer was merged into another account | shopper_merge_end_mst_date from shopper_merge | Note: set only on source (original) shopper, not the surviving shopper |
| `customer_fraud_mst_date` | MST date when a fraud flag was set on customer | analytic_feature.customer_fraud | Good as-is |
| `customer_state_enum` | @Enumerated(active, churned, merged, reactivated) customer states as of evaluation date | Derived from lifecycle state logic | Good; enum values documented; trailing space in comment should be trimmed |
| `active_status_flag` | True if customer is currently active at evaluation date | Derived from state = 'active' | Good as-is |
| `point_of_purchase_name` | Point of purchase name from the customer acquisition bill | From bill_line_traffic_ext acquisition bill | Good as-is |
| `customer_acquisition_bill_fraud_flag` | True if acquisition bill has fraud record in dim_bill_fraud_history_vw | finance360.dim_bill_fraud_history_vw | Good; source table explicitly mentioned |
| `etl_build_mst_ts` | Time when this record was build by ETL system | ETL pipeline build timestamp | Minor typo fix: "build" → "built" |

---

## Summary

The current DDL comments are reasonably well-described. The main enrichment opportunities are:

1. **ttm_gcr_usd_amt** — Verify GCR abbreviation expansion ("Gross Cash Received" in current DDL vs. potentially "Gross Cash Receipts" per GoDaddy Certified Data Dictionary). Correct if needed.
2. **customer_acquisition_mst_month** — Clarify it is stored as the first day of the month (e.g., YYYY-MM-01).
3. **customer_region_1/2/3_name** — Add clarity on geographic hierarchy levels (continent, sub-region, country cluster).
4. **customer_tenure_year_count** — Clarify it is an integer derived from shopper_tenure_days_count / 365.
5. **customer_state_enum** — Trailing space in existing comment; clean up.
6. **etl_build_mst_ts** — Typo fix ("build" → "built").
7. **customer_merge_mst_date** — Add note that this is only set on the original/source shopper_id, not the surviving merged shopper.
8. **reseller_type_name** — Clarify it is the display name corresponding to reseller_type_id.
9. All comments are generally consistent and provide good business context. The SCD2 / partition_eval_mst_date context is well-established from the @PrimaryKey annotation on customer_id.

**The agent's final response to the user was:**
The research has been appended to `research.md`. Here is a summary of what I did and found:

## Work Summary

**Step 1-2: Read table files**
- DDL: `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl` — 35 columns with existing COMMENT annotations
- YAML: Partition key `partition_eval_mst_date`, Data Tier 4, SLA = daily by 08:00 MST, 19 upstream dependencies

**Step 3: Fetched both Confluence pages**
- **Customer360** (3779199819): `customer_life_cycle_vw` is the SSOT for customer lifecycle, SCD2-based, replaces 5+ legacy datasets across `finance_cln`/`customer_mart`/`enterprise`
- **Customer Lifecycle** (3970861345): Detailed per-column data sources and business logic for all 35 columns including acquisition date edge-case handling, churn/reactivation logic, merge logic

**Step 4: Alation lookup**
- Not possible — neither `MOONUNIT_ALATION` nor `ALATION_REFRESH_TOKEN` env vars are set in this environment. All reference table lookups and the Certified Data Dictionary (Document Folder 6) were skipped.

**Key enrichment recommendations identified:**
1. **`ttm_gcr_usd_amt`** — Existing comment says "gross cash received (GCR)"; the Certified Data Dictionary may define GCR as "Gross Cash Receipts" — **needs verification in the next stage** when Alation is accessible
2. **`customer_acquisition_mst_month`** — Should clarify it's stored as YYYY-MM-01 (first day of month)
3. **`customer_region_1/2/3_name`** — Geographic hierarchy levels need labeling
4. **`customer_tenure_year_count`** — Derived as `shopper_tenure_days_count / 365`
5. **`etl_build_mst_ts`** — Minor typo: "build" → "built"
6. **`customer_merge_mst_date`** — Only set on source (original) shopper, not the surviving shopper_id after merge
7. **`customer_state_enum`** — Trailing whitespace in existing comment