<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# security

보안·컴플라이언스 — OWASP, 위협 모델링, 인증 패턴, 공급망, 시크릿, PIPA·GDPR·SOC2

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install security@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/security/skills/<이름> <프로젝트>/.claude/skills/
```

## 함께 쓰면 좋은 plugin

본문에서 참조하는 순서다. 없어도 동작하지만 해당 참조는 열리지 않는다.

- [`saas`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/saas/README.md)
- [`infra`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/infra/README.md)
- [`dx`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/dx/README.md)
- [`ai`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/ai/README.md)
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`messaging`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/messaging/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`core/security.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/security.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (11)

| 이름 | 설명 |
|---|---|
| `/security:anti-bot` | 봇·매크로 방어 — 다층 방어 아키텍처, 행동 분석 기반 봇 탐지, Device/Browser Fingerprint, Headless 브라우저 탐지, JA3 TLS 지문, JS … |
| `/security:auth-patterns` | 인증·인가 설계 — OAuth2 flow, OIDC, PKCE, JWT, 세션, API Key, RBAC/ABAC/ReBAC, 멀티테넌시 인증 |
| `/security:child-data-protection` | 만14세 미만 아동 데이터 보호 — 검증 가능한 법정대리인 동의, COPPA·GDPR Art.8 비교, 가족 계정, 데이터 최소화, 광고 금지 |
| `/security:compliance-frameworks` | SOC2, HIPAA, GDPR, PCI-DSS 컴플라이언스 프레임워크 비교와 통제 항목 매핑, K8s 적용, 자동 증거 수집 |
| `/security:data-subject-rights` | 정보주체 권리 행사 DSR 자동화 — PIPA·GDPR·CCPA 열람·정정·삭제·이동, 본인 인증, 삭제 vs 익명화, Crypto-Shredding, 수탁자 통지 |
| `/security:kr-location-info-act` | 위치정보법 운영 — 사업 신고·허가, 별도 동의(제18조), 보유·파기, 국외 이전, 위반 처벌, PIPA·GDPR 비교 |
| `/security:ops-mcp-security` | 운영 시스템에 붙는 MCP 서버를 자격 증명 경계, 서버 read-only 모드, Claude Code deny 규칙의 세 겹으로 묶고 운영 데이터를 신뢰하지 않는 입력으로 다룬다 |
| `/security:owasp-top10` | OWASP Top 10(2021) A01~A10 취약점 설명과 언어별 방어 패턴 — Broken Access Control, Injection, SSRF, 암호화 실패 등 |
| `/security:secrets-management` | 시크릿 관리 — External Secrets Operator, HashiCorp Vault, Infisical, SOPS+age, 로테이션 자동화, Go·Spring 연동 |
| `/security:secure-coding` | 시큐어 코딩 — 입력 검증, 출력 인코딩, 암호화, 안전한 에러 처리, 파일 업로드, HTTP 보안 헤더, secure random, CI 보안 테스트 |
| `/security:threat-modeling` | 위협 모델링 — STRIDE, DREAD 점수화, Microsoft Kubernetes Threat Matrix, 4단계 분석 프로세스, 위협별 완화책 |

## Agents (2)

| 이름 | 설명 |
|---|---|
| `security:compliance-auditor` | SOC2/HIPAA/GDPR/PCI-DSS 컴플라이언스 *사후* 감사 에이전트 — 자동화된 보안 체크, 증거 수집, 감사 보고서 생성 |
| `security:compliance-strategy-agent` | 설계 단계 컴플라이언스 결정 에이전트 — 한국 PIPA(개인정보 보호법) / 위치정보법 / GDPR / CCPA / PCI-DSS를 built-in design으로 통합. 새 프로젝트의 … |
