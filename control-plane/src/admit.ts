import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { loadSkills, type LoadedSkill } from "./skill-loader.js";

export type AdmitMode = "warn" | "deny";

export interface AdmitInput {
  tool: string;
  path?: string;
  skill?: string;
  root: string;
  assets: string;
  mode?: AdmitMode;
}

export interface AdmitDecision {
  allow: boolean;
  reason: string;
}

const MUTATING_TOOLS = new Set(["Edit", "Write", "NotebookEdit"]);

export async function admit(input: AdmitInput): Promise<AdmitDecision> {
  if (!MUTATING_TOOLS.has(input.tool)) {
    return { allow: true, reason: `tool '${input.tool}' is read-only` };
  }
  if (!input.skill) {
    return { allow: true, reason: "no active skill — admission out of scope" };
  }
  if (!input.path) {
    return { allow: true, reason: "no path provided — admission skipped" };
  }

  const { skills } = await loadSkills(input.assets);
  const found = skills.find((s) => s.manifest.name === input.skill);
  if (!found) {
    return {
      allow: true,
      reason: `skill '${input.skill}' not in assets — admission skipped`,
    };
  }

  const sandbox = found.manifest.security?.sandbox;
  if (sandbox === "read-only") {
    return {
      allow: false,
      reason: `skill '${found.manifest.name}' has security.sandbox=read-only; ${input.tool} on '${input.path}' denied`,
    };
  }

  const aw = found.manifest.applies_when;
  if (!aw) {
    return {
      allow: true,
      reason: `skill '${found.manifest.name}' has no applies_when; admission permissive`,
    };
  }

  const relPath = toRelative(input.path, input.root);
  const fullPath = path.resolve(input.root, relPath);

  if (matchAnyGlob(relPath, aw.exclude_when?.files_present ?? [])) {
    return {
      allow: false,
      reason: `'${relPath}' matches applies_when.exclude_when.files_present`,
    };
  }

  if (matchAnyGlob(relPath, aw.files_present ?? [])) {
    return {
      allow: true,
      reason: `'${relPath}' matches applies_when.files_present`,
    };
  }

  const containsRules = Object.entries(aw.files_contain ?? {});
  for (const [glob, regexStr] of containsRules) {
    if (!matchGlob(relPath, glob)) continue;
    if (!existsSync(fullPath)) continue;
    let regex: RegExp;
    try {
      regex = new RegExp(regexStr, "m");
    } catch {
      continue;
    }
    let content: string;
    try {
      content = readFileSync(fullPath, "utf8");
    } catch {
      continue;
    }
    if (regex.test(content)) {
      return {
        allow: true,
        reason: `'${relPath}' matches applies_when.files_contain['${glob}']`,
      };
    }
  }

  return {
    allow: false,
    reason: `'${relPath}' does not match skill '${found.manifest.name}' applies_when`,
  };
}

export function matchGlob(p: string, pattern: string): boolean {
  return globToRegex(pattern).test(p);
}

function matchAnyGlob(p: string, patterns: string[]): boolean {
  return patterns.some((pat) => matchGlob(p, pat));
}

export function globToRegex(glob: string): RegExp {
  let out = "^";
  let i = 0;
  while (i < glob.length) {
    const c = glob[i]!;
    if (c === "*" && glob[i + 1] === "*") {
      const next = glob[i + 2];
      if (next === "/") {
        out += "(?:.*/)?";
        i += 3;
        continue;
      }
      out += ".*";
      i += 2;
      continue;
    }
    if (c === "*") {
      out += "[^/]*";
      i++;
      continue;
    }
    if (c === "?") {
      out += "[^/]";
      i++;
      continue;
    }
    if (".(){}[]+^$|\\".includes(c)) {
      out += `\\${c}`;
      i++;
      continue;
    }
    out += c;
    i++;
  }
  out += "$";
  return new RegExp(out);
}

function toRelative(p: string, root: string): string {
  const abs = path.isAbsolute(p) ? p : path.resolve(root, p);
  const rel = path.relative(path.resolve(root), abs);
  return rel.split(path.sep).join("/");
}
