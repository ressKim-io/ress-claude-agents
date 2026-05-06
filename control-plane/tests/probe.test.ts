import { describe, expect, it } from "vitest";
import {
  countLanguages,
  detectBuildSystems,
} from "../src/probe.js";

describe("countLanguages", () => {
  it("returns empty array on empty input", () => {
    expect(countLanguages([])).toEqual([]);
  });

  it("groups by extension and marks the highest count as primary", () => {
    const result = countLanguages([
      "src/a.go",
      "src/b.go",
      "src/c.go",
      "deploy/values.yaml",
      "Dockerfile",
    ]);
    expect(result).toEqual([
      { name: "go", files: 3, primary: true },
      { name: "dockerfile", files: 1, primary: false },
      { name: "yaml", files: 1, primary: false },
    ]);
  });

  it("breaks ties on count by name ascending", () => {
    const result = countLanguages(["a.go", "b.py"]);
    expect(result).toEqual([
      { name: "go", files: 1, primary: true },
      { name: "python", files: 1, primary: false },
    ]);
  });

  it("ignores files with no recognized extension", () => {
    expect(countLanguages(["LICENSE", "README"])).toEqual([]);
  });

  it("merges variant extensions into one language", () => {
    const result = countLanguages(["a.ts", "b.tsx", "c.mts"]);
    expect(result).toEqual([{ name: "typescript", files: 3, primary: true }]);
  });

  it("recognizes Dockerfile as a special filename", () => {
    expect(countLanguages(["Dockerfile"])).toEqual([
      { name: "dockerfile", files: 1, primary: true },
    ]);
  });
});

describe("detectBuildSystems", () => {
  it("returns empty when no build manifest is present", () => {
    expect(detectBuildSystems(["README.md", "src/main.go"])).toEqual([]);
  });

  it("detects multiple systems and sorts ascending", () => {
    expect(
      detectBuildSystems([
        "go.mod",
        "package.json",
        "deploy/Chart.yaml",
        "infra/main.tf",
      ]),
    ).toEqual(["go-modules", "helm", "npm", "terraform"]);
  });

  it("dedupes pip across requirements.txt and pyproject.toml", () => {
    expect(detectBuildSystems(["requirements.txt", "pyproject.toml"])).toEqual([
      "pip",
    ]);
  });

  it("detects terraform from any .tf file", () => {
    expect(detectBuildSystems(["infra/networking.tf"])).toEqual(["terraform"]);
  });
});
