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

## Stage: generate — TABLE_METADATA.md

**Generated:** 2026-06-10
**Target table resolved:** `customer360.customer_life_cycle_vw`
**Internal staging table:** `customer_core_conformed.customer_life_cycle`
**Confidence:** HIGH

### Sections requiring manual input
Count: **0** — all 20 sections (A1–E3) were completed from verified sources.

No `<!-- REQUIRES_MANUAL_INPUT -->` tags were inserted. All facts are backed by:
- PySpark code (`customer_life_cycle.py`)
- DAG code (`customer_life_cycle_dag.py`)
- Lake registry (`table.yaml`, `table.ddl`)
- Confluence pages (Customer Lifecycle ID 3970861345, Customer360 ID 3779199819, Customer Metrics ID 4042131239)
- Alation (Lake table ID 7038345, Dev Serverless ID 7038917, 10 saved queries)
- DQ constraints (`customer_life_cycle.json`)
- Policy YAML (`customer_life_cycle_dag.yaml`)

### Key sources used

| Source | Details |
|---|---|
| PySpark | customer360/customer-metrics/src/pyspark/customer_life_cycle.py (authoritative for all logic) |
| DAG | customer360/customer-metrics/src/dag/customer_life_cycle_dag.py (schedule, task flow, SLA, alerts) |
| Lake table.ddl | repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl |
| Lake table.yaml | repos/lake/catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.yaml (SLA, data tier, consumers) |
| Confluence | Customer Lifecycle (3970861345) — churn/reactivation/merge/acquisition date business rules |
| Alation Lake | Table ID 7038345 — extended description and key features narrative |
| Alation Dev RS | Table ID 7038917 — Redshift dev entry metadata |
| Alation Queries | 10 most recently saved queries (IDs: 123877, 139259, 139061, 138820, 138821, 138886, 135046, 123350, 138288, 138291) |
| DQ constraints | data_quality/constraints/customer_life_cycle.json — composite PK evidence |
| Policy YAML | policies/customer_life_cycle_dag.yaml — SLA max duration, severity tier |

### Unresolved lineage items

- **External S3 source** (`s3://gd-ckpetlbatch-prod-analytic/analytic/ads_bill_line_ext/`): Not registered as a lake table; hardcoded to prod bucket in PySpark. Documented in D1 as external S3 platform with pre-2022-08 scope. No further resolution possible without lake registration.
- **Depth 2 upstream tables**: Not derived — would require reading each Depth 1 lake table's own `table.yaml` lineage metadata. Out of scope per lineage documentation rules.
- **Column profiling (Sample Values / Key Statistics in C1)**: No Alation profiling data was available from the gather stage (Alation v2 table API did not return per-column statistics). All Sample Values and Key Statistics cells in C1 are intentionally empty.

### Discrepancies surfaced and handled

1. Stale Hive DDL PK comment → overridden by DQ constraint in C2 and C4
2. Alation description: PK = `customer_id` alone → corrected in C2 and C4
3. Alation description: `customer_state_enum` includes 'fraud' → corrected in C7 and C4
4. Confluence references `analytic_feature.shopper_tenure` as tenure source → corrected in C4
5. DAG SLA field = "N/A" → lake registry SLA used in A1 and D3
6. Lake registry lists 7 extra upstream tables → validated as reached through intermediates; included in D1 depth-1 lineage

**The agent's final response to the user was:**
`TABLE_METADATA.md` has been created at `/tmp/moonunit-workspace/TABLE_METADATA.md`. Here is a summary of what was produced:

---

**Target table:** `customer360.customer_life_cycle_vw` (lake) / `customer_core_conformed.customer_life_cycle` (internal Hive/Parquet)

**All 20 sections completed — 0 require manual input.**

**Document highlights:**

- **A1:** Full identity table with Redshift dev entry (ID 7038917), lake entry (ID 7038345), grain, partition key, storage format, data tier, SLA, DAG ID, and internal S3 path.
- **A2:** Narrative covering lifecycle state tracking, subscription portfolio, TTM GCR, geography/channel dimensions, fraud signals, and role as Finance driver table.
- **B2:** 10 Alation queries documented in structured format (IDs: 123877, 139259, 139061, 138820, 138821, 138886, 135046, 123350, 138288, 138291), each with a descriptive paragraph.
- **C1:** All 35 columns with data types, business descriptions, column lineage referencing the first lake table boundary (no intermediate/staging tables referenced), and categories. Sample values and key statistics left empty — Alation profiling data was not available.
- **C4:** Key pitfalls called out: incorrect Alation PK, incorrect `customer_state_enum` values in Alation, NULL metrics for churned rows, UK→GB normalization, outdated Confluence tenure source reference.
- **D1:** 21 Depth 1 upstream lake tables (including 1 external S3 legacy source), 2 confirmed downstream Redshift tables, plus ad-hoc Alation consumers. Depth 2 not derivable.
- **D4:** Four sub-sections — ETL Processes (11 numbered steps), Data Processing Steps (10 bullet transformations), Error Handling, and Data Validation.