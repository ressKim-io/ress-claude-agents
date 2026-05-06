import { describe, expect, it } from "vitest";
import {
  countLanguages,
  detectBuildSystems,
  detectCiProvider,
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

describe("detectCiProvider", () => {
  it("returns none when no CI config is present", () => {
    expect(detectCiProvider(["src/main.go", "README.md"])).toBe("none");
  });

  it("returns github-actions for any .github/workflows/*.yml", () => {
    expect(detectCiProvider([".github/workflows/ci.yml"])).toBe(
      "github-actions",
    );
  });

  it("returns the first matching provider in scan order", () => {
    // github-actions wins over gitlab-ci because it appears first in CI_RULES
    expect(
      detectCiProvider([".github/workflows/ci.yml", ".gitlab-ci.yml"]),
    ).toBe("github-actions");
  });

  it("detects gitlab-ci, circleci, jenkins, drone, azure", () => {
    expect(detectCiProvider([".gitlab-ci.yml"])).toBe("gitlab-ci");
    expect(detectCiProvider([".circleci/config.yml"])).toBe("circleci");
    expect(detectCiProvider(["Jenkinsfile"])).toBe("jenkins");
    expect(detectCiProvider([".drone.yml"])).toBe("drone");
    expect(detectCiProvider(["azure-pipelines.yml"])).toBe("azure-pipelines");
    expect(detectCiProvider(["bitbucket-pipelines.yml"])).toBe(
      "bitbucket-pipelines",
    );
  });
});
