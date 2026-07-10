# CLAUDE.md — snowflake-semantic-view mission

Mission-specific guidance. Loaded automatically when working under
`missions/snowflake-semantic-view/`. Repo-level guidance lives in `../../CLAUDE.md`.

## What this mission does

Generates a **Snowflake Semantic View YAML** for a Data Lake table from
its **authoritative code**:

- The PySpark job/script that populates the table
- The Airflow DAG that calls the PySpark job

The mission auto-discovers related upstream/dimension tables, foreign-key
relationships, fields, and business metrics to produce a semantic view
conforming to the [Snowflake Semantic View YAML Spec](https://docs.snowflake.com/en/user-guide/views-semantic/semantic-view-yaml-spec).

Supporting sources (Alation, Confluence, in-repo DDL/policies/data-quality) may
be used **only when consistent** with the code.

## Source-of-truth rules (non-negotiable)

- **PySpark + DAG are the source of truth.** If DDL/policies/Alation/Confluence
  contradict the PySpark or DAG, treat the code as correct and flag the
  discrepancy in validation.
- **Always traverse to the lake table — recursively.** If the PySpark
  references local/intermediate Athena tables (e.g., `*_stg`, `*_conformed.*`,
  `*_driver`), you MUST find the PySpark script that builds that intermediate
  table, read it, discover ITS sources, and continue upstream until you reach
  an actual lake table (one that exists in `gdcorp-dna/lake`). If traversal
  fails, omit the table or mark it with a note in research.md — never use
  intermediate tables as Snowflake `base_table` sources.
- **User notes in config** (`notes: |` in YAML) are highest priority after code.
  Fold them into descriptions, custom_instructions, and metrics.
- **Never guess.** If a field, relationship, or metric cannot be populated with
  high confidence, omit it and document the gap in research.md / validate.md.

## Lineage-enriched descriptions

Every dimension, time_dimension, and fact `description` MUST include:

1. Business meaning of the column
2. Source lake table.column it is derived from (first lake table boundary)
3. Transformation logic (joins, CASE, COALESCE, casts, aggregations)

This follows the table-metadata mission's C1.Column Lineage format (detailed
inline). Intermediate/staging tables are traced through but never cited.

## Snowflake output contract

The final deliverable is `SNOWFLAKE_SEMANTIC_VIEW.yaml` in the workspace root,
copied by `run.sh` to:
- `output/<id>/<name>/<schema>.<table>.snowflake.yaml` (audit trail)
- `repos/<source-repo>/<...>/src/semantics/<schema>.<table>.snowflake.yaml` (source repo)
- A pull request opened against the **PySpark source repo**, not moon-unit-missions

Structure reference: `docs/snowflake-spec-reference.md`

Required root shape:
```yaml
name: ...
tables:
  - name: ...
    base_table: {database, schema, table}
    dimensions: [...]
    time_dimensions: [...]
    facts: [...]
    metrics: [...]
relationships: [...]
verified_queries: [...]
custom_instructions: ...
```

## Stages (3 total)

| Stage | Output | Description |
|-------|--------|-------------|
| `research` | `research.md` + `RESOLVED_TARGET.json` + `PROVENANCE.json` | Merged gather + analyze |
| `generate` | `SNOWFLAKE_SEMANTIC_VIEW.yaml` + `generate.md` | YAML generation |
| `validate` | `validate.md` + `VALIDATION_REPORT.json` | Runs deterministic Python validator; fixes failures |

## Validation

Validation uses `scripts/validate_snowflake_yaml.py` — a deterministic Python
script (not LLM-based). It checks structural, semantic, and referential
integrity against the Snowflake spec. The validate stage LLM only runs the
script, reads the JSON report, and fixes any failures in-place.

## Where things live

- `manifest.yaml` — static template; **never edit per-table.**
- `config/<id>/<name>.yaml` — per-run input. The only files to add for new tables.
- `docs/creating-a-config.md` — playbook for authoring configs.
- `docs/snowflake-spec-reference.md` — condensed Snowflake spec for agent context.
- `scripts/validate_snowflake_yaml.py` — deterministic YAML validator.
- `output/<id>/<name>/` — per-run artifacts (stage `.md` files + Snowflake YAML). Committed.
- `.env.local` — local secrets; never committed.

## Adding/updating configs

Use the repo-level skill `snowflake-semantic-view-config` (under `.claude/skills/`)
when creating new configs.

## Config schema

Same as the semantic-model mission config, plus an optional `snowflake_database`
field for `base_table.database`:

```yaml
target:
  pyspark_url: "https://github.com/..."
  lake_table_override: null
  semantic_model_name: null
  snowflake_database: "GODADDY_LAKE"
```

## Model notes

The manifest uses `claude-sonnet-4-6` for all stages.

## Don't

- Edit `manifest.yaml` for a single table — use a per-table config.
- Run `./run.sh` proactively; the user runs it after reviewing configs.
- Commit `.env.local`, `.workspace/`, or `.mu-run.log` (all gitignored).
- Use intermediate/staging tables as Snowflake `base_table` sources.
- Drop do-not-claim lineage — preserve it in descriptions or custom_instructions.
