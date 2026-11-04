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
- [`architecture`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/architecture/README.md)
- [`cicd`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/cicd/README.md)
- [`k8s`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/k8s/README.md)
- [`messaging`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/messaging/README.md)
- [`observability`](https://github.com/ressKim-io/ress-claude-agents/blob/main/plugins/observability/README.md)

## 설치본에 포함되지 않는 것

**rule** 은 plugin 에 실을 수 없다. 필요하면 프로젝트의 `.claude/rules/` 로 복사한다.

- [`core/security.md`](https://github.com/ressKim-io/ress-claude-agents/blob/main/.claude/rules/core/security.md)

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (10)

| 이름 | 설명 |
|---|---|
| `/security:anti-bot` | 봇·매크로 방어 — 다층 방어 아키텍처, 행동 분석 기반 봇 탐지, Device/Browser Fingerprint, Headless 브라우저 탐지, JA3 TLS 지문, JS … |
| `/security:auth-patterns` | Authentication & Authorization Patterns 가이드 — OAuth2/OIDC, PKCE, JWT, Session, API Key 인증/인가 패턴 및 구현 가이드 |
| `/security:child-data-protection` | 만14세 미만 아동 개인정보·위치정보 처리 — 법정대리인 동의 검증, 추적 사실 가시화, 가족 계정 모델, 데이터 최소화, 미성년 채팅 모더레이션, 광고/마케팅 금지. 한국 PIPA 제22조의2 … |
| `/security:compliance-frameworks` | Compliance Frameworks Guide — SOC2, HIPAA, GDPR, PCI-DSS 컴플라이언스 프레임워크 매핑 및 자동화 증거 수집 |
| `/security:data-subject-rights` | 데이터 주체 권리(DSR) 운영 자동화 — 열람·정정·삭제·이동·처리정지·거부·자동결정거부, 본인 인증, 데이터 카탈로그, 백업/Kafka/캐시/검색 전파, Event Sourcing … |
| `/security:kr-location-info-act` | 한국 위치정보법(「위치정보의 보호 및 이용 등에 관한 법률」) 운영 — 사업 신고/허가, 별도 동의(약관·개인정보와 분리), 만8세 이하/14세 미만 법정대리인 동의, 즉시 파기, 매년 통계 … |
| `/security:owasp-top10` | OWASP Top 10 방어 가이드 — OWASP Top 10 (2021) 취약점 상세 설명과 언어별 실전 방어 패턴 |
| `/security:secrets-management` | 시크릿 관리 가이드 — K8s 시크릿 자동 주입, External Secrets Operator, Vault, Infisical, SOPS — 개발자가 .env 없이 개발하는 환경 |
| `/security:secure-coding` | Secure Coding Practices 가이드 — 언어별 시큐어 코딩, 입력 검증, 암호화 패턴, 에러 처리, 보안 헤더 |
| `/security:threat-modeling` | Threat Modeling Guide — STRIDE/DREAD 위협 모델링, Microsoft Kubernetes Threat Matrix, 위협 분석 프로세스 |

## Agents (2)

| 이름 | 설명 |
|---|---|
| `security:compliance-auditor` | SOC2/HIPAA/GDPR/PCI-DSS 컴플라이언스 *사후* 감사 에이전트 — 자동화된 보안 체크, 증거 수집, 감사 보고서 생성 |
| `security:compliance-strategy-agent` | 설계 단계 컴플라이언스 결정 에이전트 — 한국 PIPA(개인정보 보호법) / 위치정보법 / GDPR / CCPA / PCI-DSS를 built-in design으로 통합. 새 프로젝트의 … |
