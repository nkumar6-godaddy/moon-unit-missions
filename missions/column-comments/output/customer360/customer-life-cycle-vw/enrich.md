**Stage name:** enrich
**The coding agent was given these instructions:** You are a Data Governance specialist writing column descriptions that comply with
the GoDaddy Data Governance Council's Column Description Standard for Data Lake Assets.

## Step 1: Read INPUT.md
Read `INPUT.md` to understand the target table (database, table, DDL path).

## CRITICAL: Use Official Terminology from Research
The research.md file contains a "Certified Data Dictionary Mappings" section with
the OFFICIAL GoDaddy abbreviation expansions. You MUST use these EXACT terms.
For example:
- GCR = "Gross Cash Receipts" (NOT "Gross Customer Receipt" or any other variation)
- NRU = "New Registered User"
- MRR = "Monthly Recurring Revenue"
If the research lists an official name for an abbreviation, that is the ONLY
acceptable expansion. NEVER invent or guess alternative expansions.

## Column Description Standard (mandatory rules)

1. **Be Clear and Concise** — Use plain, unambiguous language. Avoid jargon unless standard.
2. **Describe What, Not How** — Focus on what the data represents, not how it's computed.
3. **Include Context When Needed** — Add business/domain context for ambiguous terms.
4. **Avoid Abbreviations** — Use full words unless industry standard (SSN, URL, ISO).
5. **Indicate Units and Scale** — Include currency, percentage, milliseconds, etc.
6. **Avoid Redundancy with Column Names** — Provide additional value, don't repeat the name.
7. **Standardize Format** — Use: [What it is] [optional qualifier], [optional business context], [optional format or unit].
8. **Key Annotations**:
   - Add `@PrimaryKey`, `@UniqueKey` or `@ForeignKey(destination_table)` if applicable
   - Add `@Enumerated(value1, value2, ...)` for columns with limited important values
9. **AI Search Optimization**:
   - Use semantic-rich phrases (full sentences or structured fragments)
   - Include synonyms or aliases in parentheses where applicable
   - Tag key data concepts (timestamp, email address, SKU, revenue, etc.)
   - Avoid generic or placeholder descriptions
10. **PK/Primary Key** — Every table must have at least one column with a comment starting
    with PK, Primary Key, Unique Key, or Unique Identifier.
11. **Audit columns** — Must contain timestamp with timezone info (e.g., etl_build_mst_ts).
12. **Preserve existing valid annotations** — Keep comments like 'Employee PII' and append
    descriptive text after them.

## Examples of Good Descriptions
| Column | Description |
|--------|-------------|
| customer_id | @PrimaryKey The UUID identifier of a customer. |
| billing_country_code | @ForeignKey(dm_reference.dim_geography) Billing country code. |
| order_total_usd_amt | Total value of the order in US dollars, including taxes and discounts. |
| create_utc_ts | Timestamp representing when the record was created (UTC, ISO 8601). |
| email_opt_in_flag | Indicates whether the user consented to receive email communications (true/false). |

## Your Task
Using the research output from the previous stage (`research.md`), edit the
target table's DDL file in place at the path given in INPUT.md (under
`repos/lake/...`). Rewrite each column line to include a COMMENT clause
that follows the standard above.

**Rules:**
- Every column MUST have a COMMENT clause.
- **HARD LIMIT: Column comments MUST NOT exceed 255 characters. NO EXCEPTIONS.**
  This is a system constraint — longer comments are TRUNCATED by the database
  engine and cause data loss. For EVERY comment, count characters; if it
  exceeds 255, condense per the rules below.
  - Keep ONLY: the key annotation (@PrimaryKey etc.) + what the data represents.
  - DROP: synonyms, parenthetical aliases, verbose qualifiers, secondary context.
  - DROP: @Enumerated values if the list is too long — summarize instead.
  - NEVER sacrifice the 255-char limit for completeness — brevity wins.
- Preserve the exact column names, types, and order from the original DDL.
- Preserve existing valid comments (like 'Employee PII') — append descriptive text.
- If a column already has a good description, keep or enhance it.
- Use single quotes around comment strings in the DDL.
- Maintain proper DDL syntax (CREATE TABLE, commas, trailing semicolon).
- Do NOT change any column names, types, or table structure.

## MANDATORY VALIDATION (before finishing)
After drafting all comments, verify EVERY comment string between the single
quotes is ≤ 255 characters. If any exceed, rewrite shorter and re-check.
Only then save the edited DDL.

## Step 3: Append a summary to `enrich.md`
The framework pre-created `enrich.md` in your workspace with a header.
Append — do not overwrite — a summary with these sections:

```
## Enrichment summary

- Target: <db>.<table>
- Columns touched: <N>
- Columns with pre-existing comments preserved: <N>
- Columns newly annotated: <N>

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | gcr_usd_amt, margin_gcr_usd_amt |
...

## Notable decisions

- <short bullets on non-obvious judgment calls: which Source Comments
  were preserved verbatim, which reference-table columns were mapped,
  any comments condensed near the 255-char limit, etc.>

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| <col> | 254 | <comment text> |
```

Keep it tight — this is an operator-facing audit trail, not a re-explanation
of the standard.

**The agent summarized its work in this way:**

## Enrichment summary

- Target: customer360.customer_life_cycle_vw
- Columns touched: 34
- Columns with pre-existing comments preserved (enhanced): 34
- Columns newly annotated (from scratch): 0

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| GCR | Gross Cash Receipts | ttm_gcr_usd_amt |
| TTM | Trailing Twelve Months | ttm_gcr_usd_amt, ttm_all_bill_list |
| MST | Mountain Standard Time | customer_acquisition_mst_date, customer_acquisition_mst_month, customer_churn_mst_date, customer_reactivate_mst_date, customer_merge_mst_date, customer_fraud_mst_date, etl_build_mst_ts |
| PNL | Profit and Loss | product_pnl_category_list, product_pnl_category_qty, product_pnl_line_list |
| ETL | Extract, Transform, Load | etl_build_mst_ts |

## Notable decisions

- **GCR corrected**: Existing DDL comment said "gross cash received"; overridden to "Gross Cash Receipts" per Data Governance Council instructions in enrich.md (official term). Alation Certified Data Dictionary was inaccessible in the research stage, so the instruction-level default was applied.
- **customer_acquisition_mst_month**: Clarified storage format as YYYY-MM-01 (first day of month) per Confluence Customer Lifecycle page.
- **customer_region_1/2/3_name**: Added geographic hierarchy level semantics (highest/mid/lowest) drawn from Confluence dim_geography usage notes.
- **customer_tenure_year_count**: Added derivation context (shopper tenure days / 365) per Confluence Customer Lifecycle source logic.
- **customer_merge_mst_date**: Added critical qualifier that this date is set only on the original source shopper_id, not the surviving merged account — sourced from Confluence merge logic.
- **customer_acquisition_mst_date**: Added edge-case note that the date defaults to subscription create date for new customers with a future acquisition date, per Confluence business logic.
- **customer_state_enum**: Trailing whitespace in original comment removed; inline enum state descriptions added.
- **etl_build_mst_ts**: Typo corrected ("build" → "built"); timezone expanded to "Mountain Standard Time" per audit column standard.
- **Apostrophe handling**: All comment strings avoid single quotes (apostrophes) to maintain valid DDL syntax within single-quoted COMMENT clauses.
- **active_paid_subscription_list**: FK annotation reformatted from `@ForeignKey (table)` to `@ForeignKey(table)` for consistency; null-on-churn behavior noted per Confluence.

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| customer_id | 168 | @PrimaryKey Unique UUID identifying a customer across GoDaddy systems. Composite key with partition_eval_mst_date; enables SCD2 historical tracking of lifecycle states. |
| customer_acquisition_mst_date | 166 | Date when the customer first reached net-positive billing status (Mountain Standard Time). For new customers with a future date, defaults to subscription create date. |
| customer_state_enum | 165 | @Enumerated(active, churned, merged, reactivated) Lifecycle state of the customer as of the evaluation date. Active = paid subs; churned = lapsed; merged = absorbed. |
| active_paid_subscription_list | 158 | @ForeignKey(enterprise.dim_subscription_history) Array of active paid subscription identifiers for the customer as of the evaluation date. Null when churned. |

**The agent's final response to the user was:**
All 34 columns in `customer360.customer_life_cycle_vw` have been enriched. Here's a summary of what was done:

**DDL updated:** `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl`

Key changes made:
- All 34 columns now have enriched COMMENT clauses following the Column Description Standard
- All comments validated ≤255 characters (longest: `customer_id` at 168 chars)
- No single quotes/apostrophes inside comment strings (preserves DDL syntax validity)

Notable enrichments:
- **GCR** expanded to "Gross Cash Receipts" (corrected from "gross cash received" in original DDL, per official terminology in governance instructions)
- **`customer_acquisition_mst_date`** — added edge-case business logic note (defaults to subscription create date for future-dated new customers)
- **`customer_acquisition_mst_month`** — clarified as YYYY-MM-01 storage format
- **`customer_region_1/2/3_name`** — added geographic hierarchy level semantics (highest/mid/lowest)
- **`customer_merge_mst_date`** — added critical qualifier: set only on the source shopper, not the surviving merged account
- **`etl_build_mst_ts`** — fixed typo "build" → "built"; timezone expanded per audit column standard
- **`customer_state_enum`** — trailing whitespace removed; inline state definitions added