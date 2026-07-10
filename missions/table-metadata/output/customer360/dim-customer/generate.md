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

## Stage: generate — TABLE_METADATA.md produced

**Date:** 2026-06-09

### Target table resolved
`customer360.dim_customer_vw` (confidence: high)

### Sections requiring manual input: 3

| Section | Tag | Missing Information |
|---|---|---|
| C1 (column reference) | `DE` | `signals_platform_cln.profile_audit_lake_cln_v2` is not registered in the lake catalog; 17 of 29 column descriptions inferred from ETL aliases, not verified against a registered DDL |
| D1 (data source reference) | `DE` | Same — owning team must register `signals_platform_cln.profile_audit_lake_cln_v2` in the lake catalog and confirm schema/SLA |
| E1 (data quality checks) | `DG` | Full DQ constraint inventory beyond primary key definitions not captured; `src/data_quality/constraints/` should be reviewed for the complete rule set |

### Key sources used

| Source | Used For |
|---|---|
| `dim_customer.py` (PySpark) | SCD merge/insert logic, column transformations, row_hash definition |
| `dim_customer_iceberg_common.py` | Iceberg DDL, S3 path, physical table name |
| `dim_customer_dag.py` (DAG) | Schedule, SLA, upstream sensors, pipeline flow, lake API registration |
| `dim_customer_daily_delta.py` | Recursive lineage traversal to lake sources for 17+ columns |
| `dim_customer_attributes.py` | Recursive lineage traversal for federation_partner_id / name |
| `src/dag/templates/create_view.sql` | View column list and filter |
| `src/data_quality/constraints/` | Primary key definitions (composite + single-column) |
| `src/policies/dim_customer_dag.yaml` | SLA (maxDurationMins: 90), declared inputs/outputs |
| Lake `table.yaml` + `table.ddl` | Data tier, SLA cron, consumer roles, column annotations |
| Confluence page 3829375759 | Business context, release date (2025-06-16), FortKnox deprecation deadline, historical baseline |
| Alation (table IDs 7027529, 7022291) | Alation URLs, descriptions, runtime limitation note |
| Alation queries (10 saved queries) | B2 use-case queries, SQL for queries 136716 and 138294 (partial) |

### Unresolved lineage items

| Table | Status | Impact |
|---|---|---|
| `signals_platform_cln.profile_audit_lake_cln_v2` | Not in lake catalog (`signals-platform-cln` schema absent); confirmed upstream via DAG S3KeySensor | 17 of 29 view columns (rows 8–27 in C1) have UNRESOLVED source annotation |
| `global_profile_service_cln.profile_snapshot` | Not in lake catalog; bootstrap-only (2025-06-01 special case) | Not part of daily lineage; not documented in C1 |

### Conflicts documented (not asserted in output)

| # | Conflict | Resolution Applied |
|---|---|---|
| 1 | Lake `table.yaml` claims `current_record_flag` as Iceberg partition key; code creates unpartitioned table | Code is authoritative; flagged in C4 |
| 2 | Alation uses `effective_end_mst_dt` (`_dt` suffix); code/DDL uses `effective_end_mst_ts` (`_ts`) | Code is authoritative; Alation error flagged in C4 and E2 |
| 3 | Lake `table.yaml` lineage includes 2 SSO tables not in DAG sensors or PySpark | Not surfaced as direct sources in C1 (they feed via `dim_customer_attributes`) |
| 4 | Redshift view does not project `current_record_flag`; lake DDL does | Noted in C1 and C4 |

**The agent's final response to the user was:**
`TABLE_METADATA.md` has been created and `generate.md` has been updated. Here is a summary of what was produced:

---

## Output: `TABLE_METADATA.md`

**Target:** `customer360.dim_customer_vw` (high confidence)

The document covers all 5 pillars and 20 sections (A1–E3):

**Pillar A — Identity & Purpose**
- A1 includes the full access/identity table (Table Name → Alation URLs → Lake Table → Grain → SLA, etc.)
- A2 describes the Customer Master Dimension purpose, Customer360 v1.0 launch context, and FortKnox replacement role
- A3 documents EDT ownership, on-call group, consumer roles, and release info

**Pillar B — Value & Use Cases**
- B1 articulates 6 key business value points
- B2 includes 9 natural-language questions + all 10 Alation queries in full structured format (SQL included verbatim where captured; 2 queries had partial SQL, 8 had none captured in the gather phase)
- B3 covers 5 advanced analytics use cases (Google migration attribution, OLS/OLA sizing, segmentation, lifecycle analysis)

**Pillar C — Schema, Rules & Guidance**
- C1: 29-column reference table with Source Table(s) (first lake boundary), type, description, and transformation notes
- 17 columns carry `UNRESOLVED` source annotation (`signals_platform_cln.profile_audit_lake_cln_v2` not in lake catalog) → `<!-- REQUIRES_MANUAL_INPUT: DE -->`
- C4 documents 6 critical pitfalls including the Alation column name typo, partition key conflict, and the `deleted_mst_ts = closed_mst_ts` identity

**Pillar D — Pipeline & Provenance**
- D2 identifies repo, file paths, DAG ID, Airflow orchestration, EMR 7.2.0 ARM64 compute
- D4 summarizes the 4-step SCD merge logic without long code walk-throughs

**Pillar E — Governance**
- E1 documents the 2 DQ constraints (composite PK on physical, single-column PK on view) with a `<!-- REQUIRES_MANUAL_INPUT: DG -->` for the full constraint inventory
- E3 links to Confluence pages, Alation entries, source repo, and lake registry

**Sections requiring manual input: 3** (C1/D1 — DE for unresolved source table; E1 — DG for full DQ inventory)