import { describe, it, expect } from "vitest";
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
