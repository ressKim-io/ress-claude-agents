#!/usr/bin/env bash
# 자산 위치와 개수 하한의 단일 출처.
#
# 왜 한곳에 모으는가: 스크립트마다 find/glob 을 따로 갖고 있으면, 자산을 옮기는 순간
# 일부가 "파일 0개" 를 돌려주고 그대로 통과한다. 경로와 하한은 여기서만 정의한다.
#
# 호출자는 레포 루트를 cwd 로 둔다. 출력은 루트 기준 상대 경로이며 정렬돼 있다.

# 개수 하한. 늘어나는 건 자유이고, 의도적으로 줄일 때만 같은 커밋에서 낮춘다.
# 일부만 사라져도 잡히도록 여유 없이 현재 개수로 둔다.
MIN_SKILLS=270
MIN_AGENTS=34
MIN_COMMANDS=43
MIN_RULES=26

# plugins/ 가 없으면 빈 목록을 돌려주고, 하한 검사(assert_floor)가 실패시킨다.
skill_files() {
    if [ -d plugins ]; then
        find plugins -mindepth 4 -maxdepth 4 -type f -path 'plugins/*/skills/*/SKILL.md' | LC_ALL=C sort
    fi
}

agent_files() {
    if [ -d plugins ]; then
        find plugins -type f -path 'plugins/*/agents/*.md' | LC_ALL=C sort
    fi
}

command_files() {
    if [ -d plugins ]; then
        find plugins -type f -path 'plugins/*/commands/*.md' | LC_ALL=C sort
    fi
}

rule_files() {
    if [ -d .claude/rules ]; then
        find .claude/rules -type f -name '*.md' | LC_ALL=C sort
    fi
}

# 위치와 무관하게 존재하는 모든 SKILL.md. skill_files 와 다르면 로드되지 않는 파일이 있다.
any_skill_manifests() {
    if [ -d plugins ]; then
        find plugins -type f -name SKILL.md | LC_ALL=C sort
    fi
}

# plugin 구조로 옮기기 전의 자산 위치. Claude Code 가 그대로 읽으므로 다시 생기면 조용히 섞인다.
legacy_asset_dirs() {
    local dir
    for dir in .claude/skills .claude/agents .claude/commands commands; do
        if [ -d "$dir" ]; then
            printf '%s\n' "$dir"
        fi
    done
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

# skill 의 영역은 속한 plugin 이다.
skill_area() {
    asset_plugin "$1"
}
