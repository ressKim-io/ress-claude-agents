import { readFileSync } from "node:fs";
import path from "node:path";
import fg from "fast-glob";
import type { ProjectProfile } from "./schema/project-profile.js";
import type { LoadedSkill } from "./skill-loader.js";

export interface MatchContext {
  root: string;
  files: string[];
  readFile(rel: string): string;
}

const VENDOR_IGNORES = [
  "**/node_modules/**",
  "**/.git/**",
  "**/dist/**",
  "**/build/**",
  "**/.cache/**",
  "**/.next/**",
  "**/coverage/**",
  "**/vendor/**",
  "**/target/**",
];

export async function buildMatchContext(root: string): Promise<MatchContext> {
  const absRoot = path.resolve(root);
  const files = await fg("**/*", {
    cwd: absRoot,
    dot: true,
    onlyFiles: true,
    suppressErrors: true,
    ignore: VENDOR_IGNORES,
  });
  files.sort();

  const cache = new Map<string, string>();
  return {
    root: absRoot,
    files,
    readFile(rel: string): string {
      const cached = cache.get(rel);
      if (cached !== undefined) return cached;
      const content = readFileSync(path.join(absRoot, rel), "utf8");
      cache.set(rel, content);
      return content;
    },
  };
}

export interface ScoreComponents {
  files_present: number;
  files_contain: number;
  language: number;
  frameworks: number;
  excluded: boolean;
}

export interface ScoreResult {
  skill: LoadedSkill;
  score: number;
  components: ScoreComponents;
}

export interface MatchOptions {
  installThreshold?: number;
  suggestThreshold?: number;
}

export interface MatchResult {
  install: ScoreResult[];
  suggest: ScoreResult[];
  skip: ScoreResult[];
}

export const DEFAULT_INSTALL_THRESHOLD = 50;
export const DEFAULT_SUGGEST_THRESHOLD = 25;

export async function score(
  skill: LoadedSkill,
  profile: ProjectProfile,
  ctx: MatchContext,
): Promise<ScoreResult> {
  const aw = skill.manifest.applies_when;
  const components: ScoreComponents = {
    files_present: 0,
    files_contain: 0,
    language: 0,
    frameworks: 0,
    excluded: false,
  };

  if (!aw) {
    return { skill, score: 0, components };
  }

  if (await isExcluded(aw.exclude_when, ctx)) {
    components.excluded = true;
    return { skill, score: Number.NEGATIVE_INFINITY, components };
  }

  components.files_present = await scoreFilesPresent(
    aw.files_present ?? [],
    ctx,
  );
  components.files_contain = await scoreFilesContain(
    aw.files_contain ?? {},
    ctx,
  );
  components.language = scoreLanguage(aw.language ?? [], profile);
  components.frameworks = scoreFrameworks(aw.frameworks ?? [], profile);

  const total =
    components.files_present +
    components.files_contain +
    components.language +
    components.frameworks;

  return { skill, score: total, components };
}

async function scoreFilesPresent(
  patterns: string[],
  ctx: MatchContext,
): Promise<number> {
  if (patterns.length === 0) return 0;
  let hits = 0;
  for (const pattern of patterns) {
    const matched = await fg(pattern, {
      cwd: ctx.root,
      onlyFiles: true,
      suppressErrors: true,
      ignore: VENDOR_IGNORES,
    });
    if (matched.length > 0) hits++;
  }
  return 40 * (hits / patterns.length);
}

async function scoreFilesContain(
  rules: Record<string, string>,
  ctx: MatchContext,
): Promise<number> {
  const entries = Object.entries(rules);
  if (entries.length === 0) return 0;
  let hits = 0;
  for (const [glob, regexStr] of entries) {
    const matched = await fg(glob, {
      cwd: ctx.root,
      onlyFiles: true,
      suppressErrors: true,
      ignore: VENDOR_IGNORES,
    });
    if (matched.length === 0) continue;
    let regex: RegExp;
    try {
      regex = new RegExp(regexStr, "m");
    } catch {
      continue;
    }
    let found = false;
    for (const rel of matched) {
      try {
        if (regex.test(ctx.readFile(rel))) {
          found = true;
          break;
        }
      } catch {
        /* unreadable */
      }
    }
    if (found) hits++;
  }
  return 30 * (hits / entries.length);
}

function scoreLanguage(
  languages: string[],
  profile: ProjectProfile,
): number {
  if (languages.length === 0) return 0;
  const primaryHit = languages.some((l) =>
    profile.languages.some((p) => p.name === l && p.primary),
  );
  return primaryHit ? 20 : 0;
}

function scoreFrameworks(
  skillFrameworks: string[],
  profile: ProjectProfile,
): number {
  if (skillFrameworks.length === 0) return 0;
  const profileSet = new Set(profile.frameworks);
  const overlap = skillFrameworks.filter((f) => profileSet.has(f)).length;
  return 15 * (overlap / skillFrameworks.length);
}

async function isExcluded(
  rule: { files_present?: string[] } | undefined,
  ctx: MatchContext,
): Promise<boolean> {
  if (!rule?.files_present) return false;
  for (const pattern of rule.files_present) {
    const matched = await fg(pattern, {
      cwd: ctx.root,
      onlyFiles: true,
      suppressErrors: true,
      ignore: VENDOR_IGNORES,
    });
    if (matched.length > 0) return true;
  }
  return false;
}

export async function selectSkills(
  skills: LoadedSkill[],
  profile: ProjectProfile,
  ctx: MatchContext,
  opts: MatchOptions = {},
): Promise<MatchResult> {
  const scored = await Promise.all(
    skills.map((skill) => score(skill, profile, ctx)),
  );
  return bucketScores(
    scored,
    opts.installThreshold ?? DEFAULT_INSTALL_THRESHOLD,
    opts.suggestThreshold ?? DEFAULT_SUGGEST_THRESHOLD,
  );
}

export function bucketScores(
  scored: ScoreResult[],
  installThreshold: number,
  suggestThreshold: number,
): MatchResult {
  const install: ScoreResult[] = [];
  const suggest: ScoreResult[] = [];
  const skip: ScoreResult[] = [];
  for (const r of scored) {
    if (r.score >= installThreshold) install.push(r);
    else if (r.score >= suggestThreshold) suggest.push(r);
    else skip.push(r);
  }

  const byScoreDesc = (a: ScoreResult, b: ScoreResult) =>
    b.score - a.score ||
    a.skill.manifest.name.localeCompare(b.skill.manifest.name);
  install.sort(byScoreDesc);
  suggest.sort(byScoreDesc);
  skip.sort(byScoreDesc);

  return { install, suggest, skip };
}
