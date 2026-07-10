# Business Context: customer360.customer_metric_daily_agg_vw

## Pillar A: WHAT Is It? — Identity & Purpose

### A1. Table Overview

| Field | Value |
|---|---|
| Table Name | customer_metric_daily_agg_vw |
| Database | Redshift - Serverless - Dev |
| Schema | customer360 |
| Alation URL | https://godaddy.alationcloud.com/table/7038918/ |
| Table ID | 7038918 |
| Type | View |
| Description | A daily aggregated metrics table providing summarized customer performance indicators. This view serves as a comprehensive source for customer lifecycle analysis, containing customer demographic, geographic, and behavioral attributes. |
| Lake Table Name | customer_metric_daily_agg_vw |
| Lake Database | GoDaddy Central Data Lake (Prod) |
| Lake Schema | customer360 |
| Lake Alation URL | https://godaddy.alationcloud.com/table/7038346/ |
| Lake Alation ID | 7038346 |
| Lake Type | Table (partitioned, Parquet) |
| Grain | One row per evaluation date × unique combination of 18 reporting dimensions |
| Partition Key | partition_eval_mst_date (STRING in Hive/Glue; DATE in Redshift) |
| Storage Format | Parquet |
| Data Tier | 4 |
| SLA | Delivery by 08:00 AM MST daily |
| Refresh Cadence | Daily (cron `30 7 * * *` MST) |
| Owner / Team | EDT (Emerald Data Team) — lake registry owner: ckpetlbatch |
| Hive/Glue Intermediate | customer_core_conformed.customer_metric_daily_agg |
| S3 Location | s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_metric_daily_agg/ |
| Replaces | customer_mart.daily_active_customers (legacy DAC) |

---

### A2. What This Table Is About

`customer360.customer_metric_daily_agg_vw` is the Customer360 (C360) daily aggregation of key customer lifecycle metrics, segmented by 18 reporting dimensions spanning geography, customer profile, product ownership, fraud status, reseller type, and brand. Each row represents a single evaluation date combined with one unique permutation of those 18 dimensions, providing a pre-aggregated view suited for trend analysis, cohort reporting, and executive dashboards. As confirmed by the table owner, this is a **daily roll-up of customer lifecycle metrics by 18 reporting dimensions** and is the designated replacement for the legacy `customer_mart.daily_active_customers` (DAC) table. The Customer360 platform extends DAC's coverage with richer dimensional granularity, a comprehensive set of customer stock-and-flow metrics, and a dimension-continuity fill mechanism that ensures reporting stability across consecutive days.

**Key Features:**

- **Daily granularity:** one data partition per calendar day (`partition_eval_mst_date`)
- **18 reporting dimensions** covering geography (country, region levels 1–3, domestic/international), customer profile (type, type reason, tenure in years, acquisition channel, acquisition month), product ownership (category list, line list, category count), brand, reseller type, fraud flags, and point of purchase
- **11 pre-computed metrics:** ending, beginning, new, churn, reactivated, and merge customer counts; three net movement metrics (net_add, net_churn, net_move); TTM GCR USD amount; and product category count
- **Dimension continuity fill:** zero-metric rows are inserted for dimension combinations present on the prior day but absent on the evaluation date, ensuring the LAG-based `beginning_customer_qty` computation is never broken
- **UK→GB country code normalization** applied in ETL — `customer_country_code = 'UK'` is silently normalized to `'GB'`
- **Successor to legacy DAC:** replaces `customer_mart.daily_active_customers`; a migration bridge query is available in Alation (Query 138254)

**Purpose:** This table enables Finance, Marketing, and Analytics teams to track daily customer stock-and-flow metrics (new, churned, reactivated, active counts, and TTM revenue) across standardized reporting dimensions, replacing the legacy Daily Active Customers (DAC) report with a governed, Customer360 data product.

---

### A3. Organizational Context & Ownership

| Field | Value |
|---|---|
| Team | EDT (Emerald Data Team) |
| DAG Owner | customer360 |
| Lake Registry Owner | ckpetlbatch |
| Project Code | edt |
| On-Call Group | #marketing-data-product-engineering, DEV-EDT-OnCall |
| Email | dl-bi-enterprise-data@godaddy.com |
| Prod Slack Alerts | #edt-airflow-alerts |
| Non-Prod Slack Alerts | #edt-airflow-alerts-low-priority, #edt |
| Domain | Customer |
| Organization | DNA |
| Business Stewards | Finance, DAP |
| Stakeholders | Marketing |
| Data Products | FORGE (PgM, Architecture) |
| Consumers | analytics (prod), martech_data (stage/dev_private/prod), revenue_and_relevance (stage/dev_private/prod/test), data_platform (stage/prod), data_lab (dev_private), ckpetlbatch (dev_private/prod) |

---

## Pillar B: WHY Does It Matter? — Value & Use Cases

### B1. Key Business Value

Per the table owner: this table is a **daily roll-up of customer lifecycle metrics by 18 reporting dimensions** and **replaces the legacy `customer_mart.daily_active_customers`** table.

It is the authoritative daily source for customer stock-and-flow metrics across GoDaddy's standardized reporting dimensions. Business value includes:

- **Customer base health tracking:** beginning, ending, new, churn, and reactivated customer counts enable day-over-day trend monitoring and executive dashboards
- **Revenue segmentation:** TTM GCR USD amounts sliced by geography, acquisition channel, customer tenure, and product ownership support Finance and Marketing analysis
- **Movement reconciliation:** `net_move_qty` provides a built-in sanity check that the five movement events (new, churn, reactivated, merged, and net_add) reconcile to the ending–beginning delta
- **Legacy DAC migration:** serves as the single replacement for `customer_mart.daily_active_customers`, with a validated union bridge available for continuity across the transition period (Alation Query 138254)
- **Multi-team consumption:** consumed by analytics, martech_data, revenue_and_relevance, data_platform, data_lab, and ckpetlbatch across prod, stage, and dev environments

---

### B2. Primary Use Cases

**Questions this table answers:**

- How many active (ending) customers did GoDaddy have on a given day, segmented by country, customer type, or acquisition channel?
- What is the net customer count change (`net_add_qty`) versus a prior period for a specific market segment?
- How many customers churned vs. were reactivated in a given week by region or brand?
- What is the trailing-twelve-month GCR by customer tenure band and product category?
- How does today's ending customer count compare to the prior day's beginning count, and what drove the change (new, churn, reactivated, or merged)?
- Which acquisition channels are producing the most new customers in a given month?
- What is the domestic vs. international customer split over the last quarter?

---

**Alation Queries**

#### NC validate EBP

| Field | Value |
|---|---|
| Query ID | 136952 |
| Title | NC validate EBP |
| Author | Not specified |
| Description | Validation scratchpad comparing legacy DAC and C360 customer metrics over the same date ranges |
| Schedule | Manual execution |
| Last Saved | |
| Last Run | Not recorded |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/136952/ |

This query validates the C360 `customer_metric_daily_agg_vw` against the legacy `dna_approved.daily_active_customers` by summing key customer movement metrics (beginning, new, net_churn, net_add, churn, ending) over the same date range from both sources. It is a primary migration validation query confirming parity between the legacy DAC and the C360 replacement.

---

#### C360 - customer_metric_daily_agg_vw_mv

| Field | Value |
|---|---|
| Query ID | 138184 |
| Title | C360 - customer_metric_daily_agg_vw_mv |
| Author | Not specified |
| Description | Creates a materialized table enriching customer_metric_daily_agg_vw with relative month attribution from dim_relative_date |
| Schedule | Manual execution |
| Last Saved | |
| Last Run | Not recorded |
| Datasource | Redshift - Serverless - Dev |
| Alation Query URL | https://godaddy.alationcloud.com/query/138184/ |

This query creates a materialized snapshot (`dev.ba_usi.customer_metric_daily_agg_vw_mv`) by joining `customer_metric_daily_agg_vw` with `bi_prod.dim_relative_date` to add `relative_mst_month` and `relative_mst_month_period_name` columns, enabling relative-period (e.g., current month, prior month) filtering without hardcoded dates.

---

#### C360 Cash Dash with budget

| Field | Value |
|---|---|
| Query ID | 138586 |
| Title | C360 Cash Dash with budget |
| Author | Not specified |
| Description | Creates a time-period comparison sandbox table from customer_metric_daily_agg_vw for Cash Dashboard analytics (QoQ, YoY, prior quarter) |
| Schedule | Manual execution |
| Last Saved | |
| Last Run | Not recorded |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/138586/ |

This query builds a sandbox table (`dna_sandbox.c360_test_sz_2`) by reading `customer_metric_daily_agg_vw` and unioning multiple time-period branches (current year, prior year same date, prior year same day-of-week, prior quarter QTD, prior quarter full) to support QoQ and YoY Cash Dashboard comparisons.

---

#### C360 - mv_customer_metric_daily_agg_vw_union

| Field | Value |
|---|---|
| Query ID | 138254 |
| Title | C360 - mv_customer_metric_daily_agg_vw_union |
| Author | Not specified |
| Description | Creates a union table merging legacy dna_approved.daily_active_customers (through 2026-03-31) with C360 data going forward, providing a continuous time series across the DAC-to-C360 migration |
| Schedule | Manual execution |
| Last Saved | |
| Last Run | Not recorded |
| Datasource | Redshift - Prod-BI |
| Alation Query URL | https://godaddy.alationcloud.com/query/138254/ |

This query creates `bi.ba_usi.mv_customer_metric_daily_agg_vw_union` as a bridge table that unions legacy DAC rows (evaluation dates ≤ 2026-03-31) with C360 `customer_metric_daily_agg_vw` rows (2026-04-01 onward), providing a continuous customer time series that spans the DAC-to-C360 migration cutover without gaps.

---

#### NC validate DAC/MAC/Cash Dash

| Field | Value |
|---|---|
| Query ID | 128804 |
| Title | NC validate DAC/MAC/Cash Dash |
| Author | Not specified |
| Description | Validation scratchpad comparing DAC, MAC, and C360 customer metrics across three different source tables |
| Schedule | Manual execution |
| Last Saved | |
| Last Run | Not recorded |
| Datasource | Redshift - Serverless - Dev |
| Alation Query URL | https://godaddy.alationcloud.com/query/128804/ |

This multi-source validation query compares customer metric totals from the Cash Dashboard view (`ba_corporate.customer_vs_target`) and `customer_metric_daily_agg_vw` over the same date ranges, serving as a cross-validation scratchpad during the legacy-to-C360 transition.

---

#### customer vs target v2

| Field | Value |
|---|---|
| Query ID | 127875 |
| Title | customer vs target v2 |
| Author | Not specified |
| Description | Explores customer_metric_daily_agg_vw alongside a date dimension for time-period attribution and QoQ customer vs. budget comparisons |
| Schedule | Manual execution |
| Last Saved | |
| Last Run | Not recorded |
| Datasource | Redshift - Serverless - Dev |
| Alation Query URL | https://godaddy.alationcloud.com/query/127875/ |

This exploratory query derives a time-dimension table (quarter start, quarter-to-date flags, period-type labels) from `customer_metric_daily_agg_vw` to support customer-versus-target analysis and quarterly period attribution in the Cash Dashboard development workflow.

---

### B3. Advanced Analytics Use Cases

- **QoQ / YoY customer trend analysis:** aggregate daily counts to quarter or year using `partition_eval_mst_date`; join to a relative-date dimension for period-over-period labels (see Alation Query 138184 and 138586)
- **Legacy DAC migration validation:** use the union bridge (Alation Query 138254) or direct comparison (Query 136952) to validate C360 metric parity against legacy `dna_approved.daily_active_customers`
- **Customer movement reconciliation:** verify that `ending_customer_qty = beginning_customer_qty + new_customer_qty − churn_customer_qty + reactivate_customer_qty − merge_customer_qty` using `net_move_qty` as the residual (should be ~0)
- **Multi-dimensional cohort analysis:** combine geography, acquisition channel, customer tenure, and product ownership dimensions to build cohort retention and growth views
- **TTM revenue segmentation:** aggregate `ttm_gcr_usd_amt` by customer type and region to track trailing-twelve-month revenue trends across segments
- **Customer vs. budget dashboards:** feed the Cash Dashboard by joining this table with target data on `partition_eval_mst_date` and standard dimension keys

---

## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance

### C1. Complete Column Reference with Data Insights

> **Note on DDL authority:** The Hive DDL (`customer_metric_daily_agg.ddl`) and PySpark output are authoritative for column definitions. The lake registry `table.ddl` is missing `data_source_enum` (column 30) and has incomplete `@PrimaryKey` annotations — see C4. Primary key membership is sourced from the DQ constraints file. Sample Values and Key Statistics are not available (Alation column profiling returned a permission error during gather stage).

| # | Name | Data Type | Description | Column Lineage | Category | Sample Values | Key Statistics |
|---|---|---|---|---|---|---|---|
| 1 | customer_type_reason_desc | STRING | Reason for customer type classification (e.g., why Active, Churned). Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_type_reason_desc to 'Not Classified'; used as GROUP BY dimension | Categorical | | |
| 2 | customer_acquisition_mst_month | STRING | Month when the customer was first acquired (MST), format YYYY-MM. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_acquisition_mst_month to empty string ''; used as GROUP BY dimension | Date | | |
| 3 | customer_domestic_international_name | STRING | Whether the customer is domestic (US) or international. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_domestic_international_name to 'International'; used as GROUP BY dimension | Categorical | | |
| 4 | customer_region_1_name | STRING | Geographic region level 1. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_region_1_name to 'International - RoW'; used as GROUP BY dimension | Categorical | | |
| 5 | customer_region_2_name | STRING | Geographic region level 2. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_region_2_name to 'Rest of World (RoW)'; used as GROUP BY dimension | Categorical | | |
| 6 | customer_region_3_name | STRING | Geographic region level 3. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_region_3_name to 'NA'; used as GROUP BY dimension | Categorical | | |
| 7 | customer_country_name | STRING | Customer country name at evaluation date. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_acquisition_country_name to 'Unknown'; renamed from customer_acquisition_country_name; used as GROUP BY dimension | Categorical | | |
| 8 | customer_country_code | STRING | Customer country ISO code at evaluation date. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_acquisition_country_code to '--', then UPPER(), then normalization: 'UK' → 'GB'; renamed from customer_acquisition_country_code | Categorical | | |
| 9 | customer_type_name | STRING | Customer type at evaluation date (e.g., Active, Churned, Reactivated). Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_type_name to 'Not Classified'; used as GROUP BY dimension | Categorical | | |
| 10 | acquisition_channel_name | STRING | Acquisition channel name at time of customer acquisition. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_acquisition_channel_name to 'Not GA Attributed'; renamed from customer_acquisition_channel_name; used as GROUP BY dimension | Categorical | | |
| 11 | customer_tenure_year_count | INT | Customer tenure in whole years at evaluation date. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_tenure_year_count to 0, cast to INT; used as GROUP BY dimension | Numeric | | |
| 12 | product_ownership_category_list | STRING | String-encoded list of product PNL categories owned by the customer. Part of 19-column composite PK. | CAST of customer_life_cycle_vw.product_pnl_category_list to STRING; renamed from product_pnl_category_list; bracket notation stripped in Redshift insert ([val1, val2] → val1, val2) | Array | | |
| 13 | product_ownership_line_list | STRING | String-encoded list of product PNL lines owned by the customer. Part of 19-column composite PK. | CAST of customer_life_cycle_vw.product_pnl_line_list to STRING; renamed from product_pnl_line_list; bracket notation stripped in Redshift insert | Array | | |
| 14 | reseller_type_name | STRING | Reseller type name. Part of 19-column composite PK. | Direct mapping from customer_life_cycle_vw.reseller_type_name; used as GROUP BY dimension | Categorical | | |
| 15 | fraud_flag | BOOLEAN | True if the customer was flagged as fraud at the evaluation date. Part of 19-column composite PK. | COALESCE of customer_life_cycle_vw.customer_fraud_flag to false; renamed from customer_fraud_flag | Boolean | | |
| 16 | point_of_purchase_name | STRING | Point of purchase name from the customer's acquisition bill. Part of 19-column composite PK. Note: missing @PrimaryKey annotation in lake registry DDL — DQ constraints file is authoritative. | COALESCE of customer_life_cycle_vw.point_of_purchase_name to 'Unknown'; used as GROUP BY dimension | Categorical | | |
| 17 | customer_acquisition_bill_fraud_flag | BOOLEAN | True if the customer's acquisition bill has a fraud record. Part of 19-column composite PK. Note: missing @PrimaryKey annotation in lake registry DDL — DQ constraints file is authoritative. | COALESCE of customer_life_cycle_vw.customer_acquisition_bill_fraud_flag to false; used as GROUP BY dimension | Boolean | | |
| 18 | brand_name_list | STRING | String-encoded list of all brands associated with the customer. Part of 19-column composite PK. | CAST of customer_life_cycle_vw.brand_name_list to STRING; bracket notation stripped in Redshift insert | Array | | |
| 19 | product_category_qty | INT | Count of distinct product PNL categories owned by customers in this dimension combination. | Derived as SIZE(product_pnl_category_list) from customer_life_cycle_vw, COALESCE to 0 when null | Numeric | | |
| 20 | ttm_gcr_usd_amt | DECIMAL(18,2) | Sum of trailing-twelve-month gross cash received (USD) for all customers in this dimension combination. | SUM of customer_life_cycle_vw.ttm_gcr_usd_amt grouped by 18 reporting dimensions | Amount | | |
| 21 | ending_customer_qty | BIGINT | Count of customers with active_status_flag = true at end of evaluation date. | COUNT_IF(customer_life_cycle_vw.active_status_flag = true) grouped by 18 reporting dimensions | Numeric | | |
| 22 | churn_customer_qty | BIGINT | Count of customers who churned on the evaluation date (non-null churn date). | COUNT_IF(customer_life_cycle_vw.customer_churn_mst_date IS NOT NULL) grouped by 18 reporting dimensions | Numeric | | |
| 23 | merge_customer_qty | BIGINT | Count of customers merged into another account on the evaluation date. | COUNT_IF(customer_life_cycle_vw.customer_merge_mst_date IS NOT NULL) grouped by 18 reporting dimensions | Numeric | | |
| 24 | new_customer_qty | BIGINT | Count of customers newly acquired on the evaluation date. | COUNT_IF(customer_life_cycle_vw.customer_acquisition_mst_date = partition_eval_mst_date) grouped by 18 reporting dimensions | Numeric | | |
| 25 | reactivate_customer_qty | BIGINT | Count of customers reactivated on the evaluation date. | COUNT_IF(customer_life_cycle_vw.customer_reactivate_mst_date IS NOT NULL) grouped by 18 reporting dimensions | Numeric | | |
| 26 | beginning_customer_qty | BIGINT | Ending customer count from the prior consecutive day for the same dimension combination; 0 if no prior consecutive day exists. | LAG(ending_customer_qty) OVER (PARTITION BY 18 dimension columns ORDER BY partition_eval_mst_date); dimension-continuity fill inserts zero-metric rows for dim combos absent on evaluation date to ensure LAG integrity | Numeric | | |
| 27 | net_move_qty | BIGINT | Net movement reconciliation metric: should be ~0 if all customer events are correctly captured. | Calculated as ending_customer_qty − beginning_customer_qty − new_customer_qty + churn_customer_qty − reactivate_customer_qty + merge_customer_qty | Numeric | | |
| 28 | net_add_qty | BIGINT | Net customer additions: ending minus beginning count for the same dimension combination. | Calculated as ending_customer_qty − beginning_customer_qty | Numeric | | |
| 29 | net_churn_qty | BIGINT | Net churn: churned customers minus reactivated customers. | Calculated as churn_customer_qty − reactivate_customer_qty | Numeric | | |
| 30 | data_source_enum | STRING | Identifier for the data source pipeline. Always 'customer360' for this table. Note: column is missing from lake registry table.ddl — lake DDL needs update. | Hardcoded literal 'customer360' in PySpark ETL output | Categorical | | |
| 31 | etl_build_mst_ts | TIMESTAMP | Timestamp when this partition was built by the ETL, expressed in MST. | Derived as CAST(from_utc_timestamp(current_timestamp(), 'MST') AS timestamp) at ETL run time | Timestamp | | |
| 32 | partition_eval_mst_date | STRING | Partition key: evaluation date in Mountain Standard Time (YYYY-MM-DD string in Hive/Glue; DATE in Redshift). Part of 19-column composite PK. Always filter on this column. | Direct mapping from customer_life_cycle_vw.partition_eval_mst_date; also the overwrite partition range key | Date | | |

---

### C2. Primary Key & Performance

**Composite Primary Key (19 columns, enforced by DataQualityOperator):**

`partition_eval_mst_date` + the 18 reporting dimension columns (columns 1–18 above):
`customer_type_reason_desc`, `customer_acquisition_mst_month`, `customer_domestic_international_name`, `customer_region_1_name`, `customer_region_2_name`, `customer_region_3_name`, `customer_country_name`, `customer_country_code`, `customer_type_name`, `acquisition_channel_name`, `customer_tenure_year_count`, `product_ownership_category_list`, `product_ownership_line_list`, `reseller_type_name`, `fraud_flag`, `point_of_purchase_name`, `customer_acquisition_bill_fraud_flag`, `brand_name_list`

> **Note:** The lake registry `table.ddl` is missing `@PrimaryKey` annotations for `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`. The DQ constraints file (`data_quality/constraints/customer_metric_daily_agg.json`) is authoritative for the full 19-column PK definition.

**Redshift distribution and sort:**

| Property | Value |
|---|---|
| DISTSTYLE | AUTO |
| DISTKEY | partition_eval_mst_date |
| SORTKEY | partition_eval_mst_date |
| Files per partition | 1 (repartition(1) before write) |

**Performance guidance:** Always include a `WHERE partition_eval_mst_date = ...` or `BETWEEN` filter. The sort key and partition key are identical, so date-range queries benefit from both partition pruning (lake) and sort-key skipping (Redshift).

---

### C3. Key Features, Capabilities & Limitations

**Capabilities:**

- Pre-aggregated daily roll-up — no need to re-aggregate from row-level customer lifecycle data
- 18 reporting dimensions provide flexible slicing across geography, customer profile, product ownership, and acquisition attributes
- Dimension continuity fill ensures `beginning_customer_qty` is always populated for consecutive days, even when a dimension combination had zero activity on the evaluation date
- Built-in reconciliation metric `net_move_qty` enables automated data quality checks on movement event completeness
- Replaces `customer_mart.daily_active_customers`; migration bridge available (Alation Query 138254)

**Limitations:**

- `data_source_enum` is always `'customer360'` — it is not a meaningful filter dimension
- Array-encoded string columns (`product_ownership_category_list`, `product_ownership_line_list`, `brand_name_list`) are stored as strings. In Redshift, bracket notation is stripped (`[val1, val2]` → `val1, val2`); in the Hive/Glue layer, values are cast from array to string
- `partition_eval_mst_date` is `STRING` (YYYY-MM-DD) in Hive/Glue and `DATE` in Redshift — use appropriate casts when querying cross-platform or constructing date arithmetic
- 2+/3+ customer metrics mentioned in Confluence documentation are **not** present as separate columns in this table
- The lake registry `table.ddl` is stale: it is missing the `data_source_enum` column and has incomplete `@PrimaryKey` annotations; the Hive DDL and PySpark code are authoritative
- `legacyLookBackEnabled: true` is set in the lake registry but the depth of available historical backfill is not specified

---

### C4. Important Notes & Pitfalls

> **USER NOTE (highest priority):** Always filter on `partition_eval_mst_date`.

1. **Always filter on `partition_eval_mst_date`** — this is the partition key. Omitting it causes a full table scan, which is expensive given the cardinality of 18 dimensions × daily history.

2. **This table replaces `customer_mart.daily_active_customers` (legacy DAC)** — do not join both in the same query without a date guard. Alation Query 138254 provides a validated union bridge with a cutover at 2026-03-31.

3. **UK→GB country code normalization** — the ETL normalizes `customer_country_code = 'UK'` to `'GB'`. Queries filtering on `'UK'` will return no rows.

4. **`data_source_enum` column is missing from the lake registry DDL** but is present in the underlying Parquet data with a hardcoded value of `'customer360'`. Queries against the lake table can reference this column, but downstream tools relying solely on the lake DDL may not show it.

5. **Incomplete primary key annotations in lake DDL** — `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag` are part of the authoritative 19-column PK (per DQ constraints JSON) but are not annotated as `@PrimaryKey` in the lake registry `table.ddl`. Use the DQ constraints file as the reference for PK definition.

6. **Dimension-continuity fill rows** — zero-metric rows exist for dimension combinations that were present on the prior day but had no matching customers on the evaluation date. These are structural rows inserted to support the LAG window function for `beginning_customer_qty`; they are not data gaps or errors.

7. **SLA discrepancy** — the DAG `documentation_markdown` states `SLA: N/A`, but the lake registry specifies delivery by 08:00 AM MST (cron `00 15 * * ? *` UTC) and the policies file defines `maxDurationMins: 120, severity: TIER_4`. <!-- REQUIRES_MANUAL_INPUT: DE --> Owner validation needed to reconcile and update the DAG documentation.

8. **Column ordering difference between Hive DDL and lake registry DDL** — `brand_name_list`, `point_of_purchase_name`, and `customer_acquisition_bill_fraud_flag` appear at different positions. This does not affect Parquet schema-on-read queries but may affect tools that depend on ordinal column position.

---

### C5. Always-On Column Filters

| Filter Column | Recommended Usage | Rationale | Source |
|---|---|---|---|
| partition_eval_mst_date | Always include — use `= 'YYYY-MM-DD'` or `BETWEEN 'start' AND 'end'` | Partition key; omitting causes full table scan | USER NOTES (highest priority); lake registry partition strategy |

No hardcoded business-rule scope filters are applied in the ETL. All customer segments, geographies, products, and fraud statuses are included without restriction.

---

### C6. Common Business Metrics

| Metric Column | Definition | Computation | Grain |
|---|---|---|---|
| ending_customer_qty | Count of customers active at end of evaluation date | COUNT_IF(active_status_flag = true) from customer_life_cycle_vw | Per date × 18 dimensions |
| beginning_customer_qty | Prior consecutive day's ending_customer_qty for the same dimension combination; 0 if no prior consecutive day | LAG(ending_customer_qty) OVER (PARTITION BY 18 dims ORDER BY partition_eval_mst_date) | Per date × 18 dimensions |
| new_customer_qty | Count of customers newly acquired on evaluation date | COUNT_IF(customer_acquisition_mst_date = partition_eval_mst_date) | Per date × 18 dimensions |
| churn_customer_qty | Count of customers who churned on evaluation date | COUNT_IF(customer_churn_mst_date IS NOT NULL) | Per date × 18 dimensions |
| reactivate_customer_qty | Count of customers reactivated on evaluation date | COUNT_IF(customer_reactivate_mst_date IS NOT NULL) | Per date × 18 dimensions |
| merge_customer_qty | Count of customers merged into another account on evaluation date | COUNT_IF(customer_merge_mst_date IS NOT NULL) | Per date × 18 dimensions |
| net_add_qty | Net change in customer base (ending minus beginning) | ending_customer_qty − beginning_customer_qty | Per date × 18 dimensions |
| net_churn_qty | Net churn (churned minus reactivated) | churn_customer_qty − reactivate_customer_qty | Per date × 18 dimensions |
| net_move_qty | Reconciliation residual; should be ~0 if all events are captured | ending − beginning − new + churn − reactivate + merge | Per date × 18 dimensions |
| ttm_gcr_usd_amt | Trailing-twelve-month gross cash received (USD) aggregated over the dimension combination | SUM(ttm_gcr_usd_amt) from customer_life_cycle_vw | Per date × 18 dimensions |
| product_category_qty | Count of distinct product PNL categories owned by customers in the dimension combination | SIZE(product_pnl_category_list) from customer_life_cycle_vw, COALESCE to 0 | Per date × 18 dimensions |

---

### C7. Glossary & Term Definitions

> **USER NOTE (highest priority):** This is the C360 replacement for `customer_mart.daily_active_customers`. Always filter on `partition_eval_mst_date`.

| Term | Definition |
|---|---|
| partition_eval_mst_date | The evaluation date for metrics in Mountain Standard Time (MST), stored as YYYY-MM-DD. This is both the partition key and the primary time dimension. Always include this in query filters. |
| Ending Customer | A customer with `active_status_flag = true` at the end of the evaluation date. Equivalent to the active customer count (formerly "active customers" in legacy DAC). |
| Beginning Customer | The prior consecutive day's ending customer count for the same dimension combination. Computed via LAG window function. Returns 0 if the prior day had no rows for that dimension combination. |
| Active Customer | Synonymous with Ending Customer for this table — a customer holding at least one active subscription at end of evaluation date. |
| New Customer | A customer whose `customer_acquisition_mst_date` equals the `partition_eval_mst_date` — acquired on that day. |
| Churned Customer | A customer with a non-null `customer_churn_mst_date` on the evaluation date — lost an active subscription on that day. |
| Reactivated Customer | A customer with a non-null `customer_reactivate_mst_date` — regained active status on the evaluation date. |
| Merged Customer | A customer account that was merged into another account on the evaluation date (`customer_merge_mst_date` is not null). |
| Net Add | `ending_customer_qty − beginning_customer_qty` — net change in the active customer base on a given day. |
| Net Churn | `churn_customer_qty − reactivate_customer_qty` — churned customers net of reactivations. |
| Net Move | `ending − beginning − new + churn − reactivate + merge` — a reconciliation residual that should be ~0 if all movement events are correctly captured. |
| TTM GCR | Trailing Twelve Month Gross Cash Received (USD) — the sum of revenue received from a customer over the prior 12 months. Aggregated across all customers in a dimension combination. |
| Dimension Continuity Fill | A mechanism in the ETL that inserts zero-metric rows for dimension combinations present on the prior evaluation day but absent on the current day. This ensures the LAG window function can compute `beginning_customer_qty` without gaps. |
| Reporting Dimension | Any of the 18 columns used to segment metrics: customer_type_reason_desc, customer_acquisition_mst_month, customer_domestic_international_name, customer_region_1_name through _3_name, customer_country_name, customer_country_code, customer_type_name, acquisition_channel_name, customer_tenure_year_count, product_ownership_category_list, product_ownership_line_list, reseller_type_name, fraud_flag, point_of_purchase_name, customer_acquisition_bill_fraud_flag, brand_name_list. |
| Legacy DAC | `customer_mart.daily_active_customers` — the legacy Daily Active Customers table that this C360 table replaces. |
| Data Tier 4 | Internal data governance classification indicating the SLA tier (delivery by 08:00 AM MST daily, max pipeline duration 120 minutes). |
| UK→GB Normalization | ETL transformation that converts `customer_country_code = 'UK'` to `'GB'` (ISO 3166-1 alpha-2 standard). Queries filtering on 'UK' will return no rows. |

---

### C8. Example Queries & Patterns

> Always include a `partition_eval_mst_date` filter. All examples target `customer360.customer_metric_daily_agg_vw`.

**Pattern 1 — Daily ending customer count by country (date range)**

```sql
-- Ending customer count per country for a date range
-- Always filter partition_eval_mst_date to avoid full scans
SELECT partition_eval_mst_date,
       customer_country_name,
       SUM(ending_customer_qty) AS ending_customers
FROM   customer360.customer_metric_daily_agg_vw
WHERE  partition_eval_mst_date BETWEEN '2026-01-01' AND '2026-03-31'
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```

**Pattern 2 — Customer movement for a single day by customer type**

```sql
-- New, churned, and net-add counts for yesterday, broken out by customer_type_name
SELECT customer_type_name,
       SUM(new_customer_qty)   AS new_customers,
       SUM(churn_customer_qty) AS churned,
       SUM(net_add_qty)        AS net_add
FROM   customer360.customer_metric_daily_agg_vw
WHERE  partition_eval_mst_date = CURRENT_DATE - 1
GROUP BY 1
ORDER BY 4 DESC;
```

**Pattern 3 — TTM GCR by region on the latest available day**

```sql
-- TTM GCR USD by region_2 as of the most recent partition
-- Use a subquery to avoid hardcoding the max date
SELECT customer_region_2_name,
       SUM(ttm_gcr_usd_amt) AS ttm_gcr_usd
FROM   customer360.customer_metric_daily_agg_vw
WHERE  partition_eval_mst_date = (
         SELECT MAX(partition_eval_mst_date)
         FROM   customer360.customer_metric_daily_agg_vw
       )
GROUP BY 1
ORDER BY 2 DESC;
```

**Pattern 4 — Movement reconciliation check (net_move_qty should be ~0)**

```sql
-- Validate that net_move_qty is ~0 (movement events reconcile to ending-beginning delta)
-- Any non-zero total may indicate missing event records
SELECT partition_eval_mst_date,
       SUM(ending_customer_qty)   AS ending,
       SUM(beginning_customer_qty) AS beginning,
       SUM(new_customer_qty)       AS new_custs,
       SUM(churn_customer_qty)     AS churned,
       SUM(net_move_qty)           AS net_move_residual
FROM   customer360.customer_metric_daily_agg_vw
WHERE  partition_eval_mst_date BETWEEN '2026-06-01' AND '2026-06-17'
GROUP BY 1
ORDER BY 1;
```

---

## Pillar D: HOW Is It Built? — Pipeline & Provenance

### D1. Data Source Reference

#### Upstream Sources

**Depth 1 Upstream Tables — Total: 1**

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| customer_life_cycle_vw | GoDaddy Central Data Lake (Prod) | customer360 | Table (Partitioned, Parquet) | lake |

> The PySpark job reads `customer_core_conformed.customer_life_cycle` (Hive/Glue form), which resolves to `customer360.customer_life_cycle_vw` via S3 path identity (`s3://gd-ckpetlbatch-prod-customer-core-conformed/customer_core_conformed/customer_life_cycle/`). They are the same underlying data; the lake lineage registry entry is `customer360.customer_life_cycle_vw`.

**Depth 2 Upstream Tables — Total: 20**
*(From `customer360.customer_life_cycle_vw` lake registry `table.yaml` lineage block)*

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| customer_fraud | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | lake |
| customer_type_history | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | lake |
| shopper_acquisition | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | lake |
| shopper_merge | GoDaddy Central Data Lake (Prod) | analytic_feature | Table | lake |
| dim_customer_history_vw | GoDaddy Central Data Lake (Prod) | customer360 | Table | lake |
| customer_id_mapping_snapshot | GoDaddy Central Data Lake (Prod) | customers | Table | lake |
| dim_reseller | GoDaddy Central Data Lake (Prod) | dp_enterprise | Table | lake |
| bill_line_traffic_ext | GoDaddy Central Data Lake (Prod) | ecomm_mart | Table | lake |
| dim_bill_line_purchase_attribution | GoDaddy Central Data Lake (Prod) | ecomm_mart | Table | lake |
| entitlement_bill_type | GoDaddy Central Data Lake (Prod) | ecomm_mart | Table | lake |
| dim_bill_shopper_id_xref | GoDaddy Central Data Lake (Prod) | enterprise | Table | lake |
| dim_entitlement_history | GoDaddy Central Data Lake (Prod) | enterprise | Table | lake |
| dim_new_acquisition_shopper | GoDaddy Central Data Lake (Prod) | enterprise | Table | lake |
| dim_subscription_history | GoDaddy Central Data Lake (Prod) | enterprise | Table | lake |
| fact_bill_line | GoDaddy Central Data Lake (Prod) | enterprise | Table | lake |
| fact_entitlement_bill | GoDaddy Central Data Lake (Prod) | enterprise | Table | lake |
| dim_bill_fraud_history_vw | GoDaddy Central Data Lake (Prod) | finance360 | Table | lake |
| dim_country_vw | GoDaddy Central Data Lake (Prod) | finance360 | Table | lake |
| dim_product_vw | GoDaddy Central Data Lake (Prod) | finance360 | Table | lake |
| manual_paid_subscription | GoDaddy Central Data Lake (Prod) | finance_cln | Table | lake |

#### Downstream Sources

**Depth 1 Downstream Tables — Total: 4**
*(Analyst-created materialized/sandbox tables observed in Alation queries; not confirmed lake-registered tables)*

| Table Name | Database | Schema | Type | Platform |
|---|---|---|---|---|
| customer_metric_daily_agg_vw_mv | Redshift - Serverless - Dev | dev.ba_usi | Materialized Table | redshift |
| mv_customer_metric_daily_agg_vw_union | Redshift - Prod-BI | bi.ba_usi | Materialized Table | redshift |
| c360_test_sz_2 | Redshift - Prod-BI | dna_sandbox | Sandbox Table | redshift |
| customer_vs_target | Redshift - Prod-BI / Dev | bi_dashboards_prod / ba_corporate | Dashboard View | redshift |

---

### D2. Data Pipeline & Infrastructure

| Field | Value |
|---|---|
| Source Repo | gdcorp-dna/dof-dpaas-customer-feature (branch: main) |
| PySpark Script | customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py |
| DAG File | customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py |
| DAG ID | customer-metric-daily-agg |
| Hive DDL | customer360/customer-metrics/src/ddls/customer_metric_daily_agg.ddl |
| Redshift DDL | customer360/customer-metrics/src/ddls/create_customer_metric_daily_agg.sql |
| Policies File | customer360/customer-metrics/src/policies/customer_metric_daily_agg_dag.yaml |
| DQ Constraints | customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg.json |
| Orchestration | AWS MWAA — environment: dof-customers (account 688051721285) |
| Compute Engine | EMR Serverless, release emr-7.10.0 |
| Instance Type | m6g.16xlarge (ARM Graviton2), 15 core instances |
| Spark Config (fallback) | Executor: 16 GB / 4 cores; Driver: 4 GB / 2 cores; maxExecutors: 10 |
| Redshift Cluster | arn:aws:redshift:us-west-2:561403605607:namespace:da7e8313-cc13-40ca-962e-715827b94b24 |
| EMR AWS Account | 664289052486 |
| Data Lake AWS Account | 028140660016 |

---

### D3. SLA & Refresh Schedule

| Field | Value |
|---|---|
| Schedule (prod) | `30 7 * * *` — 7:30 AM MST daily |
| Schedule (dev) | Disabled (None) |
| SLA Delivery Target | 08:00 AM MST daily (lake registry: `cron(00 15 * * ? *)` UTC) |
| Max Pipeline Duration | 120 minutes |
| SLA Severity | TIER_4 |
| Catchup | False |
| Max Active Runs | 15 |
| Retries | 1 retry, 3-minute delay |
| Dependency | Waits for `customer360.customer_life_cycle_vw` S3 success file before starting |
| legacyLookBackEnabled | true (lake registry) |

<!-- REQUIRES_MANUAL_INPUT: DE -->
**SLA conflict to resolve:** The DAG `documentation_markdown` states `SLA: N/A`, but the lake registry specifies delivery by 08:00 AM MST and policies.yaml defines `maxDurationMins: 120, severity: TIER_4`. A Data Engineering owner should update the DAG documentation to match the lake registry SLA.

---

### D4. Table Creation & ETL Implementation

#### ETL Processes

The `customer-metric-daily-agg` Airflow DAG (AWS MWAA, `dof-customers`) orchestrates the end-to-end pipeline on a daily schedule (`30 7 * * *` MST). It resolves date parameters, waits for the upstream customer lifecycle dependency, runs the PySpark aggregation on EMR Serverless, validates the output, publishes the lake table, and loads the Redshift view via a staging delete-insert pattern.

Numbered implementation steps:

1. **Dependency check** — `dependencies` task waits for the `customer360.customer_life_cycle_vw` S3 success file before proceeding
2. **Redshift table setup** — `create_redshift_tables` ensures both the production table and staging table exist in Redshift (runs `create_customer_metric_daily_agg.sql` and `create_customer_metric_daily_agg_stg.sql`)
3. **EMR provisioning** — `create_emr` spins up an EMR Serverless cluster (`emr-7.10.0`, `m6g.16xlarge`, 15 core instances)
4. **PySpark execution** — `run_customer_metric_daily_agg` submits `customer_metric_daily_agg.py`; aggregates customer lifecycle metrics for the requested date range and writes to `customer_core_conformed.customer_metric_daily_agg` (Hive/Glue / S3)
5. **EMR teardown** — `remove_emr` terminates the cluster regardless of success or failure
6. **Local DQ check** — `dq_check_customer_metric_daily_agg_local` validates 19-column PK uniqueness on the Hive table
7. **Lake API notification** — `call_lake_api` (prod only) sends a `SuccessNotificationOperator` signal for `customer360.customer_metric_daily_agg_vw`, triggering lake catalog registration
8. **Lake DQ check** — `dq_check_customer_metric_daily_agg_lake` validates 19-column PK uniqueness on the lake table
9. **Redshift staging load** — `s3_to_redshift_stg` COPYs Parquet partitions from S3 into the Redshift staging table
10. **Redshift production insert** — `insert_customer_metric_daily_agg` deletes rows for `end_mst_date` from the production table and inserts from staging (prod: `customer360.customer_metric_daily_agg_vw`; non-prod: `customer_core_conformed_dev.customer_metric_daily_agg_vw`)

#### Data Processing Steps

- Read `customer_core_conformed.customer_life_cycle` filtered by `partition_eval_mst_date BETWEEN '{start_mst_date_minus_1}' AND '{end_mst_date}'` — one extra prior day is fetched to support the LAG window for `beginning_customer_qty`
- Apply `COALESCE` defaults for all 18 dimension columns (e.g., `customer_domestic_international_name` → `'International'`, `customer_country_name` → `'Unknown'`, `fraud_flag` → `false`)
- Rename dimension columns to output names (e.g., `customer_acquisition_country_name` → `customer_country_name`, `customer_fraud_flag` → `fraud_flag`)
- Normalize `customer_country_code`: apply `UPPER()` then map `'UK'` → `'GB'`
- Cast array columns (`product_pnl_category_list`, `product_pnl_line_list`, `brand_name_list`) to STRING
- Compute aggregated metrics via `GROUP BY` on the 18 dimension columns: `ending_customer_qty`, `churn_customer_qty`, `merge_customer_qty`, `new_customer_qty`, `reactivate_customer_qty`, `ttm_gcr_usd_amt`, `product_category_qty`
- Apply dimension-continuity fill: identify dimension combinations present on the prior evaluation day but absent on the current day; insert zero-metric rows to maintain LAG integrity
- Compute `beginning_customer_qty` via `LAG(ending_customer_qty) OVER (PARTITION BY 18 dims ORDER BY partition_eval_mst_date)`; default to 0 for non-consecutive prior days
- Derive `net_add_qty`, `net_churn_qty`, `net_move_qty` from the aggregated and LAG-derived values
- Add ETL metadata: hardcoded `data_source_enum = 'customer360'`; `etl_build_mst_ts` = current UTC timestamp converted to MST
- Filter final output to `partition_eval_mst_date BETWEEN '{start_mst_date}' AND '{end_mst_date}'` (excludes the extra prior day)
- Write via `df.repartition(1).write.insertInto('customer_core_conformed.customer_metric_daily_agg', overwrite=True)` followed by best-effort `MSCK REPAIR TABLE`
- In Redshift insert SQL: strip bracket notation from array-string columns (`[val1, val2]` → `val1, val2`)

#### Error Handling and Logging

- Slack alert channel `#edt-airflow-alerts` (prod) and `#edt-airflow-alerts-low-priority` (non-prod) for all DAG failures
- On-call routing to `#marketing-data-product-engineering` and `DEV-EDT-OnCall`
- All tasks configured with 1 retry and a 3-minute retry delay
- EMR cluster is always removed via `remove_emr` task (cluster lifecycle managed independently of task success/failure)
- `MSCK REPAIR TABLE` is wrapped in a try/except — failure is logged but does not abort the pipeline
- Catchup is disabled; missed runs are not automatically backfilled

#### Data Validation

- `dq_check_customer_metric_daily_agg_local` (DataQualityOperator) — enforces 19-column composite PK uniqueness on `customer_core_conformed.customer_metric_daily_agg` after the EMR write; pipeline fails if violated
- `dq_check_customer_metric_daily_agg_lake` (DataQualityOperator) — enforces the same 19-column PK uniqueness on `customer360.customer_metric_daily_agg_vw` after the lake API notification; pipeline fails if violated
- Both DQ checks are blocking tasks — downstream Redshift load does not proceed if either check fails
- Dimension-completeness is structurally enforced in the ETL via zero-row fill for missing dimension combinations

---

## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem

### E1. Data Quality Checks

| Check | Target Table | Method | Detail |
|---|---|---|---|
| 19-column composite PK uniqueness | customer_core_conformed.customer_metric_daily_agg (Hive) | DataQualityOperator (DAG task: dq_check_customer_metric_daily_agg_local) | Enforces uniqueness on all 19 PK columns; defined in data_quality/constraints/customer_metric_daily_agg.json; enabled: true |
| 19-column composite PK uniqueness | customer360.customer_metric_daily_agg_vw (Lake) | DataQualityOperator (DAG task: dq_check_customer_metric_daily_agg_lake) | Same 19-column constraint applied to the lake table after lake API notification |
| Dimension completeness | customer_core_conformed.customer_metric_daily_agg | ETL structural check | Zero-metric rows inserted for dimension combinations present on prior day but absent on evaluation date; ensures LAG-based beginning_customer_qty is never broken |
| Partition registration | Hive/Glue catalog | MSCK REPAIR TABLE | Best-effort repair after insertInto; failure is non-blocking |

---

### E2. Best Practices & Tips

- **Always filter `partition_eval_mst_date`** — this is the single most important query best practice. Use an equality or `BETWEEN` filter; omitting it causes full table scans.
- **Use C360 instead of legacy DAC** — `customer_mart.daily_active_customers` is the legacy predecessor. For any new analytics, use `customer360.customer_metric_daily_agg_vw`. If you need a continuous time series spanning the transition, use the union bridge (Alation Query 138254).
- **Watch for UK vs. GB in country code** — the ETL normalizes `'UK'` to `'GB'`. If your query previously filtered on `customer_country_code = 'UK'`, update it to `'GB'`.
- **Array-encoded string columns** — `product_ownership_category_list`, `product_ownership_line_list`, and `brand_name_list` contain comma-separated values (brackets already stripped in Redshift). Use `LIKE`, `SPLIT_PART`, or `REGEXP` functions to parse them; do not treat them as native array types in Redshift.
- **`net_move_qty` as a data quality signal** — in a well-formed data set, `SUM(net_move_qty)` over a date range should be ~0. A significant non-zero value may indicate missing or double-counted lifecycle events upstream.
- **`beginning_customer_qty` on the first day** — if a dimension combination has no prior consecutive-day row, `beginning_customer_qty = 0`. This is expected behavior, not a data error.
- **Backfill support** — the DAG accepts `start_mst_date` and `end_mst_date` parameters and can process multi-day ranges in a single run (`maxActiveRuns: 15`).

---

### E3. Related Articles & Documentation

- **Confluence — Customer360 hub page:** https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360
- **Confluence — Customer360 Business Context Structure** (page 4387965088): schema overview, data tier classifications, grain definitions — https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4387965088/
- **Confluence — Customer Metrics** (page 4042131239): lifecycle event definitions (acquisition → new customers, billing → active customers, subscription → 2+/3+ customers, churn, reactivation, merge) — https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131239/
- **Alation — Redshift Dev table:** https://godaddy.alationcloud.com/table/7038918/
- **Alation — Lake table:** https://godaddy.alationcloud.com/table/7038346/
- **GitHub — PySpark script:** https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py
- **GitHub — DAG:** https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py

---

## REFERENCES

**Table Identifiers**
- `customer360.customer_metric_daily_agg_vw` — primary lake table / Redshift view
- `customer_core_conformed.customer_metric_daily_agg` — Hive/Glue intermediate table
- `customer360.customer_life_cycle_vw` — depth-1 upstream lake table

**Confluence Articles**
- Customer360 — https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/3779199819/Customer360
- Customer360 Business Context Structure — https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4387965088/
- Customer Metrics — https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/4042131239/

**Alation — Tables**
- https://godaddy.alationcloud.com/table/7038918/ (Redshift - Serverless - Dev: customer360.customer_metric_daily_agg_vw, ID 7038918)
- https://godaddy.alationcloud.com/table/7038346/ (GoDaddy Central Data Lake (Prod): customer360.customer_metric_daily_agg_vw, ID 7038346)

**Alation — Queries**
- https://godaddy.alationcloud.com/query/136952/ — NC validate EBP
- https://godaddy.alationcloud.com/query/138184/ — C360 - customer_metric_daily_agg_vw_mv
- https://godaddy.alationcloud.com/query/138586/ — C360 Cash Dash with budget
- https://godaddy.alationcloud.com/query/138254/ — C360 - mv_customer_metric_daily_agg_vw_union
- https://godaddy.alationcloud.com/query/128804/ — NC validate DAC/MAC/Cash Dash
- https://godaddy.alationcloud.com/query/127875/ — customer vs target v2

**GitHub**
- https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py
- https://github.com/gdcorp-dna/dof-dpaas-customer-feature/blob/main/customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py
