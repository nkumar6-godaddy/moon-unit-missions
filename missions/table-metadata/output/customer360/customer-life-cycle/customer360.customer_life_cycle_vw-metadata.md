# Business Context: customer360.customer_life_cycle_vw

## Pillar A: WHAT Is It? — Identity & Purpose

### A1. Table Overview

| Field | Value |
|---|---|
| Table Name | customer_life_cycle_vw |
| Database | Redshift - Serverless - Dev |
| Schema | customer360 |
| Alation URL | https://godaddy.alationcloud.com/table/7038917/ |
| Table ID | 7038917 |
| Type | TABLE |
| Description | Daily lifecycle snapshot tracking customer acquisition, state transitions (new, active, churned, reactivated, merged, intraday), active subscription portfolio, and trailing twelve-month GCR. |
| Lake Table Name | customer_life_cycle_vw |
| Lake Database | GoDaddy Central Data Lake (Prod) |
| Lake Schema | customer360 |
| Lake Alation URL | https://godaddy.alationcloud.com/table/7038345/ |
| Lake Alation ID | 7038345 |
| Grain | One row per shopper_id + partition_eval_mst_date |
| Partition Key | partition_eval_mst_date (daily; STRING in Hive/Glue, DATE in Redshift) |
| Storage Format | Parquet |
| Data Tier | 4 |
| SLA Delivery Target | 08:00 AM MST daily |
| Refresh Cadence | Daily |
| DAG ID | customer-life-cycle |
| Internal Staging Table | customer_core_conformed.customer_life_cycle |
| Internal S3 Path | s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/ |
| Domain Tags | domain:customer, sub-domain:active-customer, layer:enterprise, team:EDT |

### A2. What This Table Is About

This table is a daily point-in-time snapshot of the complete lifecycle journey of every GoDaddy customer — from their initial acquisition through all subsequent state changes including churn, reactivation, and account merges. For each evaluation date, one row is written per unique shopper, capturing their current lifecycle state, active subscription portfolio, geographic and channel attributes, trailing twelve-month gross cash received (TTM GCR), and fraud signals.

**Key Features:**

- **Lifecycle state tracking:** Classifies every customer into one of six enumerated states — `new`, `active`, `churned`, `reactivated`, `merged`, or `intraday` — based on subscription activity compared across consecutive evaluation dates.
- **Active subscription portfolio:** Stores sorted arrays of active paid subscription IDs, product PNL categories and lines, and brand associations, enabling product penetration analysis at the customer grain.
- **Trailing twelve-month GCR:** Pre-computed customer-level TTM gross cash received in USD, filtered to net-positive, non-N/A-currency transactions.
- **Acquisition and geography dimensions:** Country of acquisition (with UK→GB normalization), acquisition channel (unified across legacy and current sources), reseller type, customer type (with 123 Reg brand override), and three-level regional hierarchy.
- **Fraud and merge signals:** Acquisition bill fraud flag, customer-level fraud flag with date, and merge date for compliance and exclusion workflows.
- **Finance driver table:** Serves as the primary driver table for customer-level aggregated metrics produced by downstream Customer Metrics pipelines, fulfilling Finance requirements for customer state and revenue attribution.

This table is designed to eliminate the need for complex multi-source joins at query time; all key customer dimensions, lifecycle events, and financial metrics are denormalized into a single daily row per customer.

### A3. Organizational Context & Ownership

| Field | Value |
|---|---|
| Domain | customer |
| Sub-domain | active-customer |
| Enterprise Layer | enterprise |
| Owning Team | EDT (Enterprise Data Team) |
| DAG Owner | customer360 |
| Initial Author | REQUIRES_MANUAL_INPUT |
| On-Call Slack | #marketing-data-product-engineering |
| On-Call Email | dl-bi-enterprise-data@godaddy.com |
| On-Call SNOW Group | DEV-EDT-OnCall |
| Alerts Channel (Prod) | #edt-airflow-alerts |
| Engineering Channel | #edt |
| Confluence Design Doc | Customer Lifecycle — https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3970861345/Customer+Lifecycle |

---

## Pillar B: WHY Does It Matter? — Value & Use Cases

### B1. Key Business Value

This table is the authoritative daily snapshot of GoDaddy's customer lifecycle at the individual shopper grain. Its key business contributions are:

- **Customer retention measurement:** The `customer_state_enum` and `customer_churn_mst_date` columns enable precise identification of when customers churned, allowing Retention and Finance teams to measure churn rates at any granularity (daily, monthly, by acquisition channel, country, or customer type).
- **Reactivation and win-back tracking:** `customer_reactivate_mst_date` flags re-acquisition events, enabling Marketing to measure win-back campaign effectiveness and attribute reactivations to channels.
- **Revenue analytics:** Pre-computed `ttm_gcr_usd_amt` per customer removes the need for expensive trailing-window aggregations at query time, enabling fast revenue segmentation and value-tier analysis.
- **Product penetration analysis:** Arrays of active PNL categories and subscription IDs per customer support 2+ product customer identification and multi-product ownership analysis.
- **Downstream Finance driver:** Customer Metrics aggregation pipelines consume this table as their primary input, making it a critical dependency for Finance-facing KPI reporting.
- **Operational analytics foundation:** Supports Care, Marketing, Micro Merchant, and Google Migration cohort analyses through a consistent, pre-joined customer state snapshot.

### B2. Primary Use Cases

**Questions this table answers:**

- What lifecycle state is each customer in as of a given date (new, active, churned, reactivated, merged, intraday)?
- Which customers churned between two evaluation dates, and from which acquisition channel or region?
- What is each customer's trailing twelve-month gross cash received (TTM GCR)?
- How many distinct product PNL categories does each customer currently own?
- Which customers were reactivated after a prior churn event?
- What is the tenure (in years) of each active customer?
- Which customers were acquired through a specific channel or in a specific country?
- Which customers have a fraud flag on their account or acquisition bill?
- What is the 2+ product customer base size and its churn rate over time?
- Which Micro Merchant customers are active GoDaddy customers and what is their product portfolio?

**Alation Queries**

#### [Serverless] Lighthouse Intent Dash

| Field | Value |
|---|---|
| Query ID | 123877 |
| Title | [Serverless] Lighthouse Intent Dash |
| Author | Not specified |
| Description | Migrated from query ID: 122917. Aligns care contact/intent dates to the nearest available lifecycle partition. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/123877/ |

Builds a product ownership date lookup by joining `customer_life_cycle_vw` partitions to care intent contact dates, finding the closest available lifecycle snapshot for each reporting date. Used in the Lighthouse intent dashboard to show customer product portfolio and state at the time of a care interaction.

#### C360 - mv_customer_churn_diagnostic

| Field | Value |
|---|---|
| Query ID | 139259 |
| Title | C360 - mv_customer_churn_diagnostic |
| Author | Not specified |
| Description | Monthly churn diagnostic materialized view using customer lifecycle data. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/139259/ |

Creates a monthly churn diagnostic view by pivoting `customer_life_cycle_vw` data across a calendar date spine, enabling month-over-month churn trend analysis with customer segment breakdowns for Customer360 reporting.

#### Union: Customer Lifecycle AND 2+Customer History

| Field | Value |
|---|---|
| Query ID | 139061 |
| Title | Union: Customer Lifecycle AND 2+Customer History |
| Author | Not specified |
| Description | Unions current customer lifecycle data with legacy 2+ product customer history for bridged cohort analysis. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/139061/ |

Creates a unified customer lifecycle table (`mv_legacy_c360_lifecycle`) that unions `customer_life_cycle_vw` with legacy Customer360 history data enriched with acquisition channel information, enabling cohort analysis that bridges pre- and post-migration customer records.

#### C360 - two_plus_churn_driver_tree

| Field | Value |
|---|---|
| Query ID | 138820 |
| Title | C360 - two_plus_churn_driver_tree |
| Author | Not specified |
| Description | Churn driver tree analysis for 2+ product customers. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138820/ |

Builds a pre-aggregated churn driver tree for customers with two or more products, using `customer_life_cycle_vw` to identify churn events and segment churned customers by acquisition channel, geography, and product portfolio for root cause analysis.

#### C360 - two_plus_customer_adds

| Field | Value |
|---|---|
| Query ID | 138821 |
| Title | C360 - two_plus_customer_adds |
| Author | Not specified |
| Description | New adds analysis for 2+ product customers. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138821/ |

Identifies newly acquired customers with two or more products using `customer_life_cycle_vw` filtered to `customer_state_enum = 'new'` and `product_pnl_category_qty >= 2`, measuring multi-product acquisition rates by channel and geography.

#### Micro Merchant Phase 2 Policy Instant Payouts

| Field | Value |
|---|---|
| Query ID | 138886 |
| Title | Micro Merchant Phase 2 Policy Instant Payouts |
| Author | Not specified |
| Description | Phase 2 Policy Instant Payouts analysis for MicroMerchants. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138886/ |

Analyzes GoDaddy Payments Micro Merchant customers by joining GoDaddy Payments business data to `customer_life_cycle_vw`, enriching each merchant with their GoDaddy customer lifecycle state, TTM GCR, and product portfolio to inform Phase 2 instant payouts policy decisions.

#### Micro Merchants Fast Payouts Analysis

| Field | Value |
|---|---|
| Query ID | 135046 |
| Title | Micro Merchants Fast Payouts Analysis |
| Author | Not specified |
| Description | Micro Merchants Fast Payouts Analysis. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/135046/ |

Joins GoDaddy Payments scoring model output to `customer_life_cycle_vw` to evaluate Micro Merchant customers' lifecycle status and revenue profile as part of fast payouts eligibility analysis.

#### Care Shopper Exploration

| Field | Value |
|---|---|
| Query ID | 123350 |
| Title | Care Shopper Exploration |
| Author | Not specified |
| Description | Migrated from query ID: 79354. Explores care shopper cohorts using lifecycle data. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/123350/ |

Builds a care shopper history staging table combining `customer_life_cycle_vw` lifecycle attributes (tenure, country, customer type) with Care CRM data, enabling cohort analysis of care-contacted shoppers by segment.

#### Google Migration Query V13 — DRAFT

| Field | Value |
|---|---|
| Query ID | 138288 |
| Title | Google Migration Query V13 — DRAFT (churn via customer_life_cycle_vw, 2a2b_v2, C3 >= 2026-04-01) |
| Author | Not specified |
| Description | Draft cohort query for Google domain migration analysis; churn sourced from customer_life_cycle_vw starting V13. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138288/ |

New-query fork of V12; switches shopper churn source to `customer_life_cycle_vw` for standardization, applying to customers cohorted from 2026-04-01 onward. Used to analyze churn behavior among Google domain migration candidates.

#### Google Migration Query V14 — DRAFT

| Field | Value |
|---|---|
| Query ID | 138291 |
| Title | Google Migration Query V14 — DRAFT (refund-aware renewals; refunded renewals count as cancelled) |
| Author | Not specified |
| Description | Extends V13 with refund-aware domain renewal logic; refunded renewals treated as cancellations. |
| Schedule | Manual execution |
| Last Saved | Not recorded |
| Last Run | Not recorded |
| Datasource | 132 (Redshift Serverless Dev) |
| Alation Query URL | https://godaddy.alationcloud.com/query/138291/ |

Builds on V13 by reclassifying refunded domain renewals as cancellations; continues to use `customer_life_cycle_vw` as the churn source for Google migration cohort analysis.

### B3. Advanced Analytics Use Cases

- **Cohort retention analysis:** Using `customer_acquisition_mst_date` and `customer_state_enum` across partition dates, analysts can construct customer cohort retention curves at any segment level (channel, country, product type).
- **Churn prediction feature store:** All lifecycle attributes (tenure, channel, country, product count, TTM GCR, fraud flags) are pre-computed at daily grain, making this an ideal feature source for churn propensity models.
- **Multi-product customer segmentation:** `product_pnl_category_qty` and `product_pnl_category_list` enable rapid segmentation of 1-, 2-, and 3+-product customers for targeting and value tier analysis.
- **Win-back / reactivation attribution:** `customer_reactivate_mst_date` combined with acquisition channel supports win-back campaign attribution and Marketing Mix Model (MMM) inputs.
- **Customer value tiers:** Combining `ttm_gcr_usd_amt`, `customer_tenure_year_count`, and `product_pnl_category_qty` enables multi-dimensional customer value segmentation (e.g., high-value active customers by region).
- **Google Migration cohort analysis:** `customer_state_enum` and `customer_churn_mst_date` provide standardized churn signals for tracking outcomes among Google domain migration candidates.

---

## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance

### C1. Complete Column Reference with Data Insights

| # | Name | Data Type | Description | Column Lineage | Category | Sample Values | Key Statistics |
|---|---|---|---|---|---|---|---|
| 1 | shopper_id | STRING | Unique numeric ID for the shopper profile; composite PK component | Derived from enterprise.dim_subscription_history.shopper_id for subscription-active customers; from enterprise.dim_bill_shopper_id_xref.merged_shopper_id (or enterprise.fact_bill_line.subaccount_shopper_id for Leka brand) for TTM-only customers | Identifier | | |
| 2 | customer_id | STRING | Unique UUID representing the customer entity across GoDaddy systems | From enterprise.dim_subscription_history.customer_id (subscription customers) or customers.customer_id_mapping_snapshot.customerid joined on shopper_id (TTM-only customers); max() taken across the join to handle nulls | Identifier | | |
| 3 | customer_acquisition_bill_id | STRING | Bill ID that triggered the customer's first net-positive status (FK to acquisition bill) | For new/intraday customers: COALESCE(enterprise.dim_new_acquisition_shopper.new_acquisition_bill_id, enterprise.dim_subscription_history.original_bill_id); for existing/churned: enterprise.dim_new_acquisition_shopper.new_acquisition_bill_id | Identifier | | |
| 4 | customer_acquisition_mst_date | DATE | Date the customer was first acquired (MST); NULL for existing customers with a non-past acquisition date | Complex CASE: for new/intraday with future acq date → COALESCE(enterprise.dim_new_acquisition_shopper.new_acquisition_bill_mst_date, enterprise.dim_subscription_history.subscription_create_mst_date, eval_date); NULL for existing customers with non-past acq date | Date | | |
| 5 | customer_acquisition_mst_month | STRING | Month of customer acquisition truncated to first day of month (MST) | Computed as TRUNC(customer_acquisition_mst_date, 'MONTH'); derived from the same source as customer_acquisition_mst_date | Date | | |
| 6 | customer_acquisition_country_code | STRING | ISO country code where customer was acquired; 'UK' normalized to 'GB' by ETL | From enterprise.dim_new_acquisition_shopper.bill_country_code, uppercased with UK→GB normalization applied in ETL | Categorical | | |
| 7 | customer_acquisition_channel_name | STRING | Acquisition channel of the customer (e.g., Direct, Email, Organic Search) | From ecomm_mart.bill_line_traffic_ext.channel_grouping_name for bills dated ≥ 2022-08; from legacy external S3 ads_bill_line_ext.ga_channel_grouping_name for bills < 2022-08 | Categorical | | |
| 8 | customer_tenure_year_count | INTEGER | Number of full years the customer has been with GoDaddy as of eval date | Calculated as CAST(datediff(partition_eval_mst_date, customer_acquisition_mst_date) / 365 AS INT); acquisition date sourced from enterprise.dim_new_acquisition_shopper and enterprise.dim_subscription_history | Numeric | | |
| 9 | customer_acquisition_country_name | STRING | Full country name where the customer was acquired | Direct from finance360.dim_country_vw.country_name joined on enterprise.dim_new_acquisition_shopper.bill_country_code where current_record_flag = true | Categorical | | |
| 10 | customer_region_1_name | STRING | Geographic region 1 of the customer's acquisition country | Direct from finance360.dim_country_vw.report_region_1_name joined on acquisition country code | Categorical | | |
| 11 | customer_region_2_name | STRING | Geographic region 2 of the customer's acquisition country | Direct from finance360.dim_country_vw.report_region_2_name joined on acquisition country code | Categorical | | |
| 12 | customer_region_3_name | STRING | Geographic region 3 of the customer's acquisition country | Direct from finance360.dim_country_vw.report_region_3_name joined on acquisition country code | Categorical | | |
| 13 | customer_domestic_international_name | STRING | Whether customer is domestic (US) or international | Direct from finance360.dim_country_vw.domestic_international_ind joined on acquisition country code | Categorical | | |
| 14 | reseller_type_id | INTEGER | Type ID of the reseller organization (FK to dp_enterprise.dim_reseller) | From dp_enterprise.dim_reseller.reseller_type_id joined via customer360.dim_customer_history_vw.private_label_id effective at eval_date; NULL private_label_id treated as 1 | Identifier | | |
| 15 | reseller_type_name | STRING | Name of the reseller organization | From dp_enterprise.dim_reseller.reseller_type_name joined via customer360.dim_customer_history_vw.private_label_id (same join logic as reseller_type_id) | Categorical | | |
| 16 | customer_type_name | STRING | Customer type classification at evaluation date (e.g., 'Direct', 'Reseller', '123 Reg') | From analytic_feature.customer_type_history.customer_type_name where record_start_mst_date ≤ eval_date ≤ record_end_mst_date; overridden to '123 Reg' for shoppers with private_label_id = 587240; defaults to 'Not Evaluated' if null | Categorical | | |
| 17 | customer_type_reason_desc | STRING | Reason or explanation for the customer type classification | From analytic_feature.customer_type_history.customer_type_reason_desc; overridden to '123 Reg' for 123Reg shoppers; defaults to 'Not Evaluated' if null | Text | | |
| 18 | customer_fraud_flag | BOOLEAN | True if customer is flagged as fraudulent at the evaluation date | Direct from analytic_feature.shopper_acquisition.acq_fraud_flag where partition_evaluation_mst_date = eval_date | Boolean | | |
| 19 | active_paid_subscription_list | ARRAY\<STRING\> | Sorted array of active paid subscription IDs for the customer at eval date | Aggregated as SORT_ARRAY(COLLECT_SET(subscription_id)) from enterprise.dim_subscription_history.subscription_id, filtered for finance_payable_resource_flag = true and billing-shopper consistency rules | Array | | |
| 20 | product_pnl_category_list | ARRAY\<STRING\> | Sorted array of product PNL categories owned by the customer | Aggregated as SORT_ARRAY(COLLECT_SET(product_pnl_category)) from finance360.dim_product_vw.product_pnl_category_name, linked through enterprise.dim_entitlement_history.pf_id per active paid subscriptions | Array | | |
| 21 | product_pnl_category_qty | INTEGER | Count of distinct product PNL categories owned by the customer | Calculated as COUNT(DISTINCT product_pnl_category) from finance360.dim_product_vw, same chain as product_pnl_category_list | Numeric | | |
| 22 | product_pnl_line_list | ARRAY\<STRING\> | Sorted array of product PNL lines owned by the customer | Aggregated as SORT_ARRAY(COLLECT_SET(product_pnl_line)) from finance360.dim_product_vw.product_pnl_line_name, linked through enterprise.dim_entitlement_history.pf_id | Array | | |
| 23 | ttm_all_bill_list | ARRAY\<STRING\> | Sorted array of all bill IDs from the trailing twelve-month window | Aggregated as SORT_ARRAY(COLLECT_SET(bill_id)) from enterprise.fact_bill_line.bill_id, filtered for net_positive_ttm_payment_flag = true and trxn_currency_code ≠ 'N/A' within the trailing 12-month window | Array | | |
| 24 | brand_name_list | ARRAY\<STRING\> | Sorted array of brand names associated with the customer (GD-Default, Leka-Apple, Leka-Google) | Derived from enterprise.dim_bill_shopper_id_xref.merged_shopper_id: shopper 554670720 → 'Leka-Apple', shopper 554671405 → 'Leka-Google', all others → 'GD-Default'; union of subscription and TTM brand sources | Array | | |
| 25 | ttm_gcr_usd_amt | DECIMAL(18,2) | Trailing twelve-month Gross Cash Received (GCR) in USD; 0 if no qualifying transactions | Aggregated as SUM(gcr_usd_amt) from enterprise.fact_bill_line.gcr_usd_amt, filtered for net_positive_ttm_payment_flag = true and trxn_currency_code ≠ 'N/A'; COALESCE to 0 if null | Amount | | |
| 26 | customer_churn_mst_date | DATE | MST date when customer most recently churned; NULL if not churned | Set to partition_eval_mst_date when active on d-1 but not on d (churn event detected from consecutive-day comparison of enterprise.dim_subscription_history and enterprise.fact_bill_line activity); also set for intraday churn events | Date | | |
| 27 | customer_reactivate_mst_date | DATE | MST date of the most recent reactivation (re-acquisition after a prior churn) | Set to partition_eval_mst_date when customer_status = 'new' AND enterprise.dim_new_acquisition_shopper.new_acquisition_bill_mst_date < partition_eval_mst_date, indicating re-acquisition of a previously churned shopper | Date | | |
| 28 | customer_merge_mst_date | DATE | MST date when the customer account was merged into another account | Direct from analytic_feature.shopper_merge.shopper_merge_start_mst_date where the shopper has a merge record active at eval_date and customer_status = 'churned' | Date | | |
| 29 | customer_fraud_mst_date | DATE | MST date when a fraud flag was set on the customer | From analytic_feature.customer_fraud.fraud_flag_mst_date where acq_fraud_flag = true and reinstatement_flag = false or reinstatement_ts > eval_date | Date | | |
| 30 | customer_state_enum | STRING | Enumerated customer lifecycle state at evaluation date: intraday, merged, churned, reactivated, new, or active | Derived via CASE priority cascade: intraday (customer_status = 'intraday') > merged (customer_merge_mst_date IS NOT NULL) > churned (customer_churn_mst_date IS NOT NULL) > reactivated (customer_reactivate_mst_date IS NOT NULL) > new (customer_acquisition_mst_date = partition_eval_mst_date) > active (otherwise) | Categorical | | |
| 31 | active_status_flag | BOOLEAN | True if customer is active at the evaluation date | Derived as customer_status NOT IN ('churned', 'intraday') from consecutive two-day comparison of enterprise.dim_subscription_history and enterprise.fact_bill_line subscription activity | Boolean | | |
| 32 | point_of_purchase_name | STRING | Point-of-purchase name from the customer acquisition bill | Direct from ecomm_mart.dim_bill_line_purchase_attribution.point_of_purchase_name, latest record per acquisition bill_id (max bill_line_num) | Categorical | | |
| 33 | customer_acquisition_bill_fraud_flag | BOOLEAN | True if the customer's acquisition bill has a fraud record in dim_bill_fraud_history_vw | Set to TRUE if acquisition bill_id exists in finance360.dim_bill_fraud_history_vw; otherwise FALSE | Boolean | | |
| 34 | etl_build_mst_ts | TIMESTAMP | Timestamp when this record was written by the ETL process (MST) | from_utc_timestamp(current_timestamp(), "MST") at ETL write time; not derived from any source table | Timestamp | | |
| 35 | partition_eval_mst_date | STRING | Partition key: evaluation date (MST) for which this daily snapshot was computed | ETL job parameter eval_mst_date, defaults to logical_date of the Airflow DAG run converted to MST timezone | Date | | |

### C2. Primary Key & Performance

**Composite Primary Key:** `(partition_eval_mst_date, shopper_id)`

This composite key is enforced by the data quality constraint `isPrimaryKey("partition_eval_mst_date", "shopper_id")` in `customer360/customer-metrics/src/data_quality/constraints/customer_life_cycle.json`. Each row represents one customer (shopper) on one evaluation date.

> **Important:** Both the Alation Lake description (stating PK = `customer_id` alone) and the Hive DDL header comment (`resource_id, product_family_name, entitlement_addon_id, partition_eval_mst_date`) are stale and incorrect. The DQ constraint is the authoritative source.

**Performance guidance:**
- Always filter on `partition_eval_mst_date` — this is the partition key in both Hive/Glue and Redshift. Omitting this filter causes a full table scan.
- For current-state queries, filter on a single date (e.g., yesterday's date).
- For time-series analysis, use a bounded date range with BETWEEN.
- The table is repartitioned to 30 Parquet output files per daily partition.
- In Redshift, `partition_eval_mst_date` is both DISTKEY and SORTKEY for optimized date-range queries.

### C3. Key Features, Capabilities & Limitations

**Capabilities:**
- **Complete time-series:** Full history of each customer's state is available by querying across partition dates; the dataset captures every daily state transition.
- **Pre-joined and denormalized:** Geographic, channel, type, subscription, TTM, and fraud dimensions are all denormalized into a single row per customer per day, eliminating join complexity for the most common analytical patterns.
- **Churned customer records:** Churned customers appear in the table on the churn date with all dimension fields populated; subscription and metric fields are NULL/empty for the churn-date partition.
- **Intraday customer support:** Customers acquired on the evaluation date who are not yet in the active subscription table appear with `customer_state_enum = 'intraday'`.

**Limitations:**
- **No intraday updates:** The table reflects a single daily snapshot per `eval_mst_date`; intra-day state changes are not captured until the next day's run.
- **Array columns require special handling:** `active_paid_subscription_list`, `product_pnl_category_list`, `product_pnl_line_list`, `ttm_all_bill_list`, and `brand_name_list` are stored as `array<string>` in Hive and `SUPER` in Redshift; array functions are required for element-level access.
- **Legacy channel data (pre-2022-08):** Acquisition channel for bills before August 2022 is sourced from an external (non-lake) S3 dataset (`ads_bill_line_ext`), hardcoded to the production S3 bucket.
- **No history backfill DAG:** The pipeline does not include a history load variant; historical partition coverage depends on continuous prior daily runs.
- **Partition key type inconsistency:** `partition_eval_mst_date` is `STRING` in Hive/Glue and `DATE` in Redshift; ensure proper casting when querying the lake directly.

### C4. Important Notes & Pitfalls

- **Do not use `customer_id` alone as a unique key.** The correct composite key is `(partition_eval_mst_date, shopper_id)`. The Alation Lake description is incorrect on this point.
- **`customer_state_enum` does NOT include 'fraud' as a value.** The valid values are: `new`, `active`, `churned`, `reactivated`, `merged`, `intraday`. The Alation description erroneously lists 'fraud'; the PySpark CASE statement is authoritative.
- **Churned customers have NULL metrics.** For rows where `customer_churn_mst_date IS NOT NULL`, the subscription list, TTM GCR, and product array columns will be NULL or empty. Only acquisition and demographic dimension columns are populated for churned rows.
- **Always filter on `partition_eval_mst_date`** to avoid full table scans across all partitions.
- **`customer_acquisition_country_code = 'UK'` never appears** — the ETL normalizes 'UK' to 'GB' unconditionally before writing output.
- **Tenure is computed, not sourced from a tenure table.** The Confluence design doc references `analytic_feature.shopper_tenure` as the source for `customer_tenure_year_count`, but the current PySpark computes tenure directly as `datediff(eval_date, acq_date) / 365`. The Confluence doc is outdated on this point.
- **Internal shoppers are excluded.** Shoppers with `internal_shopper_flag = true` in `customer360.dim_customer_history_vw` are excluded from subscription, TTM, and grace policy computations.
- **123 Reg customer type override.** Shoppers with `private_label_id = 587240` always receive `customer_type_name = '123 Reg'` regardless of the `analytic_feature.customer_type_history` value.
- **Merge state applies only to the source (original) shopper.** Only the original churned account receives a `customer_merge_mst_date`; the surviving merged account continues as active.
- **Do not sum `ttm_gcr_usd_amt` across multiple partition dates** without deduplication — the same shopper's TTM value appears on every partition date, and summing across dates double-counts revenue.

### C5. Always-On Column Filters

The following filters are applied by the ETL pipeline and define the data scope of every row. They cannot be removed at query time:

| Filter | Condition | Description |
|---|---|---|
| Finance payable subscriptions | finance_payable_resource_flag = true AND (subscription_billing_shopper_differ_flag = false OR Leka brand OR domain_payment_override_flag = true) | Only subscriptions with a finance-payable resource and consistent billing shopper are included in subscription and product lists |
| TTM currency validity | trxn_currency_code ≠ 'N/A' | Bills with undefined currency are excluded from TTM GCR and bill lists |
| TTM net positive | net_positive_ttm_payment_flag = true | Only net-positive transactions are included in TTM GCR |
| Internal shopper exclusion | internal_shopper_flag = false (in dim_customer_history_vw) | GoDaddy internal shoppers are excluded from all metrics |
| Shopper ID format | REGEXP_LIKE(shopper_id, '^[0-9]+$') AND LENGTH(shopper_id) > 3 | Only well-formed numeric shopper IDs are included |

**Recommended query-time filter:** Always add `WHERE partition_eval_mst_date = '<date>'` to limit to the desired snapshot date.

### C6. Common Business Metrics

| Metric Name | Column | Definition | Grain |
|---|---|---|---|
| TTM GCR (USD) | ttm_gcr_usd_amt | Sum of net-positive, non-N/A-currency gross cash received over the trailing 12 months ending at eval_date; COALESCE to 0 | Per customer per eval_date |
| Customer Tenure (Years) | customer_tenure_year_count | Integer years since acquisition date: CAST(datediff(eval_date, acq_date) / 365 AS INT) | Per customer per eval_date |
| Product Category Count | product_pnl_category_qty | Count of distinct active product PNL categories owned by customer | Per customer per eval_date |
| Customer State | customer_state_enum | Enumerated lifecycle state (priority: intraday > merged > churned > reactivated > new > active) | Per customer per eval_date |
| Active Status | active_status_flag | Boolean: true if customer is active (not churned or intraday) | Per customer per eval_date |
| Churn Count | COUNT(*) WHERE customer_state_enum = 'churned' | Number of customers who churned on a given eval_date | Aggregate by date/segment |
| New Customer Count | COUNT(*) WHERE customer_state_enum = 'new' | Number of new customers acquired on a given eval_date | Aggregate by date/segment |
| Reactivation Count | COUNT(*) WHERE customer_state_enum = 'reactivated' | Number of customers reactivated on a given eval_date | Aggregate by date/segment |

### C7. Glossary & Term Definitions

| Term | Definition |
|---|---|
| eval_mst_date / partition_eval_mst_date | The evaluation date in Mountain Standard Time (MST). Each daily job run processes data for one specific date (defaults to yesterday). |
| TTM GCR | Trailing Twelve-Month Gross Cash Received (USD). Sum of all net-positive, valid-currency payments from a customer in the 12 months preceding and including eval_date. |
| customer_state_enum | The customer's lifecycle state on eval_date, determined by a priority cascade: intraday > merged > churned > reactivated > new > active. |
| new | Customer is active on eval_date but was NOT active on eval_date-1 and has no prior churn event (first-time acquisition). |
| active | Customer was active on both eval_date-1 and eval_date (existing subscriber). |
| churned | Customer was active on eval_date-1 but NOT active on eval_date. Metric columns (subscriptions, TTM) are NULL for this row. |
| reactivated | Customer is new on eval_date (not active on d-1) but their acquisition date predates eval_date, indicating a re-acquisition after a prior churn event. |
| merged | Customer's account was merged into another shopper account; merge date is recorded and the original shopper appears as churned. |
| intraday | Customer acquired on eval_date (subscription_create_mst_date = eval_date) but not yet present in the active subscription dataset. |
| Finance Payable | A subscription for which GoDaddy owes revenue to Finance — controlled by finance_payable_resource_flag. Non-finance-payable subscriptions are excluded from product and subscription lists. |
| 123 Reg | A GoDaddy brand for UK customers identified by private_label_id = 587240. These customers always receive customer_type_name = '123 Reg'. |
| Leka | GoDaddy's payment service brand. Leka-Apple (shopper_id 554670720) and Leka-Google (shopper_id 554671405) are brand markers in brand_name_list. |
| PNL Category / PNL Line | Product Profit and Loss classification hierarchy. PNL Category is a higher-level grouping (e.g., 'Domains', 'Hosting'); PNL Line is more granular within each category. |

### C8. Example Queries & Patterns

#### Pattern 1: Active customer count by lifecycle state for a given date

```sql
-- Count customers by lifecycle state for a specific evaluation date
SELECT
    customer_state_enum,
    COUNT(DISTINCT shopper_id) AS customer_count
FROM dev.customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-06-09'
GROUP BY 1
ORDER BY 2 DESC;
```

*Always include the `partition_eval_mst_date` filter. Without it, the query scans all historical partitions.*

#### Pattern 2: Daily new and churned customer counts over a date range

```sql
-- Track daily new, churned, and reactivated customer counts over a week
SELECT
    partition_eval_mst_date,
    COUNT(CASE WHEN customer_state_enum = 'new'         THEN 1 END) AS new_customers,
    COUNT(CASE WHEN customer_state_enum = 'churned'     THEN 1 END) AS churned_customers,
    COUNT(CASE WHEN customer_state_enum = 'reactivated' THEN 1 END) AS reactivated_customers
FROM dev.customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date BETWEEN '2026-06-01' AND '2026-06-09'
GROUP BY 1
ORDER BY 1;
```

*Use a bounded date range — avoid open-ended scans across all partitions.*

#### Pattern 3: TTM GCR by region for active customers on a snapshot date

```sql
-- Average and total TTM GCR by lifecycle state and region
SELECT
    customer_state_enum,
    customer_region_1_name,
    COUNT(DISTINCT shopper_id) AS customer_count,
    AVG(ttm_gcr_usd_amt)       AS avg_ttm_gcr_usd,
    SUM(ttm_gcr_usd_amt)       AS total_ttm_gcr_usd
FROM dev.customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-06-09'
  AND active_status_flag = TRUE
GROUP BY 1, 2
ORDER BY 5 DESC;
```

*Filter to `active_status_flag = TRUE` to exclude churned customers who have NULL TTM values.*

#### Pattern 4: 2+ product new customers by channel on a given date

```sql
-- Identify 2+ product new customers by acquisition channel
SELECT
    customer_acquisition_channel_name,
    customer_acquisition_country_code,
    COUNT(DISTINCT shopper_id) AS two_plus_product_new_adds
FROM dev.customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-06-09'
  AND customer_state_enum = 'new'
  AND product_pnl_category_qty >= 2
GROUP BY 1, 2
ORDER BY 3 DESC;
```

#### Pattern 5: Customer tenure distribution for active customers

```sql
-- Tenure distribution (in years) for active customers on a snapshot date
SELECT
    customer_tenure_year_count,
    COUNT(DISTINCT shopper_id) AS customer_count
FROM dev.customer360.customer_life_cycle_vw
WHERE partition_eval_mst_date = '2026-06-09'
  AND customer_state_enum = 'active'
GROUP BY 1
ORDER BY 1;
```

---

## Pillar D: HOW Is It Built? — Pipeline & Provenance

### D1. Data Source Reference

#### Upstream Sources

**Depth 1 Upstream Tables — First Lake Boundary (Total: 21, including 1 external S3)**

> Note: The PySpark script directly reads 16 sources. Three of those are intermediate tables (`customer_ttm_payment_driver`, `customer_active_subscription_detail_driver`, `active_customer_stg`) built by other scripts in the same repo. The 21 entries below represent the first lake table boundary reached when tracing lineage through those intermediates.

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| shopper_acquisition | GoDaddy Central Data Lake (Prod) | analytic_feature | Lake Table | lake |
| customer_type_history | GoDaddy Central Data Lake (Prod) | analytic_feature | Lake Table | lake |
| customer_fraud | GoDaddy Central Data Lake (Prod) | analytic_feature | Lake Table | lake |
| shopper_merge | GoDaddy Central Data Lake (Prod) | analytic_feature | Lake Table | lake |
| dim_customer_history_vw | GoDaddy Central Data Lake (Prod) | customer360 | Lake View | lake |
| dim_country_vw | GoDaddy Central Data Lake (Prod) | finance360 | Lake View | lake |
| dim_bill_fraud_history_vw | GoDaddy Central Data Lake (Prod) | finance360 | Lake View | lake |
| dim_product_vw | GoDaddy Central Data Lake (Prod) | finance360 | Lake View | lake |
| dim_reseller | GoDaddy Central Data Lake (Prod) | dp_enterprise | Lake Table | lake |
| dim_new_acquisition_shopper | GoDaddy Central Data Lake (Prod) | enterprise | Lake Table | lake |
| dim_subscription_history | GoDaddy Central Data Lake (Prod) | enterprise | Lake Table | lake |
| dim_entitlement_history | GoDaddy Central Data Lake (Prod) | enterprise | Lake Table | lake |
| dim_bill_shopper_id_xref | GoDaddy Central Data Lake (Prod) | enterprise | Lake Table | lake |
| fact_bill_line | GoDaddy Central Data Lake (Prod) | enterprise | Lake Table | lake |
| fact_entitlement_bill | GoDaddy Central Data Lake (Prod) | enterprise | Lake Table | lake |
| bill_line_traffic_ext | GoDaddy Central Data Lake (Prod) | ecomm_mart | Lake Table | lake |
| dim_bill_line_purchase_attribution | GoDaddy Central Data Lake (Prod) | ecomm_mart | Lake Table | lake |
| entitlement_bill_type | GoDaddy Central Data Lake (Prod) | ecomm_mart | Lake Table | lake |
| customer_id_mapping_snapshot | GoDaddy Central Data Lake (Prod) | customers | Lake Table | lake |
| manual_paid_subscription | GoDaddy Central Data Lake (Prod) | finance_cln | Lake Table | lake |
| ads_bill_line_ext (legacy) | — | — | External S3 Parquet (pre-2022-08 bill traffic; hardcoded to prod bucket) | s3 |

**Depth 2 Upstream Tables**

Depth 2 sources are not derivable from this analysis without reading each Depth 1 lake table's own lineage metadata. The 21 Depth 1 lake tables listed above represent the authoritative source boundaries for this table's documented lineage.

#### Downstream Sources

**Depth 1 Downstream Tables (Total: 2 confirmed managed + multiple ad-hoc)**

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| customer_life_cycle_vw_stg | REQUIRES_MANUAL_INPUT | customer_core_conformed | Redshift Staging Table | redshift |
| customer_life_cycle_vw | customer360 (Redshift) | customer360 | Redshift Prod Table | redshift |

**Additional ad-hoc downstream consumers (from Alation queries — not managed pipelines):**

| Table Name | Schema | Type | Query Reference |
|---|---|---|---|
| mv_legacy_c360_lifecycle | dev.ba_usi | Redshift Temp | Alation query 139061 |
| mv_two_plus_churn_driver_tree_pre | dev.ba_usi | Redshift Temp | Alation query 138820 |
| mv_two_plus_customer_adds | dev.ba_usi | Redshift Temp | Alation query 138821 |
| Various ad-hoc analyses | dev.* | Temp/staging | Alation queries 123877, 138288, 138291, 138886, 135046, 123350, 139259 |

### D2. Data Pipeline & Infrastructure

| Field | Value |
|---|---|
| Source Repository | https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git |
| PySpark Script | customer360/customer-metrics/src/pyspark/customer_life_cycle.py |
| DAG File | customer360/customer-metrics/src/dag/customer_life_cycle_dag.py |
| Hive DDL | customer360/customer-metrics/src/ddl/customer_life_cycle.ddl |
| Redshift DDL | customer360/customer-metrics/src/dag/ddls/create_customer_life_cycle.sql |
| DQ Constraints | customer360/customer-metrics/src/data_quality/constraints/customer_life_cycle.json |
| Policy YAML | customer360/customer-metrics/src/policies/customer_life_cycle_dag.yaml |
| Orchestration Tool | Apache Airflow — DAG ID: customer-life-cycle |
| Compute Platform | AWS EMR 7.10.0 — 1× m6g.xlarge (master) + 15× m6g.16xlarge (core nodes) |
| Spark Catalog | AWS Glue Data Catalog (Iceberg extensions enabled) |
| PySpark Script S3 | REQUIRES_MANUAL_INPUT |
| Output S3 Location | s3://gd-ckpetlbatch-{AWS_ENV}-customer-core-conformed/customer_core_conformed/customer_life_cycle/ |

### D3. SLA & Refresh Schedule

| Field | Value |
|---|---|
| DAG Schedule | 20 7 * * * — 7:20 AM MST daily |
| SLA Delivery Target | 08:00 AM MST daily (cron: 00 15 * * ? * UTC) |
| SLA Identifier | customer360.customer_life_cycle_vw |
| Data Tier | 4 |
| Max Pipeline Duration | 120 minutes (policy YAML severity: TIER_4) |
| Retries | 1 retry; 3-minute retry delay |
| Eval Date Default | Previous day in MST timezone (Airflow logical_date converted to MST) |
| Catchup | Disabled |
| DAG Start Date | 2026-01-01 |
| Legacy Lookback | Enabled (legacyLookBackEnabled: true in lake registry table.yaml) |

> **Note:** The DAG documentation `sla` field is set to "N/A" — this is stale. The authoritative SLA (delivery by 08:00 AM MST daily) comes from the lake registry `table.yaml`.

### D4. Table Creation & ETL Implementation

#### ETL Processes

The `customer-life-cycle` pipeline is a daily Apache Airflow DAG that orchestrates an AWS EMR Serverless Spark job to produce a point-in-time snapshot of every GoDaddy customer's lifecycle state. The pipeline resolves all upstream table readiness via success file sensors before launching the EMR cluster, executes the PySpark transformation job, writes output to the internal Hive/Glue table (`customer_core_conformed.customer_life_cycle`) in Parquet format, notifies the Data Lake API, validates quality, and finally loads the Redshift analytical table via S3 COPY and SQL upsert.

Numbered implementation steps:

1. **Dependency check** (`dependencies` task): S3KeySensor group waits for success files from all upstream table partitions before the pipeline proceeds.
2. **Redshift table setup** (`create_redshift_tables_done`): Creates Redshift staging and production tables via SQL DDL files if they do not already exist.
3. **EMR cluster creation** (`create_emr`): Provisions an EMR 7.10.0 cluster (1× m6g.xlarge master, 15× m6g.16xlarge cores).
4. **Spark job execution** (`run_customer_life_cycle`): Submits `customer_life_cycle.py` via spark-submit; processes all upstream sources, applies business logic, and writes 30-partition Parquet output to S3 using dynamic partition overwrite for the eval_date partition.
5. **EMR teardown** (`remove_emr`): Terminates the EMR cluster regardless of job outcome.
6. **Local DQ check** (`customer_life_cycle_local_dq`): DataQualityOperator validates the primary key constraint (`isPrimaryKey("partition_eval_mst_date", "shopper_id")`) on `customer_core_conformed.customer_life_cycle`.
7. **Lake API notification** (`call_lake_api`, prod only): SuccessNotificationOperator registers `customer360.customer_life_cycle_vw` as successfully refreshed in the Data Lake catalog.
8. **Lake DQ check** (`customer_life_cycle_lake_dq`): DataQualityOperator runs post-lake-API on `customer360.customer_life_cycle_vw`.
9. **Redshift staging load** (`s3_to_redshift_customer_life_cycle_stg`): S3 COPY into the Redshift staging table from the eval_date S3 partition.
10. **Redshift upsert** (`insert_customer_life_cycle`): SQL upsert from staging into the Redshift production table `customer360.customer_life_cycle_vw`.
11. **Final status gate** (`check_for_failure_branch`): Branches to `succeed_dag_run` or `fail_dag_run` based on overall pipeline outcome.

#### Data Processing Steps

- **Customer status classification:** Reads two consecutive partitions (d and d-1) of active customer subscription data to classify each shopper as `new`, `existing`, `churned`, or `intraday`.
- **Intraday resolution:** Cross-references `enterprise.dim_new_acquisition_shopper` with `enterprise.dim_subscription_history` to identify shoppers acquired today who are not yet in the active dataset; flags as `intraday`.
- **Acquisition dimension enrichment:** Joins `enterprise.dim_new_acquisition_shopper` (bill date, country, bill_id) and `enterprise.dim_subscription_history` (subscription create date for fallback); normalizes UK→GB country codes; joins `finance360.dim_country_vw` for country name and regional hierarchy.
- **Customer type and reseller enrichment:** Joins `analytic_feature.customer_type_history` for type classification effective at eval_date; joins `customer360.dim_customer_history_vw` for private_label_id then `dp_enterprise.dim_reseller` for reseller type; applies 123 Reg override for private_label_id = 587240.
- **Fraud signal derivation:** `customer_fraud_flag` from `analytic_feature.shopper_acquisition`; `customer_fraud_mst_date` from `analytic_feature.customer_fraud`; `customer_acquisition_bill_fraud_flag` by checking acquisition bill_id against `finance360.dim_bill_fraud_history_vw`.
- **Merge signal:** Sets `customer_merge_mst_date` from `analytic_feature.shopper_merge` for churned shoppers with active merge records.
- **Subscription and product aggregation:** Reads active subscription data (sourced from `enterprise.dim_subscription_history`, `enterprise.dim_entitlement_history`, `finance360.dim_product_vw`); aggregates as sorted arrays per customer.
- **TTM GCR computation:** Reads TTM payment data (sourced from `enterprise.fact_bill_line`); filters for net-positive, valid-currency transactions; sums per customer; COALESCEs to 0.
- **Acquisition channel join:** Joins `ecomm_mart.bill_line_traffic_ext` (bills ≥ 2022-08) or external S3 `ads_bill_line_ext` (bills < 2022-08) for channel attribution.
- **Customer state derivation:** Applies CASE priority cascade to produce `customer_state_enum` and `active_status_flag`.
- **Final assembly and write:** Unions churned and non-churned customer DataFrames; repartitions to 30 output files; writes as dynamic partition overwrite.

#### Error Handling and Logging

- Slack alerts on DAG failure: `#edt-airflow-alerts` (prod), `#edt-airflow-alerts-low-priority` (non-prod).
- 1 automatic retry with a 3-minute delay for transient failures.
- EMR cluster is always terminated after the Spark job completes (success or failure), preventing orphaned clusters.
- `MSCK REPAIR TABLE` is run post-write as a best-effort operation; failures are logged and skipped (non-blocking).
- `check_for_failure_branch` provides a final DAG-level success/failure gate before marking the run complete.
- On-call coverage: `#marketing-data-product-engineering` (Slack), `dl-bi-enterprise-data@godaddy.com` (email), `DEV-EDT-OnCall` (ServiceNow).

#### Data Validation

- **Primary key uniqueness:** `isPrimaryKey("partition_eval_mst_date", "shopper_id")` on `customer_core_conformed.customer_life_cycle` post-EMR (`customer_life_cycle_local_dq` task).
- **Lake DQ check:** DataQualityOperator on `customer360.customer_life_cycle_vw` post-lake-API notification (`customer_life_cycle_lake_dq` task).
- **Dependency gating:** All upstream tables must have success files present before the pipeline proceeds (S3KeySensor group).
- **Partition registration:** `MSCK REPAIR TABLE` is run post-write to ensure the new partition is registered in the AWS Glue catalog.

---

## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem

### E1. Data Quality Checks

| Check | Constraint | Table Applied | DAG Task | Status |
|---|---|---|---|---|
| Primary key uniqueness | isPrimaryKey("partition_eval_mst_date", "shopper_id") | customer_core_conformed.customer_life_cycle | customer_life_cycle_local_dq | Enabled |
| Lake table DQ | DataQualityOperator (constraints in customer_life_cycle.json) | customer360.customer_life_cycle_vw | customer_life_cycle_lake_dq | Enabled |
| Dependency completeness | S3KeySensor on all upstream partition success files | All upstream tables | dependencies | Enabled |
| Partition repair | MSCK REPAIR TABLE customer_core_conformed.customer_life_cycle | customer_core_conformed.customer_life_cycle | Post-EMR (best effort) | Enabled |

DQ constraints file: `customer360/customer-metrics/src/data_quality/constraints/customer_life_cycle.json`

### E2. Best Practices & Tips

- **Always partition-filter first.** Add `WHERE partition_eval_mst_date = '<date>'` as the first filter. For multi-day ranges, use BETWEEN with explicit start and end dates.
- **Use `customer_state_enum` for segmentation** rather than deriving state from individual lifecycle date columns. The enum respects the business-defined priority ordering.
- **For active-customer-only analysis**, filter `active_status_flag = TRUE` (equivalent to `customer_state_enum NOT IN ('churned', 'intraday')`).
- **Understand NULL semantics for churned rows.** On the churn date, `ttm_gcr_usd_amt`, `active_paid_subscription_list`, `product_pnl_category_list`, `product_pnl_line_list`, and `ttm_all_bill_list` are NULL or empty.
- **Do not sum `ttm_gcr_usd_amt` across multiple partition dates** without deduplication — the same shopper's TTM value is repeated on every partition date.
- **For cohort analysis**, select the customer record from the partition where `customer_state_enum = 'new'` to get the canonical acquisition snapshot.
- **Array columns in Redshift** (`active_paid_subscription_list`, etc.) are stored as `SUPER` type; use `JSON_PARSE` or Redshift SUPER function syntax for element-level access.
- **Prefer Redshift** (`dev.customer360.customer_life_cycle_vw`) for ad-hoc SQL analysis; use the lake table (`AwsDataCatalog.customer360.customer_life_cycle_vw`) for Spark-based batch processing.
- **`customer_acquisition_country_code = 'UK'` does not exist** in this table — always use 'GB' when filtering for United Kingdom customers.

### E3. Related Articles & Documentation

| Resource | Type | URL / Reference |
|---|---|---|
| Customer360 Hub | Confluence Page | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360 |
| Customer Lifecycle Design Doc | Confluence Page | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3970861345/Customer+Lifecycle |
| Customer Metrics Design Doc | Confluence Page | https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131239/Customer+Metrics |
| PySpark ETL Script | GitHub | https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/pyspark/customer_life_cycle.py |
| DAG File | GitHub | https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/dag/customer_life_cycle_dag.py |
| Alation Lake Table Entry | Alation | https://godaddy.alationcloud.com/table/7038345/ |
| Alation Dev Serverless Table Entry | Alation | https://godaddy.alationcloud.com/table/7038917/ |
| Churned Customer Definition | Alation Article | https://godaddy.alationcloud.com/article/98/churned-customer |

---

## REFERENCES

**Tables:**
- `customer360.customer_life_cycle_vw` — lake table (GoDaddy Central Data Lake, Prod)
- `customer_core_conformed.customer_life_cycle` — internal Hive/Parquet staging table

**Confluence Articles:**
- Customer360 (Page ID 3779199819)
- Customer Lifecycle (Page ID 3970861345)
- Customer Metrics (Page ID 4042131239)

**URLs:**
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3970861345/Customer+Lifecycle
- https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131239/Customer+Metrics
- https://github.com/gdcorp-dna/dof-dpaas-customer-feature.git
- https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/pyspark/customer_life_cycle.py
- https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/dag/customer_life_cycle_dag.py
- https://godaddy.alationcloud.com/table/7038345/
- https://godaddy.alationcloud.com/table/7038917/
- https://godaddy.alationcloud.com/article/98/churned-customer
- https://godaddy.alationcloud.com/query/123877/
- https://godaddy.alationcloud.com/query/139259/
- https://godaddy.alationcloud.com/query/139061/
- https://godaddy.alationcloud.com/query/138820/
- https://godaddy.alationcloud.com/query/138821/
- https://godaddy.alationcloud.com/query/138886/
- https://godaddy.alationcloud.com/query/135046/
- https://godaddy.alationcloud.com/query/123350/
- https://godaddy.alationcloud.com/query/138288/
- https://godaddy.alationcloud.com/query/138291/
