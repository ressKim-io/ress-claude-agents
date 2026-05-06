import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { lint } from "../src/lint.js";

function tmpRoot(): string {
  return mkdtempSync(path.join(os.tmpdir(), "lint-"));
}

function addScript(root: string, name: string, body: string): void {
  const dir = path.join(root, "scripts");
  mkdirSync(dir, { recursive: true });
  const file = path.join(dir, name);
  writeFileSync(file, `#!/usr/bin/env bash\n${body}\n`);
  chmodSync(file, 0o755);
}

describe("lint", () => {
  it("returns empty result when no scripts/validate-*.sh exists", async () => {
    const tmp = tmpRoot();
    try {
      const out = await lint({ root: tmp });
      expect(out.results).toEqual([]);
      expect(out.allGreen).toBe(true);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("only picks up validate-*.sh, ignores other scripts in the same dir", async () => {
    const tmp = tmpRoot();
    try {
      addScript(tmp, "validate-pass.sh", "exit 0");
      addScript(tmp, "generate-thing.sh", "exit 0");
      addScript(tmp, "build.sh", "exit 0");
      const out = await lint({ root: tmp });
      expect(out.results.map((r) => r.script)).toEqual([
        "scripts/validate-pass.sh",
      ]);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("aggregates exit codes (one fails → allGreen false)", async () => {
    const tmp = tmpRoot();
    try {
      addScript(tmp, "validate-pass.sh", "exit 0");
      addScript(tmp, "validate-fail.sh", "echo boom >&2\nexit 1");
      const out = await lint({ root: tmp });
      expect(out.results).toHaveLength(2);
      expect(out.allGreen).toBe(false);
      const fail = out.results.find((r) =>
        r.script.endsWith("validate-fail.sh"),
      );
      expect(fail?.exitCode).toBe(1);
      expect(fail?.stderr).toContain("boom");
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("captures stdout per script and runs in alphabetical order", async () => {
    const tmp = tmpRoot();
    try {
      addScript(tmp, "validate-zeta.sh", "echo zeta-out");
      addScript(tmp, "validate-alpha.sh", "echo alpha-out");
      addScript(tmp, "validate-beta.sh", "echo beta-out");
      const out = await lint({ root: tmp });
      expect(out.results.map((r) => r.script)).toEqual([
        "scripts/validate-alpha.sh",
        "scripts/validate-beta.sh",
        "scripts/validate-zeta.sh",
      ]);
      expect(out.results[0]?.stdout).toContain("alpha-out");
      expect(out.results[2]?.stdout).toContain("zeta-out");
      expect(out.allGreen).toBe(true);
    } finally {
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});
