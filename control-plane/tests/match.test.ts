import { describe, expect, it } from "vitest";
import path from "node:path";
import os from "node:os";
import { mkdtempSync, rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import {
  buildMatchContext,
  bucketScores,
  score,
  selectSkills,
  type ScoreResult,
} from "../src/match.js";
import type { LoadedSkill } from "../src/skill-loader.js";
import type { ProjectProfile } from "../src/schema/project-profile.js";
import type { SkillManifest } from "../src/schema/skill-manifest.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = (name: string): string => path.join(here, "profiles", name);

function fakeSkill(
  name: string,
  manifest: Partial<SkillManifest>,
): LoadedSkill {
  return {
    category: "test",
    dirName: name,
    sourcePath: "",
    manifest: {
      name,
      description: `Use when ${name} applies — test skill description over forty characters in length.`,
      ...manifest,
    } as SkillManifest,
  };
}

function fakeProfile(
  overrides: Partial<ProjectProfile> = {},
): ProjectProfile {
  return {
    schema_version: 1,
    generated_at: "2026-05-06T00:00:00Z",
    generator: "@ress/test",
    repo: { vcs: "none", default_branch: "main", monorepo: false },
    languages: [],
    frameworks: [],
    build_systems: [],
    files_signatures: {
      ci_provider: "none",
      dockerfile_present: false,
      helm_chart_present: false,
      k8s_manifest_present: false,
    },
    domain_hints: [],
    ...overrides,
  };
}

function fakeScored(name: string, total: number): ScoreResult {
  return {
    skill: fakeSkill(name, { applies_when: { language: ["go"] } }),
    score: total,
    components: {
      files_present: 0,
      files_contain: 0,
      language: 0,
      frameworks: 0,
      excluded: false,
    },
  };
}

describe("bucketScores", () => {
  it("partitions by install/suggest/skip thresholds", () => {
    const result = bucketScores(
      [fakeScored("a", 90), fakeScored("b", 30), fakeScored("c", 10)],
      50,
      25,
    );
    expect(result.install.map((r) => r.skill.manifest.name)).toEqual(["a"]);
    expect(result.suggest.map((r) => r.skill.manifest.name)).toEqual(["b"]);
    expect(result.skip.map((r) => r.skill.manifest.name)).toEqual(["c"]);
  });

  it("sorts each bucket by score desc, then name asc", () => {
    const result = bucketScores(
      [
        fakeScored("zeta", 80),
        fakeScored("alpha", 80),
        fakeScored("beta", 95),
      ],
      50,
      25,
    );
    expect(result.install.map((r) => r.skill.manifest.name)).toEqual([
      "beta",
      "alpha",
      "zeta",
    ]);
  });

  it("sends -Infinity (excluded) to skip", () => {
    const excluded: ScoreResult = {
      skill: fakeSkill("ex", { applies_when: { language: ["go"] } }),
      score: Number.NEGATIVE_INFINITY,
      components: {
        files_present: 0,
        files_contain: 0,
        language: 0,
        frameworks: 0,
        excluded: true,
      },
    };
    const result = bucketScores([excluded], 50, 25);
    expect(result.skip).toHaveLength(1);
  });
});

describe("score (real fixtures)", () => {
  it("score is 0 when applies_when is missing", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "match-empty-"));
    try {
      const ctx = await buildMatchContext(tmp);
      const profile = fakeProfile();
      const result = await score(fakeSkill("no-rules", {}), profile, ctx);
      expect(result.score).toBe(0);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("frameworks intersection contributes 15 (full match)", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "match-fw-"));
    try {
      const ctx = await buildMatchContext(tmp);
      const profile = fakeProfile({ frameworks: ["gin", "grpc"] });
      const skill = fakeSkill("ginny", {
        applies_when: { frameworks: ["gin"] },
      });
      const result = await score(skill, profile, ctx);
      expect(result.components.frameworks).toBe(15);
      expect(result.score).toBe(15);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("language primary match contributes exactly 20", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "match-lang-"));
    try {
      const ctx = await buildMatchContext(tmp);
      const profile = fakeProfile({
        languages: [{ name: "go", files: 10, primary: true }],
      });
      const result = await score(
        fakeSkill("go-x", { applies_when: { language: ["go"] } }),
        profile,
        ctx,
      );
      expect(result.components.language).toBe(20);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("files_present full match contributes 40 (real fixture)", async () => {
    const ctx = await buildMatchContext(fixture("k8s-only"));
    const skill = fakeSkill("helm-rule", {
      applies_when: { files_present: ["**/Chart.yaml"] },
    });
    const result = await score(skill, fakeProfile(), ctx);
    expect(result.components.files_present).toBe(40);
  });

  it("exclude_when zero-out: kustomize sibling makes skill -Infinity", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "match-excl-"));
    try {
      // create a dummy file matching exclude pattern
      const { writeFileSync } = await import("node:fs");
      writeFileSync(path.join(tmp, "kustomization.yaml"), "resources: []\n");

      const ctx = await buildMatchContext(tmp);
      const result = await score(
        fakeSkill("helm", {
          applies_when: {
            files_present: ["**/Chart.yaml"],
            exclude_when: { files_present: ["**/kustomization.yaml"] },
          },
        }),
        fakeProfile(),
        ctx,
      );
      expect(result.components.excluded).toBe(true);
      expect(result.score).toBe(Number.NEGATIVE_INFINITY);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe("selectSkills end-to-end on go-gin fixture", () => {
  it("go-gin manifest scores >= 50 against the go-gin fixture", async () => {
    const root = fixture("go-gin");
    const ctx = await buildMatchContext(root);
    const profile = fakeProfile({
      languages: [{ name: "go", files: 2, primary: true }],
      frameworks: ["gin"],
    });
    const ginSkill = fakeSkill("go-gin", {
      applies_when: {
        files_present: ["**/go.mod"],
        files_contain: { "**/go.mod": "gin-gonic/gin" },
        language: ["go"],
        frameworks: ["gin"],
      },
    });
    const result = await selectSkills([ginSkill], profile, ctx);
    expect(result.install).toHaveLength(1);
    expect(result.install[0]?.score).toBeGreaterThanOrEqual(50);
  });
});
