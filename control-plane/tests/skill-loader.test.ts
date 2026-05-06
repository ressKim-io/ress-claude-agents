import { describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { extractFrontmatter, loadSkills } from "../src/skill-loader.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(here, "../..");
const ASSETS_ROOT = path.join(REPO_ROOT, "assets");

describe("extractFrontmatter", () => {
  it("returns null when content does not start with ---", () => {
    expect(extractFrontmatter("# title\nbody")).toBeNull();
  });

  it("returns null when closing --- is missing", () => {
    expect(extractFrontmatter("---\nname: x\nbody")).toBeNull();
  });

  it("returns the frontmatter slice between two --- lines", () => {
    const fm = extractFrontmatter(
      "---\nname: foo\nversion: 1.0.0\n---\n# body\n",
    );
    expect(fm).toBe("name: foo\nversion: 1.0.0");
  });

  it("handles CRLF line endings", () => {
    expect(extractFrontmatter("---\r\nname: x\r\n---\r\nbody")).toBe(
      "name: x",
    );
  });
});

describe("loadSkills (PoC assets)", () => {
  it("loads all 10 PoC skills with no issues", async () => {
    const result = await loadSkills(ASSETS_ROOT);
    expect(result.issues).toEqual([]);
    expect(result.skills).toHaveLength(10);
  });

  it("each skill's manifest.name matches its directory name", async () => {
    const { skills } = await loadSkills(ASSETS_ROOT);
    for (const s of skills) {
      expect(s.manifest.name).toBe(s.dirName);
    }
  });

  it("skills are sorted by (category, name)", async () => {
    const { skills } = await loadSkills(ASSETS_ROOT);
    const keys = skills.map((s) => `${s.category}/${s.manifest.name}`);
    expect(keys).toEqual([...keys].sort());
  });

  it("includes both go and kubernetes categories", async () => {
    const { skills } = await loadSkills(ASSETS_ROOT);
    const cats = new Set(skills.map((s) => s.category));
    expect(cats.has("go")).toBe(true);
    expect(cats.has("kubernetes")).toBe(true);
  });

  it("k8s-helm declares frameworks=[helm] and applies_when.files_present", async () => {
    const { skills } = await loadSkills(ASSETS_ROOT);
    const helm = skills.find((s) => s.manifest.name === "k8s-helm");
    expect(helm).toBeDefined();
    expect(helm?.manifest.applies_when?.frameworks).toContain("helm");
    expect(helm?.manifest.applies_when?.files_present).toContain(
      "**/Chart.yaml",
    );
  });

  it("go-gin declares language=[go] and frameworks=[gin]", async () => {
    const { skills } = await loadSkills(ASSETS_ROOT);
    const gin = skills.find((s) => s.manifest.name === "go-gin");
    expect(gin?.manifest.applies_when?.language).toContain("go");
    expect(gin?.manifest.applies_when?.frameworks).toContain("gin");
  });

  it("returns empty result for an assets root with no skills", async () => {
    const result = await loadSkills(path.join(REPO_ROOT, "control-plane"));
    expect(result.skills).toEqual([]);
    expect(result.issues).toEqual([]);
  });
});
