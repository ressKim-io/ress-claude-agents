import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

export type HookMode = "warn" | "deny";

export interface InstallHookInput {
  root: string;
  mode?: HookMode;
  dryRun?: boolean;
}

export interface InstallHookResult {
  installed: boolean;
  alreadyPresent: boolean;
  settingsPath: string;
  mode: HookMode;
}

const HOOK_MARKER = "@ress/claude-agents admit";
const HOOK_MATCHER = "Edit|Write|NotebookEdit";

interface SettingsShape {
  hooks?: {
    PreToolUse?: HookGroup[];
    [k: string]: unknown;
  };
  [k: string]: unknown;
}

interface HookGroup {
  matcher?: string;
  hooks?: HookEntry[];
  [k: string]: unknown;
}

interface HookEntry {
  type?: string;
  command?: string;
  [k: string]: unknown;
}

export async function installHook(
  input: InstallHookInput,
): Promise<InstallHookResult> {
  const mode = input.mode ?? "warn";
  const settingsPath = path.join(
    input.root,
    ".claude",
    "settings.local.json",
  );

  let settings: SettingsShape = {};
  if (existsSync(settingsPath)) {
    try {
      settings = JSON.parse(readFileSync(settingsPath, "utf8")) as SettingsShape;
    } catch {
      settings = {};
    }
  }

  if (!settings.hooks) settings.hooks = {};
  if (!settings.hooks.PreToolUse) settings.hooks.PreToolUse = [];

  const alreadyPresent = settings.hooks.PreToolUse.some((g) =>
    (g.hooks ?? []).some((h) =>
      typeof h.command === "string" && h.command.includes(HOOK_MARKER),
    ),
  );

  if (alreadyPresent) {
    return {
      installed: false,
      alreadyPresent: true,
      settingsPath,
      mode,
    };
  }

  const command =
    `npx @ress/claude-agents admit ` +
    `--tool="$CLAUDE_TOOL" ` +
    `--path="$CLAUDE_TOOL_INPUT_path" ` +
    `--skill="$CLAUDE_ACTIVE_SKILL" ` +
    `--mode=${mode}`;

  settings.hooks.PreToolUse.push({
    matcher: HOOK_MATCHER,
    hooks: [{ type: "command", command }],
  });

  if (!input.dryRun) {
    mkdirSync(path.dirname(settingsPath), { recursive: true });
    writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
  }

  return {
    installed: !input.dryRun,
    alreadyPresent: false,
    settingsPath,
    mode,
  };
}
