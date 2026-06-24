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

- Target: marketing-mart.customer_suppression
- Columns touched: 11
- Columns with pre-existing comments preserved: 1 (private_label_13_suppression_flag — enhanced, core content kept)
- Columns newly annotated: 10

## Certified Data Dictionary terms applied

| Abbreviation | Official expansion | Where used |
|---|---|---|
| MST | Mountain Standard Time | etl_build_mst_ts |
| PL13 | Private Label 13 (Reseller suppression) | private_label_13_suppression_flag |
| ETL | Extract, Transform, Load (industry standard) | etl_build_mst_ts |

*Note: Alation Document Folder 6 (Certified Data Dictionary) was unavailable during research — no credentials in environment. Abbreviations above were resolved from Confluence documentation. No GoDaddy-specific business metric abbreviations (GCR, MRR, NRU, etc.) appear in this table's column names.*

## Notable decisions

- `shopper_id` annotated `@PrimaryKey` per Confluence design doc ("Primary key: shopper_id (alternative key: customer_id)").
- `customer_id` annotated `@ForeignKey(customer360.dim_customer_vw)` per lineage — this is the alternative key linking to the upstream ShopperUniverse table.
- `private_label_13_suppression_flag` had the only existing DDL comment; original meaning was preserved and wording tightened to add context about the business rationale (reseller relationship protection).
- `restricted_country_flag` consolidates two legacy flags (`TrrstCtryFlg` country-level and `RstkCtryFlg` country-region-level), both documented in Confluence and evidenced by dual upstream tables (ecomm_cln.gdshop_blocked_country_cln + ecomm_cln.gdshop_blocked_country_region_cln). Comment captures this consolidation explicitly.
- `bad_email_address_format_flag` is the inverted form of `IsValidEmailAddress` from MDM; comment notes the inversion to prevent misinterpretation.
- Apostrophes removed from all comments to avoid SQL single-quote escaping complexity ("shopper's" → "shopper").
- `etl_build_mst_ts` comment specifies timezone as "Mountain Standard Time" per the column naming convention and table SLA (6:00 AM MST daily delivery).

## Longest comments (for QA)

| Column | Length | Comment |
|---|---|---|
| email_address_soft_bounced_flag | 203 | TRUE if the shopper email address has been flagged as soft-bounced (temporary delivery failure) in the FortKnox email attributes system, corroborated by marketing bounce system and email platform events. |
| email_address_hard_bounced_flag | 197 | TRUE if the shopper email address has experienced a hard bounce (permanent delivery failure), as recorded in the FortKnox email attributes system and corroborated by marketing bounce system events. |
| etl_build_mst_ts | 195 | Timestamp (Mountain Standard Time) recording when this row was last built by the ETL pipeline. Used for data freshness auditing and SLA monitoring per the marketing_mart.customer_suppression SLO. |
| private_label_13_suppression_flag | 194 | Private Label suppression: the shopper email is tied to a Reseller who the shopper purchased from in the last 12 months. Suppresses direct GoDaddy marketing to protect the reseller relationship. |

**The agent's final response to the user was:**
All done. Here's a summary of what was produced:

## DDL enrichment complete — `marketing-mart.customer_suppression`

**11 columns annotated**, all comments validated ≤255 characters.

### Key decisions

| Column | Action | Notes |
|---|---|---|
| `shopper_id` | `@PrimaryKey` added | Per Confluence design doc — this is the declared PK |
| `customer_id` | `@ForeignKey(customer360.dim_customer_vw)` added | Alternative key linking to ShopperUniverse upstream |
| `private_label_13_suppression_flag` | Existing comment enhanced | Original wording preserved, business rationale added (194 chars) |
| `restricted_country_flag` | New comment | Explicitly notes consolidation of two legacy flags (TrrstCtryFlg + RstkCtryFlg) |
| `bad_email_address_format_flag` | New comment | Notes the inversion from `IsValidEmailAddress` (TRUE=bad, not valid) |
| `etl_build_mst_ts` | New comment | Timezone spelled out as "Mountain Standard Time" per audit column standard |

**Longest comment:** `email_address_soft_bounced_flag` at **203 chars** (well within 255-char hard limit).

**Certified Data Dictionary:** Alation folder 6 was unavailable during research (no credentials). No GoDaddy business metric abbreviations (GCR, MRR, NRU) appear in this table — the only abbreviations are timezone (MST) and industry-standard (ETL), resolved from Confluence documentation.