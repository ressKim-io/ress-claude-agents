#!/usr/bin/env python3
"""plugins/<plugin>/README.md 를 자산 frontmatter 에서 생성한다.

왜 생성하는가: 무엇을 가져갈지 판단하는 첫 화면이 이 파일이다. 손으로 쓴 목록과 개수는
반드시 drift 한다 (AGENTS.md §개수를 산문에 쓰지 않는다). CI 가 신선도를 검사한다.

사용:
  scripts/generate-plugin-readmes.py generate
  scripts/generate-plugin-readmes.py validate   # 다르면 exit 1
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
REPO = "ressKim-io/ress-claude-agents"
BLOB_URL = f"https://github.com/{REPO}/blob/main/"
RULE_URL = f"{BLOB_URL}.claude/rules/"

# plugin 은 rule 을 실을 수 없다 (2026-11-04 공식 docs). 함께 가져갈 rule 을 안내한다.
RULES = {
    "dx": ["core/workflow.md", "core/git.md", "core/security.md", "process/code-review.md",
           "process/debugging.md", "process/testing.md", "process/documentation.md",
           "process/phase-workflow.md"],
    "devlog": ["process/devlog-lifecycle.md"],
    "go": ["lang/go.md"],
    "java": ["lang/java.md", "lang/spring.md"],
    "k8s": ["infra/k8s-manifest.md", "infra/version-compatibility.md", "core/user-approval.md"],
    "service-mesh": ["infra/istio.md"],
    "infra": ["infra/terraform.md", "core/cloud-cli-safety.md"],
    "cicd": ["core/user-approval.md"],
    "observability": ["infra/monitoring.md"],
    "security": ["core/security.md"],
}
# 다른 plugin 없이는 동작하지 않는 자산. "함께 쓰면 좋은" 정도가 아니라 호출이 실패한다.
REQUIRES = {
    "dx": "`/dx:review-pr-terraform` 은 `infra` 의 `terraform-reviewer` 와 `sre` 의 `cost-analyzer` 를 호출한다. "
          "이 명령을 쓰려면 두 plugin 도 설치한다.",
}
SUMMARY_LIMIT = 110


def read_description(path):
    lines = path.read_text(encoding="utf8").split("\n")
    if not lines or lines[0] != "---":
        return ""
    for index, line in enumerate(lines[1:], 1):
        if line == "---":
            return ""
        match = re.match(r"description:\s*(.*)$", line)
        if not match:
            continue
        value = match.group(1).strip()
        if value and value[0] not in "|>":
            return value.strip("\"'")
        block = []
        for follow in lines[index + 1:]:
            if follow == "---" or (follow and not follow[0].isspace()):
                break
            block.append(follow.strip())
        return " ".join(part for part in block if part)
    return ""


def summarize(description):
    text = re.split(r"\s*(?:Use when|Use PROACTIVELY|Use for|Use to)\b", description, maxsplit=1)[0].strip()
    text = text.rstrip(".").replace("|", "\\|")
    if len(text) > SUMMARY_LIMIT:
        text = text[:SUMMARY_LIMIT].rsplit(" ", 1)[0] + " …"
    return text


def table(title, prefix, entries):
    if not entries:
        return ""
    rows = "\n".join(f"| `{prefix}{name}` | {summarize(desc)} |" for name, desc in entries)
    return f"\n## {title} ({len(entries)})\n\n| 이름 | 설명 |\n|---|---|\n{rows}\n"


def plugin_assets(plugin):
    plugin_dir = ROOT / "plugins" / plugin
    names = {p.parent.name for p in plugin_dir.glob("skills/*/SKILL.md")}
    names |= {p.stem for p in plugin_dir.glob("agents/*.md")}
    names |= {p.stem for p in plugin_dir.glob("commands/*.md")}
    return names


def related_plugins(plugin_dir, name, known):
    assets = {plugin: plugin_assets(plugin) for plugin in known}
    counts = {}
    for path in plugin_dir.rglob("*.md"):
        if path.name == "README.md":
            continue
        for other, asset in re.findall(r"(?<![\w/.-])/?([a-z0-9-]+):([a-z0-9-]+)", path.read_text(encoding="utf8")):
            if other != name and asset in assets.get(other, ()):
                counts[other] = counts.get(other, 0) + 1
    ordered = sorted(counts, key=lambda other: (-counts[other], other))
    return ordered


def render(entry, known):
    name = entry["name"]
    plugin_dir = ROOT / "plugins" / name
    manifest = json.loads((plugin_dir / ".claude-plugin" / "plugin.json").read_text(encoding="utf8"))

    skills = [(p.parent.name, read_description(p)) for p in sorted(plugin_dir.glob("skills/*/SKILL.md"))]
    agents = [(p.stem, read_description(p)) for p in sorted(plugin_dir.glob("agents/*.md"))]
    commands = [(p.stem, read_description(p)) for p in sorted(plugin_dir.glob("commands/*.md"))]

    out = [
        "<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->",
        f"# {name}",
        "",
        manifest.get("description", ""),
        "",
        "## 설치",
        "",
        "```",
        f"/plugin marketplace add {REPO}",
        f"/plugin install {name}@ress",
        "```",
        "",
        "하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.",
        "",
        "```",
        f"cp -r plugins/{name}/skills/<이름> <프로젝트>/.claude/skills/",
        "```",
    ]

    if name in REQUIRES:
        out += ["", "## 필요한 plugin", "", REQUIRES[name]]

    related = related_plugins(plugin_dir, name, known)
    if related:
        out += ["", "## 함께 쓰면 좋은 plugin", "", "본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.", ""]
        out += [f"- [`{other}`]({BLOB_URL}plugins/{other}/README.md)" for other in related]

    out += ["", "## 설치본에 포함되지 않는 것", ""]
    rules = RULES.get(name, [])
    if rules:
        out.append("**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.")
        out.append("")
        out += [f"- [`{rule}`]({RULE_URL}{rule})" for rule in rules]
        out.append("")
    out.append("**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.")

    body = "\n".join(out) + "\n"
    body += table("Skills", f"/{name}:", skills)
    body += table("Agents", f"{name}:", agents)
    body += table("Commands", f"/{name}:", commands)
    return body


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "generate"
    if mode not in ("generate", "validate"):
        sys.exit(f"unknown mode: {mode}")
    marketplace = json.loads((ROOT / ".claude-plugin" / "marketplace.json").read_text(encoding="utf8"))
    entries = marketplace["plugins"]
    if not entries:
        sys.exit("FAIL  marketplace 에 plugin 이 없다")
    known = {entry["name"] for entry in entries}

    stale = []
    for entry in entries:
        target = ROOT / "plugins" / entry["name"] / "README.md"
        body = render(entry, known)
        current = target.read_text(encoding="utf8") if target.exists() else None
        if current == body:
            continue
        if mode == "generate":
            target.write_text(body, encoding="utf8")
        else:
            stale.append(entry["name"])

    if stale:
        print(f"FAIL  plugin README 가 오래됐다: {', '.join(stale)}. 실행: scripts/generate-plugin-readmes.py generate")
        sys.exit(1)
    print(f"OK  plugin README {len(entries)}개 {'생성' if mode == 'generate' else '최신'}")


if __name__ == "__main__":
    main()
