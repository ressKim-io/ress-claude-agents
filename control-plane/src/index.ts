import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import kleur from "kleur";
import { parse as parseYaml, stringify } from "yaml";
import {
  adapter,
  type AdapterMode,
  type AdapterTool,
} from "./adapter.js";
import { admit, type AdmitMode } from "./admit.js";
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
export { adapter };
export { admit };

const COMMANDS = ["probe", "match", "init", "lint", "adapter", "admit"] as const;
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
    case "adapter":
      return runAdapter(rest, out, err);
    case "admit":
      return runAdmit(rest, out, err);
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

interface AdapterCliOpts {
  tool: AdapterTool;
  root: string;
  assets: string;
  mode: AdapterMode;
}

async function runAdapter(
  args: string[],
  out: NodeJS.WritableStream,
  err: NodeJS.WritableStream,
): Promise<number> {
  const parsed = parseAdapterArgs(args, err);
  if (!parsed) return 2;

  try {
    const result = await adapter({
      tool: parsed.tool,
      root: parsed.root,
      assets: parsed.assets,
      mode: parsed.mode,
    });

    let createCount = 0;
    let updateCount = 0;
    let unchangedCount = 0;
    for (const c of result.changes) {
      if (c.status === "create") createCount++;
      else if (c.status === "update") updateCount++;
      else unchangedCount++;
      const tag =
        c.status === "create"
          ? kleur.green("+")
          : c.status === "update"
            ? kleur.yellow("~")
            : kleur.gray("=");
      out.write(`${tag} ${c.path} (${c.status})\n`);
    }

    if (result.issues.length > 0) {
      err.write(
        kleur.yellow(
          `adapter: ${result.issues.length} issue(s)\n`,
        ),
      );
      for (const i of result.issues) {
        err.write(kleur.yellow(`  - ${i}\n`));
      }
    }

    out.write(
      `\nadapter --tool=${parsed.tool} (${parsed.mode}): ${createCount} create, ${updateCount} update, ${unchangedCount} unchanged\n`,
    );
    return 0;
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    err.write(kleur.red(`adapter failed: ${message}\n`));
    return 1;
  }
}

function parseAdapterArgs(
  args: string[],
  err: NodeJS.WritableStream,
): AdapterCliOpts | null {
  const queue = [...args];
  const opts: Partial<AdapterCliOpts> = {
    root: process.cwd(),
    assets: process.cwd(),
    mode: "write",
  };
  while (queue.length > 0) {
    const raw = queue.shift();
    if (raw === undefined) break;
    if (raw === "--dry-run") {
      opts.mode = "dry-run";
      continue;
    }
    if (raw === "--diff") {
      opts.mode = "diff";
      continue;
    }
    const eqIdx = raw.indexOf("=");
    const flag = eqIdx === -1 ? raw : raw.slice(0, eqIdx);
    const inlineValue = eqIdx === -1 ? undefined : raw.slice(eqIdx + 1);
    if (flag === "--tool" || flag === "--root" || flag === "--assets") {
      const value = inlineValue ?? queue.shift();
      if (value === undefined) {
        err.write(kleur.red(`${flag} requires a value\n`));
        return null;
      }
      if (flag === "--root") opts.root = value;
      else if (flag === "--assets") opts.assets = value;
      else if (flag === "--tool") {
        if (value !== "claude" && value !== "codex" && value !== "cursor") {
          err.write(
            kleur.red(
              `--tool must be one of: claude, codex, cursor (got: ${value})\n`,
            ),
          );
          return null;
        }
        opts.tool = value;
      }
    } else {
      err.write(kleur.red(`unknown adapter flag: ${raw}\n`));
      return null;
    }
  }
  if (opts.tool === undefined) {
    err.write(kleur.red(`adapter requires --tool=<claude|codex|cursor>\n`));
    return null;
  }
  return opts as AdapterCliOpts;
}

interface AdmitCliOpts {
  tool: string;
  path?: string;
  skill?: string;
  root: string;
  assets: string;
  mode: AdmitMode;
}

async function runAdmit(
  args: string[],
  out: NodeJS.WritableStream,
  err: NodeJS.WritableStream,
): Promise<number> {
  const parsed = parseAdmitArgs(args, err);
  if (!parsed) return 2;

  try {
    const decisionInput: Parameters<typeof admit>[0] = {
      tool: parsed.tool,
      root: parsed.root,
      assets: parsed.assets,
      mode: parsed.mode,
    };
    if (parsed.path !== undefined) decisionInput.path = parsed.path;
    if (parsed.skill !== undefined) decisionInput.skill = parsed.skill;

    const decision = await admit(decisionInput);
    const outcome: "allow" | "warn" | "deny" = decision.allow
      ? "allow"
      : parsed.mode === "warn"
        ? "warn"
        : "deny";
    appendBaselineRecord({
      tool: parsed.tool,
      pathArg: parsed.path,
      skill: parsed.skill,
      mode: parsed.mode,
      outcome,
      reason: decision.reason,
    });
    if (decision.allow) {
      out.write(kleur.green(`admit: allow — ${decision.reason}\n`));
      return 0;
    }
    if (parsed.mode === "warn") {
      err.write(
        kleur.yellow(
          `[claude-agents admit] WARN: ${decision.reason}\n`,
        ),
      );
      return 0;
    }
    err.write(kleur.red(`[claude-agents admit] DENY: ${decision.reason}\n`));
    return 2;
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : String(e);
    err.write(kleur.red(`admit failed: ${message}\n`));
    return 1;
  }
}

interface BaselineRecord {
  tool: string;
  pathArg: string | undefined;
  skill: string | undefined;
  mode: AdmitMode;
  outcome: "allow" | "warn" | "deny";
  reason: string;
}

// ADR 0004: warn-mode baseline sink.
// Opt-in via CLAUDE_AGENTS_ADMIT_LOG. Errors are silently swallowed so logging
// never breaks the admission flow itself (PreToolUse hook context).
function appendBaselineRecord(record: BaselineRecord): void {
  const sinkPath = process.env.CLAUDE_AGENTS_ADMIT_LOG;
  if (!sinkPath) return;
  try {
    const dir = path.dirname(sinkPath);
    if (dir && dir !== "." && dir !== "/") {
      mkdirSync(dir, { recursive: true });
    }
    const line = JSON.stringify({
      ts: new Date().toISOString(),
      tool: record.tool,
      path: record.pathArg ?? null,
      skill: record.skill ?? null,
      mode: record.mode,
      decision: record.outcome,
      reason: record.reason,
      version: VERSION,
    });
    appendFileSync(sinkPath, line + "\n", "utf8");
  } catch {
    // Silent: hook context may run with restricted FS permissions.
  }
}

function parseAdmitArgs(
  args: string[],
  err: NodeJS.WritableStream,
): AdmitCliOpts | null {
  const queue = [...args];
  const opts: Partial<AdmitCliOpts> = {
    root: process.cwd(),
    assets: process.cwd(),
    mode: "warn",
  };
  while (queue.length > 0) {
    const raw = queue.shift();
    if (raw === undefined) break;
    const eqIdx = raw.indexOf("=");
    const flag = eqIdx === -1 ? raw : raw.slice(0, eqIdx);
    const inline = eqIdx === -1 ? undefined : raw.slice(eqIdx + 1);
    if (
      flag === "--tool" ||
      flag === "--path" ||
      flag === "--skill" ||
      flag === "--root" ||
      flag === "--assets" ||
      flag === "--mode"
    ) {
      const value = inline ?? queue.shift();
      if (value === undefined) {
        err.write(kleur.red(`${flag} requires a value\n`));
        return null;
      }
      if (flag === "--tool") opts.tool = value;
      else if (flag === "--path") opts.path = value;
      else if (flag === "--skill") opts.skill = value;
      else if (flag === "--root") opts.root = value;
      else if (flag === "--assets") opts.assets = value;
      else if (flag === "--mode") {
        if (value !== "warn" && value !== "deny") {
          err.write(
            kleur.red(`--mode must be 'warn' or 'deny' (got: ${value})\n`),
          );
          return null;
        }
        opts.mode = value;
      }
    } else {
      err.write(kleur.red(`unknown admit flag: ${raw}\n`));
      return null;
    }
  }
  if (opts.tool === undefined) {
    err.write(kleur.red(`admit requires --tool=<name>\n`));
    return null;
  }
  return opts as AdmitCliOpts;
}

function helpText(): string {
  return [
    `@ress/claude-agents v${VERSION}`,
    ``,
    `Usage: claude-agents <command> [options]`,
    ``,
    `Commands:`,
    `  probe    Generate project-profile.yml (deterministic, no LLM)`,
    `  match    Score skills against profile (threshold 50)`,
    `  init     Bootstrap project: probe → match → confirm → adapter → hook`,
    `  lint     Run all repo validators`,
    `  adapter  Generate per-tool view (--tool=claude|codex|cursor)`,
    `  admit    PreToolUse admission check (--tool/--path/--skill/--mode warn|deny)`,
    ``,
    `Flags:`,
    `  -h, --help     Show this help`,
    `  -v, --version  Print version`,
    ``,
  ].join("\n");
}
