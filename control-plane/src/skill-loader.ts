import { readFileSync } from "node:fs";
import path from "node:path";
import fg from "fast-glob";
import { parse as parseYaml } from "yaml";
import { SkillManifest } from "./schema/skill-manifest.js";

export interface LoadedSkill {
  category: string;
  dirName: string;
  sourcePath: string;
  manifest: SkillManifest;
}

export interface LoadIssue {
  sourcePath: string;
  reason: string;
}

export interface LoadResult {
  skills: LoadedSkill[];
  issues: LoadIssue[];
}

export async function loadSkills(assetsRoot: string): Promise<LoadResult> {
  const root = path.resolve(assetsRoot);
  const matches = await fg("skills/*/*/SKILL.md", {
    cwd: root,
    onlyFiles: true,
    suppressErrors: true,
  });

  const skills: LoadedSkill[] = [];
  const issues: LoadIssue[] = [];

  for (const rel of matches) {
    const sourcePath = path.join(root, rel);
    const skillDir = path.dirname(sourcePath);
    const dirName = path.basename(skillDir);
    const category = path.basename(path.dirname(skillDir));

    let raw: string;
    try {
      raw = readFileSync(sourcePath, "utf8");
    } catch (e: unknown) {
      issues.push({
        sourcePath,
        reason: `read failed: ${(e as Error).message}`,
      });
      continue;
    }

    const fm = extractFrontmatter(raw);
    if (!fm) {
      issues.push({
        sourcePath,
        reason: "no yaml frontmatter delimited by ---",
      });
      continue;
    }

    let parsed: unknown;
    try {
      parsed = parseYaml(fm);
    } catch (e: unknown) {
      issues.push({
        sourcePath,
        reason: `yaml parse failed: ${(e as Error).message}`,
      });
      continue;
    }

    const result = SkillManifest.safeParse(parsed);
    if (!result.success) {
      issues.push({
        sourcePath,
        reason: `manifest invalid: ${result.error.issues
          .map((i) => `${i.path.join(".")}: ${i.message}`)
          .join("; ")}`,
      });
      continue;
    }

    if (result.data.name !== dirName) {
      issues.push({
        sourcePath,
        reason: `name '${result.data.name}' does not match directory '${dirName}'`,
      });
      continue;
    }

    skills.push({
      category,
      dirName,
      sourcePath,
      manifest: result.data,
    });
  }

  skills.sort(
    (a, b) =>
      a.category.localeCompare(b.category) ||
      a.manifest.name.localeCompare(b.manifest.name),
  );
  issues.sort((a, b) => a.sourcePath.localeCompare(b.sourcePath));

  return { skills, issues };
}

export function extractFrontmatter(content: string): string | null {
  if (!content.startsWith("---")) return null;
  const lines = content.split(/\r?\n/);
  if (lines[0] !== "---") return null;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") {
      return lines.slice(1, i).join("\n");
    }
  }
  return null;
}
