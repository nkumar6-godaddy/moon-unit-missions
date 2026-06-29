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

Content guidance (follow the PDF):
- A1 should be a compact key-value table. The FIRST rows must be the access/identity
  information in this exact order (if available from gather.md Alation section):
    1. Table Name (the table name as seen in Redshift)
    2. Database — always "Redshift - Serverless - Dev" (use the dev.* entry, never bi.*)
    3. Schema (the Redshift schema, e.g. `customer360`)
    4. Alation URL (link to the dev Redshift Serverless table entry in Alation)
    5. Lake Alation URL (link to the Lake table entry in Alation)
  Then continue with the remaining technical metadata (Lake Table, Grain, Partition Key,
  Storage Format, Data Tier, SLA, Refresh Cadence, etc.).
  If Alation was skipped or URLs are unavailable, omit those rows but keep the rest.
  A1 MUST include grain.
- B2 must contain TWO parts:
  1. **Questions this table answers** — bullet list of natural-language questions.
  2. **Alation Queries** (if gather.md has ## Alation Queries with results) — for EACH
     query, use this format (use empty string if a field is unknown):

     #### Query: <Title or "Untitled">

     | Field | Value |
     |---|---|
     | Query ID | <id> |
     | Title | <title> |
     | Author | <author> |
     | Description | <description> |
     | Schedule | <schedule or "Not scheduled"> |
     | Last Saved | <date> |
     | Last Run | <date> |
     | Datasource | <datasource> |
     | Alation Query URL | <url> |

     ```sql
     <SQL verbatim — do not modify>
     ```

     If Alation was skipped or no queries were found, omit the Alation Queries part.
- C1 should be a single readable schema table with a "Source Table(s)" column.
  **CRITICAL C1 RULE**: The "Source Table(s)" column must show the FIRST upstream
  lake table in the lineage chain — NOT that lake table's own sources. For example:
    - If PySpark reads from an intermediate that resolves to lake table X, show X.
    - If PySpark reads directly from lake table X, show X.
    - Do NOT trace into X's own upstream sources and list those instead.
    - External systems (e.g., "S3 direct read") are also acceptable.
    - `UNRESOLVED - requires manual input` if analyze.md marked it unresolved.
  NEVER list intermediate/local/staging tables (e.g., `*_stg`, `*_conformed.*`,
  `*_driver`) as sources. These are implementation details.
- C8 should include 2-5 short, annotated query patterns (avoid huge queries; keep focused).
- D2 should identify repo + file paths + orchestration tool + compute platform.
- D4 should summarize creation logic (no long code walk-through).

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

## generate stage — marketing_mart.customer_suppression

**Generated:** 2026-06-29

### Target table resolved
`marketing_mart.customer_suppression` — HIGH confidence (6 independent evidence sources: PySpark write, DAG SuccessNotificationOperator, lake registry table.yaml/table.ddl, policies YAML, DQ constraints file).

### Sections requiring manual input
**0 sections require manual input.** All 20 sections (A1–E3) were completed from authoritative sources.

### Key sources used
| Source | Used for |
|---|---|
| PySpark: `customer/eds-customer-suppression/src/pyspark/customer_suppression.py` | All 11 column definitions, all business logic, source table list, competitor domain list |
| DAG: `customer/eds-customer-suppression/src/dag/customer_suppression_dag.py` | Schedule, SLA, task flow, dependencies, ownership tags, write target |
| Lake `table.ddl` + `table.yaml` (`us-west-2/marketing-mart/customer-suppression/`) | Storage format, table type, SLA cron, permissions, lake sloIdentifier |
| Policies YAML: `policies/customer_suppression_dag.yaml` | SLA max duration, S3 output location, inputs/outputs list |
| DQ constraints: `data_quality/constraints/customer_suppression.json` | isPrimaryKey(customer_id) check |
| Confluence page 10370826 + child 3114766874 | Business context, legacy migration context |
| Alation (lake ID 6619866, dev ID 6987832) | Alation URLs, table descriptions, access entry rows in A1 |
| Alation queries (10 total, IDs: 127671, 113896, 126796, 127407, 124303, 118630, 118595, 118535, 117784, 101385) | B2 Alation Queries section; full SQL captured for query 127407 only |

### Unresolved lineage items
**None.** All 19 upstream source tables were confirmed as authoritative lake tables. Three tables in `signals_platform_cln` (oeg_email_event_send_cln, oeg_email_event_open_cln, profile_audit_lake_cln_v2) have no DDL file in this lake registry but are confirmed lake tables via the target table's own `table.yaml` upstream lineage and cross-references in other lake table YAMLs.

### Notable decisions
- `excluded_email_flag` and `bad_email_address_format_flag` documented as always NULL per PySpark code (overrides DDL and Confluence claims).
- Bounce flag sources documented as OEG + SFMC per code (overrides Confluence/design doc references to FortKnox, which is not used).
- `private_label_13_suppression_flag` documented as NULLABLE (no COALESCE in final SELECT).
- Alation stale GitHub repo reference (`de-marketing-mart-eds`) noted and corrected in C4.
- Full SQL captured only for Alation query 127407 (DATAGOV_WhatsApp_StandardSuppression); remaining 9 queries have metadata only with links to Alation for full SQL.

**The agent's final response to the user was:**
`TABLE_METADATA.md` has been created and `generate.md` has been updated with the stage summary.

Here's what was produced:

---

## Summary

**Target table:** `marketing_mart.customer_suppression`

**`TABLE_METADATA.md`** written with all 20 sections (A1–E3) across 5 pillars — zero sections require manual input.

**Key content highlights:**

- **A1** — Access/identity rows first (Table Name, Database = "Redshift - Serverless - Dev", Schema, Alation URL, Lake Alation URL), followed by full technical metadata including grain.
- **A2** — Business description of the 7 suppression dimensions with a table clearly noting which 2 are always NULL.
- **C1** — Full 11-column schema reference with source lake tables, nullability, and precise business logic per column. Bounce flags show all 14 contributing source tables.
- **C4** — 8 concrete pitfalls documented (NULL flags, PL13 nullable, same-day re-engagement behavior, stale Alation GitHub link, etc.).
- **B2** — 10 Alation queries documented with metadata tables. Full SQL captured verbatim for query 127407 (DATAGOV_WhatsApp_StandardSuppression); remaining 9 include metadata + Alation URLs.
- **D1** — All 19 upstream lake tables listed with their role in the pipeline.
- **D4** — ETL implementation summarized without long code walk-through.
- **E1** — DQ check (`isPrimaryKey("customer_id")`) and its DAG task placement documented.

**Lineage:** All 19 upstream sources confirmed as authoritative lake tables. No unresolved items.