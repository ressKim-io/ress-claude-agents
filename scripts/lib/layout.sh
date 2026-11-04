#!/usr/bin/env bash
# 자산 위치와 개수 하한의 단일 출처.
#
# 왜 한곳에 모으는가: 스크립트마다 find/glob 을 따로 갖고 있으면, 자산을 옮기는 순간
# 일부가 "파일 0개" 를 돌려주고 그대로 통과한다. 경로와 하한은 여기서만 정의한다.
#
# 호출자는 레포 루트를 cwd 로 둔다. 출력은 루트 기준 상대 경로이며 정렬돼 있다.
# plugin 구조 전환 기간에는 .claude/ 와 plugins/ 를 함께 나열한다.

# frontmatter category 파서
# shellcheck source=scripts/lib/skill-category.sh
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/skill-category.sh"

# 개수 하한. 늘어나는 건 자유이고, 의도적으로 줄일 때만 같은 커밋에서 낮춘다.
# 일부만 사라져도 잡히도록 여유 없이 현재 개수로 둔다.
MIN_SKILLS=269
MIN_AGENTS=34
MIN_COMMANDS=43
MIN_RULES=26

skill_files() {
    {
        if [ -d .claude/skills ]; then
            find .claude/skills -mindepth 2 -maxdepth 2 -type f -name SKILL.md
        fi
        if [ -d plugins ]; then
            find plugins -mindepth 4 -maxdepth 4 -type f -path 'plugins/*/skills/*/SKILL.md'
        fi
    } | LC_ALL=C sort
}

agent_files() {
    {
        if [ -d .claude/agents ]; then
            find .claude/agents -type f -name '*.md'
        fi
        if [ -d plugins ]; then
            find plugins -type f -path 'plugins/*/agents/*.md'
        fi
    } | LC_ALL=C sort
}

# help/ 는 명령 사용 안내 문서라 명령 수에 넣지 않는다.
command_files() {
    {
        if [ -d .claude/commands ]; then
            find .claude/commands -type f -name '*.md' -not -path '.claude/commands/help/*'
        fi
        if [ -d plugins ]; then
            find plugins -type f -path 'plugins/*/commands/*.md'
        fi
    } | LC_ALL=C sort
}

rule_files() {
    if [ -d .claude/rules ]; then
        find .claude/rules -type f -name '*.md' | LC_ALL=C sort
    fi
}

# 위치와 무관하게 존재하는 모든 SKILL.md. skill_files 와 다르면 로드되지 않는 파일이 있다.
any_skill_manifests() {
    {
        if [ -d .claude/skills ]; then
            find .claude/skills -type f -name SKILL.md
        fi
        if [ -d plugins ]; then
            find plugins -type f -name SKILL.md
        fi
    } | LC_ALL=C sort
}

# $1 = rule 파일명 (예: git.md). 하위 폴더로 옮겨도 찾는다.
rule_path_by_name() {
    rule_files | awk -v name="/$1" '
        !found && substr($0, length($0) - length(name) + 1) == name { print; found = 1 }
    '
}

asset_count() {
    case "$1" in
        skills)   skill_files ;;
        agents)   agent_files ;;
        commands) command_files ;;
        rules)    rule_files ;;
        *) printf 'ERROR: 알 수 없는 자산 종류: %s\n' "$1" >&2; return 2 ;;
    esac | wc -l | tr -d ' '
}

asset_floor() {
    case "$1" in
        skills)   printf '%s\n' "$MIN_SKILLS" ;;
        agents)   printf '%s\n' "$MIN_AGENTS" ;;
        commands) printf '%s\n' "$MIN_COMMANDS" ;;
        rules)    printf '%s\n' "$MIN_RULES" ;;
        *) printf 'ERROR: 알 수 없는 자산 종류: %s\n' "$1" >&2; return 2 ;;
    esac
}

# $1 = skills|agents|commands|rules. 하한 미달이면 사유를 출력하고 1 을 반환한다.
assert_floor() {
    local kind="$1" count floor
    count=$(asset_count "$kind") || return 2
    floor=$(asset_floor "$kind") || return 2
    if [ "$count" -lt "$floor" ]; then
        printf 'FAIL  %s %s개 — 하한 %s개 미달. 자산이 사라졌거나 경로가 바뀌었다 (scripts/lib/layout.sh)\n' \
            "$kind" "$count" "$floor"
        return 1
    fi
}

# plugins/<plugin>/... 경로에서 plugin 이름을 꺼낸다. plugin 구조가 아니면 1 을 반환한다.
asset_plugin() {
    case "$1" in
        plugins/*/*)
            local rest="${1#plugins/}"
            printf '%s\n' "${rest%%/*}"
            ;;
        *) return 1 ;;
    esac
}

# skill 의 영역. plugin 구조는 경로에서, 이전 구조는 frontmatter category 에서 읽는다.
# 찾지 못하면 실패한다 — 빈 값이 "other" 나 자기 이름으로 흡수되면 조용히 틀린 목록이 된다.
skill_area() {
    local file="$1" area
    if area=$(asset_plugin "$file"); then
        printf '%s\n' "$area"
        return 0
    fi
    area=$(skill_frontmatter_category "$file")
    if [ -z "$area" ]; then
        printf 'ERROR: 영역을 알 수 없다: %s (plugins/ 밖인데 category 가 없다)\n' "$file"
        return 1
    fi
    printf '%s\n' "$area"
}
