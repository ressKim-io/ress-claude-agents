import {
  mkdirSync,
  readFileSync,
  writeFileSync,
  existsSync,
} from "node:fs";
import path from "node:path";
import fg from "fast-glob";
import { parse as parseYaml } from "yaml";
import { extractFrontmatter, loadSkills } from "./skill-loader.js";

export type AdapterTool = "claude" | "cursor";
export type AdapterMode = "write" | "dry-run" | "diff";

export interface AdapterOptions {
  tool: AdapterTool;
  root: string;
  assets: string;
  mode?: AdapterMode;
}

export interface AdapterFileChange {
  path: string;
  source: string;
  status: "create" | "update" | "unchanged";
  content: string;
}

export interface AdapterResult {
  tool: AdapterTool;
  changes: AdapterFileChange[];
  issues: string[];
}

export async function adapter(
  opts: AdapterOptions,
): Promise<AdapterResult> {
  const mode = opts.mode ?? "write";
  switch (opts.tool) {
    case "claude":
      return adapterClaude(opts.root, opts.assets, mode);
    case "cursor":
      return adapterCursor(opts.root, opts.assets, mode);
  }
}

async function adapterClaude(
  root: string,
  assets: string,
  mode: AdapterMode,
): Promise<AdapterResult> {
  const { skills, issues: loadIssues } = await loadSkills(assets);
  const changes: AdapterFileChange[] = [];
  const issues = loadIssues.map((i) => `${rel(i.sourcePath, root)}: ${i.reason}`);

  for (const s of skills) {
    const target = path.join(
      root,
      ".claude",
      "skills",
      s.category,
      s.dirName,
      "SKILL.md",
    );
    const content = readFileSync(s.sourcePath, "utf8");
    changes.push(applyChange(target, content, s.sourcePath, root, mode));
  }

  return { tool: "claude", changes: sortChanges(changes), issues };
}

async function adapterCursor(
  root: string,
  assets: string,
  mode: AdapterMode,
): Promise<AdapterResult> {
  const { skills, issues: loadIssues } = await loadSkills(assets);
  const changes: AdapterFileChange[] = [];
  const issues = loadIssues.map((i) => `${rel(i.sourcePath, root)}: ${i.reason}`);

  for (const s of skills) {
    const body = readBody(s.sourcePath);
    const mdc = stringifyCursorMdc({
      description: s.manifest.description,
      globs: s.manifest.applies_when?.files_present ?? [],
      body,
    });
    const target = path.join(root, ".cursor", "rules", `${s.dirName}.mdc`);
    changes.push(applyChange(target, mdc, s.sourcePath, root, mode));
  }

  return { tool: "cursor", changes: sortChanges(changes), issues };
}

function applyChange(
  targetPath: string,
  content: string,
  sourcePath: string,
  root: string,
  mode: AdapterMode,
): AdapterFileChange {
  const existing = existsSync(targetPath)
    ? readFileSync(targetPath, "utf8")
    : null;
  let status: AdapterFileChange["status"];
  if (existing === null) status = "create";
  else if (existing === content) status = "unchanged";
  else status = "update";

  if (mode === "write" && status !== "unchanged") {
    mkdirSync(path.dirname(targetPath), { recursive: true });
    writeFileSync(targetPath, content);
  }

  return {
    path: rel(targetPath, root),
    source: rel(sourcePath, root),
    status,
    content,
  };
}

function rel(p: string, root: string): string {
  const r = path.relative(root, p);
  return r === "" ? path.basename(p) : r;
}

function sortChanges(changes: AdapterFileChange[]): AdapterFileChange[] {
  return [...changes].sort((a, b) => a.path.localeCompare(b.path));
}

function readBody(filePath: string): string {
  const raw = readFileSync(filePath, "utf8");
  if (!raw.startsWith("---")) return raw;
  const lines = raw.split(/\r?\n/);
  if (lines[0] !== "---") return raw;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") {
      return lines.slice(i + 1).join("\n");
    }
  }
  return raw;
}

interface CursorMdcArgs {
  description: string;
  globs: string[];
  body: string;
}

function stringifyCursorMdc(args: CursorMdcArgs): string {
  const lines: string[] = ["---"];
  lines.push(`description: ${yamlInlineString(args.description)}`);
  if (args.globs.length === 0) {
    lines.push("globs: []");
  } else {
    lines.push("globs:");
    for (const g of args.globs) {
      lines.push(`  - ${yamlInlineString(g)}`);
    }
  }
  lines.push("alwaysApply: false");
  lines.push("---");
  lines.push("");
  lines.push(stripLeadingBlank(args.body));
  const out = lines.join("\n");
  return out.endsWith("\n") ? out : `${out}\n`;
}

function yamlInlineString(value: string): string {
  if (
    value === "" ||
    /[:#\-?,&*!|>'"%@`{}\[\]]/.test(value) ||
    /^\s|\s$/.test(value)
  ) {
    const escaped = value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    return `"${escaped}"`;
  }
  return value;
}

function stripLeadingBlank(body: string): string {
  return body.replace(/^\n+/, "");
}
