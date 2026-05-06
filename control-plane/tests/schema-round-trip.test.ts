import { describe, it, expect } from "vitest";
import Ajv2020 from "ajv/dist/2020.js";
import jsonSchema from "../../schemas/project-profile.v1.json" with { type: "json" };
import { ProjectProfile } from "../src/schema/project-profile.js";

const ajv = new Ajv2020.default({ strict: false, allErrors: true });
const validateJson = ajv.compile(jsonSchema as object);

const validSample = {
  schema_version: 1 as const,
  generated_at: "2026-05-06T10:00:00Z",
  generator: "@ress/claude-agents@0.1.0",
  repo: { vcs: "git" as const, default_branch: "main", monorepo: false },
  languages: [
    { name: "go", files: 142, primary: true },
    { name: "yaml", files: 38, primary: false },
  ],
  frameworks: ["gin"],
  build_systems: ["go-modules"],
  files_signatures: {
    helm_chart_present: false,
    k8s_manifest_present: false,
    dockerfile_present: true,
    ci_provider: "github-actions" as const,
    test_framework: "go-test",
  },
  domain_hints: ["microservice", "api-gateway"],
};

describe("project-profile round-trip (zod ↔ JSON Schema)", () => {
  it("valid sample passes both validators", () => {
    expect(ProjectProfile.safeParse(validSample).success).toBe(true);
    expect(validateJson(validSample)).toBe(true);
  });

  it("missing required field is rejected by both", () => {
    const broken = { ...validSample } as Record<string, unknown>;
    delete broken.schema_version;
    expect(ProjectProfile.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("non-ISO generated_at is rejected by both", () => {
    const broken = { ...validSample, generated_at: "2026-01-01" };
    expect(ProjectProfile.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("unknown top-level property is rejected by both", () => {
    const broken = { ...validSample, surprise: 1 };
    expect(ProjectProfile.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("invalid ci_provider enum is rejected by both", () => {
    const broken = {
      ...validSample,
      files_signatures: {
        ...validSample.files_signatures,
        ci_provider: "concourse",
      },
    };
    expect(ProjectProfile.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("primary=true on multiple languages is caught by zod (JSON schema does not enforce)", () => {
    const broken = {
      ...validSample,
      languages: [
        { name: "go", files: 100, primary: true },
        { name: "yaml", files: 50, primary: true },
      ],
    };
    expect(ProjectProfile.safeParse(broken).success).toBe(false);
  });
});
