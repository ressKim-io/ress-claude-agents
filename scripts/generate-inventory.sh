#!/usr/bin/env bash
# generate-inventory.sh - Generate .claude/inventory.yml from skills and agents
# Usage: ./scripts/generate-inventory.sh [generate|validate]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$REPO_ROOT/.claude/inventory.yml"

# 자산 위치와 하한의 단일 구현
# shellcheck source=scripts/lib/layout.sh
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/lib/layout.sh"

cd "$REPO_ROOT"

# Category mapping for agents (이전 구조 전용. plugin 구조는 경로에서 읽는다)
categorize_agent() {
  local name="$1"
  case "$name" in
    go-expert) echo "go" ;;
    java-expert) echo "spring" ;;
    python-expert) echo "python" ;;
    architect-agent|saga-agent) echo "architecture" ;;
    k8s-*) echo "kubernetes" ;;
    platform-engineer|platform-strategy-agent) echo "platform" ;;
    otel-expert|observability-reviewer) echo "observability" ;;
    security-scanner|anti-bot|terraform-reviewer|compliance-auditor|compliance-strategy-agent|dockerfile-reviewer|container-security-reviewer|network-security-reviewer) echo "security" ;;
    ci-optimizer|git-workflow|pr-review-bot|cicd-reviewer|gitops-reviewer|cicd-security-reviewer) echo "cicd" ;;
    code-reviewer|ticketing-expert|dev-logger|debugging-expert) echo "devops" ;;
    tech-lead|product-engineer|migration-expert|business-decision-agent) echo "devops" ;;
    frontend-expert) echo "frontend" ;;
    incident-responder) echo "sre" ;;
    load-tester*) echo "testing" ;;
    database-expert*|redis-expert) echo "database" ;;
    finops-*|cost-analyzer) echo "finops" ;;
    mlops-expert) echo "platform" ;;
    messaging-expert) echo "messaging" ;;
    service-mesh-expert) echo "service-mesh" ;;
    *) echo "other" ;;
  esac
}

# Escape YAML special characters in a string
yaml_escape() {
  local s="$1"
  # Replace backslash, then double quotes
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  echo "$s"
}

# Extract metadata from a skill file (# Title on line 1, description on line 3)
extract_skill_meta() {
  local file="$1"
  local lines
  lines=$(wc -l < "$file" | tr -d ' ')
  local first_line
  first_line=$(head -1 "$file")

  local title desc
  if [ "$first_line" = "---" ]; then
    # YAML front matter: title from first # heading after closing ---,
    # desc from front matter `description:` field
    title=$(awk '/^---$/{n++; next} n>=2 && /^# /{sub(/^# /,""); print; exit}' "$file")
    desc=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: *"?/,""); sub(/"$/,""); print; exit}' "$file")
  else
    # Plain markdown: # Title on line 1, description on line 3
    title=$(head -1 "$file" | sed 's/^# //')
    desc=$(sed -n '3p' "$file")
  fi
  echo "$lines|$title|$desc"
}

# Extract metadata from an agent file (YAML front matter + # Title after ---)
extract_agent_meta() {
  local file="$1"
  local lines
  lines=$(wc -l < "$file" | tr -d ' ')
  local first_line
  first_line=$(head -1 "$file")

  local title desc
  if [ "$first_line" = "---" ]; then
    # Has YAML front matter: title from first # heading after ---, desc from front matter
    title=$(awk '/^---$/{n++; next} n>=1 && /^# /{sub(/^# /,""); print; exit}' "$file")
    desc=$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: *"?/,""); sub(/"$/,""); print; exit}' "$file")
  else
    # No front matter: same format as skills (# Title on line 1, desc on line 3)
    title=$(head -1 "$file" | sed 's/^# //')
    desc=$(sed -n '3p' "$file")
  fi
  echo "$lines|$title|$desc"
}

generate() {
  # 0개로 재생성되면 신선도 검사가 무력해진다.
  assert_floor skills || exit 1
  assert_floor agents || exit 1

  local tmp
  tmp=$(mktemp)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Collect skill data: category|name|lines|title|desc
  declare -a skill_entries=()
  local total_skill_lines=0
  local skill_count=0

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    local basename
    basename=$(basename "$(dirname "$file")")
    local meta
    meta=$(extract_skill_meta "$file")
    local lines title desc category
    lines=$(echo "$meta" | cut -d'|' -f1)
    title=$(echo "$meta" | cut -d'|' -f2)
    desc=$(echo "$meta" | cut -d'|' -f3-)
    category=$(skill_area "$file") || { printf '%s\n' "$category"; exit 1; }
    skill_entries+=("$category|$basename|$lines|$title|$desc")
    total_skill_lines=$((total_skill_lines + lines))
    skill_count=$((skill_count + 1))
  done < <(skill_files)

  # Duplicate name check
  local all_names dupes
  all_names=$(printf '%s\n' "${skill_entries[@]}" | cut -d'|' -f2 | sort)
  dupes=$(echo "$all_names" | uniq -d)
  if [ -n "$dupes" ]; then
    echo "ERROR: Duplicate skill names: $dupes" >&2
    exit 1
  fi

  # Collect agent data
  declare -a agent_entries=()
  local total_agent_lines=0
  local agent_count=0

  while IFS= read -r file; do
    local basename
    basename=$(basename "$file" .md)
    local meta
    meta=$(extract_agent_meta "$file")
    local lines title desc category
    lines=$(echo "$meta" | cut -d'|' -f1)
    title=$(echo "$meta" | cut -d'|' -f2)
    desc=$(echo "$meta" | cut -d'|' -f3-)
    category=$(asset_plugin "$file") || category=$(categorize_agent "$basename")
    agent_entries+=("$category|$basename|$lines|$title|$desc")
    total_agent_lines=$((total_agent_lines + lines))
    agent_count=$((agent_count + 1))
  done < <(agent_files)

  # rules / commands / templates 는 개수만 집계한다 (본문 인덱스 없음).
  local rule_count command_count template_count
  rule_count=$(asset_count rules)
  command_count=$(asset_count commands)
  template_count=$(find "$REPO_ROOT/.claude/templates" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')

  # Write YAML
  {
    echo "# Auto-generated by scripts/generate-inventory.sh"
    echo "# 직접 수정하지 마세요. 스크립트로 재생성하세요."
    echo "generated: \"$timestamp\""
    echo ""
    echo "summary:"
    echo "  skills: { count: $skill_count, total_lines: $total_skill_lines }"
    echo "  agents: { count: $agent_count, total_lines: $total_agent_lines }"
    # rules / commands / templates 는 본문 인덱스를 만들지 않지만, AGENTS.md 가
    # 개수를 산문에 박는 대신 여기를 참조할 수 있도록 count 만 노출한다.
    # (2026-08-16 audit §2 — 산문 숫자는 CI 가 검사하지 않아 반드시 drift 한다)
    echo "  rules: { count: $rule_count }"
    echo "  commands: { count: $command_count }"
    echo "  templates: { count: $template_count }"
    echo ""

    # Skills by category
    echo "skills:"
    local prev_cat=""
    # Sort by category then name
    printf '%s\n' "${skill_entries[@]}" | sort -t'|' -k1,1 -k2,2 | while IFS='|' read -r cat name lines title desc; do
      if [ "$cat" != "$prev_cat" ]; then
        echo "  $cat:"
        prev_cat="$cat"
      fi
      echo "    - name: $name"
      echo "      lines: $lines"
      echo "      title: \"$(yaml_escape "$title")\""
      echo "      desc: \"$(yaml_escape "$desc")\""
    done

    echo ""

    # Agents by category
    echo "agents:"
    prev_cat=""
    printf '%s\n' "${agent_entries[@]}" | sort -t'|' -k1,1 -k2,2 | while IFS='|' read -r cat name lines title desc; do
      if [ "$cat" != "$prev_cat" ]; then
        echo "  $cat:"
        prev_cat="$cat"
      fi
      echo "    - name: $name"
      echo "      lines: $lines"
      echo "      title: \"$(yaml_escape "$title")\""
      echo "      desc: \"$(yaml_escape "$desc")\""
    done
  } > "$tmp"

  # If content (excluding timestamp) hasn't changed, preserve existing timestamp
  if [ -f "$OUTPUT" ]; then
    local existing_no_ts current_no_ts
    existing_no_ts=$(grep -v '^generated:' "$OUTPUT" 2>/dev/null || echo "")
    current_no_ts=$(grep -v '^generated:' "$tmp" 2>/dev/null || echo "")
    if [ "$existing_no_ts" = "$current_no_ts" ]; then
      local old_ts
      old_ts=$(grep '^generated:' "$OUTPUT" | head -1)
      sed -i.bak "s/^generated:.*/$old_ts/" "$tmp"
      rm -f "$tmp.bak"
    fi
  fi

  mv "$tmp" "$OUTPUT"
  echo "Generated $OUTPUT ($skill_count skills, $agent_count agents)"
}

validate() {
  local tmp
  tmp=$(mktemp)
  # Generate to temp, compare with existing. 생성 실패를 숨기면 원인이 "outdated" 로 둔갑한다.
  local gen_output
  if ! gen_output=$(OUTPUT="$tmp"; generate 2>&1); then
    printf '%s\n' "$gen_output"
    rm -f "$tmp"
    return 1
  fi

  # Compare ignoring the generated timestamp line
  local existing_no_ts current_no_ts
  existing_no_ts=$(grep -v '^generated:' "$REPO_ROOT/.claude/inventory.yml" 2>/dev/null || echo "")
  current_no_ts=$(grep -v '^generated:' "$tmp" 2>/dev/null || echo "")

  if [ "$existing_no_ts" = "$current_no_ts" ]; then
    echo "✓ inventory.yml is up to date"
    rm -f "$tmp"
    return 0
  else
    echo "✗ inventory.yml is outdated. Run: ./scripts/generate-inventory.sh generate"
    diff <(echo "$existing_no_ts") <(echo "$current_no_ts") || true
    rm -f "$tmp"
    return 1
  fi
}

case "${1:-generate}" in
  generate) generate ;;
  validate) validate ;;
  *) echo "Usage: $0 [generate|validate]"; exit 1 ;;
esac
