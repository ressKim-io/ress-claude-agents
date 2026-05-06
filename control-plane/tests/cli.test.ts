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

  it.each(["probe", "match", "init", "lint"] as const)(
    "stub %s returns non-zero with TODO message",
    async (cmd) => {
      const { stderr, opts } = captureStreams();
      const code = await run([cmd], opts);
      expect(code).toBeGreaterThan(0);
      expect(stderr.join("")).toContain("not implemented");
    },
  );
});
