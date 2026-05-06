// Shared file-glob ignore list for probe + match + init walks.
// Vendor / build directories never carry signal; init artifacts are
// listed so re-running probe/match after a successful init does not
// re-ingest its own outputs and produce drifted profiles.
export const PROBE_IGNORES: readonly string[] = [
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
  "project-profile.yml",
  ".claude-agents.yml",
];
