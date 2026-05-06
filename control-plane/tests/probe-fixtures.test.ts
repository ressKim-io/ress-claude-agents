import { describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import crypto from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import os from "node:os";
import { stringify } from "yaml";
import { probe } from "../src/probe.js";
import { ProjectProfile } from "../src/schema/project-profile.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const FROZEN_TIME = "2026-05-06T10:00:00Z";

const fixture = (name: string): string => path.join(here, "profiles", name);

describe("probe fixtures", () => {
  it("go-gin: gin + go-modules + dockerfile + github-actions + domain hints", async () => {
    const result = await probe({
      root: fixture("go-gin"),
      frozenTime: FROZEN_TIME,
    });

    expect(ProjectProfile.safeParse(result).success).toBe(true);

    const goLang = result.languages.find((l) => l.name === "go");
    expect(goLang).toBeDefined();
    expect(goLang?.primary).toBe(true);

    expect(result.frameworks).toContain("gin");
    expect(result.build_systems).toContain("go-modules");
    expect(result.files_signatures.dockerfile_present).toBe(true);
    expect(result.files_signatures.helm_chart_present).toBe(false);
    expect(result.files_signatures.k8s_manifest_present).toBe(false);
    expect(result.files_signatures.ci_provider).toBe("github-actions");

    expect(result.domain_hints).toContain("api-gateway");
    expect(result.domain_hints).toContain("health-check");
  });

  it("k8s-only: helm + k8s manifest, no dockerfile, no CI", async () => {
    const result = await probe({
      root: fixture("k8s-only"),
      frozenTime: FROZEN_TIME,
    });

    expect(ProjectProfile.safeParse(result).success).toBe(true);
    expect(result.frameworks).toContain("helm");
    expect(result.build_systems).toContain("helm");
    expect(result.files_signatures.helm_chart_present).toBe(true);
    expect(result.files_signatures.k8s_manifest_present).toBe(true);
    expect(result.files_signatures.dockerfile_present).toBe(false);
    expect(result.files_signatures.ci_provider).toBe("none");
    expect(result.domain_hints).toContain("microservice-deployment");
  });

  it("empty directory yields an empty profile shape", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "probe-empty-"));
    try {
      const result = await probe({ root: tmp, frozenTime: FROZEN_TIME });
      expect(ProjectProfile.safeParse(result).success).toBe(true);
      expect(result.languages).toEqual([]);
      expect(result.frameworks).toEqual([]);
      expect(result.build_systems).toEqual([]);
      expect(result.files_signatures.helm_chart_present).toBe(false);
      expect(result.files_signatures.dockerfile_present).toBe(false);
      expect(result.files_signatures.k8s_manifest_present).toBe(false);
      expect(result.files_signatures.ci_provider).toBe("none");
      expect(result.domain_hints).toEqual([]);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("frozenTime makes generated_at predictable", async () => {
    const result = await probe({
      root: fixture("go-gin"),
      frozenTime: FROZEN_TIME,
    });
    expect(result.generated_at).toBe(FROZEN_TIME);
  });

  it("produces deterministic yaml across 10 runs (same input → same hash)", async () => {
    const hashes = new Set<string>();
    for (let i = 0; i < 10; i++) {
      const result = await probe({
        root: fixture("go-gin"),
        frozenTime: FROZEN_TIME,
      });
      const yaml = stringify(result, { sortMapEntries: true });
      hashes.add(crypto.createHash("sha256").update(yaml).digest("hex"));
    }
    expect(hashes.size).toBe(1);
  });

  it("missing root throws and probe rejects (caught at CLI layer)", async () => {
    await expect(
      probe({ root: "/this/path/should/not/exist/zzzz" }),
    ).rejects.toThrow(/does not exist/);
  });
});
