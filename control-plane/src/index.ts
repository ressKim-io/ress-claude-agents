import { writeFileSync } from "node:fs";
import kleur from "kleur";
import { stringify } from "yaml";
import { probe, type ProbeOptions } from "./probe.js";
import { VERSION } from "./version.js";

export { VERSION };
export { probe };

const COMMANDS = ["probe", "match", "init", "lint"] as const;
type Command = (typeof COMMANDS)[number];

export interface RunOptions {
  stdout?: NodeJS.WritableStream;
  stderr?: NodeJS.WritableStream;
}

export async function run(argv: string[], opts: RunOptions = {}): Promise<number> {
  const out = opts.stdout ?? process.stdout;
  const err = opts.stderr ?? process.stderr;

  const [cmd, ...rest] = argv;

  if (!cmd || cmd === "--help" || cmd === "-h") {
    out.write(helpText());
    return 0;
  }
  if (cmd === "--version" || cmd === "-v") {
    out.write(`${VERSION}\n`);
    return 0;
  }
  if (!isCommand(cmd)) {
    err.write(kleur.red(`Unknown command: ${cmd}\n\n`));
    err.write(helpText());
    return 2;
  }

  switch (cmd) {
    case "probe":
      return runProbe(rest, out, err);
    case "match":
      return stub("match", "P3 step 3 — score skills against profile", rest, err);
    case "init":
      return stub("init", "P3 step 5 — bootstrap project (5 step orchestration)", rest, err);
    case "lint":
      return stub("lint", "P3 step 6 — delegate to repo lint scripts", rest, err);
  }
}

interface ProbeCliOpts extends ProbeOptions {
  outFile?: string;
}

async function runProbe(
  args: string[],
  out: NodeJS.WritableStream,
  err: NodeJS.WritableStream,
): Promise<number> {
  const parsed = parseProbeArgs(args, err);
  if (!parsed) return 2;

  try {
    const profile = await probe(parsed);
    const yaml = stringify(profile, { sortMapEntries: true });
    if (parsed.outFile) {
      writeFileSync(parsed.outFile, yaml);
    } else {
      out.write(yaml);
    }
    return 0;
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    err.write(kleur.red(`probe failed: ${message}\n`));
    return 1;
  }
}

function parseProbeArgs(
  args: string[],
  err: NodeJS.WritableStream,
): ProbeCliOpts | null {
  const queue = [...args];
  const opts: ProbeCliOpts = { root: process.cwd() };
  while (queue.length > 0) {
    const flag = queue.shift();
    if (flag === undefined) break;
    if (flag === "--root" || flag === "--out" || flag === "--frozen-time") {
      const value = queue.shift();
      if (value === undefined) {
        err.write(kleur.red(`${flag} requires a value\n`));
        return null;
      }
      if (flag === "--root") opts.root = value;
      else if (flag === "--out") opts.outFile = value;
      else opts.frozenTime = value;
    } else {
      err.write(kleur.red(`unknown probe flag: ${flag}\n`));
      return null;
    }
  }
  return opts;
}

function isCommand(value: string): value is Command {
  return (COMMANDS as readonly string[]).includes(value);
}

function stub(
  name: Command,
  todo: string,
  _rest: string[],
  err: NodeJS.WritableStream,
): number {
  err.write(kleur.yellow(`[${name}] not implemented (${todo})\n`));
  return 1;
}

function helpText(): string {
  return [
    `@ress/claude-agents v${VERSION}`,
    ``,
    `Usage: claude-agents <command> [options]`,
    ``,
    `Commands:`,
    `  probe   Generate project-profile.yml (deterministic, no LLM)`,
    `  match   Score skills against profile (threshold 50)`,
    `  init    Bootstrap project: probe → match → confirm → adapter → hook`,
    `  lint    Run all repo validators`,
    ``,
    `Flags:`,
    `  -h, --help     Show this help`,
    `  -v, --version  Print version`,
    ``,
  ].join("\n");
}
