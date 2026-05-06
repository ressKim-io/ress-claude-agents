import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { parse as parseYaml } from "yaml";
import { adapter } from "../src/adapter.js";
import { extractFrontmatter } from "../src/skill-loader.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(here, "../..");

interface CodexAgentParsed {
  name: string;
  description: string;
  body: string;
}

function parseCodexAgentToml(toml: string): CodexAgentParsed {
  const desc = /^description = "((?:[^"\\]|\\.)*)"$/m.exec(toml);
  if (!desc) throw new Error("description not found");
  const name = /^name = "((?:[^"\\]|\\.)*)"$/m.exec(toml);
  if (!name) throw new Error("name not found");
  const body = /^developer_instructions = (?:'''|""")\n([\s\S]*?)\n(?:'''|""")$/m.exec(
    toml,
  );
  if (!body) throw new Error("developer_instructions not found");
  return {
    name: unescapeBasic(name[1]!),
    description: unescapeBasic(desc[1]!),
    body: body[1]!,
  };
}

function parseManifestYamlField(toml: string): string {
  const m = /^manifest_yaml = (?:'''|""")\n([\s\S]*?)\n(?:'''|""")$/m.exec(toml);
  if (!m) throw new Error("manifest_yaml not found");
  return m[1]!;
}

function unescapeBasic(s: string): string {
  return s
    .replace(/\\n/g, "\n")
    .replace(/\\r/g, "\r")
    .replace(/\\t/g, "\t")
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, "\\");
}

function makeTestRoot(): string {
  return mkdtempSync(path.join(os.tmpdir(), "adapter-"));
}

function copyAgent(tmp: string, name: string): string {
  const src = path.join(REPO_ROOT, ".claude", "agents", `${name}.md`);
  const dest = path.join(tmp, ".claude", "agents", `${name}.md`);
  mkdirSync(path.dirname(dest), { recursive: true });
  cpSync(src, dest);
  return dest;
}

function copySkill(tmp: string, category: string, name: string): string {
  const src = path.join(REPO_ROOT, "assets", "skills", category, name);
  const dest = path.join(tmp, "assets", "skills", category, name);
  mkdirSync(path.dirname(dest), { recursive: true });
  cpSync(src, dest, { recursive: true });
  return dest;
}

function readBodyFromMarkdown(filePath: string): string {
  const raw = readFileSync(filePath, "utf8");
  const lines = raw.split(/\r?\n/);
  if (lines[0] !== "---") return raw;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") {
      return lines.slice(i + 1).join("\n");
    }
  }
  return raw;
}

describe("adapter --tool=codex (agent round-trip)", () => {
  it("converts .claude/agents/<n>.md to .codex/agents/<n>.toml with parse-equal data", async () => {
    // Given
    const tmp = makeTestRoot();
    try {
      const agentSource = copyAgent(tmp, "code-reviewer");

      // When
      const result = await adapter({
        tool: "codex",
        root: tmp,
        assets: path.join(tmp, "assets"),
        mode: "write",
      });

      // Then
      const generatedPath = path.join(
        tmp,
        ".codex",
        "agents",
        "code-reviewer.toml",
      );
      expect(existsSync(generatedPath)).toBe(true);

      const generated = readFileSync(generatedPath, "utf8");
      const parsed = parseCodexAgentToml(generated);

      const sourceRaw = readFileSync(agentSource, "utf8");
      const fmRaw = extractFrontmatter(sourceRaw) ?? "";
      const sourceFm = parseYaml(fmRaw) as {
        name: string;
        description: string;
      };
      const sourceBody = readBodyFromMarkdown(agentSource);

      expect(parsed.name).toBe(sourceFm.name);
      expect(parsed.description).toBe(sourceFm.description);
      expect(parsed.body).toBe(sourceBody);

      const codexChange = result.changes.find(
        (c) => c.path === ".codex/agents/code-reviewer.toml",
      );
      expect(codexChange?.status).toBe("create");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("re-running adapter produces unchanged status (idempotent)", async () => {
    const tmp = makeTestRoot();
    try {
      copyAgent(tmp, "code-reviewer");
      await adapter({ tool: "codex", root: tmp, assets: path.join(tmp, "assets"), mode: "write" });
      const second = await adapter({
        tool: "codex",
        root: tmp,
        assets: path.join(tmp, "assets"),
        mode: "write",
      });
      const codexChange = second.changes.find(
        (c) => c.path === ".codex/agents/code-reviewer.toml",
      );
      expect(codexChange?.status).toBe("unchanged");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("adapter --tool=codex (skill view)", () => {
  it("emits .codex/skills/<cat>/<n>.toml with manifest_yaml preserving 9 keys", async () => {
    const tmp = makeTestRoot();
    try {
      const skillSrc = copySkill(tmp, "kubernetes", "k8s-helm");

      await adapter({ tool: "codex", root: tmp, assets: path.join(tmp, "assets"), mode: "write" });

      const generated = path.join(
        tmp,
        ".codex",
        "skills",
        "kubernetes",
        "k8s-helm.toml",
      );
      expect(existsSync(generated)).toBe(true);

      const toml = readFileSync(generated, "utf8");
      const parsed = parseCodexAgentToml(toml);
      const fmYaml = parseManifestYamlField(toml);
      const fm = parseYaml(fmYaml) as Record<string, unknown>;

      expect(parsed.name).toBe("k8s-helm");
      expect(fm.applies_when).toBeDefined();
      expect(fm.portability).toBeDefined();
      expect(fm.produces).toEqual(["helm-chart"]);
      expect(fm.consumes).toEqual(["k8s-manifest", "service-boundary"]);
      expect(fm.security).toBeDefined();
      expect(fm.version).toBe("1.0.0");
      expect(fm.license).toBe("MIT");

      const sourceBody = readBodyFromMarkdown(
        path.join(skillSrc, "SKILL.md"),
      );
      expect(parsed.body).toBe(sourceBody);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("adapter --tool=cursor", () => {
  it("emits .cursor/rules/<n>.mdc with globs from applies_when.files_present", async () => {
    const tmp = makeTestRoot();
    try {
      copySkill(tmp, "kubernetes", "k8s-helm");

      await adapter({ tool: "cursor", root: tmp, assets: path.join(tmp, "assets"), mode: "write" });

      const generated = path.join(tmp, ".cursor", "rules", "k8s-helm.mdc");
      expect(existsSync(generated)).toBe(true);

      const mdc = readFileSync(generated, "utf8");
      expect(mdc.startsWith("---\n")).toBe(true);

      const fmRaw = mdc.split(/\r?\n/).slice(1);
      const fmEnd = fmRaw.indexOf("---");
      const fm = parseYaml(fmRaw.slice(0, fmEnd).join("\n")) as {
        description: string;
        globs: string[];
        alwaysApply: boolean;
      };

      expect(fm.alwaysApply).toBe(false);
      expect(fm.globs).toEqual([
        "**/Chart.yaml",
        "**/values*.yaml",
        "**/templates/*.tpl",
        "**/templates/*.yaml",
      ]);
      expect(fm.description).toContain("Helm");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("emits empty globs array when applies_when.files_present is missing", async () => {
    const tmp = makeTestRoot();
    try {
      // Build a synthetic skill without files_present (only frameworks).
      const skillDir = path.join(
        tmp,
        "assets",
        "skills",
        "synthetic",
        "synth-only-frameworks",
      );
      mkdirSync(skillDir, { recursive: true });
      const fm = [
        "---",
        "name: synth-only-frameworks",
        'description: "Synthetic skill used to verify cursor adapter handles missing files_present gracefully and still emits a valid frontmatter."',
        "applies_when:",
        "  frameworks:",
        "    - made-up-framework",
        "---",
        "",
        "# Body",
        "",
      ].join("\n");
      writeFileSync(path.join(skillDir, "SKILL.md"), fm);

      await adapter({ tool: "cursor", root: tmp, assets: path.join(tmp, "assets"), mode: "write" });

      const generated = path.join(
        tmp,
        ".cursor",
        "rules",
        "synth-only-frameworks.mdc",
      );
      expect(existsSync(generated)).toBe(true);
      const mdc = readFileSync(generated, "utf8");
      expect(mdc).toContain("globs: []");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("adapter --tool=claude", () => {
  it("copies assets/skills/<cat>/<n>/SKILL.md to .claude/skills/<cat>/<n>/SKILL.md byte-equal", async () => {
    const tmp = makeTestRoot();
    try {
      const skillSrc = copySkill(tmp, "kubernetes", "k8s-helm");

      await adapter({ tool: "claude", root: tmp, assets: path.join(tmp, "assets"), mode: "write" });

      const generated = path.join(
        tmp,
        ".claude",
        "skills",
        "kubernetes",
        "k8s-helm",
        "SKILL.md",
      );
      expect(existsSync(generated)).toBe(true);
      expect(readFileSync(generated, "utf8")).toBe(
        readFileSync(path.join(skillSrc, "SKILL.md"), "utf8"),
      );
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("adapter mode=dry-run", () => {
  it("does not write files but reports planned changes", async () => {
    const tmp = makeTestRoot();
    try {
      copySkill(tmp, "kubernetes", "k8s-helm");

      const result = await adapter({
        tool: "cursor",
        root: tmp,
        assets: path.join(tmp, "assets"),
        mode: "dry-run",
      });

      const generated = path.join(tmp, ".cursor", "rules", "k8s-helm.mdc");
      expect(existsSync(generated)).toBe(false);
      const change = result.changes.find(
        (c) => c.path === ".cursor/rules/k8s-helm.mdc",
      );
      expect(change?.status).toBe("create");
      expect(change?.content.length ?? 0).toBeGreaterThan(0);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("adapter determinism", () => {
  it("produces identical bytes across 10 runs (codex skill)", async () => {
    const tmp = makeTestRoot();
    try {
      copySkill(tmp, "kubernetes", "k8s-helm");

      const outputs = new Set<string>();
      for (let i = 0; i < 10; i++) {
        const result = await adapter({
          tool: "codex",
          root: tmp,
          assets: path.join(tmp, "assets"),
          mode: "dry-run",
        });
        const change = result.changes.find(
          (c) => c.path === ".codex/skills/kubernetes/k8s-helm.toml",
        );
        outputs.add(change?.content ?? "");
      }
      expect(outputs.size).toBe(1);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});
