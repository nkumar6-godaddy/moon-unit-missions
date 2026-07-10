# CLAUDE.md

Repo-level guidance for Claude Code. Mission-specific notes live in each
mission's own CLAUDE.md (e.g., `missions/column-comments/CLAUDE.md`),
which are loaded automatically when working inside that mission directory.

## What this repo is

A collection of Moon Units missions — automated AI agent workflows that
run inside Docker containers via GoDaddy's internal `mu` CLI. Each mission
is a self-contained directory under `missions/` with its own manifest,
launcher, configs, and outputs.

Currently:
- `missions/column-comments/` — enriches Data Lake table DDLs with
 standardized column descriptions.
- `missions/table-metadata/` — generates 5-pillar business metadata docs
 from PySpark + DAG code.
- `missions/semantic-model/` — generates OSI-compliant semantic model YAML
 from PySpark + DAG code.
- `missions/snowflake-semantic-view/` — generates Snowflake Semantic View
 YAML from PySpark + DAG code, with lineage-enriched field descriptions
 and deterministic (script-based) validation.
- `missions/repo-semantic-view/` — generates a single repo-level Snowflake
 Semantic View YAML from a git repo URL + Confluence pages, auto-discovering
 all PySpark jobs and lake tables with upstream lineage resolution.

## Conventions across missions

- **One mission per directory under `missions/`.** Each mission owns its
  `manifest.yaml`, `run.sh`, `config/`, `output/`, `scripts/`, `docs/`,
  and `CLAUDE.md`. No shared state across missions.
- **Static manifest, dynamic input.** `manifest.yaml` is a generic
  template; per-run variables live in `config/` and are assembled into
  `.manifest.generated.yaml` by `run.sh` at launch time.
- **Outputs are committed** under `output/<…>/` as an audit trail. Per-run
  scratch space (`.workspace/`) is gitignored.
- **Helper scripts go under `<mission>/scripts/`** with their own README
  explaining purpose and env vars.
- **Skills live at `.claude/skills/<name>/`** at the repo root, not under
  individual missions (Claude Code does not search nested `.claude/`
  directories). Mission-scoped skills are prefixed with the mission name
  (e.g. `column-comments-config`); cross-mission skills use no prefix.
  See `.claude/skills/README.md`.
- **Secrets**: `.env.local` per mission (gitignored), credentials sourced
  by `run.sh`. Never commit secrets.

## Running any mission

```bash
cd missions/<mission-name>
./run.sh <args>
```

Cross-mission prerequisites: `mu` CLI installed, Docker running
(`colima start`), `AWS_PROFILE` set, `~/.config/mu/mu.env` configured
with `MOONUNIT_*` credentials. Mission-specific prerequisites are in the
mission's CLAUDE.md and README.

## Moon Units conventions worth remembering

- `manifest.yaml`'s `plan.stages[].output` is a **markdown file** (the
  framework pre-writes a header, the agent appends a summary, the
  framework appends a footer). It is *not* a generic file path.
- Default stage output filename is `<stage-name>.md` if `output:` is omitted.
- `mu launch --mount-workspace <path>` bind-mounts the container's cwd to
  the host so artifacts and cloned repos appear in real time.
- `INPUT.md` is auto-written by the framework from the manifest's
  top-level `input.content`. Don't have the launcher overwrite it.
