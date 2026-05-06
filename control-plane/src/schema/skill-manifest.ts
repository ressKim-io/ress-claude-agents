import { z } from "zod";

const NAME_PATTERN = /^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$/;
const SEMVER_PATTERN =
  /^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/;

export const PortabilityLevel = z.enum([
  "universal",
  "claude-only",
  "codex-incompat",
]);
export type PortabilityLevel = z.infer<typeof PortabilityLevel>;

export const ModelDependency = z.enum([
  "none",
  "claude-features",
  "tool-use",
]);
export type ModelDependency = z.infer<typeof ModelDependency>;

export const DomainSpecificity = z.enum(["focused", "general"]);
export type DomainSpecificity = z.infer<typeof DomainSpecificity>;

export const SandboxLevel = z.enum(["read-only", "exec-allowed"]);
export type SandboxLevel = z.infer<typeof SandboxLevel>;

export const NetworkLevel = z.enum(["none", "egress-only", "full"]);
export type NetworkLevel = z.infer<typeof NetworkLevel>;

export const ExcludeWhen = z
  .object({
    files_present: z.array(z.string().min(1)).optional(),
  })
  .strict();
export type ExcludeWhen = z.infer<typeof ExcludeWhen>;

const AppliesWhenBase = z
  .object({
    files_present: z.array(z.string().min(1)).optional(),
    files_contain: z.record(z.string().min(1)).optional(),
    language: z.array(z.string().min(1)).optional(),
    frameworks: z.array(z.string().min(1)).optional(),
    context_keywords: z.array(z.string().min(1)).optional(),
    exclude_when: ExcludeWhen.optional(),
  })
  .strict();

export const AppliesWhen = AppliesWhenBase.refine(
  (a) =>
    (a.files_present?.length ?? 0) > 0 ||
    (a.files_contain && Object.keys(a.files_contain).length > 0) ||
    (a.language?.length ?? 0) > 0 ||
    (a.frameworks?.length ?? 0) > 0,
  {
    message:
      "applies_when requires at least one of files_present / files_contain / language / frameworks",
  },
);
export type AppliesWhen = z.infer<typeof AppliesWhen>;

export const Portability = z
  .object({
    level: PortabilityLevel.optional(),
    tested_on: z.array(z.string().min(1)).optional(),
    model_dependency: ModelDependency.optional(),
    domain_specificity: DomainSpecificity.optional(),
  })
  .strict();
export type Portability = z.infer<typeof Portability>;

export const Security = z
  .object({
    signature: z.string().optional(),
    sandbox: SandboxLevel.optional(),
    network: NetworkLevel.optional(),
    secrets_required: z.array(z.string().min(1)).optional(),
  })
  .strict();
export type Security = z.infer<typeof Security>;

export const SkillManifest = z
  .object({
    name: z.string().regex(NAME_PATTERN).min(3).max(64),
    description: z.string().min(1).max(1024),
    version: z.string().regex(SEMVER_PATTERN).optional(),
    license: z.string().optional(),
    applies_when: AppliesWhen.optional(),
    portability: Portability.optional(),
    produces: z.array(z.string().min(1)).optional(),
    consumes: z.array(z.string().min(1)).optional(),
    security: Security.optional(),
  })
  .strict();
export type SkillManifest = z.infer<typeof SkillManifest>;
