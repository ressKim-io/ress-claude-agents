import kleur from "kleur";

export const VERSION = "0.1.0";

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
      return stub("probe", "P3 step 2 — generate project-profile.yml", rest, err);
    case "match":
      return stub("match", "P3 step 3 — score skills against profile", rest, err);
    case "init":
      return stub("init", "P3 step 5 — bootstrap project (5 step orchestration)", rest, err);
    case "lint":
      return stub("lint", "P3 step 6 — delegate to repo lint scripts", rest, err);
  }
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
