**Stage name:** generate
**The coding agent was given these instructions:** You are an author producing a **Business Context / Metadata** document for a Data Lake table.
Your output must be 100% accurate. Never fabricate. Avoid too much technical implementation detail.

## Step 1: Read INPUT.md, gather.md, analyze.md
Read:
- `INPUT.md` — includes USER NOTES (HIGHEST PRIORITY) if provided
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`

**USER NOTES (if present in INPUT.md):** Treat as verified expert input from the
table owner. Incorporate into A2, B1, C4, C7, and other relevant sections. USER NOTES
override Confluence, Alation descriptions, and DDL — but NEVER override PySpark/DAG code.

## Step 2: Create the final metadata document
Create a new markdown file in the workspace root named:
`TABLE_METADATA.md`

This file must follow the structure defined in `docs/Metadata-Structure.pdf`:
5 pillars, 20 sections, in order:
- A1, A2, A3
- B1, B2, B3
- C1..C8
- D1..D4
- E1..E3

Use this exact heading skeleton (keep headings even if content is missing):

- `# Business Context: <schema>.<table>`
- `## Pillar A: WHAT Is It? — Identity & Purpose`
  - `### A1. Table Overview`
  - `### A2. What This Table Is About`
  - `### A3. Organizational Context & Ownership`
- `## Pillar B: WHY Does It Matter? — Value & Use Cases`
  - `### B1. Key Business Value`
  - `### B2. Primary Use Cases`
  - `### B3. Advanced Analytics Use Cases`
- `## Pillar C: HOW Do I Use It Correctly? — Schema, Rules & Guidance`
  - `### C1. Complete Column Reference with Data Insights`
  - `### C2. Primary Key & Performance`
  - `### C3. Key Features, Capabilities & Limitations`
  - `### C4. Important Notes & Pitfalls`
  - `### C5. Always-On Column Filters`
  - `### C6. Common Business Metrics`
  - `### C7. Glossary & Term Definitions`
  - `### C8. Example Queries & Patterns`
- `## Pillar D: HOW Is It Built? — Pipeline & Provenance`
  - `### D1. Data Source Reference`
  - `### D2. Data Pipeline & Infrastructure`
  - `### D3. SLA & Refresh Schedule`
  - `### D4. Table Creation & ETL Implementation`
- `## Pillar E: HOW Is It Governed? — Quality, Standards & Ecosystem`
  - `### E1. Data Quality Checks`
  - `### E2. Best Practices & Tips`
  - `### E3. Related Articles & Documentation`
- `## REFERENCES` (deduplicated list at end of document)

Content guidance (follow the PDF):
- A1 should be a compact key-value table. The FIRST rows must be the access/identity
  information in this exact order (if available from gather.md Alation section):
    1. Table Name (the table name as seen in Redshift)
    2. Database — always "Redshift - Serverless - Dev" (use the dev.* entry, never bi.*)
    3. Schema (the Redshift schema, e.g. `customer360`)
    4. Alation URL (link to the dev Redshift Serverless table entry in Alation)
    5. Table ID (Alation table ID for the Redshift entry)
    6. Type (e.g., View, Table)
    7. Description (brief table description from Alation or Confluence)
    8. Lake Table Name
    9. Lake Database — "GoDaddy Central Data Lake (Prod)"
    10. Lake Schema
    11. Lake Alation URL
    12. Lake Alation ID
  Then continue with the remaining technical metadata (Grain, Partition Key,
  Storage Format, Data Tier, SLA, Refresh Cadence, etc.).
  If Alation was skipped or URLs are unavailable, omit those rows but keep the rest.
  A1 MUST include grain.
- A2 should include a narrative paragraph, a "Key Features:" bullet list, and a
  purpose statement explaining business value (similar to sample format).
- B2 must contain TWO parts:
  1. **Questions this table answers** — bullet list of natural-language questions (optional
     if Alation queries are available; sample format leads with query cards).
  2. **Alation Queries** (if gather.md has ## Alation Queries with results) — for EACH
     query, use this format (use empty string if a field is unknown):

     #### <Title>

     | Field | Value |
     |---|---|
     | Query ID | <id> |
     | Title | <title> |
     | Author | <author or "Not specified"> |
     | Description | <description> |
     | Schedule | <schedule or "Manual execution"> |
     | Last Saved | <date> |
     | Last Run | <date or "Not recorded"> |
     | Datasource | <datasource> |
     | Alation Query URL | <url or "Query #<id>"> |

     Follow the metadata table with a 1-2 sentence descriptive paragraph explaining
     what the query does and how it uses this table. Do NOT include the full SQL body
     in B2 (keep B2 readable; reference the Alation URL instead).

     If Alation was skipped or no queries were found, use the "Questions this table
     answers" bullet list instead.
- C1 should be a single readable schema table with EXACTLY these columns:
  | # | Name | Data Type | Description | Column Lineage | Category | Sample Values | Key Statistics |
  Column definitions:
  - **#**: Row number (1-based)
  - **Name**: Column name (no backticks in cell — plain name)
  - **Data Type**: SQL data type (uppercase, e.g., STRING, DATE, INTEGER)
  - **Description**: Business-facing description; include PK/UK/@ForeignKey annotations if in DDL
  - **Column Lineage**: Descriptive transformation text referencing the first lake
    table.column (e.g., "Direct mapping from dim_country_vw.country_name joined on
    acquisition country code" or "Calculated as datediff(partition_eval_mst_date,
    customer_acquisition_mst_date) / 365"). Use `UNRESOLVED - requires manual input`
    if analyze.md marked it unresolved.
  - **Category**: Classify each column as one of: `Identifier`, `Categorical`, `Date`,
    `Numeric`, `Boolean`, `Text`, `Amount`, `Timestamp`, `Array`
  - **Sample Values**: JSON array of 3-5 representative values from Alation profiling
    (gather.md). Leave empty if not available — do NOT fabricate.
  - **Key Statistics**: Brief stats from Alation profiling: distinct count, value range,
    average, null count, common values. Leave empty if not available — do NOT fabricate.
  Do NOT include extra columns (e.g., "Source Table(s)", "Transformation / Notes").
  **CRITICAL C1 RULE**: Column Lineage must describe derivation from the FIRST upstream
  lake table — NOT that lake table's own sources. NEVER list intermediate/local/staging
  tables (e.g., `*_stg`, `*_conformed.*`, `*_driver`) as sources.
- D1 should use multi-depth lineage tables when available from analyze.md or gather.md:
  - **Upstream Sources**
    - Depth 1 Upstream Tables (Total: N)
    - Depth 2 Upstream Tables (Total: N) — only if resolvable
  - **Downstream Sources**
    - Depth 1 Downstream Tables (Total: N)
  Each table: | Table Name | Database | Schema | Type | Platform |
  Platform values: `lake`, `redshift`, `s3`, or `—` for unknown.
  If multi-depth lineage is unavailable, fall back to a flat list of direct upstream
  lake tables with their roles.
- C8 should include 2-5 short, annotated query patterns (avoid huge queries; keep focused).
- D2 should identify repo + file paths + orchestration tool + compute platform.
- D4 must use these sub-sections (in order):
  1. **ETL Processes** — narrative paragraph describing the pipeline, followed by
     numbered implementation steps (dependency checks, EMR, transformations, persistence, DQ)
  2. **Data Processing Steps** — bullet list of key transformation logic (status derivation,
     enrichment joins, aggregations, derived columns, special-case handling)
  3. **Error Handling and Logging** — bullet list (Slack alerts, retries, cluster lifecycle, etc.)
  4. **Data Validation** — bullet list (DQ operators, business rule checks, partition validation)
  Keep each sub-section concise; no long code walk-through.
- **REFERENCES** section at the end of the document: deduplicated list of:
  - Main Table and Lake Table identifiers (schema.table)
  - All Confluence article titles referenced in the doc
  - All URLs (Alation table/article links, Confluence, GitHub repo/file links, Query links)

### Requirements
- If a section cannot be completed accurately, include:
  `<!-- REQUIRES_MANUAL_INPUT: <BA|DE|DG|DP> -->`
  and briefly state what information is missing.
- Do not include long code blocks. Reference file paths + brief snippets only when needed.
- Do not assert owners, SLAs, or definitions unless supported by code or authoritative sources.
- Keep “pipeline identity” concise (repo, paths, DAG name, schedule), not a walkthrough.

## Step 3: Append a stage summary to generate.md
Append to `generate.md`:
- Target table resolved (schema.table)
- Whether any sections require manual input (count + list)
- Key sources used (PySpark, DAG, lake table.ddl/table.yaml, Confluence, Alation)
- Any unresolved lineage items

**The agent summarized its work in this way:**

---

## generate stage — summary

**Completed:** 2026-06-17
**Target table resolved:** `customer360.customer_metric_daily_agg_vw` (confidence: HIGH)
**Output file:** `TABLE_METADATA.md`

---

### Sections requiring manual input: 1

| Section | Tag | Missing information |
|---|---|---|
| D3. SLA & Refresh Schedule | `REQUIRES_MANUAL_INPUT: DE` | DAG documentation_markdown states `SLA: N/A` but lake registry specifies 08:00 AM MST / TIER_4 (120 min max). DE owner must reconcile and update DAG documentation to match lake registry SLA. |

---

### Key sources used

| Source | File / Reference |
|---|---|
| PySpark (authoritative) | `customer360/customer-metrics/src/pyspark/customer_metric_daily_agg.py` (main branch) |
| DAG (authoritative) | `customer360/customer-metrics/src/dag/customer_metric_daily_agg_dag.py` |
| Hive DDL | `customer360/customer-metrics/src/ddls/customer_metric_daily_agg.ddl` |
| Redshift DDL | `customer360/customer-metrics/src/ddls/create_customer_metric_daily_agg.sql` |
| Policies file | `customer360/customer-metrics/src/policies/customer_metric_daily_agg_dag.yaml` |
| DQ constraints | `customer360/customer-metrics/src/data_quality/constraints/customer_metric_daily_agg.json` |
| Lake table.yaml | `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.yaml` |
| Lake table.ddl | `catalog/config/prod/dlms-api/us-west-2/customer360/customer-metric-daily-agg-vw/table.ddl` |
| Confluence | Pages 3779199819 (Customer360 hub), 4387965088 (Business Context Structure), 4042131239 (Customer Metrics) |
| Alation | Redshift Dev table ID 7038918; Lake table ID 7038346; 6 saved queries (IDs 136952, 138184, 138586, 138254, 128804, 127875) |

---

### Unresolved lineage items

| Item | Status | Notes |
|---|---|---|
| `customer_core_conformed.customer_life_cycle` → lake form | **Resolved** | Resolves to `customer360.customer_life_cycle_vw` via S3 path identity + producer script confirmation |
| `customer360.customer_life_cycle_vw` | **Resolved** | Direct lake table; lake registry confirmed at `dlms-api/us-west-2/customer360/customer-life-cycle-vw/` |
| Depth 2 upstream lineage (20 tables) | **Resolved** | From `customer_life_cycle_vw` lake registry `table.yaml` lineage block |
| Depth 1 downstream tables (4 tables) | **Partially resolved** | Observed in Alation query evidence; not confirmed as lake-registered tables |
| Column Sample Values / Key Statistics | **Unresolved** | Alation column profiling API returned permission error during gather stage; all 32 C1 rows have empty Sample Values and Key Statistics |
| Lake DDL `data_source_enum` | **Known gap** | Column present in Hive DDL and PySpark output but missing from lake registry `table.ddl`; flagged in C4 |
| Lake DDL `@PrimaryKey` annotations | **Known gap** | Lake DDL missing annotations for `point_of_purchase_name` and `customer_acquisition_bill_fraud_flag`; flagged in C2 and C4 |

**The agent's final response to the user was:**
The `TABLE_METADATA.md` has been created and `generate.md` has been updated with the stage summary. Here is what was produced:

---

**`TABLE_METADATA.md`** — complete 5-pillar, 20-section metadata document for `customer360.customer_metric_daily_agg_vw`, covering:

- **A1:** Full access/identity table (Redshift Dev + Lake Alation entries, grain, partition, SLA, tier, owner, S3 location)
- **A2:** Narrative description incorporating USER NOTES (daily roll-up / 18 dims / replaces legacy DAC), Key Features list, and purpose statement
- **A3:** Ownership — EDT team, on-call groups, consumers, domain, stakeholder contacts
- **B1:** Business value framed around USER NOTES and corroborated by code evidence
- **B2:** 7 natural-language questions + all 6 Alation queries in card format with descriptive paragraphs
- **B3:** Advanced analytics patterns (QoQ, DAC migration, reconciliation, TTM revenue)
- **C1:** 32-column schema table with full column lineage tracing to `customer360.customer_life_cycle_vw` (first upstream lake table); PK annotations for all 19 PK columns; empty Sample Values/Key Statistics (not fabricated)
- **C2–C8:** Primary key, features/limitations, pitfalls (with USER NOTES), always-on filters, 11 metric definitions, glossary, and 4 example queries
- **D1:** Multi-depth lineage (1 depth-1 upstream, 20 depth-2 upstream, 4 depth-1 downstream)
- **D2–D4:** Pipeline identity, SLA, and ETL implementation with 4 sub-sections
- **E1–E3:** DQ checks, best practices, documentation links
- **REFERENCES:** Deduplicated list of all tables, Confluence articles, Alation URLs, and GitHub links

**Sections requiring manual input: 1** — D3 SLA conflict (DAG doc says `SLA: N/A` vs. lake registry 08:00 AM MST TIER_4); tagged `<!-- REQUIRES_MANUAL_INPUT: DE -->`.