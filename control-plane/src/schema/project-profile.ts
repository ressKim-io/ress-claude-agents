import { z } from "zod";

const ISO_8601 =
  /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$/;

export const Vcs = z.enum(["git", "hg", "fossil", "none"]);
export type Vcs = z.infer<typeof Vcs>;

export const CiProvider = z.enum([
  "github-actions",
  "gitlab-ci",
  "circleci",
  "jenkins",
  "buildkite",
  "drone",
  "azure-pipelines",
  "bitbucket-pipelines",
  "none",
]);
export type CiProvider = z.infer<typeof CiProvider>;

export const Repo = z
  .object({
    vcs: Vcs,
    default_branch: z.string().min(1),
    monorepo: z.boolean(),
  })
  .strict();
export type Repo = z.infer<typeof Repo>;

export const Language = z
  .object({
    name: z.string().min(1),
    files: z.number().int().min(0),
    primary: z.boolean(),
  })
  .strict();
export type Language = z.infer<typeof Language>;

export const FilesSignatures = z
  .object({
    helm_chart_present: z.boolean().optional(),
    k8s_manifest_present: z.boolean().optional(),
    dockerfile_present: z.boolean().optional(),
    ci_provider: CiProvider.optional(),
    test_framework: z.string().optional(),
  })
  .catchall(z.union([z.boolean(), z.string(), z.number().int()]));
export type FilesSignatures = z.infer<typeof FilesSignatures>;

export const Constraints = z
  .object({
    exclude_skills: z.array(z.string().min(1)).optional(),
    exclude_agents: z.array(z.string().min(1)).optional(),
    pin_skills: z.array(z.string().min(1)).optional(),
  })
  .strict();
export type Constraints = z.infer<typeof Constraints>;

export const ProjectProfile = z
  .object({
    schema_version: z.literal(1),
    generated_at: z.string().regex(ISO_8601),
    generator: z.string().min(1),
    repo: Repo,
    languages: z.array(Language),
    frameworks: z.array(z.string().min(1)),
    build_systems: z.array(z.string().min(1)),
    files_signatures: FilesSignatures,
    domain_hints: z.array(z.string().min(1)).optional(),
    constraints: Constraints.optional(),
  })
  .strict()
  .refine(
    (p) =>
      p.languages.length === 0 ||
      p.languages.filter((l) => l.primary).length === 1,
    { message: "Exactly one language must have primary=true (unless empty)" },
  );
export type ProjectProfile = z.infer<typeof ProjectProfile>;
