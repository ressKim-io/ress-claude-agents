# AGENTS.md 외부 도구 검증 가이드

**대상**: Cursor / GitHub Copilot / Windsurf / Gemini CLI / Codex / Devin
**목적**: 우리 AGENTS.md (232줄)가 Claude Code 외 다른 AI 코딩 도구에서도 실제로 인식·반영되는지 정량 검증
**관련 문서**: [docs/migration/0001-agents-md-adoption.md](../migration/0001-agents-md-adoption.md)

---

## 배경

2026-04 기준 AI 코딩 도구 시장은 6개 모델이 SWE-bench 0.8점 차이로 경쟁하고 점유율도 분산 (Copilot 29% / Cursor 18% / Claude Code 18% / Windsurf 8%). **단일 도구 lock-in이 위험**하므로 [Linux Foundation AGENTS.md](https://agents.md/) 표준을 도입했다 (60K+ repo 채택).

이 가이드는 도입한 AGENTS.md가 다른 도구에서도 실제로 작동하는지 사용자가 직접 검증할 절차를 제공한다.

---

## 검증 대상 + 우선순위

| 도구 | AGENTS.md 인식 | 우선순위 | 설치 비용 |
|---|---|---|---|
| **Cursor** | 공식 지원 (자동) | ⭐⭐⭐ (점유율 18%) | 무료 tier |
| **GitHub Copilot** | 부분 지원 (`.github/copilot-instructions.md` 우선) | ⭐⭐⭐ (점유율 29%) | 유료 ($10/월) |
| **Windsurf** | AGENTS.md 인식 | ⭐⭐ (점유율 8%) | 무료 tier |
| **Gemini CLI** | AGENTS.md 인식 | ⭐⭐ | 무료 |
| **Codex (OpenAI)** | AGENTS.md 인식 (cloud agent) | ⭐ (특정 환경) | ChatGPT Plus 필요 |
| **Devin** | AGENTS.md 인식 (cloud only) | ⭐ (검증 어려움) | $500/월~ |

**최소 검증**: Cursor + Copilot 2개로 lock-in 회피 가설 1차 검증 가능.

---

## 도구별 설정

### Cursor

```bash
# 1. 다운로드: https://cursor.sh
# 2. 레포 열기:
cursor /Users/ress/my-file/ress-claude-agents

# 3. AGENTS.md 자동 인식 확인
#    Cmd+L (Composer) → "이 레포의 작업 룰 요약해줘"
```

**충돌 주의**: `.cursorrules` 또는 `.cursor/rules/` 디렉토리가 있으면 그것이 우선. 우리 레포는 둘 다 없음 → AGENTS.md만 인식.

### GitHub Copilot

```bash
# VS Code에 Copilot 확장 설치 후:
# 1. AGENTS.md 자동 인식 — 2026 기준 부분 지원
# 2. 명시적으로 인식시키려면 .github/copilot-instructions.md 추가:
mkdir -p .github
cat > .github/copilot-instructions.md <<'EOF'
> 이 레포의 모든 코딩 룰은 [AGENTS.md](../AGENTS.md)를 따른다.
EOF
```

Copilot Chat에서 "이 레포의 작업 룰 알려줘" → AGENTS.md 참조 여부 확인.

### Windsurf

```bash
# 1. https://codeium.com/windsurf 다운로드
# 2. 레포 열기 → Cascade panel → 자동 인식
# 3. 테스트: "AGENTS.md 룰 요약해줘"
```

### Gemini CLI

```bash
npm install -g @google/gemini-cli
cd /Users/ress/my-file/ress-claude-agents
gemini "이 레포의 코딩 룰을 요약해줘"
```

---

## 공통 테스트 케이스 (도구별 동일 실행)

### Test 1: AGENTS.md 자동 인식

```
프롬프트: "이 레포의 코딩 룰과 워크플로우를 요약해줘"

기대 결과:
- AGENTS.md의 4 Core Principles 언급 (Think Before Coding, Simplicity First 등)
- EXPLORE → PLAN → IMPLEMENT → VERIFY → COMMIT 워크플로우 언급
- Conventional Commits 형식 언급
- 메서드 길이 50줄 룰 언급

실패 신호:
- "이 레포의 룰은 잘 모릅니다" / "README를 보세요"
- 일반론적 답변 (AGENTS.md 내용 미참조)
```

### Test 2: 한국어 + 영어 혼용 처리

```
프롬프트 (한국어): "신규 기능 PR 만들 때 따라야 할 절차 알려줘"

기대 결과:
- AGENTS.md §Pull Requests + §Workflow 한국어로 답변
- "≤ 400줄", "Conventional Commits" 같은 원문 영어 그대로 유지
- Test plan checklist 포함

실패 신호:
- 영어로만 답변 (한국어 입력에 영어 출력)
- AGENTS.md 무시하고 일반론
```

### Test 3: 링크 참조 (.claude/rules/)

```
프롬프트: "코드 보안 룰 자세히 알려줘"

기대 결과:
- AGENTS.md §Security 요약
- .claude/rules/security.md 내용 인용 (PreparedStatement, bcrypt 등)
  ↑ 도구가 링크 따라가는지 검증

실패 신호:
- AGENTS.md §Security 짧은 내용만 (~10줄) 답변
- .claude/rules/security.md를 읽지 않음
```

### Test 4: 코드 작성 룰 적용

```
프롬프트: "Go로 사용자 인증 함수 하나 작성해줘"

기대 결과 (AGENTS.md 룰 반영):
- 50줄 이내
- Guard Clause (early return)
- 매직 넘버 X, 상수 사용
- WHY 주석만 (WHAT/HOW 주석 없음)
- 비밀번호 bcrypt 해시
- 에러는 wrap (errors.Wrap or fmt.Errorf %w)
- DB 쿼리는 PreparedStatement

실패 신호:
- 100줄+ 거대 함수
- 비밀번호 평문 저장
- 매직 넘버 (status == 3)
- 무의미한 주석 (// counter 증가)
```

### Test 5: 비즈니스 도메인 인식

```
프롬프트: "구독 결제 시스템 설계해줘 (한국 SaaS)"

기대 결과:
- business/subscription-billing.md 패턴 인식 (SubscriptionGateway, PlanVersion)
- business/payment-integration.md (Token-first, 한국 PortOne/Toss)
- ADR 템플릿 제안
- 한국 정기결제 (빌링키 vs Setup Intent)

실패 신호:
- Stripe만 언급 (한국 PG 누락)
- Plan/PlanVersion 분리 안 함
- Webhook idempotency 누락
```

### Test 6: 보안 룰

```
프롬프트: "MySQL 연결 설정 파일 작성해줘"

기대 결과:
- 환경변수 사용 (os.Getenv / process.env)
- placeholder 사용 (YOUR_PASSWORD)
- .env는 .gitignore 권장 멘트

실패 신호:
- 비밀번호 하드코딩
- "password123" 같은 예시값
```

---

## 결과 기록 양식

각 도구별로 다음 양식으로 기록 (`docs/guides/agents-md-tool-verification-results.md`로 저장 권장):

```markdown
## [도구명] 검증 결과 (YYYY-MM-DD)

| Test | 결과 | 비고 |
|------|------|------|
| 1. AGENTS.md 인식 | ✅/⚠️/❌ | ... |
| 2. 한영 혼용 | ✅/⚠️/❌ | ... |
| 3. 링크 참조 | ✅/⚠️/❌ | ... |
| 4. 코드 룰 적용 | ✅/⚠️/❌ | ... |
| 5. 비즈니스 도메인 | ✅/⚠️/❌ | ... |
| 6. 보안 룰 | ✅/⚠️/❌ | ... |

종합 판정: ⭐⭐⭐⭐⭐ (5점 만점)

특이사항:
- [도구가 잘 못 한 것]
- [추가 설정으로 개선된 것]
```

---

## 보안 주의사항

- **실제 시크릿 / 사내 코드 절대 입력 금지** — placeholder만
- Cursor/Copilot은 입력을 학습 데이터로 사용 가능 (Privacy Mode 활성화 권장)
- AGENTS.md 자체는 공개 OK이지만, `.claude/rules/cloud-cli-safety.md` 같은 내부 룰을 외부 도구에 보낼 때 주의

---

## 빠른 검증 (15분 코스)

시간 부족 시:
1. **Cursor만** 설치 (5분)
2. **Test 1, 4, 5** 실행 (10분)
3. 결과를 위 양식으로 1줄씩 기록

이것만으로도 lock-in 회피 가설(AGENTS.md가 다른 도구에서 작동) 1차 검증 가능.

---

## 후속 조치

검증 결과에 따른 개선 후보:

| 결과 | 후속 조치 |
|---|---|
| 모든 도구가 AGENTS.md 인식 ✅ | 마이그레이션 종결, 변경 없음 |
| 일부 도구가 링크 미참조 | 핵심 룰을 AGENTS.md 본문에 직접 포함 (현재 232줄 → 250+줄로 확장) |
| Copilot이 AGENTS.md 무시 | `.github/copilot-instructions.md`에 AGENTS.md 핵심 요약 복사 (drift 위험 ↑) |
| 한국어 처리 실패 | 도구별 한국어 모델 옵션 확인, AGENTS.md에 영어 부분 추가 |
| 코드 룰 미적용 | 룰 강도 조정 (더 명시적으로 작성) |

검증 결과를 `docs/guides/agents-md-tool-verification-results.md`에 기록 후, 후속 조치는 별도 ADR 또는 마이그레이션 문서로 작성한다.
