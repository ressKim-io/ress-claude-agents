import { writeFileSync } from "node:fs";
import path from "node:path";
import { stringify } from "yaml";
import { buildMatchContext, selectSkills, type ScoreResult } from "./match.js";
import { probe } from "./probe.js";
import type { ProjectProfile } from "./schema/project-profile.js";
import { loadSkills, type LoadIssue } from "./skill-loader.js";
import { VERSION } from "./version.js";

export interface InitOptions {
  root: string;
  assets: string;
  threshold?: number;
  frozenTime?: string;
  yes?: boolean;
  dryRun?: boolean;
  outProfile?: string;
  outLock?: string;
}

export interface InitStepLog {
  step: number;
  name: "probe" | "match" | "confirm" | "adapter" | "hook";
  status: "ok" | "stub" | "skipped";
  detail: string;
}

export interface LockSkillEntry {
  name: string;
  category: string;
  score: number;
  version?: string;
}

export interface LockFile {
  schema_version: 1;
  generated_at: string;
  generator: string;
  threshold: number;
  skills: {
    install: LockSkillEntry[];
    suggest: LockSkillEntry[];
    skip_count: number;
  };
  adapters: { detected: string[]; status: "p4-stub" };
  hook: { installed: boolean; status: "p5-stub" };
}

export interface InitOutput {
  profile: ProjectProfile;
  lock: LockFile;
  logs: InitStepLog[];
  issues: LoadIssue[];
  paths: { profile?: string; lock?: string };
}

const DEFAULT_THRESHOLD = 50;

export async function init(opts: InitOptions): Promise<InitOutput> {
  const logs: InitStepLog[] = [];
  const threshold = opts.threshold ?? DEFAULT_THRESHOLD;

  const profile = await probe({
    root: opts.root,
    ...(opts.frozenTime !== undefined ? { frozenTime: opts.frozenTime } : {}),
  });
  logs.push({
    step: 1,
    name: "probe",
    status: "ok",
    detail: `${profile.languages.length} languages, ${profile.frameworks.length} frameworks, ${profile.build_systems.length} build systems`,
  });

  const ctx = await buildMatchContext(opts.root);
  const { skills, issues } = await loadSkills(opts.assets);
  const result = await selectSkills(skills, profile, ctx, {
    installThreshold: threshold,
  });
  logs.push({
    step: 2,
    name: "match",
    status: "ok",
    detail: `${result.install.length} install, ${result.suggest.length} suggest, ${result.skip.length} skip${
      issues.length > 0 ? `, ${issues.length} broken` : ""
    } (threshold ${threshold})`,
  });

  const confirmStatus: InitStepLog["status"] = opts.dryRun ? "skipped" : "ok";
  logs.push({
    step: 3,
    name: "confirm",
    status: confirmStatus,
    detail: opts.dryRun
      ? "dry-run (no files written)"
      : opts.yes
        ? "auto-accepted via --yes"
        : "auto-accepted (interactive prompt is P5+)",
  });

  logs.push({
    step: 4,
    name: "adapter",
    status: "stub",
    detail: "tool detection (.claude/, .codex/, .cursor/) deferred to P4",
  });

  logs.push({
    step: 5,
    name: "hook",
    status: "stub",
    detail: "PreToolUse hook installation deferred to P5",
  });

  const generated_at = opts.frozenTime ?? new Date().toISOString();
  const generator = `@ress/claude-agents@${VERSION}`;
  const lock: LockFile = {
    schema_version: 1,
    generated_at,
    generator,
    threshold,
    skills: {
      install: result.install.map(toLockEntry),
      suggest: result.suggest.map(toLockEntry),
      skip_count: result.skip.length,
    },
    adapters: { detected: [], status: "p4-stub" },
    hook: { installed: false, status: "p5-stub" },
  };

  const paths: InitOutput["paths"] = {};
  if (!opts.dryRun) {
    const profilePath =
      opts.outProfile ?? path.join(opts.root, "project-profile.yml");
    const lockPath =
      opts.outLock ?? path.join(opts.root, ".claude-agents.yml");
    writeFileSync(
      profilePath,
      stringify(profile, { sortMapEntries: true }),
    );
    writeFileSync(lockPath, stringify(lock, { sortMapEntries: true }));
    paths.profile = profilePath;
    paths.lock = lockPath;
  }

  return { profile, lock, logs, issues, paths };
}

function toLockEntry(r: ScoreResult): LockSkillEntry {
  const entry: LockSkillEntry = {
    name: r.skill.manifest.name,
    category: r.skill.category,
    score: round2(r.score),
  };
  if (r.skill.manifest.version !== undefined) {
    entry.version = r.skill.manifest.version;
  }
  return entry;
}

function round2(n: number): number {
  if (!Number.isFinite(n)) return n;
  return Math.round(n * 100) / 100;
}
