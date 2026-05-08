import { describe, it, expect } from "vitest";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { Writable } from "node:stream";
import { run, VERSION } from "../src/index.js";

function captureStreams() {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const sink = (sink: string[]) =>
    new Writable({
      write(chunk, _enc, cb) {
        sink.push(chunk.toString());
        cb();
      },
    });
  return {
    stdout,
    stderr,
    opts: { stdout: sink(stdout), stderr: sink(stderr) },
  };
}

describe("cli routing", () => {
  it("returns 0 and prints help on --help", async () => {
    const { stdout, opts } = captureStreams();
    const code = await run(["--help"], opts);
    expect(code).toBe(0);
    expect(stdout.join("")).toContain("@ress/claude-agents");
    expect(stdout.join("")).toContain("probe");
  });

  it("returns 0 and prints help on no args", async () => {
    const { stdout, opts } = captureStreams();
    const code = await run([], opts);
    expect(code).toBe(0);
    expect(stdout.join("")).toContain("Usage");
  });

  it("returns 0 and prints version on --version", async () => {
    const { stdout, opts } = captureStreams();
    const code = await run(["--version"], opts);
    expect(code).toBe(0);
    expect(stdout.join("")).toContain(VERSION);
  });

  it("returns 2 on unknown command", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(["nope"], opts);
    expect(code).toBe(2);
    expect(stderr.join("")).toContain("Unknown command");
  });

  it("probe with non-existent --root returns 1 (probe failed)", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(
      ["probe", "--root", "/nonexistent/abc123-claude-agents-test"],
      opts,
    );
    expect(code).toBe(1);
    expect(stderr.join("")).toContain("probe failed");
  });

  it("probe with unknown flag returns 2", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(["probe", "--no-such-flag"], opts);
    expect(code).toBe(2);
    expect(stderr.join("")).toContain("unknown probe flag");
  });

  it("probe missing flag value returns 2", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(["probe", "--root"], opts);
    expect(code).toBe(2);
    expect(stderr.join("")).toContain("--root requires a value");
  });

  it("match with unknown flag returns 2", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(["match", "--no-such-flag"], opts);
    expect(code).toBe(2);
    expect(stderr.join("")).toContain("unknown match flag");
  });

  it("match with non-integer threshold returns 2", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(["match", "--threshold", "abc"], opts);
    expect(code).toBe(2);
    expect(stderr.join("")).toContain("--threshold requires an integer");
  });

  it("init with unknown flag returns 2", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(["init", "--no-such-flag"], opts);
    expect(code).toBe(2);
    expect(stderr.join("")).toContain("unknown init flag");
  });

  it("init --dry-run with non-existent --root returns 1 (probe failed)", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(
      [
        "init",
        "--dry-run",
        "--root",
        "/nonexistent/abc-claude-agents-init",
        "--assets",
        "/nonexistent/abc-claude-agents-init",
      ],
      opts,
    );
    expect(code).toBe(1);
    expect(stderr.join("")).toContain("init failed");
  });

  it("lint with unknown flag returns 2", async () => {
    const { stderr, opts } = captureStreams();
    const code = await run(["lint", "--no-such-flag"], opts);
    expect(code).toBe(2);
    expect(stderr.join("")).toContain("unknown lint flag");
  });
});

describe("admit baseline sink (ADR 0004)", () => {
  it("does not create sink file when CLAUDE_AGENTS_ADMIT_LOG is unset", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "admit-sink-"));
    const sink = path.join(tmp, "should-not-exist.jsonl");
    const prev = process.env.CLAUDE_AGENTS_ADMIT_LOG;
    delete process.env.CLAUDE_AGENTS_ADMIT_LOG;
    try {
      const { opts } = captureStreams();
      const code = await run(
        ["admit", "--tool=Read", "--assets", tmp],
        opts,
      );
      expect(code).toBe(0);
      expect(existsSync(sink)).toBe(false);
    } finally {
      if (prev !== undefined) process.env.CLAUDE_AGENTS_ADMIT_LOG = prev;
      rmSync(tmp, { recursive: true, force: true });
    }
  });

  it("appends a JSONL record with all required fields when env is set", async () => {
    const tmp = mkdtempSync(path.join(os.tmpdir(), "admit-sink-"));
    const sink = path.join(tmp, "nested", "admit.jsonl");
    const prev = process.env.CLAUDE_AGENTS_ADMIT_LOG;
    process.env.CLAUDE_AGENTS_ADMIT_LOG = sink;
    try {
      const { opts } = captureStreams();
      const code = await run(
        ["admit", "--tool=Read", "--path=foo.md", "--assets", tmp],
        opts,
      );
      expect(code).toBe(0);
      const content = readFileSync(sink, "utf8").trim();
      const lines = content.split("\n").filter((l) => l.length > 0);
      expect(lines).toHaveLength(1);
      const record = JSON.parse(lines[0]!);
      // ADR 0004 schema fields
      expect(typeof record.ts).toBe("string");
      expect(record.ts).toMatch(/^\d{4}-\d{2}-\d{2}T/);
      expect(record.tool).toBe("Read");
      expect(record.path).toBe("foo.md");
      expect(record.skill).toBeNull();
      expect(record.mode).toBe("warn");
      expect(record.decision).toBe("allow"); // Read is non-mutating
      expect(typeof record.reason).toBe("string");
      expect(record.version).toBe(VERSION);
    } finally {
      if (prev === undefined) delete process.env.CLAUDE_AGENTS_ADMIT_LOG;
      else process.env.CLAUDE_AGENTS_ADMIT_LOG = prev;
      rmSync(tmp, { recursive: true, force: true });
    }
  });
});
