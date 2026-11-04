#!/usr/bin/env node
// 모든 skill / agent / command 의 frontmatter 를 실제 YAML 파서로 검사한다.
//
// 왜 필요한가: 기존 validator 는 line 기반이라 `description: "앞"뒤` 같은 깨진 YAML 을
// 통과시킨다. 런타임은 이런 frontmatter 를 통째로 버린다. config-explicit-defaults 가
// 실제로 그 상태였다.
//
// 의존성: control-plane 의 yaml 패키지. 없으면 건너뛰지 않고 실패한다.
// 사용: node scripts/validate-frontmatter-yaml.mjs
// Exit code: 0 = 통과, 1 = 실패

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
process.chdir(root);

function loadYamlParser() {
  const require = createRequire(path.join(root, "control-plane", "package.json"));
  try {
    return require("yaml").parse;
  } catch {
    console.error("FAIL  yaml 패키지를 찾을 수 없다. 실행: cd control-plane && npm ci");
    process.exit(1);
  }
}

function listAssets() {
  const script = [
    "source scripts/lib/layout.sh",
    "assert_floor skills",
    "assert_floor agents",
    "assert_floor commands",
    "skill_files",
    "agent_files",
    "command_files",
  ].join(" && ");
  try {
    return execFileSync("bash", ["-c", script], { encoding: "utf8" }).trim().split("\n");
  } catch (err) {
    console.error(String(err.stdout ?? "").trim() || err.message);
    process.exit(1);
  }
}

const parse = loadYamlParser();
const files = listAssets();
const errors = [];
let parsed = 0;

for (const file of files) {
  const match = readFileSync(file, "utf8").match(/^---\n([\s\S]*?)\n---/);
  if (!match) continue;
  parsed += 1;
  try {
    const data = parse(match[1]);
    if (data === null || typeof data !== "object" || Array.isArray(data)) {
      errors.push(`${file}: frontmatter 가 key-value 형태가 아니다`);
    }
  } catch (err) {
    errors.push(`${file}: ${err.message.split("\n")[0]}`);
  }
}

if (parsed === 0) {
  console.error("FAIL  검사한 frontmatter 가 0건이다");
  process.exit(1);
}

if (errors.length > 0) {
  for (const error of errors) console.error(`YAML 오류  ${error}`);
  console.error(`\nFAIL  ${errors.length}건 / 전체 ${parsed}건`);
  process.exit(1);
}

console.log(`OK  frontmatter ${parsed}건 YAML 유효 (대상 ${files.length}개 파일)`);
