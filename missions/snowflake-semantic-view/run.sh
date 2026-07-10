#!/bin/bash
# Launch the Snowflake Semantic View Generation mission
#
# Usage:
#   ./run.sh <identifier> <name>           # Uses config/<identifier>/<name>.yaml
#   ./run.sh path/to/config.yaml           # Direct config file path
#   ./run.sh --pr-only <identifier> <name> # Copy output YAML to source repo and open PR
#
# Output:
#   output/<identifier>/<name>/
#     INPUT.md
#     research.md
#     generate.md
#     validate.md
#     RESOLVED_TARGET.json
#     <schema>.<table>.snowflake.yaml
#     .workspace/repos/<repo>/<...>/src/semantics/<schema>.<table>.snowflake.yaml
#   Pull request opened against the PySpark source repo (not moon-unit-missions)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_TEMPLATE="$SCRIPT_DIR/manifest.yaml"
MANIFEST_FILE="$SCRIPT_DIR/.manifest.generated.yaml"
OUTPUT_BASE="$SCRIPT_DIR/output"

usage() {
  echo "Usage: ./run.sh [--pr-only] <identifier> <name>" >&2
  echo "       ./run.sh [--pr-only] path/to/config.yaml" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --pr-only  Copy semantic view from output/ to source repo and open PR (skip mission)" >&2
  echo "" >&2
  echo "Available configs:" >&2
  find "$SCRIPT_DIR/config" -name "*.yaml" -type f 2>/dev/null | sort | while read -r f; do
    rel="${f#$SCRIPT_DIR/config/}"
    ident=$(dirname "$rel")
    name=$(basename "$rel" .yaml)
    echo "  $ident $name" >&2
  done
}

PR_ONLY=false
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-only) PR_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done
set -- "${POSITIONAL[@]}"

# Resolve config file from arguments
if [[ $# -ge 2 ]]; then
  IDENTIFIER="$1"
  NAME="$2"
  CONFIG_FILE="$SCRIPT_DIR/config/$IDENTIFIER/$NAME.yaml"
elif [[ $# -eq 1 ]]; then
  CONFIG_FILE="$1"
  IDENTIFIER="$(basename "$(dirname "$CONFIG_FILE")")"
  NAME="$(basename "$CONFIG_FILE" .yaml)"
else
  usage
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE" >&2
  echo "" >&2
  usage
  exit 1
fi

# Validate prerequisites (full mission only)
if ! $PR_ONLY; then
  if ! command -v mu &>/dev/null; then
    echo "Error: mu CLI not found. Install it first." >&2
    exit 1
  fi

  if ! docker info &>/dev/null 2>&1; then
    echo "Error: Docker is not running. Start it with 'colima start'." >&2
    exit 1
  fi
fi

# Load environment variables from .env.local file (full mission only)
ENV_FILE="$SCRIPT_DIR/.env.local"
if ! $PR_ONLY; then
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
  else
    echo "Error: .env.local not found at $ENV_FILE" >&2
    exit 1
  fi
fi

if [[ -z "${AWS_PROFILE:-}" ]]; then
  export AWS_PROFILE=claude-p1
fi
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}"
export AWS_REGION="${AWS_REGION:-us-west-2}"

read_yaml_string() {
  local key="$1"
  local line
  line=$(grep -E "^[[:space:]]*${key}:" "$CONFIG_FILE" | head -1 || true)
  if [[ -z "$line" ]]; then
    echo ""
    return
  fi
  if echo "$line" | grep -qE ": *null( |$|#)"; then
    echo ""
    return
  fi
  echo "$line" | sed -E 's/.*: *"([^"]*)".*/\1/'
}

parse_github_blob_url() {
  local url="$1"
  local rest
  rest="${url#https://github.com/}"
  if [[ "$rest" == "$url" ]]; then
    echo "Error: pyspark_url must start with https://github.com/" >&2
    exit 1
  fi
  local org repo blob ref path
  org=$(echo "$rest" | awk -F'/' '{print $1}')
  repo=$(echo "$rest" | awk -F'/' '{print $2}')
  blob=$(echo "$rest" | awk -F'/' '{print $3}')
  ref=$(echo "$rest" | awk -F'/' '{print $4}')
  path=$(echo "$rest" | cut -d'/' -f5-)

  if [[ -z "$org" || -z "$repo" || "$blob" != "blob" || -z "$ref" || -z "$path" ]]; then
    echo "Error: unsupported pyspark_url format: $url" >&2
    exit 1
  fi

  SOURCE_ORG="$org"
  SOURCE_REPO="$repo"
  SOURCE_REF="$ref"
  SOURCE_PATH="$path"
  SOURCE_REPO_URL="https://github.com/${SOURCE_ORG}/${SOURCE_REPO}.git"
}

read_yaml_notes() {
  local in_notes=false
  local line
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^notes:[[:space:]]*\|'; then
      in_notes=true
      continue
    fi
    if $in_notes; then
      if echo "$line" | grep -qE '^[a-zA-Z0-9_]+:'; then
        break
      fi
      printf '%s\n' "$line"
    fi
  done < "$CONFIG_FILE"
}

read_yaml_max_queries() {
  local val
  val=$(grep -E '^[[:space:]]*max_queries:' "$CONFIG_FILE" | head -1 | sed -E 's/.*max_queries: *//;s/ *#.*//' || true)
  if [[ -z "$val" ]]; then
    echo "5"
  else
    echo "$val"
  fi
}

generate_confluence_section() {
  local in_block=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^[[:space:]]*confluence_pages:'; then
      in_block=true
      continue
    fi
    if $in_block; then
      if echo "$line" | grep -qE '^[[:space:]]*[a-zA-Z0-9_]+:'; then
        break
      fi
      if echo "$line" | grep -qE '^[[:space:]]*-[[:space:]]*url:'; then
        local url
        url=$(echo "$line" | sed -E 's/.*url: *"([^"]*)".*/\1/')
        echo "    - ${url}"
      elif echo "$line" | grep -qE '^[[:space:]]*description:'; then
        local desc
        desc=$(echo "$line" | sed -E 's/.*description: *"([^"]*)".*/\1/')
        echo "      (${desc})"
      fi
    fi
  done < "$CONFIG_FILE"
}

generate_input_content() {
  local lake_override semantic_model_name snowflake_database alation_enabled alation_search_query alation_max_queries
  local notes_content notes_section
  lake_override=$(read_yaml_string "lake_table_override")
  semantic_model_name=$(read_yaml_string "semantic_model_name")
  snowflake_database=$(read_yaml_string "snowflake_database")

  alation_enabled=$(grep -E '^[[:space:]]*enabled:' "$CONFIG_FILE" | head -1 | sed -E 's/.*enabled: *//;s/ *#.*//')
  alation_search_query=$(read_yaml_string "search_query")
  alation_max_queries=$(read_yaml_max_queries)

  notes_content=$(read_yaml_notes)
  if [[ -n "$(echo "$notes_content" | tr -d '[:space:]')" ]]; then
    local indented_notes
    indented_notes=$(echo "$notes_content" | sed 's/^  /    /')
    notes_section=$(printf '    ## USER NOTES (HIGHEST PRIORITY)\n    These notes come directly from the table owner/expert. They take priority over\n    Confluence, Alation, and other secondary sources — but NOT over PySpark/DAG code.\n    Incorporate them into Snowflake descriptions, custom_instructions, and metrics.\n\n%s' "$indented_notes")
  else
    notes_section=""
  fi

  local confluence_section
  confluence_section=$(generate_confluence_section)
  if [[ -z "$confluence_section" ]]; then
    confluence_section="    - None provided"
  fi

  cat <<EOF
    Generate a Snowflake Semantic View YAML for a Data Lake table.
    The PySpark script and its calling DAG are the source of truth.
    Output must conform to the Snowflake semantic view YAML spec
    (see docs/snowflake-spec-reference.md).
${notes_section:+
${notes_section}
}
    ## TARGET (INPUT)
    - Identifier: ${IDENTIFIER}
    - Name: ${NAME}
    - PySpark GitHub URL: ${PYSPARK_URL}
    - Source repo URL: ${SOURCE_REPO_URL}
    - Source git ref: ${SOURCE_REF}
    - Source file path: ${SOURCE_PATH}
    - Lake table override (optional): ${lake_override:-}
    - Semantic view name (optional): ${semantic_model_name:-}
    - Snowflake database: ${snowflake_database:-GODADDY_LAKE}

    ## WORKSPACE REPOS (container)
    - Source repo folder: repos/${SOURCE_REPO}/
    - Lake repo folder: repos/lake/

    ## CONFLUENCE PAGES
${confluence_section}

    ## ALATION
    - Enabled: ${alation_enabled:-false}
    - Search query override: ${alation_search_query:-}
    - Max queries (for metric/usage context): ${alation_max_queries}
EOF
}

# Parse the PySpark URL early so SOURCE_* vars are available
PYSPARK_URL=$(read_yaml_string "pyspark_url")
if [[ -z "$PYSPARK_URL" ]]; then
  echo "Error: target.pyspark_url is required in $CONFIG_FILE" >&2
  exit 1
fi
parse_github_blob_url "$PYSPARK_URL"

# Set output directory
OUTPUT_DIR="$OUTPUT_BASE/${IDENTIFIER}/${NAME}"
WORKSPACE_DIR="$OUTPUT_DIR/.workspace"
mkdir -p "$OUTPUT_DIR"

collect_artifact() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || return 1
  cp "$src" "$dst"
}

copy_stage_outputs() {
  collect_artifact "$WORKSPACE_DIR/INPUT.md"       "$OUTPUT_DIR/INPUT.md"       || true
  collect_artifact "$WORKSPACE_DIR/research.md"    "$OUTPUT_DIR/research.md"    || true
  collect_artifact "$WORKSPACE_DIR/generate.md"    "$OUTPUT_DIR/generate.md"    || true
  collect_artifact "$WORKSPACE_DIR/validate.md"    "$OUTPUT_DIR/validate.md"    || true
  collect_artifact "$WORKSPACE_DIR/RESOLVED_TARGET.json" "$OUTPUT_DIR/RESOLVED_TARGET.json" || true
  collect_artifact "$WORKSPACE_DIR/VALIDATION_REPORT.json" "$OUTPUT_DIR/VALIDATION_REPORT.json" || true
}

resolve_output_filename() {
  local resolved="$OUTPUT_DIR/RESOLVED_TARGET.json"
  if [[ -f "$resolved" ]]; then
    local schema table_u
    schema=$(node -e "const j=require('$resolved'); console.log(j.schema||'');" 2>/dev/null || true)
    table_u=$(node -e "const j=require('$resolved'); console.log(j.table_underscore||'');" 2>/dev/null || true)
    if [[ -n "$schema" && -n "$table_u" ]]; then
      echo "${schema}.${table_u}.snowflake.yaml"
      return
    fi
  fi
  echo "unknown.unknown.snowflake.yaml"
}

find_output_semantic_file() {
  local out_name="$1"
  local candidate="$OUTPUT_DIR/$out_name"
  if [[ -f "$candidate" ]]; then
    echo "$candidate"
    return 0
  fi
  return 1
}

semantics_rel_path() {
  local out_name="$1"
  local src_parent
  src_parent=$(dirname "$(dirname "$SOURCE_PATH")")
  echo "${src_parent}/semantics/${out_name}"
}

semantics_abs_path() {
  local out_name="$1"
  echo "$WORKSPACE_DIR/repos/$SOURCE_REPO/$(semantics_rel_path "$out_name")"
}

read_github_token() {
  local token=""
  if [[ -f "$HOME/.config/mu/mu.env" ]]; then
    token=$(grep -E '^MOONUNIT_GITHUB_TOKEN=' "$HOME/.config/mu/mu.env" | head -1 | sed 's/^MOONUNIT_GITHUB_TOKEN=//' \
      | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).token||'')}catch{}})" 2>/dev/null || true)
  fi
  if [[ -z "$token" ]] && command -v gh &>/dev/null; then
    token=$(gh auth token 2>/dev/null || true)
  fi
  echo "$token"
}

find_existing_pr_url() {
  local branch="$1"
  local token="$2"
  local url=""

  if command -v gh &>/dev/null; then
    url=$(GH_TOKEN="$token" gh pr list \
      --repo "${SOURCE_ORG}/${SOURCE_REPO}" \
      --head "${SOURCE_ORG}:${branch}" \
      --state open \
      --json url \
      --jq '.[0].url // empty' 2>/dev/null || true)
    if [[ -z "$url" ]]; then
      url=$(GH_TOKEN="$token" gh pr list \
        --repo "${SOURCE_ORG}/${SOURCE_REPO}" \
        --head "$branch" \
        --state open \
        --json url \
        --jq '.[0].url // empty' 2>/dev/null || true)
    fi
  fi

  if [[ -z "$url" ]]; then
    url=$(curl -sS \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${SOURCE_ORG}/${SOURCE_REPO}/pulls?head=${SOURCE_ORG}:${branch}&state=open" \
      | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const j=JSON.parse(d);console.log((j[0]&&j[0].html_url)||'')}catch{}})" 2>/dev/null || true)
  fi

  echo "$url"
}

ensure_source_repo_clone() {
  local repo_dir="$WORKSPACE_DIR/repos/$SOURCE_REPO"
  if [[ -d "$repo_dir/.git" ]]; then
    return 0
  fi
  echo "[*] Cloning ${SOURCE_REPO_URL}..."
  mkdir -p "$WORKSPACE_DIR/repos"
  git clone --quiet "$SOURCE_REPO_URL" "$repo_dir"
}

create_source_repo_pr() {
  local source_file="$1"
  local out_name="$2"
  local repo_dir="$WORKSPACE_DIR/repos/$SOURCE_REPO"
  local semantics_rel branch schema table_u token pr_url existing_pr

  if [[ ! -f "$source_file" ]]; then
    echo "[!] Semantic view file not found: $source_file" >&2
    return 1
  fi

  ensure_source_repo_clone

  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "[!] Source repo clone not found — skipping PR" >&2
    return 1
  fi

  semantics_rel=$(semantics_rel_path "$out_name")
  schema=$(node -e "const j=require('$OUTPUT_DIR/RESOLVED_TARGET.json'); console.log(j.schema||'');" 2>/dev/null || true)
  table_u=$(node -e "const j=require('$OUTPUT_DIR/RESOLVED_TARGET.json'); console.log(j.table_underscore||'');" 2>/dev/null || true)
  branch="snowflake-semantic-view/${schema}.${table_u}"

  token=$(read_github_token)
  if [[ -z "$token" ]]; then
    echo "[!] No GitHub token available — skipping PR (set MOONUNIT_GITHUB_TOKEN or run gh auth login)" >&2
    return 1
  fi

  existing_pr=$(find_existing_pr_url "$branch" "$token")

  git -C "$repo_dir" fetch origin "$SOURCE_REF" --quiet 2>/dev/null || true
  git -C "$repo_dir" checkout "$SOURCE_REF" --quiet 2>/dev/null \
    || git -C "$repo_dir" checkout -B "$SOURCE_REF" "origin/$SOURCE_REF" --quiet
  git -C "$repo_dir" checkout -B "$branch" --quiet

  mkdir -p "$repo_dir/$(dirname "$semantics_rel")"
  cp "$source_file" "$repo_dir/$semantics_rel"
  git -C "$repo_dir" add "$semantics_rel"

  if git -C "$repo_dir" diff --cached --quiet; then
    if [[ -n "$existing_pr" ]]; then
      echo "$existing_pr"
      return 0
    fi
    echo "[!] No changes to commit — skipping PR" >&2
    return 1
  fi

  git -C "$repo_dir" \
    -c user.email="${MOONUNIT_GIT_EMAIL:-moonunit@gdcorp-dna.com}" \
    -c user.name="${MOONUNIT_GIT_NAME:-Moon Unit}" \
    commit -m "Add Snowflake semantic view for ${schema}.${table_u}" --quiet

  git -C "$repo_dir" push --force \
    "https://x-access-token:${token}@github.com/${SOURCE_ORG}/${SOURCE_REPO}.git" \
    "$branch" --quiet 2>&1 | grep -v '^remote:' >&2 || true

  if [[ -n "$existing_pr" ]]; then
    echo "$existing_pr"
    return 0
  fi

  if command -v gh &>/dev/null; then
    pr_url=$(GH_TOKEN="$token" gh pr create \
      --repo "${SOURCE_ORG}/${SOURCE_REPO}" \
      --head "$branch" \
      --base "$SOURCE_REF" \
      --title "Add Snowflake semantic view for ${schema}.${table_u}" \
      --body "Adds \`${semantics_rel}\` generated by the moon-unit-missions snowflake-semantic-view mission." 2>/dev/null || true)
  fi

  if [[ -z "${pr_url:-}" ]]; then
    pr_url=$(curl -sS -X POST \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      -d "$(node -e "
        console.log(JSON.stringify({
          title: 'Add Snowflake semantic view for ${schema}.${table_u}',
          head: '${branch}',
          base: '${SOURCE_REF}',
          body: 'Adds \`${semantics_rel}\` generated by the moon-unit-missions snowflake-semantic-view mission.'
        }))
      ")" \
      "https://api.github.com/repos/${SOURCE_ORG}/${SOURCE_REPO}/pulls" \
      | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const j=JSON.parse(d);console.log(j.html_url||'')}catch{}})" 2>/dev/null || true)
  fi

  if [[ -n "${pr_url:-}" ]]; then
    echo "$pr_url"
    return 0
  fi

  echo "[!] Branch pushed but PR creation failed — open manually: ${SOURCE_ORG}/${SOURCE_REPO} compare ${SOURCE_REF}...${branch}" >&2
  return 1
}

run_pr_only_mode() {
  local out_name source_file semantics_path pr_url

  echo "=== Snowflake Semantic View PR-only ==="
  echo "Config:  $CONFIG_FILE"
  echo "Target:  ${IDENTIFIER}/${NAME}"
  echo "Repo:    ${SOURCE_ORG}/${SOURCE_REPO}@${SOURCE_REF}"
  echo "Output:  $OUTPUT_DIR"
  echo ""

  if [[ ! -f "$OUTPUT_DIR/RESOLVED_TARGET.json" ]]; then
    echo "Error: RESOLVED_TARGET.json not found in $OUTPUT_DIR" >&2
    echo "Run the full mission first: ./run.sh ${IDENTIFIER} ${NAME}" >&2
    exit 1
  fi

  out_name=$(resolve_output_filename)
  if ! source_file=$(find_output_semantic_file "$out_name"); then
    echo "Error: Semantic view YAML not found in $OUTPUT_DIR (expected ${out_name})" >&2
    exit 1
  fi

  semantics_path=$(semantics_abs_path "$out_name")
  pr_url=$(create_source_repo_pr "$source_file" "$out_name" || true)

  echo ""
  echo "═══════════════════════════════════════════════════"
  if [[ -n "$pr_url" ]]; then
    echo " ✓ PR READY"
    echo " Semantics: $semantics_path"
    echo " PR: $pr_url"
  else
    echo " ✗ PR STEP FAILED"
    echo " Semantics: $semantics_path"
    echo " Check errors above (token, push permissions, or no changes)."
  fi
  echo "═══════════════════════════════════════════════════"

  [[ -n "$pr_url" ]]
}

if $PR_ONLY; then
  run_pr_only_mode
  exit $?
fi

# Assemble generated manifest with dynamic input content + source repo URL
INPUT_CONTENT=$(generate_input_content)

while IFS= read -r line; do
  if echo "$line" | grep -q '^  url:' && echo "$line" | grep -q '__GENERATED_BY_RUN_SH__'; then
    echo "  url: ${SOURCE_REPO_URL}"
  elif echo "$line" | grep -q '^  content:' && echo "$line" | grep -q '__GENERATED_BY_RUN_SH__'; then
    echo "  content: |"
    echo "$INPUT_CONTENT"
  elif echo "$line" | grep -q '^    - url: "__GENERATED_BY_RUN_SH__SOURCE_REPO_URL__"'; then
    echo "    - url: ${SOURCE_REPO_URL}"
  else
    echo "$line"
  fi
done < "$MANIFEST_TEMPLATE" > "$MANIFEST_FILE"

echo "=== Snowflake Semantic View Generation Mission ==="
echo "Config:    $CONFIG_FILE"
echo "Target:    ${IDENTIFIER}/${NAME}"
echo "PySpark:   ${SOURCE_ORG}/${SOURCE_REPO}@${SOURCE_REF}:${SOURCE_PATH}"
echo "Manifest:  $MANIFEST_FILE"
echo "Output:    $OUTPUT_DIR"
echo "AWS:       $AWS_PROFILE"
echo ""

if ! mu lint "$MANIFEST_FILE" >/dev/null 2>&1; then
  echo "Error: manifest failed mu lint:" >&2
  mu lint "$MANIFEST_FILE" >&2
  exit 1
fi

MU_LOG="$SCRIPT_DIR/.mu-run.log"
rm -f "$MU_LOG"
rm -rf "$WORKSPACE_DIR"
rm -f "$OUTPUT_DIR"/{INPUT,research,generate,validate}.md \
      "$OUTPUT_DIR"/RESOLVED_TARGET.json \
      "$OUTPUT_DIR"/VALIDATION_REPORT.json \
      "$OUTPUT_DIR"/*.snowflake.yaml
mkdir -p "$WORKSPACE_DIR/docs"
mkdir -p "$WORKSPACE_DIR/scripts"
cp "$SCRIPT_DIR/docs/snowflake-spec-reference.md" "$WORKSPACE_DIR/docs/snowflake-spec-reference.md"
cp "$SCRIPT_DIR/scripts/validate_snowflake_yaml.py" "$WORKSPACE_DIR/scripts/validate_snowflake_yaml.py"

cleanup() {
  local sig="${1:-}"
  if [[ -n "${MU_PID:-}" ]] && kill -0 "$MU_PID" 2>/dev/null; then
    kill "$MU_PID" 2>/dev/null || true
  fi
  if [[ -n "${TAIL_PID:-}" ]] && kill -0 "$TAIL_PID" 2>/dev/null; then
    kill "$TAIL_PID" 2>/dev/null || true
    wait "$TAIL_PID" 2>/dev/null || true
  fi
  if [[ -f "${MU_LOG:-/dev/null}" ]]; then
    local cn
    cn=$(grep -oE 'mu-[0-9]+' "$MU_LOG" 2>/dev/null | head -1 || true)
    if [[ -n "$cn" ]]; then
      docker stop --time 5 "$cn" >/dev/null 2>&1 || true
      docker rm   --force  "$cn" >/dev/null 2>&1 || true
    fi
  fi
  if [[ "$sig" == "INT" || "$sig" == "TERM" ]]; then
    echo ""
    echo "[!] Interrupted — workspace left at $WORKSPACE_DIR for inspection."
    exit 130
  fi
}
trap 'cleanup INT'  INT
trap 'cleanup TERM' TERM

# Merge mu.env with mission .env.local
MU_ENV_FILE="$SCRIPT_DIR/.mu-env.merged"
{
  if [[ -f "$HOME/.config/mu/mu.env" ]]; then
    cat "$HOME/.config/mu/mu.env"
  fi
  echo ""
  grep -E '^(MOONUNIT_|ALATION_)' "$ENV_FILE" 2>/dev/null || true
} > "$MU_ENV_FILE"

mu launch "$MANIFEST_FILE" \
  --mount-workspace "$WORKSPACE_DIR" \
  --keep-container \
  --env-file "$MU_ENV_FILE" \
  > "$MU_LOG" 2>&1 &
MU_PID=$!

echo "[*] mu launched (PID: $MU_PID)"
echo "[*] Workspace mounted at: $WORKSPACE_DIR"
echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "[*] Tailing log (Ctrl+C to cancel mission)"
echo "─────────────────────────────────────────────────────────────────"
echo ""

tail -f "$MU_LOG" 2>/dev/null &
TAIL_PID=$!

TERMINAL=""
while true; do
  if grep -q "state=SUCCEEDED" "$MU_LOG" 2>/dev/null; then
    TERMINAL="SUCCEEDED"
    break
  fi
  if grep -q "state=FAILED\\|mu fatal error" "$MU_LOG" 2>/dev/null; then
    TERMINAL="FAILED"
    break
  fi
  if ! kill -0 "$MU_PID" 2>/dev/null; then
    TERMINAL="EXITED"
    break
  fi
  sleep 1
done

kill "$TAIL_PID" 2>/dev/null || true
wait "$TAIL_PID" 2>/dev/null || true

if [[ "$TERMINAL" == "SUCCEEDED" ]]; then
  copy_stage_outputs

  SEMANTICS_PATH=""
  PR_URL=""
  if [[ -f "$WORKSPACE_DIR/SNOWFLAKE_SEMANTIC_VIEW.yaml" ]]; then
    OUT_NAME=$(resolve_output_filename)
    cp "$WORKSPACE_DIR/SNOWFLAKE_SEMANTIC_VIEW.yaml" "$OUTPUT_DIR/$OUT_NAME"
    SEMANTICS_PATH=$(semantics_abs_path "$OUT_NAME")
    PR_URL=$(create_source_repo_pr "$OUTPUT_DIR/$OUT_NAME" "$OUT_NAME" || true)
  fi

  kill "$MU_PID" 2>/dev/null || true
  CONTAINER_NAME=$(grep -oE 'mu-[0-9]+' "$MU_LOG" 2>/dev/null | head -1 || true)
  if [[ -n "$CONTAINER_NAME" ]]; then
    docker stop --time 5 "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm   --force  "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
  wait "$MU_PID" 2>/dev/null || true

  osascript -e "display notification \"Output ready in output/\" with title \"Moon Unit Complete ✓\"" 2>/dev/null || true
  printf "\a"
  MISSION_ID=$(grep -o "lmsn_[A-Z0-9]*" "$MU_LOG" | head -1 || true)
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo " ✓ MISSION SUCCEEDED ${MISSION_ID:+($MISSION_ID)}"
  echo " Target: ${IDENTIFIER}/${NAME}"
  echo " Output: $OUTPUT_DIR/"
  if [[ -n "$PR_URL" ]]; then
    echo " Semantics: $SEMANTICS_PATH"
    echo " Workspace: $WORKSPACE_DIR (preserved)"
    echo " PR: $PR_URL"
  elif [[ -n "$SEMANTICS_PATH" ]]; then
    echo " Semantics: $SEMANTICS_PATH"
    echo " Workspace: $WORKSPACE_DIR (preserved)"
    echo " PR: (not created — see warnings above)"
  fi
  echo "═══════════════════════════════════════════════════"
  exit 0
fi

if [[ "$TERMINAL" == "FAILED" ]]; then
  copy_stage_outputs
  ERROR=$(grep "fatal error\\|state=FAILED" "$MU_LOG" | tail -1 | sed "s/.*fatal error: //" | cut -c1-160)
  kill "$MU_PID" 2>/dev/null || true
  osascript -e "display notification \"$ERROR\" with title \"Moon Unit Failed ✗\"" 2>/dev/null || true
  printf "\a"
  echo ""
  echo "═══════════════════════════════════════════════════"
  echo " ✗ MISSION FAILED"
  echo " Target: ${IDENTIFIER}/${NAME}"
  echo " Error: $ERROR"
  echo " Workspace: $WORKSPACE_DIR (left for debugging)"
  echo " Log: $MU_LOG"
  echo " Partial outputs: $OUTPUT_DIR/ (stage outputs if reached)"
  echo "═══════════════════════════════════════════════════"
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo " ! mu exited without a terminal state"
echo " Workspace: $WORKSPACE_DIR (left for debugging)"
echo " Log: $MU_LOG"
echo "═══════════════════════════════════════════════════"
exit 1
