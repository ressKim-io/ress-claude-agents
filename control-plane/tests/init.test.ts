import crypto from "node:crypto";
import {
  cpSync,
  mkdtempSync,
  readFileSync,
  rmSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { parse as parseYaml } from "yaml";
import { init } from "../src/init.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(here, "../..");
const ASSETS_ROOT = path.join(REPO_ROOT, "assets");
const FROZEN_TIME = "2026-05-06T10:00:00Z";

interface FixtureCase {
  name: "go-gin" | "k8s-only" | "empty";
  source: string | null;
  expectedInstall: string[];
}

const FIXTURES: FixtureCase[] = [
  {
    name: "go-gin",
    source: path.join(here, "profiles/go-gin"),
    expectedInstall: ["go-gin", "go-microservice"],
  },
  {
    name: "k8s-only",
    source: path.join(here, "profiles/k8s-only"),
    expectedInstall: ["k8s-helm"],
  },
  {
    name: "empty",
    source: null,
    expectedInstall: [],
  },
];

function makeFixtureRoot(c: FixtureCase): string {
  const tmp = mkdtempSync(path.join(os.tmpdir(), `init-${c.name}-`));
  if (c.source) cpSync(c.source, tmp, { recursive: true });
  return tmp;
}

async function runOnce(
  c: FixtureCase,
): Promise<{ profile: string; lock: string }> {
  const root = makeFixtureRoot(c);
  try {
    await init({
      root,
      assets: ASSETS_ROOT,
      frozenTime: FROZEN_TIME,
      yes: true,
    });
    return {
      profile: readFileSync(path.join(root, "project-profile.yml"), "utf8"),
      lock: readFileSync(path.join(root, ".claude-agents.yml"), "utf8"),
    };
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function sha256(s: string): string {
  return crypto.createHash("sha256").update(s).digest("hex");
}

interface ParsedLock {
  schema_version: number;
  skills: { install: { name: string }[]; skip_count: number };
  threshold: number;
  adapters: { status: string };
  hook: { status: string };
}

describe.each(FIXTURES)("init on fixture: $name", (fixture) => {
  it("writes project-profile.yml and .claude-agents.yml", async () => {
    const out = await runOnce(fixture);
    expect(out.profile.length).toBeGreaterThan(0);
    expect(out.lock.length).toBeGreaterThan(0);
  });

  it("lock file install names match expected set", async () => {
    const out = await runOnce(fixture);
    const lock = parseYaml(out.lock) as ParsedLock;
    const installNames = lock.skills.install
      .map((s) => s.name)
      .slice()
      .sort();
    expect(installNames).toEqual(fixture.expectedInstall.slice().sort());
  });

  it("lock carries P4/P5 stub markers + threshold default 50", async () => {
    const out = await runOnce(fixture);
    const lock = parseYaml(out.lock) as ParsedLock;
    expect(lock.schema_version).toBe(1);
    expect(lock.threshold).toBe(50);
    expect(lock.adapters.status).toBe("p4-stub");
    expect(lock.hook.status).toBe("p5-stub");
  });

  it("produces deterministic outputs across 10 runs (P3 gate)", async () => {
    const profileHashes = new Set<string>();
    const lockHashes = new Set<string>();
    for (let i = 0; i < 10; i++) {
      const out = await runOnce(fixture);
      profileHashes.add(sha256(out.profile));
      lockHashes.add(sha256(out.lock));
    }
    expect(profileHashes.size).toBe(1);
    expect(lockHashes.size).toBe(1);
  });
});

describe("init dry-run", () => {
  it("does not write files when --dry-run is set", async () => {
    const fx = FIXTURES[0]!;
    const root = makeFixtureRoot(fx);
    try {
      const result = await init({
        root,
        assets: ASSETS_ROOT,
        frozenTime: FROZEN_TIME,
        dryRun: true,
      });
      expect(result.paths.profile).toBeUndefined();
      expect(result.paths.lock).toBeUndefined();
      expect(() =>
        readFileSync(path.join(root, "project-profile.yml")),
      ).toThrow();
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  });
});
