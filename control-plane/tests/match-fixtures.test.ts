import { beforeAll, describe, expect, it } from "vitest";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import { parse as parseYaml } from "yaml";
import { probe } from "../src/probe.js";
import { buildMatchContext, selectSkills } from "../src/match.js";
import { loadSkills } from "../src/skill-loader.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(here, "../..");
const ASSETS_ROOT = path.join(REPO_ROOT, "assets");
const EXPECTED_DIR = path.join(here, "expected");
const FROZEN_TIME = "2026-05-06T10:00:00Z";

interface Expected {
  install: string[];
  suggest: string[];
}

function readExpected(name: string): Expected {
  const raw = readFileSync(path.join(EXPECTED_DIR, `${name}.yml`), "utf8");
  const data = parseYaml(raw) as { install?: string[]; suggest?: string[] };
  return { install: data.install ?? [], suggest: data.suggest ?? [] };
}

interface MatchOutcome {
  fixture: string;
  installNames: string[];
  expected: Expected;
}

async function runFixture(
  fixture: string,
  root: string,
): Promise<MatchOutcome> {
  const profile = await probe({ root, frozenTime: FROZEN_TIME });
  const ctx = await buildMatchContext(root);
  const { skills } = await loadSkills(ASSETS_ROOT);
  const result = await selectSkills(skills, profile, ctx);
  const installNames = result.install
    .map((r) => r.skill.manifest.name)
    .sort();
  return { fixture, installNames, expected: readExpected(fixture) };
}

describe("match fixtures (gold dataset)", () => {
  let outcomes: MatchOutcome[] = [];
  let emptyTmp = "";

  beforeAll(async () => {
    emptyTmp = mkdtempSync(path.join(os.tmpdir(), "gold-empty-"));
    outcomes = await Promise.all([
      runFixture("go-gin", path.join(here, "profiles/go-gin")),
      runFixture("k8s-only", path.join(here, "profiles/k8s-only")),
      runFixture("empty", emptyTmp),
    ]);
    rmSync(emptyTmp, { recursive: true, force: true });
  });

  it.each(["go-gin", "k8s-only", "empty"])(
    "%s install set matches expected",
    (name) => {
      const outcome = outcomes.find((o) => o.fixture === name);
      expect(outcome).toBeDefined();
      const expectedSorted = outcome!.expected.install.slice().sort();
      expect(outcome!.installNames).toEqual(expectedSorted);
    },
  );

  it("aggregate precision >= 0.9 and recall >= 0.85 (P3 gate)", () => {
    expect(outcomes).toHaveLength(3);
    let tp = 0;
    let fp = 0;
    let fn = 0;
    for (const o of outcomes) {
      const expected = new Set(o.expected.install);
      const actual = new Set(o.installNames);
      for (const a of actual) {
        if (expected.has(a)) tp++;
        else fp++;
      }
      for (const e of expected) {
        if (!actual.has(e)) fn++;
      }
    }
    const precision = tp + fp === 0 ? 1 : tp / (tp + fp);
    const recall = tp + fn === 0 ? 1 : tp / (tp + fn);

    // Surface the metric in the test name on failure.
    expect(precision, `precision ${precision} (TP=${tp} FP=${fp})`).toBeGreaterThanOrEqual(0.9);
    expect(recall, `recall ${recall} (TP=${tp} FN=${fn})`).toBeGreaterThanOrEqual(0.85);
  });
});
