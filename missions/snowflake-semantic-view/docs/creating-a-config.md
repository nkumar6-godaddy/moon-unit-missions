# Creating a config (snowflake-semantic-view)

This mission generates a Snowflake Semantic View YAML for a Data Lake
table based on the **authoritative code** (PySpark + DAG).

## 1) Choose an identifier + name

Configs live at:

`config/<identifier>/<name>.yaml`

- `<identifier>`: a grouping bucket (team, domain, or just `example`)
- `<name>`: a human-friendly short name (often the target table name)

## 2) Provide the PySpark GitHub URL (required)

The mission expects a GitHub **blob** URL pointing to the exact PySpark file,
for example:

- `https://github.com/<org>/<repo>/blob/<ref>/src/.../pyspark/<job>.py`

The mission will clone the repo and checkout `<ref>` to ensure it reads the
exact version you linked.

## 3) Provide the Snowflake database name

The Snowflake semantic view spec requires `base_table.database` for each
logical table. Set it in your config:

```yaml
target:
  snowflake_database: "GODADDY_LAKE"
```

If omitted, defaults to `GODADDY_LAKE`.

## 4) Optional: user notes (highest priority after code)

Add expert/owner notes that the agent must honor over Confluence, Alation, and
DDL (but **not** over PySpark/DAG):

```yaml
notes: |
  This table is the primary customer lifecycle snapshot.
  Always filter on partition_eval_mst_date.
  Key metric: active customer count by country.
```

Use a YAML block scalar (`|`) for multiline text.

## 5) Optional: lake table override

If the PySpark writes to a lake table that is difficult to auto-detect, set:

- `target.lake_table_override: "<db>/<table>"` (hyphenated, lake registry path form)

Example: `enterprise/payment-cogs-audit`

## 6) Optional: semantic view name

If you want a specific view name instead of auto-derivation:

- `target.semantic_model_name: "customer_lifecycle_view"`

If omitted, the mission derives a name from the resolved schema and table.

## 7) Optional: supporting docs and Alation

Add Confluence URLs, enable Alation, and set how many saved queries to pull for
verified_queries and metric context:

```yaml
sources:
  confluence_pages:
    - url: "https://godaddy-corp.atlassian.net/wiki/spaces/BI/pages/12345/..."
      description: "Parent page — child pages may be explored"

  alation:
    enabled: true
    search_query: null
    max_queries: 5

  additional_docs: []
```

**Alation credentials:** Set `MOONUNIT_ALATION` in `missions/snowflake-semantic-view/.env.local`
with a **numeric** `user_id` (not email):

```bash
MOONUNIT_ALATION='{"refresh_token":"<token>","user_id":1664,"url":"https://godaddy.alationcloud.com"}'
```

`run.sh` merges `.env.local` into the container env alongside `~/.config/mu/mu.env`.

## Config schema

Minimal config:

```yaml
target:
  pyspark_url: "https://github.com/<org>/<repo>/blob/<ref>/<path>.py"
  lake_table_override: null
  semantic_model_name: null
  snowflake_database: "GODADDY_LAKE"

notes: |

sources:
  confluence_pages: []
  alation:
    enabled: true
    search_query: null
    max_queries: 5
  additional_docs: []
```

Notes:

- `pyspark_url` must be a GitHub **blob** URL.
- `lake_table_override` uses hyphenated lake registry paths.
- `snowflake_database` is the Snowflake database name for `base_table.database`.
- Confluence/Alation are optional; **code remains the source of truth**.

## 8) Run

From `missions/snowflake-semantic-view/`:

```bash
./run.sh <identifier> <name>
```

Outputs appear under `output/<identifier>/<name>/`.

## Output

| File | Contents |
|------|----------|
| `INPUT.md` | Run parameters |
| `research.md` | Stage 1 gathered facts + analysis |
| `generate.md` | Stage 2 summary |
| `validate.md` | Stage 3 validation report |
| `RESOLVED_TARGET.json` | Resolved schema/table/view name |
| `VALIDATION_REPORT.json` | Deterministic validation results (JSON) |
| `<schema>.<table>.snowflake.yaml` | Final Snowflake semantic view (deliverable) |
| `.workspace/repos/<repo>/<...>/src/semantics/<schema>.<table>.snowflake.yaml` | Same YAML placed in source repo |
| PR in source repo | `run.sh` opens a PR in the PySpark repo on branch `snowflake-semantic-view/<schema>.<table>` |
