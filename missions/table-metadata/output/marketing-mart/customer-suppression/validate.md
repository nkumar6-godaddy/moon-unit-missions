**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent. Your job is to ensure the final metadata doc is:
1) accurate (no false claims) and 2) complete in structure (all 20 sections present).

## Step 1: Read all artifacts
Read:
- `INPUT.md`
- `gather.md`
- `analyze.md`
- `RESOLVED_TARGET.json`
- `TABLE_METADATA.md`

## Step 2: Accuracy validation
For each non-trivial claim in TABLE_METADATA.md (grain, keys, filters, metrics, SLA, lineage):
- Identify the exact evidence source (PySpark line, DAG setting, lake table.yaml, etc.)
- If evidence is missing or contradictory, rewrite the metadata doc to remove or soften the claim.
- If a claim cannot be validated, replace it with a REQUIRES_MANUAL_INPUT marker.

**DO NOT modify A1's Redshift Serverless Dev fields.** The A1 section intentionally shows
the Redshift Dev Serverless entry (Database = "Redshift - Serverless - Dev", Alation URL
pointing to the dev.* table) as the primary access identity. This is BY DESIGN — do not
change it to "AWS Data Catalog" or any other value.

## Step 2b: C1 Source Table validation (CRITICAL)
Scan the C1 "Source Table(s)" column in TABLE_METADATA.md. For EACH entry:
- If it references a local/intermediate/staging table (look for patterns like `*_stg`,
  `*_conformed.*`, `*_driver`, `analytic_local.*`, or any table NOT in the lake registry),
  this is a FAILURE. Replace it with:
  - The actual lake table if analyze.md resolved it
  - `UNRESOLVED - requires manual input` if analyze.md could not resolve it
- Only lake tables (those in `repos/lake/`) or external systems are acceptable as sources.

## Step 3: Completeness validation
Ensure all 20 sections exist with the correct headings. If missing, add them.
If a section is too sparse and cannot be completed accurately, add the manual-input marker.

## Step 4: Append a report to validate.md
Append:
- Target table
- PASS/FAIL for accuracy and completeness
- List of issues found + how they were fixed
- Sections requiring manual input (final list)

**The agent summarized its work in this way:**

---

## validate stage — marketing_mart.customer_suppression

**Validated:** 2026-06-29
**Validator:** Strict Validation Agent
**Target table:** `marketing_mart.customer_suppression`

---

### Overall Result

| Check | Result |
|---|---|
| **Accuracy** | **PASS** (4 issues found and fixed) |
| **Completeness (all 20 sections)** | **PASS** (21 sections present — all 20 required + 1 bonus) |
| **C1 Source Table check (Step 2b)** | **PASS** (no local/intermediate/staging tables found) |

---

### Artifacts Read

| Artifact | Status |
|---|---|
| `INPUT.md` | Read ✓ |
| `gather.md` | Read ✓ |
| `analyze.md` | Read ✓ |
| `RESOLVED_TARGET.json` | Read ✓ |
| `TABLE_METADATA.md` | Read ✓ |
| `repos/lake/.../marketing-mart/customer-suppression/table.ddl` | Read ✓ |
| `repos/lake/.../marketing-mart/customer-suppression/table.yaml` | Read ✓ |
| `repos/dps-customermarketing/.../customer_suppression.py` (PySpark) | Read ✓ |

---

### Step 2: Accuracy Validation — Issues Found and Fixed

#### Issue 1 — A1 Grain: "active customers" overclaim
- **Location:** A1 Table Overview → Grain row
- **Claim in original:** `One row per customer_id — all **active** customers at time of daily snapshot`
- **Code evidence:** PySpark `source_df` uses `FROM marketing_mart.customer cust` with no WHERE clause filtering on "active" status. The code does not filter for active customers — it includes all customers present in the upstream base table.
- **Evidence source:** `customer_suppression.py` lines 640–687 (source_df query); `analyze.md` Step 5/A2: "Universe: All customers present in marketing_mart.customer at run time"
- **Fix applied:** Changed to `One row per customer_id — all customers present in marketing_mart.customer at time of daily snapshot`

#### Issue 2 — A2: "seven suppression dimensions" but 8 rows listed
- **Location:** A2 What This Table Is About — introductory sentence
- **Claim in original:** `The table covers **seven** suppression dimensions:`
- **Actual count:** The table immediately below lists 8 rows (6 Active + 2 Not populated). The PySpark code produces 8 boolean flag columns.
- **Evidence source:** `customer_suppression.py` lines 658–668 (source_df SELECT — 8 flag columns)
- **Fix applied:** Changed to `The table covers **eight** suppression dimensions (six active, two reserved for future use):`

#### Issue 3 — C1: `competitor_email_flag` incorrectly marked NOT NULL
- **Location:** C1 Complete Column Reference — `competitor_email_flag` row, Nullable column
- **Claim in original:** `NOT NULL`
- **Code evidence:** The competitor flag CTE filters `WHERE email_domain IS NOT NULL` (line 601), excluding customers with no email domain. The final SELECT joins via `LEFT JOIN competitor_email_flag cef ON cust.customer_id = cef.customer_id` (line 673) with no COALESCE wrapper on `cef.competitor_email_flag`. A customer in `marketing_mart.customer` with NULL `email_domain` will receive NULL for this column — not FALSE.
- **Evidence source:** `customer_suppression.py` lines 593–627 (competitor CTE), line 673 (LEFT JOIN), line 651 (no COALESCE on cef.competitor_email_flag); lake `table.ddl` has no NOT NULL constraint on any column.
- **Fix applied:**
  - C1 Nullable changed to `NULLABLE`
  - C1 Description updated to note NULL is possible for customers with no email_domain and advises `COALESCE(competitor_email_flag, FALSE)`
  - C3 Limitations section: added bullet noting competitor_email_flag can be NULL
  - C4 Pitfalls: added item 2a for competitor_email_flag
  - C6 Metrics: wrapped competitor_email_flag with COALESCE in Total suppressed and Audience reach formulas
  - C8 Example queries: applied COALESCE to competitor_email_flag in Patterns 1 and 2
  - E2 Best Practices: updated to include competitor_email_flag alongside private_label_13_suppression_flag in nullable handling guidance

#### Issue 4 — C2: "active customer" overclaim (same root cause as Issue 1)
- **Location:** C2 Primary Key & Performance → Table size row
- **Claim in original:** `(one row per **active** customer)`
- **Fix applied:** Changed to `(one row per customer in that table)` with additional clarification that no filter reduces the customer universe.

---

### Step 2b: C1 Source Table Validation — PASS

All 11 columns in C1 were checked for local/intermediate/staging table references:

| Column | Source Table(s) in C1 | Lake Table? | Result |
|---|---|---|---|
| `customer_id` | `marketing_mart.customer` | ✓ Lake (confirmed: `us-west-2/marketing-mart/customer/`) | PASS |
| `shopper_id` | `marketing_mart.customer` | ✓ Lake | PASS |
| `internal_account_flag` | `customer360.dim_customer_vw` | ✓ Lake (confirmed: `dlms-api/us-west-2/customer360/dim-customer-vw/`) | PASS |
| `private_label_13_suppression_flag` | `cust_customertracking.shopper_crossover_cln` | ✓ Lake (confirmed: `us-west-2/cust-customertracking/shopper-crossover-cln/`) | PASS |
| `restricted_country_flag` | `marketing_mart.customer`, `ecomm_cln.gdshop_blocked_country_region_cln`, `ecomm_cln.gdshop_blocked_country_cln` | ✓ All confirmed Lake tables | PASS |
| `excluded_email_flag` | `*(none — hard-coded NULL)*` | N/A | PASS |
| `competitor_email_flag` | `marketing_mart.customer` | ✓ Lake | PASS |
| `bad_email_address_format_flag` | `*(none — hard-coded NULL)*` | N/A | PASS |
| `email_address_hard_bounced_flag` | 14 lake tables (bouncesystem ×3, signals_platform_cln ×3, sfmc_email_events_cln ×4, emailsystem ×4) | ✓ All confirmed Lake tables | PASS |
| `email_address_soft_bounced_flag` | Same 14 lake tables | ✓ All confirmed Lake tables | PASS |
| `etl_build_mst_ts` | `*(pipeline runtime — computed)*` | N/A | PASS |

No local (`*_local.*`), intermediate (`*_stg`, `*_conformed.*`, `*_driver`), or analytic_local tables found in C1. All sources are lake tables or explicitly noted as computed/NULL.

---

### Step 3: Completeness Validation

The document contains **21 numbered sections** — exceeds the 20 required:

| Pillar | Sections Present | Count |
|---|---|---|
| A — Identity | A1, A2, A3 | 3 |
| B — Value & Use Cases | B1, B2, B3 | 3 |
| C — Schema, Rules & Guidance | C1, C2, C3, C4, C5, C6, C7, C8 | 8 |
| D — Pipeline & Provenance | D1, D2, D3, D4 | 4 |
| E — Quality, Standards & Ecosystem | E1, E2, E3 | 3 |
| **Total** | | **21** |

All core sections (A1–E3) are present and substantive. No REQUIRES_MANUAL_INPUT markers were needed — all claims could be verified from code and artifact evidence.

---

### A1 — Redshift Serverless Dev Fields (Step 2 Special Rule)
- **Database:** `Redshift - Serverless - Dev` — **preserved as-is (BY DESIGN)**
- **Alation URL:** `https://godaddy.alationcloud.com/table/6987832/` (dev.* entry, Alation key `132.dev.marketing_mart.customer_suppression`) — **preserved as-is**
- No modifications were made to A1's Redshift Serverless Dev fields.

---

### Sections Requiring Manual Input (Final List)

**None.** All 21 sections could be fully populated from the PySpark source code, DAG, lake registry artifacts (table.ddl + table.yaml), policies YAML, data quality JSON, Confluence pages, and Alation entries. No REQUIRES_MANUAL_INPUT markers are present in the final document.

---

### Additional Observation (Not a Fix)
Gather.md Conflict #6 stated that `marketing_mart.customer` was "missing from lake lineage YAML; needs update." Upon direct inspection of `repos/lake/catalog/config/prod/us-west-2/marketing-mart/customer-suppression/table.yaml`, `marketing_mart.customer` IS present at the end of the `upstream_table_dependencies` list (line 54 of table.yaml). The conflict was already resolved in the lake registry. The TABLE_METADATA.md correctly lists all 19 upstream tables in D1, consistent with the current table.yaml.


**The agent's final response to the user was:**
Validation complete. Here is a summary of what was done:

---

## Validation Summary — `marketing_mart.customer_suppression`

### Overall Result: PASS

| Check | Result |
|---|---|
| Accuracy | **PASS** — 4 issues found and fixed |
| Completeness (20 sections) | **PASS** — 21 sections present |
| C1 Source Table check | **PASS** — no local/intermediate tables found |

---

### Issues Found and Fixed

**Issue 1 — A1/C2: "active customers" overclaim**
The PySpark `source_df` uses `FROM marketing_mart.customer` with no WHERE clause filtering on "active" status. Changed "all active customers" → "all customers present in `marketing_mart.customer` at time of daily snapshot" in A1 and C2.

**Issue 2 — A2: "seven" vs 8 suppression dimensions**
The introductory sentence said "seven suppression dimensions" but the table below lists 8 rows (6 active + 2 reserved NULL columns). Corrected to "eight suppression dimensions (six active, two reserved for future use)."

**Issue 3 — C1: `competitor_email_flag` incorrectly marked NOT NULL**
The competitor CTE filters `WHERE email_domain IS NOT NULL`, excluding customers with no email domain from the result. The final SELECT joins via `LEFT JOIN ... competitor_email_flag` with **no COALESCE wrapper**. Customers with NULL email_domain receive NULL — not FALSE. Fixed nullability to NULLABLE in C1, and propagated the fix to: C3 Limitations, C4 Pitfalls (new item 2a), C6 Metrics formulas, C8 Example query patterns, and E2 Best Practices.

**Issue 4 — C2: "active customer" overclaim (same root cause as Issue 1)**
Changed "one row per active customer" → "one row per customer in that table."

### Sections Requiring Manual Input: **None**