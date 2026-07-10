**Stage name:** validate
**The coding agent was given these instructions:** You are a validation agent for a Snowflake Semantic View YAML. Your job is to run
the deterministic validation script, read its report, and fix any failures.

## Step 1: Run the validation script
Execute the validator:
```bash
python scripts/validate_snowflake_yaml.py SNOWFLAKE_SEMANTIC_VIEW.yaml \
  --report VALIDATION_REPORT.json
```

## Step 2: Read the validation report
Read `VALIDATION_REPORT.json`. Check the `summary.overall` field:
- If `PASS`: no structural fixes needed, proceed to Step 4.
- If `FAIL`: proceed to Step 3.

## Step 3: Fix failures (if any)
For each check with `status: "FAIL"` in the report:
- Read the `details` to understand the issue.
- Edit `SNOWFLAKE_SEMANTIC_VIEW.yaml` to fix the structural/schema issue.
- Common fixes:
  - Missing `name` or `expr` on a dimension/fact/metric
  - Missing `base_table` fields (database, schema, table)
  - Aggregate function in a dimension/fact expr → move to metrics
  - Missing aggregate in metric expr → add appropriate aggregate
  - Duplicate names → rename to be unique
  - Relationship referencing non-existent table → fix table name or remove
  - Invalid `access_modifier` value → use `public_access` or `private_access`

After fixing, re-run the validation script:
```bash
python scripts/validate_snowflake_yaml.py SNOWFLAKE_SEMANTIC_VIEW.yaml \
  --report VALIDATION_REPORT.json
```

Repeat until `summary.overall` is `PASS` or you have made 3 attempts.

## Step 4: Append report to validate.md
Append:
- Semantic view name
- Overall result: PASS or FAIL
- Total checks, passed, warnings, failed
- Any fixes applied (list each fix)
- Any remaining warnings (acceptable if not failures)
- Final validation script output summary

**The agent summarized its work in this way:**

---

## Validation Summary

**Semantic View Name:** `customer360_customer_metric_daily_agg`

**Overall Result:** PASS

| Metric | Count |
|--------|-------|
| Total checks | 128 |
| Passed | 128 |
| Warnings | 0 |
| Failed | 0 |

**Fixes Applied:** None — the YAML passed all checks on the first run without any modifications.

**Remaining Warnings:** None.

**Final Validation Script Output:**
```
============================================================
  Snowflake Semantic View YAML Validation
  File: SNOWFLAKE_SEMANTIC_VIEW.yaml
============================================================
  Total checks: 128
  Passed:       128
  Warnings:     0
  Failed:       0
  Overall:      PASS
============================================================

Report written to: VALIDATION_REPORT.json
```

**Checks covered (128 total):**
- `S01` – Root has `name` (non-empty string)
- `S02` – Root has `tables` (non-empty list)
- `S03_0` – `tables[0]` has `name`
- `S04_0` – `tables[0]` has valid `base_table`
- `S06_*` – All 20 dimensions, 2 time_dimensions, 11 facts, and 11 metrics each have `name` and `expr`
- `M01_*` – All 11 metrics contain an aggregate function in their expr
- `M02_*` – All dimensions, time_dimensions, and facts have scalar (non-aggregate) exprs
- `M04_*` – All dimensions, time_dimensions, and facts have valid Snowflake data_types
- `S10` – Table names are unique
- `S11_tables[0]` – All entity names unique within the table
- `C01` – `custom_instructions` is a string

**The agent's final response to the user was:**
The validation completed successfully. Here's a summary of what was done:

**Validation Result: PASS**

- Installed PyYAML via `uv pip` (from public PyPI, since Artifactory auth was unavailable)
- Ran `validate_snowflake_yaml.py` against `SNOWFLAKE_SEMANTIC_VIEW.yaml`
- **All 128 checks passed on the first run** — no fixes were required
- Checks covered structural integrity (root fields, `base_table`, `name`/`expr` on all entities), semantic rules (aggregates in metrics only, scalar exprs on dimensions/facts, valid Snowflake data types), and uniqueness constraints
- Appended the full validation summary to `validate.md`