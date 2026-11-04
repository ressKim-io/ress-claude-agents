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

# layout.sh 기준 첫 자산. 자산이 어느 구조에 있든 테스트가 따라간다.
first_asset() {
    # shellcheck disable=SC1091
    (cd "$CASE_DIR" && source scripts/lib/layout.sh && "$1" | head -1)
}

remove_skills() {
    rm -rf "$CASE_DIR"/plugins/*/skills
}

remove_agents() {
    rm -f "$CASE_DIR"/plugins/*/agents/*.md
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
        expect_pass node scripts/validate-frontmatter-yaml.mjs &&
        expect_pass python3 scripts/generate-plugin-readmes.py validate
}

# ---------------------------------------------------------------------------
# validate-links.sh
# ---------------------------------------------------------------------------
should_fail_links_when_no_skills_exist() {
    # Given
    remove_skills
    # When/Then
    expect_fail '하한' ./scripts/validate-links.sh
}

should_fail_links_when_agent_has_broken_link() {
    # Given
    printf '\n[x](./no-such-file.md)\n' >>"$CASE_DIR/$(first_asset agent_files)"
    # When/Then
    expect_fail '깨진 내부 링크' ./scripts/validate-links.sh
}

should_fail_links_when_command_has_broken_link() {
    # Given
    printf '\n[x](./no-such-file.md)\n' >>"$CASE_DIR/$(first_asset command_files)"
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
    remove_agents
    # When/Then
    expect_fail '하한' ./scripts/validate-skill-frontmatter.sh agents
}

should_fail_frontmatter_when_no_skills_exist() {
    # Given
    remove_skills
    # When/Then
    expect_fail '하한' ./scripts/validate-skill-frontmatter.sh skills
}

should_fail_frontmatter_when_plugin_skill_name_mismatches() {
    # Given: 옮겨진 자산도 검사 대상이어야 한다
    add_plugin_skill a from wrong-name
    # When/Then
    expect_fail "name='wrong-name'" ./scripts/validate-skill-frontmatter.sh skills
}

should_fail_frontmatter_when_skill_has_unofficial_field() {
    # Given: Claude Code 는 조용히 무시하고, 패키징·업로드할 때만 오류가 된다
    add_plugin_skill a from
    sed -i.bak 's/^name: from$/name: from\ncategory: go/' "$CASE_DIR/plugins/a/skills/from/SKILL.md"
    # When/Then
    expect_fail '공식 필드가 아니다.*category' ./scripts/validate-skill-frontmatter.sh skills
}

should_fail_frontmatter_when_skill_sets_effort() {
    # Given: 공식 필드지만 그 턴이 끝날 때까지 세션 effort 를 덮어쓴다
    add_plugin_skill a from
    sed -i.bak 's/^name: from$/name: from\neffort: high/' "$CASE_DIR/plugins/a/skills/from/SKILL.md"
    # When/Then
    expect_fail 'effort 를 쓰지 않는다' ./scripts/validate-skill-frontmatter.sh skills
}

should_pass_frontmatter_when_skill_uses_every_allowed_field() {
    # Given: 허용 목록의 오타를 잡는 대조군. effort 만 정책으로 뺀다
    local field fields=""
    for field in when_to_use argument-hint arguments disable-model-invocation user-invocable \
        allowed-tools disallowed-tools model context agent background hooks paths shell \
        metadata license compatibility; do
        fields="$fields$field: x\n"
    done
    mkdir -p "$CASE_DIR/plugins/a/skills/full"
    printf -- '---\nname: full\ndescription: "테스트 skill. Use when 테스트할 때."\n%b---\n\n# Test\n' "$fields" \
        >"$CASE_DIR/plugins/a/skills/full/SKILL.md"
    # When/Then
    expect_pass ./scripts/validate-skill-frontmatter.sh skills
}

# ---------------------------------------------------------------------------
# generate-inventory*.sh
# ---------------------------------------------------------------------------
should_fail_inventory_generate_when_no_skills_exist() {
    # Given
    remove_skills
    # When/Then: 0개 재생성이 깨끗하게 끝나면 신선도 검사가 무력해진다
    expect_fail '하한' ./scripts/generate-inventory.sh generate
}

should_fail_inventory_validate_when_generate_fails() {
    # Given
    remove_skills
    # When/Then
    expect_fail '하한' ./scripts/generate-inventory.sh validate
}

should_keep_inventory_fresh_when_rule_changes_group() {
    # Given
    mv "$CASE_DIR/.claude/rules/core/git.md" "$CASE_DIR/.claude/rules/process/git.md"
    # When/Then: rule 개수는 재귀로 세므로 그대로여야 한다
    expect_pass ./scripts/generate-inventory.sh validate
}

should_fail_labels_when_no_agents_exist() {
    # Given
    remove_agents
    # When/Then
    expect_fail '하한' ./scripts/generate-inventory-labels.sh generate
}

# ---------------------------------------------------------------------------
# validate-schemas.sh / validate-agent-handoff.sh
# ---------------------------------------------------------------------------
should_fail_schemas_when_one_agent_disappears() {
    # Given
    rm -f "$CASE_DIR/$(first_asset agent_files)"
    # When/Then
    expect_fail '하한' ./scripts/validate-schemas.sh
}

should_fail_handoff_when_plugin_agent_is_unregistered() {
    # Given
    mkdir -p "$CASE_DIR/plugins/a/agents"
    cp "$CASE_DIR/$(first_asset agent_files)" "$CASE_DIR/plugins/a/agents/brand-new-agent.md"
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
    printf '# no frontmatter\n' >"$CASE_DIR/$(first_asset command_files)"
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
    mkdir -p "$CASE_DIR/plugins/go/skills/testing/nested-skill"
    printf -- '---\nname: nested-skill\ndescription: "x"\n---\n' >"$CASE_DIR/plugins/go/skills/testing/nested-skill/SKILL.md"
    # When/Then
    expect_fail '로드되지 않는 위치' ./scripts/validate-catalog.sh
}

# ---------------------------------------------------------------------------
# skill description
# ---------------------------------------------------------------------------
set_description() {
    python3 - "$CASE_DIR/plugins/$1/skills/$2/SKILL.md" "$3" <<'PY'
import re, sys
path, description = sys.argv[1:]
text = open(path, encoding="utf-8").read()
text = re.sub(r"^description:.*$", lambda _: f'description: "{description}"', text, count=1, flags=re.M)
open(path, "w", encoding="utf-8").write(text)
PY
}

should_fail_descriptions_when_template_phrase_returns() {
    # Given: 무엇도 언제도 말하지 않아 224개를 다시 쓰게 만든 문구
    add_plugin_skill go brand-new
    set_description go brand-new "Go 패턴. Use when working with go 도메인의 패턴 / 구현 선택."
    # When/Then
    expect_fail '템플릿 문구.*brand-new' ./scripts/validate-catalog.sh
}

should_fail_descriptions_when_use_when_is_missing() {
    # Given
    add_plugin_skill go brand-new
    set_description go brand-new "Go 패턴 모음이다."
    # When/Then
    expect_fail 'Use when.*brand-new' ./scripts/validate-catalog.sh
}

should_fail_descriptions_when_longer_than_limit() {
    # Given: 길면 목록 예산을 먼저 다 쓴다
    local long
    long=$(python3 -c 'print("가" * 240)')
    add_plugin_skill go brand-new
    set_description go brand-new "$long. Use when 길 때 쓴다."
    # When/Then
    expect_fail '250자.*brand-new' ./scripts/validate-catalog.sh
}

should_pass_descriptions_when_multibyte_text_is_within_limit() {
    # Given: 바이트로 세면 한글 90자도 넘는다
    local text
    text=$(python3 -c 'print("가" * 220)')
    add_plugin_skill go brand-new
    set_description go brand-new "$text. Use when 짧을 때 쓴다."
    # When/Then
    expect_pass ./scripts/validate-catalog.sh
}

should_fail_descriptions_when_two_skills_share_one() {
    # Given: 같으면 모델이 둘을 구분할 수 없다
    add_plugin_skill go brand-new
    add_plugin_skill java other-new
    # When/Then
    expect_fail '중복.*other-new' ./scripts/validate-catalog.sh
}

# ---------------------------------------------------------------------------
# validate-frontmatter-yaml.mjs
# ---------------------------------------------------------------------------
should_fail_yaml_when_skill_frontmatter_is_invalid() {
    # Given: line 기반 파서는 통과시키지만 런타임에는 frontmatter 가 버려진다
    local skill
    skill=$(first_asset skill_files)
    printf -- '---\nname: x\ndescription: "앞부분"뒷부분\n---\n\n# x\n' >"$CASE_DIR/$skill"
    # When/Then
    expect_fail "YAML 오류.*$skill" node scripts/validate-frontmatter-yaml.mjs
}

should_fail_yaml_when_no_files_are_found() {
    # Given
    remove_skills
    # When/Then
    expect_fail '하한' node scripts/validate-frontmatter-yaml.mjs
}

# ---------------------------------------------------------------------------
# plugin 구조
# ---------------------------------------------------------------------------
should_fail_plugin_catalog_when_marketplace_entry_has_no_directory() {
    # Given
    python3 - "$CASE_DIR/.claude-plugin/marketplace.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["plugins"].append({"name": "ghost", "source": "./plugins/ghost"})
json.dump(data, open(path, "w", encoding="utf-8"))
PY
    # When/Then
    expect_fail 'marketplace.*ghost' ./scripts/validate-catalog.sh
}

should_fail_plugin_catalog_when_directory_is_not_in_marketplace() {
    # Given: 있어도 설치할 수 없는 plugin
    add_plugin_skill stray from
    mkdir -p "$CASE_DIR/plugins/stray/.claude-plugin"
    printf '{"name": "stray"}\n' >"$CASE_DIR/plugins/stray/.claude-plugin/plugin.json"
    # When/Then
    expect_fail 'marketplace 에 없다.*stray' ./scripts/validate-catalog.sh
}

should_fail_plugin_catalog_when_manifest_is_missing() {
    # Given
    rm -f "$CASE_DIR/plugins/dx/.claude-plugin/plugin.json"
    # When/Then
    expect_fail 'plugin\.json.*dx' ./scripts/validate-catalog.sh
}

should_fail_plugin_catalog_when_manifest_name_differs() {
    # Given
    printf '{"name": "other"}\n' >"$CASE_DIR/plugins/dx/.claude-plugin/plugin.json"
    # When/Then
    expect_fail 'plugin\.json.*dx' ./scripts/validate-catalog.sh
}

should_fail_plugin_catalog_when_enabled_plugin_is_unknown() {
    # Given
    python3 - "$CASE_DIR/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["enabledPlugins"]["ghost@ress"] = True
json.dump(data, open(path, "w", encoding="utf-8"))
PY
    # When/Then
    expect_fail 'enabledPlugins.*ghost' ./scripts/validate-catalog.sh
}

should_fail_plugin_catalog_when_plain_rule_path_is_dangling() {
    # Given: 링크가 아닌 경로 표기도 옮길 때 자주 빠진다
    # shellcheck disable=SC2016  # 백틱은 실행이 아니라 문서 표기다
    printf '\n자세한 내용은 `.claude/rules/core/no-such-rule.md` 를 본다\n' >>"$CASE_DIR/AGENTS.md"
    # When/Then
    expect_fail '없는 경로.*no-such-rule' ./scripts/validate-catalog.sh
}

should_fail_plugin_links_when_repo_url_target_is_missing() {
    # Given: 설치본에서 쓰는 원격 링크. 파일을 옮기면 조용히 404 가 된다
    printf '\n[x](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/no-such.md)\n' \
        >>"$CASE_DIR/$(first_asset command_files)"
    # When/Then
    expect_fail 'no-such\.md' ./scripts/validate-links.sh
}

should_fail_plugin_links_when_living_doc_has_broken_link() {
    # Given: 살아 있는 문서의 옛 경로가 게이트에 안 잡혀 실제로 깨진 채 남았었다
    printf '\n[x](../../.claude/rules/no-such-rule.md)\n' >>"$CASE_DIR/docs/architecture/multi-tool-mapping.md"
    # When/Then
    expect_fail 'multi-tool-mapping' ./scripts/validate-links.sh
}

should_fail_plugin_catalog_when_command_is_shadowed_by_skill() {
    # Given: 이름이 같으면 skill 이 이겨서 command 가 조용히 사라진다
    printf -- '---\ndescription: "x"\n---\n' >"$CASE_DIR/plugins/go/commands/go-testing.md"
    # When/Then
    expect_fail '이름이 겹친다.*go-testing' ./scripts/validate-catalog.sh
}

should_fail_plugin_catalog_when_legacy_skills_directory_returns() {
    # Given: Claude Code 는 이 경로도 읽는다. 이 레포에서는 plugin 밖에 skill 이 생기면 안 된다
    mkdir -p "$CASE_DIR/.claude/skills/stray"
    printf -- '---\nname: stray\ndescription: "x"\n---\n' >"$CASE_DIR/.claude/skills/stray/SKILL.md"
    # When/Then
    expect_fail '옛 구조.*\.claude/skills' ./scripts/validate-catalog.sh
}

should_fail_plugin_catalog_when_legacy_agents_directory_returns() {
    # Given
    mkdir -p "$CASE_DIR/.claude/agents"
    printf -- '---\nname: stray\n---\n' >"$CASE_DIR/.claude/agents/stray.md"
    # When/Then
    expect_fail '옛 구조.*\.claude/agents' ./scripts/validate-catalog.sh
}

should_fail_plugin_refs_when_rule_uses_bare_skill_name() {
    # Given: plugin 으로 옮긴 뒤로 bare 이름은 등록되지 않는다
    # shellcheck disable=SC2016  # 백틱은 실행이 아니라 문서 표기다
    printf '\n`/go-testing` 을 쓴다\n' >>"$CASE_DIR/.claude/rules/core/git.md"
    # When/Then
    expect_fail '해석되지 않는 명령.*go-testing' ./scripts/validate-catalog.sh
}

should_fail_plugin_refs_when_plugin_file_mentions_unknown_skill() {
    # Given: 설치본에서 열리지 않는 참조. 이름을 바꾸거나 옮기면 조용히 깨진다
    printf '\n자세한 내용은 /go:no-such-skill 참조\n' >>"$CASE_DIR/$(first_asset skill_files)"
    # When/Then
    expect_fail '해석되지 않는 명령.*go:no-such-skill' ./scripts/validate-catalog.sh
}

should_fail_plugin_refs_when_mention_has_double_prefix() {
    # Given: skill 과 plugin 의 이름이 같아 이동 도구가 실제로 만든 형태
    # shellcheck disable=SC2016  # 백틱은 실행이 아니라 문서 표기다
    printf '\n`/observability:observability:observability-cost` 참조\n' >>"$CASE_DIR/docs/guides/quick-reference.md"
    # When/Then
    expect_fail '해석되지 않는 명령.*observability:observability:' ./scripts/validate-catalog.sh
}

should_fail_plugin_refs_when_subagent_type_has_no_plugin_prefix() {
    # Given: plugin 의 agent 는 접두사 없이 부를 수 없다
    # shellcheck disable=SC2016  # 백틱은 실행이 아니라 문서 표기다
    printf '\n- subagent_type: `code-reviewer`\n' >>"$CASE_DIR/$(first_asset command_files)"
    # When/Then
    expect_fail '없는 agent.*code-reviewer' ./scripts/validate-catalog.sh
}

should_fail_plugin_readme_when_stale() {
    # Given
    printf '\n손으로 고친 줄\n' >>"$CASE_DIR/plugins/dx/README.md"
    # When/Then
    expect_fail 'README 가 오래됐다.*dx' python3 scripts/generate-plugin-readmes.py validate
}

should_fail_plugin_readme_when_new_skill_is_not_listed() {
    # Given
    add_plugin_skill dx brand-new-skill
    # When/Then
    expect_fail 'README 가 오래됐다.*dx' python3 scripts/generate-plugin-readmes.py validate
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
