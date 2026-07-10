**Stage name:** validate
**The coding agent was given these instructions:** You are a strict validation agent. Your ONLY job is to enforce the 255-character
limit on column COMMENT strings in the target table's DDL.

## Instructions

1. Read INPUT.md to get the DDL path (under `repos/lake/...`). That file
   was modified by the previous `enrich` stage; you will edit it in place.

2. For EVERY line containing COMMENT, extract the string between the single
   quotes and count its characters.

3. If ALL comments are ≤ 255 characters, leave the file UNCHANGED.

4. If ANY comment exceeds 255 characters, rewrite ONLY those comments to fit
   within 255 characters. Apply these condensing rules IN ORDER:
   - Remove parenthetical synonyms/aliases: "(also known as X)" → remove
   - Remove verbose qualifiers: "that is used for" → remove or shorten
   - Shorten @Enumerated lists: if enum values make it too long, keep only
     the most important 2-3 values and add "etc." or remove @Enumerated entirely
   - Remove secondary context sentences (keep only the primary definition)
   - Use shorter phrasing: "Indicates whether" → "Whether"
   - Abbreviate well-known terms if needed: "Mountain Standard Time" → "MST"
   - As a last resort, drop the least essential clause entirely

   **NEVER truncate mid-word or mid-sentence. NEVER use "..." to cut off.**
   The condensed comment must be a complete, grammatically correct description
   that preserves the essential meaning and any key annotations (@PrimaryKey, etc.).

5. After rewriting, verify AGAIN that all comments are ≤ 255 characters.
   If any still exceed the limit, condense further. Repeat until compliant.

**CRITICAL:** Do NOT change column names, types, order, or table structure.
Do NOT modify comments that are already ≤ 255 characters.

## Append a summary to `validate.md`
The framework pre-created `validate.md` with a header. Append — do not
overwrite — a short report:

```
## Validation summary

- Total columns checked: <N>
- Comments condensed (were > 255): <N>
- Final max comment length: <N>
- Result: PASS | FAIL

## Columns rewritten (if any)

| Column | Before len | After len | Before (first 80 chars) | After (first 80 chars) |
|---|---|---|---|---|
...
```

If no rewrites were needed, say so in one line under "Columns rewritten".

**The agent summarized its work in this way:**

## Validation summary

- Total columns checked: 34
- Comments condensed (were > 255): 0
- Final max comment length: 168 (column: customer_id)
- Result: PASS

## Columns rewritten (if any)

No rewrites were needed. All 34 column comments were already ≤ 255 characters.

**The agent's final response to the user was:**
All checks complete. Here's a summary of what was done:

**Validation Result: PASS**

- Checked all **34** `COMMENT` strings in `catalog/config/prod/dlms-api/us-west-2/customer360/customer-life-cycle-vw/table.ddl`
- **0** comments exceeded 255 characters
- Maximum comment length found: **168 chars** (`customer_id`)
- Range: 100–168 characters across all columns
- The DDL file was **left unchanged**
- Appended the validation summary to `validate.md`