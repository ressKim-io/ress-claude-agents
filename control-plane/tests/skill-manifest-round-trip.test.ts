import { describe, expect, it } from "vitest";
import Ajv2020 from "ajv/dist/2020.js";
import jsonSchema from "../../schemas/skill-manifest.v1.json" with { type: "json" };
import { SkillManifest } from "../src/schema/skill-manifest.js";

const ajv = new Ajv2020.default({ strict: false, allErrors: true });
const validateJson = ajv.compile(jsonSchema as object);

const validSample = {
  name: "k8s-helm",
  description:
    "Use when modifying Helm charts (Chart.yaml, templates/*.tpl, values*.yaml).",
  version: "1.0.0",
  license: "MIT",
  applies_when: {
    files_present: ["**/Chart.yaml", "**/values*.yaml"],
    files_contain: { "**/Chart.yaml": "^apiVersion:\\s*v[12]" },
    frameworks: ["helm"],
    exclude_when: { files_present: ["**/kustomization.yaml"] },
  },
  portability: {
    level: "universal",
    tested_on: ["claude-code", "codex"],
    model_dependency: "none",
    domain_specificity: "focused",
  },
};

describe("skill-manifest round-trip (zod ↔ JSON Schema)", () => {
  it("valid sample passes both validators", () => {
    expect(SkillManifest.safeParse(validSample).success).toBe(true);
    expect(validateJson(validSample)).toBe(true);
  });

  it("missing name is rejected by both", () => {
    const broken = { ...validSample } as Record<string, unknown>;
    delete broken.name;
    expect(SkillManifest.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("non-kebab name is rejected by both", () => {
    const broken = { ...validSample, name: "K8sHelm" };
    expect(SkillManifest.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("non-semver version is rejected by both", () => {
    const broken = { ...validSample, version: "v1" };
    expect(SkillManifest.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("unknown top-level property is rejected by both", () => {
    const broken = { ...validSample, surprise: 1 };
    expect(SkillManifest.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("empty applies_when (none of the four signals) is rejected by both", () => {
    const broken = {
      name: "minimal",
      description: "x",
      applies_when: {},
    };
    expect(SkillManifest.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });

  it("language-only applies_when is accepted by both", () => {
    const ok = {
      name: "go-errors",
      description: "Use when wrapping Go errors",
      applies_when: { language: ["go"] },
    };
    expect(SkillManifest.safeParse(ok).success).toBe(true);
    expect(validateJson(ok)).toBe(true);
  });

  it("invalid portability.level enum is rejected by both", () => {
    const broken = {
      ...validSample,
      portability: { ...validSample.portability, level: "wrong" },
    };
    expect(SkillManifest.safeParse(broken).success).toBe(false);
    expect(validateJson(broken)).toBe(false);
  });
});
