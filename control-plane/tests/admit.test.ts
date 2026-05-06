import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { admit, globToRegex, matchGlob } from "../src/admit.js";

function makeTestRoot(): string {
  return mkdtempSync(path.join(os.tmpdir(), "admit-"));
}

function writeSkill(
  assetsRoot: string,
  category: string,
  name: string,
  frontmatter: string,
): void {
  const dir = path.join(assetsRoot, "skills", category, name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(
    path.join(dir, "SKILL.md"),
    `---\n${frontmatter}\n---\n\n# Body\n`,
  );
}

const HELM_FRONTMATTER = String.raw`name: helm-edit
description: "Use when modifying Helm charts (Chart.yaml, templates/*.tpl, values*.yaml). Skip when kustomize is the deployment tool."
applies_when:
  files_present:
    - "**/Chart.yaml"
    - "**/values*.yaml"
  files_contain:
    "**/Chart.yaml": '^apiVersion:\s*v[12]'`;

const READ_ONLY_FRONTMATTER = String.raw`name: review-only
description: "Use when reviewing code without making changes. This skill is read-only and admission denies all Edit/Write attempts."
applies_when:
  files_present: ["**/*.md"]
security:
  sandbox: read-only`;

describe("admit — deny cases (P5 verification gate)", () => {
  it("DENY when applies_when.files_present does not match path", async () => {
    const tmp = makeTestRoot();
    try {
      writeSkill(tmp, "kubernetes", "helm-edit", HELM_FRONTMATTER);
      // path outside files_present patterns
      const result = await admit({
        tool: "Edit",
        path: "src/main.go",
        skill: "helm-edit",
        root: tmp,
        assets: tmp,
      });
      expect(result.allow).toBe(false);
      expect(result.reason).toContain("does not match");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("DENY when security.sandbox is read-only and tool is mutating", async () => {
    const tmp = makeTestRoot();
    try {
      writeSkill(tmp, "review", "review-only", READ_ONLY_FRONTMATTER);
      const result = await admit({
        tool: "Write",
        path: "docs/notes.md",
        skill: "review-only",
        root: tmp,
        assets: tmp,
      });
      expect(result.allow).toBe(false);
      expect(result.reason).toContain("read-only");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("DENY when files_contain glob matches but regex does not", async () => {
    const tmp = makeTestRoot();
    try {
      writeSkill(tmp, "kubernetes", "helm-edit", HELM_FRONTMATTER);
      // Chart.yaml exists but apiVersion is "v3" → regex ^apiVersion:\s*v[12] fails.
      // Path matches files_contain glob but does NOT match files_present
      // (we use a non-Chart.yaml glob to avoid files_present short-circuit).
      const chartPath = path.join(tmp, "templates", "deployment.yaml");
      mkdirSync(path.dirname(chartPath), { recursive: true });
      writeFileSync(chartPath, "kind: Deployment\n");

      // Custom skill: files_contain points to deployment.yaml requiring "ImpossibleKind"
      writeSkill(
        tmp,
        "kubernetes",
        "deploy-strict",
        String.raw`name: deploy-strict
description: "Use when modifying Kubernetes deployments — required content kind ImpossibleKind which never matches real charts (synthetic regex-miss case)."
applies_when:
  files_contain:
    "**/deployment.yaml": '^kind:\s*ImpossibleKind'`,
      );

      const result = await admit({
        tool: "Edit",
        path: "templates/deployment.yaml",
        skill: "deploy-strict",
        root: tmp,
        assets: tmp,
      });
      expect(result.allow).toBe(false);
      expect(result.reason).toContain("does not match");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("admit — allow cases (P5 verification gate)", () => {
  it("ALLOW when applies_when.files_present matches", async () => {
    const tmp = makeTestRoot();
    try {
      writeSkill(tmp, "kubernetes", "helm-edit", HELM_FRONTMATTER);
      const result = await admit({
        tool: "Edit",
        path: "charts/myapp/Chart.yaml",
        skill: "helm-edit",
        root: tmp,
        assets: tmp,
      });
      expect(result.allow).toBe(true);
      expect(result.reason).toContain("files_present");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("ALLOW when tool is read-only (Read/Glob/Grep/Bash)", async () => {
    const tmp = makeTestRoot();
    try {
      writeSkill(tmp, "review", "review-only", READ_ONLY_FRONTMATTER);
      const result = await admit({
        tool: "Read",
        path: "src/main.go",
        skill: "review-only",
        root: tmp,
        assets: tmp,
      });
      expect(result.allow).toBe(true);
      expect(result.reason).toContain("read-only");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("ALLOW when no active skill (skill-aware admission is P6+)", async () => {
    const tmp = makeTestRoot();
    try {
      const result = await admit({
        tool: "Edit",
        path: "src/main.go",
        root: tmp,
        assets: tmp,
      });
      expect(result.allow).toBe(true);
      expect(result.reason).toContain("no active skill");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("admit — globToRegex unit", () => {
  it("matches **/Chart.yaml across nested paths", () => {
    expect(matchGlob("Chart.yaml", "**/Chart.yaml")).toBe(true);
    expect(matchGlob("charts/myapp/Chart.yaml", "**/Chart.yaml")).toBe(true);
    expect(matchGlob("a/b/c/Chart.yaml", "**/Chart.yaml")).toBe(true);
  });

  it("matches **/*.go but not **/*.ts", () => {
    expect(matchGlob("src/main.go", "**/*.go")).toBe(true);
    expect(matchGlob("src/main.ts", "**/*.go")).toBe(false);
  });

  it("escapes regex special chars in literal segments", () => {
    expect(matchGlob("a.b.c", "a.b.c")).toBe(true);
    expect(matchGlob("axbxc", "a.b.c")).toBe(false);
    expect(globToRegex("**/*.yaml").test("k8s/config.yaml")).toBe(true);
  });
});
