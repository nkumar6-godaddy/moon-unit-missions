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

## Validation Stage Results

**Semantic View Name:** `customer360_customer_life_cycle_vw`

**Overall Result:** PASS

### Summary

| Metric        | Count |
|---------------|-------|
| Total Checks  | 131   |
| Passed        | 131   |
| Warnings      | 0     |
| Failed        | 0     |

### Fixes Applied

None. The YAML passed all validation checks on the first run with no structural or schema issues detected.

### Remaining Warnings

None.

### Final Validation Script Output

```
============================================================
  Snowflake Semantic View YAML Validation
  File: SNOWFLAKE_SEMANTIC_VIEW.yaml
============================================================
  Total checks: 131
  Passed:       131
  Warnings:     0
  Failed:       0
  Overall:      PASS
============================================================
```

**Validation report written to:** `VALIDATION_REPORT.json`

**The agent's final response to the user was:**
Validation is complete:

- **Semantic View:** `customer360_customer_life_cycle_vw`
- **Result:** PASS — 131/131 checks passed, 0 warnings, 0 failures
- **Fixes applied:** None required — the YAML was valid on the first run
- Results appended to `validate.md`