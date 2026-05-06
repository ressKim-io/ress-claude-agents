import { spawn } from "node:child_process";
import path from "node:path";
import fg from "fast-glob";

export interface LintOptions {
  root: string;
}

export interface LintScriptResult {
  script: string;
  exitCode: number;
  stdout: string;
  stderr: string;
}

export interface LintOutcome {
  results: LintScriptResult[];
  allGreen: boolean;
}

export async function lint(opts: LintOptions): Promise<LintOutcome> {
  const root = path.resolve(opts.root);
  const matches = await fg("scripts/validate-*.sh", {
    cwd: root,
    onlyFiles: true,
    suppressErrors: true,
  });
  matches.sort();

  const results: LintScriptResult[] = [];
  for (const rel of matches) {
    results.push(await runScript(path.join(root, rel), root));
  }

  return {
    results,
    allGreen: results.every((r) => r.exitCode === 0),
  };
}

function runScript(scriptAbs: string, cwd: string): Promise<LintScriptResult> {
  return new Promise((resolve) => {
    const proc = spawn("bash", [scriptAbs], { cwd, env: process.env });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });
    proc.on("close", (code) => {
      resolve({
        script: path.relative(cwd, scriptAbs),
        exitCode: code ?? 1,
        stdout,
        stderr,
      });
    });
    proc.on("error", (err: unknown) => {
      const message = err instanceof Error ? err.message : String(err);
      resolve({
        script: path.relative(cwd, scriptAbs),
        exitCode: 1,
        stdout: "",
        stderr: message,
      });
    });
  });
}
