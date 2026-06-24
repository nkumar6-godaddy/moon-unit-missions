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

- Total columns checked: 11
- Comments condensed (were > 255): 0
- Final max comment length: 203
- Result: PASS

## Columns rewritten (if any)

No rewrites were needed. All 11 column comments were already within the 255-character limit.

**The agent's final response to the user was:**
All validation complete. Here's the summary:

**Validation Result: PASS**

- **Total columns checked:** 11
- **Comments exceeding 255 chars:** 0 (no rewrites needed)
- **Final max comment length:** 203 chars (`email_address_soft_bounced_flag`)
- **DDL file:** left unchanged

All comment lengths per column:
| Column | Length |
|---|---|
| customer_id | 157 |
| shopper_id | 177 |
| internal_account_flag | 186 |
| private_label_13_suppression_flag | 194 |
| restricted_country_flag | 178 |
| excluded_email_flag | 177 |
| competitor_email_flag | 185 |
| bad_email_address_format_flag | 173 |
| email_address_hard_bounced_flag | 197 |
| email_address_soft_bounced_flag | 203 |
| etl_build_mst_ts | 195 |