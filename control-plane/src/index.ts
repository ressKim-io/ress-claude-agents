import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import kleur from "kleur";
import { parse as parseYaml, stringify } from "yaml";
import { init, type InitOptions } from "./init.js";
import { lint } from "./lint.js";
import {
  buildMatchContext,
  DEFAULT_INSTALL_THRESHOLD,
  selectSkills,
  type ScoreResult,
} from "./match.js";
import { probe, type ProbeOptions } from "./probe.js";
import { ProjectProfile } from "./schema/project-profile.js";
import { loadSkills } from "./skill-loader.js";
import { VERSION } from "./version.js";

export { VERSION };
export { probe };
export { selectSkills, buildMatchContext };
export { loadSkills };
export { init };
export { lint };

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
      return runMatch(rest, out, err);
    case "init":
      return runInit(rest, out, err);
    case "lint":
      return runLint(rest, out, err);
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

interface MatchCliOpts {
  root: string;
  assets: string;
  profilePath?: string;
  outFile?: string;
  threshold: number;
  frozenTime?: string;
}

async function runMatch(
  args: string[],
  out: NodeJS.WritableStream,
  err: NodeJS.WritableStream,
): Promise<number> {
  const parsed = parseMatchArgs(args, err);
  if (!parsed) return 2;

  let profile: ProjectProfile;
  if (parsed.profilePath) {
    try {
      const raw = readFileSync(parsed.profilePath, "utf8");
      const obj = parseYaml(raw) as unknown;
      const result = ProjectProfile.safeParse(obj);
      if (!result.success) {
        err.write(
          kleur.red(`profile invalid: ${result.error.issues[0]?.message ?? "unknown"}\n`),
        );
        return 1;
      }
      profile = result.data;
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      err.write(kleur.red(`profile load failed: ${message}\n`));
      return 1;
    }
  } else {
    try {
      profile = await probe({
        root: parsed.root,
        ...(parsed.frozenTime !== undefined
          ? { frozenTime: parsed.frozenTime }
          : {}),
      });
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : String(e);
      err.write(kleur.red(`probe failed: ${message}\n`));
      return 1;
    }
  }

  const { skills, issues } = await loadSkills(parsed.assets);
  if (issues.length > 0) {
    err.write(
      kleur.yellow(
        `match: skipped ${issues.length} broken skill(s) — first: ${issues[0]?.reason ?? ""}\n`,
      ),
    );
  }

  const ctx = await buildMatchContext(parsed.root);
  const result = await selectSkills(skills, profile, ctx, {
    installThreshold: parsed.threshold,
  });

  const output = {
    install: result.install.map(formatScored),
    suggest: result.suggest.map(formatScored),
    skip: result.skip.map(formatScored),
  };
  const yamlOut = stringify(output, { sortMapEntries: true });
  if (parsed.outFile) {
    writeFileSync(parsed.outFile, yamlOut);
  } else {
    out.write(yamlOut);
  }
  return 0;
}

function formatScored(r: ScoreResult): Record<string, unknown> {
  return {
    name: r.skill.manifest.name,
    category: r.skill.category,
    score: round2(r.score),
    components: {
      files_present: round2(r.components.files_present),
      files_contain: round2(r.components.files_contain),
      language: r.components.language,
      frameworks: round2(r.components.frameworks),
      excluded: r.components.excluded,
    },
  };
}

function round2(n: number): number {
  if (!Number.isFinite(n)) return n;
  return Math.round(n * 100) / 100;
}

function parseMatchArgs(
  args: string[],
  err: NodeJS.WritableStream,
): MatchCliOpts | null {
  const queue = [...args];
  const opts: MatchCliOpts = {
    root: process.cwd(),
    assets: process.cwd(),
    threshold: DEFAULT_INSTALL_THRESHOLD,
  };
  while (queue.length > 0) {
    const flag = queue.shift();
    if (flag === undefined) break;
    if (
      flag === "--root" ||
      flag === "--assets" ||
      flag === "--profile" ||
      flag === "--out" ||
      flag === "--threshold" ||
      flag === "--frozen-time"
    ) {
      const value = queue.shift();
      if (value === undefined) {
        err.write(kleur.red(`${flag} requires a value\n`));
        return null;
      }
      if (flag === "--root") opts.root = value;
      else if (flag === "--assets") opts.assets = value;
      else if (flag === "--profile") opts.profilePath = value;
      else if (flag === "--out") opts.outFile = value;
      else if (flag === "--frozen-time") opts.frozenTime = value;
      else if (flag === "--threshold") {
        const parsedNum = Number.parseInt(value, 10);
        if (!Number.isFinite(parsedNum)) {
          err.write(kleur.red(`--threshold requires an integer\n`));
          return null;
        }
        opts.threshold = parsedNum;
      }
    } else {
      err.write(kleur.red(`unknown match flag: ${flag}\n`));
      return null;
    }
  }
  return opts;
}

interface InitCliOpts {
  root: string;
  assets: string;
  threshold?: number;
  frozenTime?: string;
  yes: boolean;
  dryRun: boolean;
}

async function runInit(
  args: string[],
  out: NodeJS.WritableStream,
  err: NodeJS.WritableStream,
): Promise<number> {
  const parsed = parseInitArgs(args, err);
  if (!parsed) return 2;

  try {
    const initOpts: InitOptions = {
      root: parsed.root,
      assets: parsed.assets,
      yes: parsed.yes,
      dryRun: parsed.dryRun,
    };
    if (parsed.threshold !== undefined) initOpts.threshold = parsed.threshold;
    if (parsed.frozenTime !== undefined) initOpts.frozenTime = parsed.frozenTime;

    const result = await init(initOpts);

    for (const log of result.logs) {
      const tag =
        log.status === "ok"
          ? kleur.green("✓")
          : log.status === "stub"
            ? kleur.yellow("·")
            : kleur.gray("-");
      out.write(`${tag} [${log.step}/5] ${log.name}: ${log.detail}\n`);
    }

    if (result.issues.length > 0) {
      err.write(
        kleur.yellow(
          `init: skipped ${result.issues.length} broken skill(s)\n`,
        ),
      );
    }

    if (parsed.dryRun) {
      out.write("\n--- .claude-agents.yml (dry-run preview) ---\n");
      out.write(stringify(result.lock, { sortMapEntries: true }));
    } else if (result.paths.profile && result.paths.lock) {
      out.write(
        `\nWrote: ${path.relative(parsed.root, result.paths.profile)}, ${path.relative(parsed.root, result.paths.lock)}\n`,
      );
    }

    return 0;
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    err.write(kleur.red(`init failed: ${message}\n`));
    return 1;
  }
}

interface LintCliOpts {
  root: string;
  verbose: boolean;
}

async function runLint(
  args: string[],
  out: NodeJS.WritableStream,
  err: NodeJS.WritableStream,
): Promise<number> {
  const parsed = parseLintArgs(args, err);
  if (!parsed) return 2;

  try {
    const result = await lint({ root: parsed.root });

    if (result.results.length === 0) {
      err.write(
        kleur.yellow(
          `lint: no scripts/validate-*.sh under ${parsed.root}\n`,
        ),
      );
      return 0;
    }

    for (const r of result.results) {
      const tag = r.exitCode === 0 ? kleur.green("✓") : kleur.red("✗");
      out.write(`${tag} ${r.script} (exit ${r.exitCode})\n`);
      if (parsed.verbose || r.exitCode !== 0) {
        if (r.stdout) out.write(r.stdout);
        if (r.stderr) err.write(r.stderr);
      }
    }

    return result.allGreen ? 0 : 1;
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    err.write(kleur.red(`lint failed: ${message}\n`));
    return 1;
  }
}

function parseLintArgs(
  args: string[],
  err: NodeJS.WritableStream,
): LintCliOpts | null {
  const queue = [...args];
  const opts: LintCliOpts = { root: process.cwd(), verbose: false };
  while (queue.length > 0) {
    const flag = queue.shift();
    if (flag === undefined) break;
    if (flag === "--verbose" || flag === "-v") {
      opts.verbose = true;
      continue;
    }
    if (flag === "--root") {
      const value = queue.shift();
      if (value === undefined) {
        err.write(kleur.red(`${flag} requires a value\n`));
        return null;
      }
      opts.root = value;
    } else {
      err.write(kleur.red(`unknown lint flag: ${flag}\n`));
      return null;
    }
  }
  return opts;
}

function parseInitArgs(
  args: string[],
  err: NodeJS.WritableStream,
): InitCliOpts | null {
  const queue = [...args];
  const opts: InitCliOpts = {
    root: process.cwd(),
    assets: process.cwd(),
    yes: false,
    dryRun: false,
  };
  while (queue.length > 0) {
    const flag = queue.shift();
    if (flag === undefined) break;
    if (flag === "--yes") {
      opts.yes = true;
      continue;
    }
    if (flag === "--dry-run") {
      opts.dryRun = true;
      continue;
    }
    if (
      flag === "--root" ||
      flag === "--assets" ||
      flag === "--threshold" ||
      flag === "--frozen-time"
    ) {
      const value = queue.shift();
      if (value === undefined) {
        err.write(kleur.red(`${flag} requires a value\n`));
        return null;
      }
      if (flag === "--root") opts.root = value;
      else if (flag === "--assets") opts.assets = value;
      else if (flag === "--frozen-time") opts.frozenTime = value;
      else if (flag === "--threshold") {
        const parsedNum = Number.parseInt(value, 10);
        if (!Number.isFinite(parsedNum)) {
          err.write(kleur.red(`--threshold requires an integer\n`));
          return null;
        }
        opts.threshold = parsedNum;
      }
    } else {
      err.write(kleur.red(`unknown init flag: ${flag}\n`));
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
