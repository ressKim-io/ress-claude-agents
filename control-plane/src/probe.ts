import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import fg from "fast-glob";
import type {
  Language,
  ProjectProfile,
  Repo,
} from "./schema/project-profile.js";
import { VERSION } from "./version.js";

export interface ProbeOptions {
  root: string;
  frozenTime?: string;
  generator?: string;
}

const VENDOR_IGNORES = [
  "**/node_modules/**",
  "**/.git/**",
  "**/dist/**",
  "**/build/**",
  "**/.cache/**",
  "**/.next/**",
  "**/.turbo/**",
  "**/coverage/**",
  "**/vendor/**",
  "**/target/**",
  "**/__pycache__/**",
];

export async function probe(opts: ProbeOptions): Promise<ProjectProfile> {
  const root = path.resolve(opts.root);
  if (!existsSync(root)) {
    throw new Error(`probe root does not exist: ${root}`);
  }

  const files = await listFiles(root);
  const repo = detectRepo(root, files);
  const languages = countLanguages(files);
  const build_systems = detectBuildSystems(files);
  const frameworks = detectFrameworks(root, files);

  const generated_at = opts.frozenTime ?? new Date().toISOString();
  const generator = opts.generator ?? `@ress/claude-agents@${VERSION}`;

  return {
    schema_version: 1,
    generated_at,
    generator,
    repo,
    languages,
    frameworks,
    build_systems,
    files_signatures: {},
  };
}

export async function listFiles(root: string): Promise<string[]> {
  const files = await fg("**/*", {
    cwd: root,
    dot: true,
    ignore: VENDOR_IGNORES,
    onlyFiles: true,
    suppressErrors: true,
  });
  return files.sort();
}

export function detectRepo(root: string, files: string[]): Repo {
  const gitDir = path.join(root, ".git");
  if (!existsSync(gitDir)) {
    return { vcs: "none", default_branch: "main", monorepo: detectMonorepo(root, files) };
  }

  const headPath = path.join(gitDir, "HEAD");
  let default_branch = "main";
  if (existsSync(headPath)) {
    const head = readFileSync(headPath, "utf8").trim();
    const match = /^ref: refs\/heads\/(.+)$/.exec(head);
    if (match && match[1]) {
      default_branch = match[1];
    }
  }

  return {
    vcs: "git",
    default_branch,
    monorepo: detectMonorepo(root, files),
  };
}

function detectMonorepo(root: string, files: string[]): boolean {
  const pkgPath = path.join(root, "package.json");
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf8")) as {
        workspaces?: unknown;
      };
      if (pkg.workspaces) return true;
    } catch {
      /* malformed package.json — treat as no signal */
    }
  }
  if (files.includes("pnpm-workspace.yaml")) return true;
  if (files.includes("lerna.json")) return true;
  if (files.includes("turbo.json")) return true;
  if (files.includes("nx.json")) return true;
  return false;
}

const EXT_LANG: Record<string, string> = {
  ts: "typescript",
  tsx: "typescript",
  mts: "typescript",
  cts: "typescript",
  js: "javascript",
  jsx: "javascript",
  mjs: "javascript",
  cjs: "javascript",
  go: "go",
  py: "python",
  java: "java",
  kt: "kotlin",
  scala: "scala",
  rb: "ruby",
  rs: "rust",
  cpp: "cpp",
  cc: "cpp",
  c: "c",
  h: "c",
  hpp: "cpp",
  cs: "csharp",
  php: "php",
  swift: "swift",
  yaml: "yaml",
  yml: "yaml",
  json: "json",
  toml: "toml",
  md: "markdown",
  sh: "shell",
  bash: "shell",
  zsh: "shell",
  proto: "protobuf",
};

const FILENAME_LANG: Record<string, string> = {
  Dockerfile: "dockerfile",
  Makefile: "make",
};

export function countLanguages(files: string[]): Language[] {
  const counts = new Map<string, number>();
  for (const f of files) {
    const lang = extToLang(f);
    if (!lang) continue;
    counts.set(lang, (counts.get(lang) ?? 0) + 1);
  }
  if (counts.size === 0) return [];

  const entries = [...counts.entries()].sort(
    ([aName, aFiles], [bName, bFiles]) =>
      bFiles - aFiles || aName.localeCompare(bName),
  );
  const top = entries[0];
  if (!top) return [];
  const topName = top[0];

  return entries.map(([name, fileCount]) => ({
    name,
    files: fileCount,
    primary: name === topName,
  }));
}

function extToLang(file: string): string | null {
  const base = path.basename(file);
  const filenameMatch = FILENAME_LANG[base];
  if (filenameMatch) return filenameMatch;
  const dot = base.lastIndexOf(".");
  if (dot < 0) return null;
  const ext = base.slice(dot + 1).toLowerCase();
  return EXT_LANG[ext] ?? null;
}

const BUILD_SYSTEM_RULES: ReadonlyArray<{ filename: string; system: string }> = [
  { filename: "package.json", system: "npm" },
  { filename: "pnpm-lock.yaml", system: "pnpm" },
  { filename: "yarn.lock", system: "yarn" },
  { filename: "go.mod", system: "go-modules" },
  { filename: "pom.xml", system: "maven" },
  { filename: "build.gradle", system: "gradle" },
  { filename: "build.gradle.kts", system: "gradle" },
  { filename: "Cargo.toml", system: "cargo" },
  { filename: "Gemfile", system: "bundler" },
  { filename: "requirements.txt", system: "pip" },
  { filename: "pyproject.toml", system: "pip" },
  { filename: "Chart.yaml", system: "helm" },
];

export function detectBuildSystems(files: string[]): string[] {
  const out = new Set<string>();
  const basenames = new Set(files.map((f) => path.basename(f)));
  for (const { filename, system } of BUILD_SYSTEM_RULES) {
    if (basenames.has(filename)) out.add(system);
  }
  if (files.some((f) => f.endsWith(".tf"))) out.add("terraform");
  return [...out].sort();
}

export function detectFrameworks(root: string, files: string[]): string[] {
  const out = new Set<string>();

  const pkgPath = path.join(root, "package.json");
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf8")) as {
        dependencies?: Record<string, string>;
        devDependencies?: Record<string, string>;
        peerDependencies?: Record<string, string>;
      };
      const deps = {
        ...(pkg.dependencies ?? {}),
        ...(pkg.devDependencies ?? {}),
        ...(pkg.peerDependencies ?? {}),
      };
      const has = (name: string): boolean =>
        Object.prototype.hasOwnProperty.call(deps, name);
      if (has("react")) out.add("react");
      if (has("next")) out.add("next");
      if (has("vue")) out.add("vue");
      if (has("svelte")) out.add("svelte");
      if (has("@nestjs/core")) out.add("nestjs");
      if (has("express")) out.add("express");
      if (has("fastify")) out.add("fastify");
    } catch {
      /* malformed */
    }
  }

  const goMod = path.join(root, "go.mod");
  if (existsSync(goMod)) {
    const content = readFileSync(goMod, "utf8");
    if (/gin-gonic\/gin/.test(content)) out.add("gin");
    if (/labstack\/echo/.test(content)) out.add("echo");
    if (/gofiber\/fiber/.test(content)) out.add("fiber");
    if (/google\.golang\.org\/grpc/.test(content)) out.add("grpc");
  }

  if (files.some((f) => path.basename(f) === "Chart.yaml")) {
    out.add("helm");
  }

  for (const rel of files) {
    const base = path.basename(rel);
    if (base !== "requirements.txt" && base !== "pyproject.toml") continue;
    try {
      const content = readFileSync(path.join(root, rel), "utf8");
      if (/(^|\W)fastapi(\W|$)/i.test(content)) out.add("fastapi");
      if (/(^|\W)flask(\W|$)/i.test(content)) out.add("flask");
      if (/(^|\W)django(\W|$)/i.test(content)) out.add("django");
    } catch {
      /* skip */
    }
  }

  return [...out].sort();
}
