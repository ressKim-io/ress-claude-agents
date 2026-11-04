#!/usr/bin/env bash
# 검증 게이트 자체를 검증한다.
#
# 왜 필요한가: 이 레포의 게이트는 "검사 대상이 0개여도 통과" 하는 상태로 여러 번 방치됐다.
# 게이트가 초록불인 것만으로는 아무것도 증명되지 않는다 (2026-08-25 audit F11).
# 각 테스트는 레포 사본을 일부러 망가뜨린 뒤, 게이트가 **의도한 사유로** 실패하는지 본다.
# 사유까지 보는 이유: 스크립트가 엉뚱한 곳에서 크래시해도 exit code 는 똑같이 0 이 아니다.
#
# 사용:
#   ./scripts/test-gates.sh              # 전체
#   ./scripts/test-gates.sh links        # 이름에 links 가 들어간 테스트만
#
# Exit code: 0 = 전부 기대대로, 1 = 하나라도 다름

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
BASE="$WORK/base"
CASE_DIR="$WORK/case"
LOG="$WORK/gate.log"
FILTER="${1:-}"
PASSED=0
FAILED=0

trap 'rm -rf "$WORK"' EXIT

mkdir -p "$BASE"
tar -C "$ROOT" \
    --exclude=./.git \
    --exclude=./control-plane/node_modules \
    --exclude=./control-plane/dist \
    -cf - . | tar -C "$BASE" -xf -
if [[ -d "$ROOT/control-plane/node_modules" ]]; then
    ln -s "$ROOT/control-plane/node_modules" "$BASE/control-plane/node_modules"
fi

# ---------------------------------------------------------------------------
# 헬퍼
# ---------------------------------------------------------------------------
new_case() {
    rm -rf "$CASE_DIR"
    cp -R "$BASE" "$CASE_DIR"
}

in_case() { (cd "$CASE_DIR" && "$@") >"$LOG" 2>&1; }

report_mismatch() {
    printf '    %s\n' "$1"
    tail -8 "$LOG" | cut -c1-160 | sed 's/^/      | /'
}

# $1 = 기대 사유(ERE), 나머지 = 명령. 0 이 아닌 exit + 사유 일치여야 통과.
expect_fail() {
    local reason="$1" rc
    shift
    in_case "$@"
    rc=$?
    if [[ $rc -eq 0 ]]; then
        report_mismatch "실패해야 하는데 통과했다: $*"
        return 1
    fi
    if [[ $rc -ge 126 ]]; then
        report_mismatch "게이트를 실행하지 못했다 (rc=$rc): $*"
        return 1
    fi
    if ! grep -qE "$reason" "$LOG"; then
        report_mismatch "실패 사유가 다르다 (기대: $reason): $*"
        return 1
    fi
}

expect_pass() {
    in_case "$@" && return 0
    report_mismatch "통과해야 하는데 실패했다: $*"
    return 1
}

run_test() {
    local name="$1"
    if [[ -n "$FILTER" && "$name" != *"$FILTER"* ]]; then
        return 0
    fi
    new_case
    if "$name"; then
        printf 'PASS  %s\n' "$name"
        PASSED=$((PASSED + 1))
    else
        printf 'FAIL  %s\n' "$name"
        FAILED=$((FAILED + 1))
    fi
}

# plugin 구조의 최소 skill 을 만든다. $1=plugin $2=skill $3=frontmatter name (기본 $2)
add_plugin_skill() {
    local dir="$CASE_DIR/plugins/$1/skills/$2"
    mkdir -p "$dir"
    printf -- '---\nname: %s\ndescription: "테스트 skill. Use when 테스트할 때."\n---\n\n# Test\n' \
        "${3:-$2}" >"$dir/SKILL.md"
}

# ---------------------------------------------------------------------------
# 대조군: 손대지 않은 사본은 전부 통과해야 한다
# ---------------------------------------------------------------------------
should_pass_every_gate_when_repo_is_unmodified() {
    # Given: 수정하지 않은 사본
    # When/Then
    expect_pass ./scripts/validate-links.sh &&
        expect_pass ./scripts/validate-rules-drift.sh all &&
        expect_pass ./scripts/validate-skill-frontmatter.sh all &&
        expect_pass ./scripts/validate-agent-handoff.sh all &&
        expect_pass ./scripts/validate-schemas.sh &&
        expect_pass ./scripts/validate-enforcement.sh &&
        expect_pass ./scripts/validate-catalog.sh &&
        expect_pass ./scripts/generate-inventory.sh validate &&
        expect_pass ./scripts/generate-inventory-labels.sh validate &&
        expect_pass node scripts/validate-frontmatter-yaml.mjs
}

# ---------------------------------------------------------------------------
# validate-links.sh
# ---------------------------------------------------------------------------
should_fail_links_when_no_skills_exist() {
    # Given
    rm -rf "$CASE_DIR/.claude/skills"
    # When/Then
    expect_fail '하한' ./scripts/validate-links.sh
}

should_fail_links_when_agent_has_broken_link() {
    # Given
    printf '\n[x](./no-such-file.md)\n' >>"$CASE_DIR/.claude/agents/code-reviewer.md"
    # When/Then
    expect_fail '깨진 내부 링크' ./scripts/validate-links.sh
}

should_fail_links_when_command_has_broken_link() {
    # Given
    printf '\n[x](./no-such-file.md)\n' >>"$CASE_DIR/.claude/commands/where.md"
    # When/Then
    expect_fail '깨진 내부 링크' ./scripts/validate-links.sh
}

should_fail_links_when_nested_rule_has_broken_link() {
    # Given
    printf '\n[x](./no-such-file.md)\n' >>"$CASE_DIR/.claude/rules/core/git.md"
    # When/Then
    expect_fail 'core/git\.md' ./scripts/validate-links.sh
}

should_fail_links_when_non_markdown_target_is_missing() {
    # Given
    printf '\n[x](../no-such-settings.json)\n' >>"$CASE_DIR/.claude/rules/core/git.md"
    # When/Then
    expect_fail '깨진 내부 링크' ./scripts/validate-links.sh
}

should_fail_links_when_plugin_link_escapes_plugin_root() {
    # Given: 대상 파일은 있지만 다른 plugin 에 있다. 설치본에서는 깨진다.
    add_plugin_skill a from
    add_plugin_skill b target
    printf '\n[x](../../../b/skills/target/SKILL.md)\n' >>"$CASE_DIR/plugins/a/skills/from/SKILL.md"
    # When/Then
    expect_fail 'plugin 경계' ./scripts/validate-links.sh
}

should_pass_links_when_plugin_link_stays_inside_plugin() {
    # Given
    add_plugin_skill a from
    add_plugin_skill a target
    printf '\n[x](../target/SKILL.md)\n' >>"$CASE_DIR/plugins/a/skills/from/SKILL.md"
    # When/Then
    expect_pass ./scripts/validate-links.sh
}

# ---------------------------------------------------------------------------
# validate-rules-drift.sh
# ---------------------------------------------------------------------------
should_fail_drift_when_rule_has_stale_model_id() {
    # Given
    printf '\nclaude-opus-4-7\n' >>"$CASE_DIR/.claude/rules/core/git.md"
    # When/Then
    expect_fail '구 모델 ID' ./scripts/validate-rules-drift.sh model-ids
}

should_fail_drift_when_plugin_has_stale_model_id() {
    # Given
    add_plugin_skill a from
    printf '\nclaude-sonnet-4-6\n' >>"$CASE_DIR/plugins/a/skills/from/SKILL.md"
    # When/Then
    expect_fail '구 모델 ID' ./scripts/validate-rules-drift.sh model-ids
}

should_fail_drift_when_agents_md_has_no_rule_refs() {
    # Given: 참조 0건은 "전부 유효" 가 아니라 regex 회귀다
    sed -i.bak 's#\.claude/rules/#.claude/RULES/#g' "$CASE_DIR/AGENTS.md"
    # When/Then
    expect_fail '참조 0건' ./scripts/validate-rules-drift.sh refs
}

should_fail_drift_when_nested_rule_ref_is_dangling() {
    # Given
    printf '\n.claude/rules/core/no-such-rule.md\n' >>"$CASE_DIR/AGENTS.md"
    # When/Then
    expect_fail 'core/no-such-rule' ./scripts/validate-rules-drift.sh refs
}

should_pass_drift_when_critical_rule_changes_group() {
    # Given: critical rule 은 경로가 아니라 파일명으로 찾는다
    mv "$CASE_DIR/.claude/rules/core/security.md" "$CASE_DIR/.claude/rules/process/security.md"
    # When/Then
    expect_pass ./scripts/validate-rules-drift.sh consistency
}

# ---------------------------------------------------------------------------
# validate-skill-frontmatter.sh
# ---------------------------------------------------------------------------
should_fail_frontmatter_when_no_agents_exist() {
    # Given
    rm -f "$CASE_DIR"/.claude/agents/*.md
    # When/Then
    expect_fail '하한' ./scripts/validate-skill-frontmatter.sh agents
}

should_fail_frontmatter_when_no_skills_exist() {
    # Given
    rm -rf "$CASE_DIR/.claude/skills"
    # When/Then
    expect_fail '하한' ./scripts/validate-skill-frontmatter.sh skills
}

should_fail_frontmatter_when_plugin_skill_name_mismatches() {
    # Given: 옮겨진 자산도 검사 대상이어야 한다
    add_plugin_skill a from wrong-name
    # When/Then
    expect_fail "name='wrong-name'" ./scripts/validate-skill-frontmatter.sh skills
}

# ---------------------------------------------------------------------------
# generate-inventory*.sh
# ---------------------------------------------------------------------------
should_fail_inventory_generate_when_no_skills_exist() {
    # Given
    rm -rf "$CASE_DIR/.claude/skills"
    # When/Then: 0개 재생성이 깨끗하게 끝나면 신선도 검사가 무력해진다
    expect_fail '하한' ./scripts/generate-inventory.sh generate
}

should_fail_inventory_validate_when_generate_fails() {
    # Given
    rm -rf "$CASE_DIR/.claude/skills"
    # When/Then
    expect_fail '하한' ./scripts/generate-inventory.sh validate
}

should_fail_inventory_when_skill_has_no_area() {
    # Given
    sed -i.bak '/^category:/d' "$CASE_DIR/.claude/skills/go-testing/SKILL.md"
    # When/Then: 빈 값이 자기 이름을 카테고리로 삼으면 안 된다
    expect_fail '영역을 알 수 없' ./scripts/generate-inventory.sh generate
}

should_keep_inventory_fresh_when_rule_changes_group() {
    # Given
    mv "$CASE_DIR/.claude/rules/core/git.md" "$CASE_DIR/.claude/rules/process/git.md"
    # When/Then: rule 개수는 재귀로 세므로 그대로여야 한다
    expect_pass ./scripts/generate-inventory.sh validate
}

should_fail_labels_when_skill_has_no_area() {
    # Given
    sed -i.bak '/^category:/d' "$CASE_DIR/.claude/skills/go-testing/SKILL.md"
    # When/Then
    expect_fail '영역을 알 수 없' ./scripts/generate-inventory-labels.sh generate
}

should_fail_labels_when_no_agents_exist() {
    # Given
    rm -f "$CASE_DIR"/.claude/agents/*.md
    # When/Then
    expect_fail '하한' ./scripts/generate-inventory-labels.sh generate
}

# ---------------------------------------------------------------------------
# validate-schemas.sh / validate-agent-handoff.sh
# ---------------------------------------------------------------------------
should_fail_schemas_when_one_agent_disappears() {
    # Given
    rm -f "$CASE_DIR/.claude/agents/code-reviewer.md"
    # When/Then
    expect_fail '하한' ./scripts/validate-schemas.sh
}

should_fail_handoff_when_plugin_agent_is_unregistered() {
    # Given
    mkdir -p "$CASE_DIR/plugins/a/agents"
    cp "$CASE_DIR/.claude/agents/code-reviewer.md" "$CASE_DIR/plugins/a/agents/brand-new-agent.md"
    # When/Then
    expect_fail '미등록' ./scripts/validate-agent-handoff.sh all
}

# ---------------------------------------------------------------------------
# validate-catalog.sh
# ---------------------------------------------------------------------------
should_fail_catalog_when_rule_disappears() {
    # Given
    rm -f "$CASE_DIR/.claude/rules/core/git.md"
    # When/Then
    expect_fail '하한' ./scripts/validate-catalog.sh
}

should_fail_catalog_when_command_has_no_description() {
    # Given
    printf '# no frontmatter\n' >"$CASE_DIR/.claude/commands/where.md"
    # When/Then
    expect_fail 'description 없음' ./scripts/validate-catalog.sh
}

should_fail_catalog_when_rule_references_missing_command() {
    # Given
    # shellcheck disable=SC2016  # 백틱은 실행이 아니라 문서 표기다
    printf '\n`/no-such-command` 를 쓴다\n' >>"$CASE_DIR/.claude/rules/core/git.md"
    # When/Then
    expect_fail '해석되지 않는 명령.*no-such-command' ./scripts/validate-catalog.sh
}

should_fail_catalog_when_skill_is_nested_under_category() {
    # Given: 문서에 없는 형태. 2026-08 에 260개가 이 형태로 로드되지 않았다
    mkdir -p "$CASE_DIR/.claude/skills/go/nested-skill"
    printf -- '---\nname: nested-skill\ndescription: "x"\n---\n' >"$CASE_DIR/.claude/skills/go/nested-skill/SKILL.md"
    # When/Then
    expect_fail '로드되지 않는 위치' ./scripts/validate-catalog.sh
}

# ---------------------------------------------------------------------------
# validate-frontmatter-yaml.mjs
# ---------------------------------------------------------------------------
should_fail_yaml_when_skill_frontmatter_is_invalid() {
    # Given: line 기반 파서는 통과시키지만 런타임에는 frontmatter 가 버려진다
    printf -- '---\nname: go-testing\ndescription: "앞부분"뒷부분\n---\n\n# x\n' \
        >"$CASE_DIR/.claude/skills/go-testing/SKILL.md"
    # When/Then
    expect_fail 'YAML 오류.*go-testing' node scripts/validate-frontmatter-yaml.mjs
}

should_fail_yaml_when_no_files_are_found() {
    # Given
    rm -rf "$CASE_DIR/.claude/skills"
    # When/Then
    expect_fail '하한' node scripts/validate-frontmatter-yaml.mjs
}

# ---------------------------------------------------------------------------
# 실행
# ---------------------------------------------------------------------------
TESTS=$(declare -F | awk '{print $3}' | grep '^should_')
for t in $TESTS; do
    run_test "$t"
done

printf '\n통과 %d / 실패 %d\n' "$PASSED" "$FAILED"
if [[ $((PASSED + FAILED)) -eq 0 ]]; then
    printf 'FAIL  실행한 테스트가 없다 (필터: %s)\n' "$FILTER"
    exit 1
fi
[[ $FAILED -eq 0 ]]
