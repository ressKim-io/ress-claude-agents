---
name: incident-postmortem
description: 인시던트 회고 표준 + Blameless 문화 — Severity 분류(SEV1~4), 24/48/72h 회고 SLA, postmortem 템플릿(timeline/impact/RCA 5 Whys/lessons/action items), Etsy "Just Culture" 5 questions, action item 70% 룰, repeating incident 분석, 외부 통신(status page/학부모 공지), 위치정보법/PIPA 24h 신고 의무. observability-incident-playbook의 Stage 5 분리/심화.
license: MIT
---

# Incident Postmortem — Blameless 회고 + Action Item 추적

인시던트 대응 5단계(Detect → Triage → Investigate → Mitigate → **Review**) 중 마지막 Stage 5 Review를 표준화한다. 목적은 (1) 재발 방지, (2) 조직 학습, (3) 외부 신뢰 회복. 한국은 위치정보법·PIPA의 **24시간 신고 의무**가 결합되어 회고와 법적 신고가 같은 타임라인에서 움직인다.

> 이 skill은 사고 회고 hub. 인시던트 대응 흐름은 `observability/observability-incident-playbook.md`. 회고에서 도출된 action item이 runbook 추가/개선이면 `operations/runbook-driven-ops.md`로 이동. 위치정보법 24h 신고 의무는 `legal/kr-location-info-act.md` §6.1.

## When to Use

- SEV1~2 인시던트 종료 후 회고 작성
- Repeating incident (같은 RCA N회) 패턴 분석
- 외부 통신 (status page / 학부모 공지 / refund 정책) 표준화
- Blameless 문화 도입 (Etsy "Just Culture")
- Action item 추적 + 미완 시 escalation
- 회고 facilitation (참석자/agenda/시간박스)
- Postmortem corpus 검색 (과거 사례 lookup)
- 위치정보법/PIPA 침해사고 24h 신고 SOP 결합
- Phase 1 안정화 단계 — on-call/회고 표준화

**관련 skill (cross-link)**:
- `observability/observability-incident-playbook.md` — Stage 5 Review 분리/심화 (이 skill이 해당 stage 깊이)
- `operations/runbook-driven-ops.md` — action item 중 SOP 개선은 runbook PR로 환류
- `sre/sre-sli-slo.md` — SLO 위반 회고 트리거
- `sre/chaos-engineering.md` — game-day로 회고 시뮬레이션
- `observability/aiops-remediation.md` — 재발 자동화 (반복 패턴 → auto-remediation)
- `legal/kr-location-info-act.md` §6.1 — 위치정보 침해 24h KISA 신고
- `legal/data-subject-rights.md` — 데이터 손실 시 정보주체 통지 의무
- `business/audit-log.md` — 회고 보존 (1년+) + 내부 감사
- `observability/alerting-discord.md` — 외부 통신 도구

**관련 agent**: `incident-responder`, `tech-lead`, `otel-expert`, `debugging-expert`, `compliance-auditor`

---

## 1. Severity 매트릭스

### 1.1 SEV 정의

| SEV | 영향 | 대응 시작 | 회고 SLA | 회고 필수 |
|---|---|---|---|---|
| **SEV1** | 전체 서비스 중단, 데이터 손실, 보안 침해 | 즉시 (CTO 호출 + war room) | **24시간** | 필수 |
| **SEV2** | 핵심 기능 중단, 다수 사용자 영향 | 30분 | **48시간** | 필수 |
| **SEV3** | 일부 기능 / 일부 사용자 영향 | 4시간 | 1주 | 선택 (반복 시 필수) |
| **SEV4** | 사소한 결함, 회피 가능 | 영업일 | 회고 X (issue만) | X |

### 1.2 eodini 매핑

| 사고 패턴 | SEV | 외부 통신 | 법적 신고 |
|---|---|---|---|
| 전체 서비스 다운 | SEV1 | status + 푸시 + 블로그 | - |
| 위치 데이터 손실/유출 | SEV1 | 학부모 직접 통지 | KISA 24h (위치정보법) |
| 개인정보 침해 (이름·연락처 유출) | SEV1 | 학부모 직접 통지 | PIPA 24h |
| 보안 침해 (인증·권한 우회) | SEV1 | 학부모 + 블로그 | KISA + PIPA |
| SSE 단절 5%+ | SEV2 | status | - |
| MQTT broker 다운 | SEV2 | status | - |
| FCM 발송 실패 5%+ | SEV2 | status (영향 적으면 생략) | - |
| Kafka consumer lag 폭주 | SEV2 | status | - |
| 한 노선 추적 지연 | SEV3 | 해당 학부모만 | - |
| 대시보드 오류 | SEV3 | 관리자 채널 | - |
| 채팅 일부 지연 | SEV3 | - | - |

> SEV1 + 위치정보법/PIPA 신고는 **법적 deadline이 회고 deadline보다 짧다**. 신고 SOP가 회고보다 우선 트리거.

---

## 2. 회고 템플릿

```markdown
---
postmortem_id: pm-2026-04-15-tracking-sse
title: Tracking SSE 단절 — 학부모 앱 위치 표시 멈춤
date: 2026-04-15
severity: SEV2
duration: 47m
author: @oncall-user
reviewers: [@tracking-lead, @cto]
related_runbook: rb-tracking-sse-001
related_postmortems: []
status: action-items-tracking
---

## Summary
{1~2줄}
학기 시작으로 학부모 동시 접속이 +40% 급증했고, Tracking 서비스 메모리 limit 부족으로 Pod이 OOMKill되어 SSE 연결이 끊김. replica 스케일로 복구.

## Impact
- 영향받은 사용자: ~1,200명 (학부모 앱 위치 표시 멈춤)
- 영향받은 시간: 14:23 ~ 15:10 KST (47분)
- 영향받은 서비스: Tracking
- 비즈니스 영향: 학부모 문의 32건, refund/보상 대상 0건
- 데이터 손실: 없음 (Kafka 이벤트 보존 정상)

## Detection
- 14:23 — Prometheus alert `SSEDisconnectRateHigh` (Discord)
- 14:24 — on-call (`@user`) 호출 응답
- 14:25 — 학부모 1차 문의 (#cs 채널)

## Timeline (KST)
| 시간 | 이벤트 |
|---|---|
| 14:23 | alert 발생 |
| 14:25 | runbook `rb-tracking-sse-001` 시작 |
| 14:28 | Pod OOMKill 5건 확인 |
| 14:35 | replica 4→8 수동 스케일 |
| 14:42 | 메트릭 회복 시작 |
| 14:55 | 정상화 확인 (5분 hysteresis) |
| 15:10 | 모니터링 종료 |
| 15:15 | status page "Resolved" |

## Root Cause (5 Whys)

1. **SSE 연결이 끊겼다** → Tracking Pod이 OOMKill됐다
2. **OOMKill 됐다** → 메모리 limit(512Mi)이 동시 연결 수에 비해 부족했다
3. **부족했다** → 학기 시작으로 학부모 동시 접속 +40% 증가
4. **증가가 capacity plan에 없었다** → 학기 시작 시즌 패턴이 반영 안 됨
5. **반영 안 됨** → 분기 capacity review에 시즌성 검토 항목이 없음

> Root cause는 시스템 결함 (capacity plan 항목 누락) — 사람의 실수 아님 (Etsy "Just Culture")

## Resolution
- 즉시: replica 4→8 스케일 (manual `kubectl scale`)
- 다음 배포: 메모리 limit 512Mi → 1Gi
- 다음 배포: HPA min replica 2 → 4

## Lessons Learned

### What went well ✅
- 알림 즉시 감지 (목표 < 1분)
- runbook `rb-tracking-sse-001` Step 3까지 효과적
- 학부모 status page 공지 5분 내

### What went wrong ❌
- OOMKill 직접 alert 없음 → 5분 진단 지연
- 학기 시작 시즌 capacity plan 누락
- runbook에 OOM 분기 절차 부재 (Step 5 일반 mitigation만)

### Where we got lucky 🍀
- 점심시간에 발생 (운행 시간대 X) → 영향 최소
- replica 8까지 1초 만에 스케일 (Pod 빠른 시작)

## Action Items

| ID | Action | Owner | Due | Issue |
|---|---|---|---|---|
| AI-1 | 학기 시작·종료 시즌 capacity plan 추가 | @ress | 2026-05-01 | #123 |
| AI-2 | OOMKill 즉시 감지 alert 추가 | @lead | 2026-04-22 | #124 |
| AI-3 | runbook `rb-tracking-sse-001` Step 5 OOM 분기 추가 | @oncall | 2026-04-25 | #125 |
| AI-4 | 메모리 limit / HPA 조정 PR | @ress | 2026-04-20 | #126 |
| AI-5 | Q3 chaos game-day에 시즌 capacity 시뮬레이션 추가 | @sre-lead | 2026-07-15 | #127 |

## Communication
- Status page: 14:25 Investigating → 14:42 Identified → 15:10 Resolved
- 학부모 공지: 푸시 발송 X (영향 47분 + 점심대 → status page만)
- 사내 Discord: #eodini-incident timeline 공유

## Related
- runbook: `rb-tracking-sse-001`
- repeating: 없음 (첫 발생, corpus 검색 결과)
- chaos game-day candidate: 시즌 capacity simulation
```

> **Steps는 검증 가능한 액션**, **사람 이름은 Owner에만** (RCA·Lessons에는 시스템 표현).

---

## 3. Blameless 원칙 — Etsy "Just Culture" 5 Questions

Allspaw의 Just Culture 프레임. 사고 분석 시 **사람 책임 전에 시스템 신호** 검토.

### 3.1 5 Questions

```
1. 그 시점에 어떤 정보를 갖고 있었는가?
   (전체 그림 vs 그 자리에서 본 부분 그림 — 후자만으로 판단)

2. 어떻게 했어야 했는가?
   (자명해 보이는 게 그 시점에도 자명했는가)

3. 어떤 신호를 놓쳤는가? 시스템이 어떻게 더 잘 알릴 수 있었는가?
   (alert 누락, 대시보드 미반영, runbook 부재 → 시스템 결함)

4. 의도적 위반인가, 오해인가, 시스템 설계의 결과인가?
   (악의는 거의 없다. 대부분 시스템이 그 실수를 가능하게 만든다)

5. 같은 상황에 다른 사람이 있었으면 다른 결과였겠나?
   (사람 교체로 해결되는 문제가 아니면 시스템 문제)
```

### 3.2 Blameless 검증 룰

- 회고 본문에 사람 이름이 RCA에 등장 → **stop**, 재구성
- "@user가 실수했다" → "시스템이 그 실수를 가능하게 했다"
- "다음엔 잘 하자" → ❌ 구체 action item 강제

### 3.3 사람 책임이 명확한 경우 (예외)

악의·반복적 게으름·의도적 우회 등 **인사 이슈**는 회고에서 분리 처리. 회고는 시스템 학습용, 인사 결정은 별도 채널.

---

## 4. Action Item 추적

| 원칙 | 동작 |
|---|---|
| **Owner 강제** | owner 없는 AI는 회고 머지 거부 (CI block) |
| **Due 강제** | 마감 없는 AI는 거부 |
| **Issue tracker 연동** | 모든 AI를 issue로 (audit + 알림) |
| **70% 룰** | 회고 후 30일 내 70% 미완 시 escalation |
| **Repeating 자동 격상** | 같은 RCA 카테고리 반복 시 AI 우선순위 자동 P0 |
| **runbook 환류** | SOP 개선 AI는 `operations/runbook-driven-ops.md` repo PR 강제 |

### 4.1 70% 룰 모니터링

```sql
-- 회고 후 30일 내 미완 비율
SELECT pm.id,
       COUNT(*) FILTER (WHERE ai.status != 'done') * 1.0 / COUNT(*) AS open_rate
FROM postmortems pm
JOIN action_items ai ON ai.postmortem_id = pm.id
WHERE pm.date < NOW() - INTERVAL '30 days'
GROUP BY pm.id
HAVING COUNT(*) FILTER (WHERE ai.status != 'done') * 1.0 / COUNT(*) > 0.3;
```

→ 결과는 주간 Discord 알림 + tech-lead 검토.

---

## 5. Repeating Incident 분석

```sql
-- 최근 90일 동일 RCA 카테고리 반복 검출
SELECT root_cause_category,
       COUNT(*)        AS occurrences,
       MAX(severity)   AS max_severity,
       array_agg(id)   AS postmortem_ids
FROM postmortems
WHERE date > NOW() - INTERVAL '90 days'
GROUP BY root_cause_category
HAVING COUNT(*) >= 2
ORDER BY occurrences DESC, max_severity ASC;
```

발견된 패턴 동작:
1. 다음 SEV 자동 1단계 격상 (SEV3 → SEV2)
2. 우선순위 P0 AI 자동 발행: "근본 원인 카테고리 X 재발 — 구조 개선 필요"
3. tech-lead 회의 의제 강제

---

## 6. 외부 통신 (Status Page + 사용자 공지)

### 6.1 Status Page 단계

| 단계 | 메시지 톤 | 채널 | 주기 |
|---|---|---|---|
| **Investigating** | "..을 조사 중" | status + Discord | 즉시 |
| **Identified** | "..원인 파악, 복구 중" | status | 5~15분 |
| **Monitoring** | "..복구 완료, 모니터링 중" | status | 정상화 후 |
| **Resolved** | "..정상화 완료" | status + (영향 큰 경우) 푸시 | 5분 후 |
| **Postmortem** | "..재발 방지 조치 발표" | 블로그 / 메일 | SEV1 24~72h 후 |

### 6.2 학부모 메시지 톤 가이드

```
❌ "기술적 문제로 일시 서비스 장애가 발생했습니다"
✅ "{14:23~15:10} 동안 학부모 앱 위치 표시가 멈췄습니다.
    원인: 학기 시작 동시 접속 증가로 인한 일시 용량 부족
    조치: 즉시 서버 증설 + 다음 주 영구 보강 예정
    피해: 운행 시간대가 아니어서 추적 영향 최소
    문의: support@eodini.io"
```

원칙:
- **사실 위주** + **사과** + **후속 조치** + **(해당 시) 환불/보상 정책**
- "기술적 문제" 같은 불투명 표현 금지
- 영향받은 시간·기능·사용자를 명시

### 6.3 법적 신고 의무

| 법령 | 트리거 | SLA | 신고처 |
|---|---|---|---|
| **위치정보법 침해사고** | 위치정보 유출/훼손 | **24시간** | KISA |
| **PIPA 침해사고** | 개인정보 유출 1천명+ 등 | **24시간** | 개인정보보호위원회 + KISA |
| 정통망법 침해 | 시스템 침입 | 24시간 | KISA |

> 24h SLA가 회고 SLA(48h)보다 짧음. 신고 트리거 SOP가 회고보다 우선.

---

## 7. Postmortem 미팅 Facilitation

```
[일정] 사고 종료 후 24~72h
        - SEV1: 24h 이내
        - SEV2: 48h 이내
        - SEV3: 1주 이내 (반복 시 단축)

[참석] 최소 인원
        - on-call (작성자)
        - 영향 서비스 owner (1명)
        - tech-lead (facilitator)
        - (SEV1만) CTO / 대표 / 법무

[시간] 60분 max — 더 길면 회고 무력화

[Agenda]
  1. Timeline 발표 (5분)
  2. 5 Whys RCA 토론 (15분)
  3. Lessons Learned 공유 (10분)
  4. Action Items 도출 (15분, owner+due 강제)
  5. 외부 통신 후속 (5분, SEV1~2)
  6. 다음 단계 (5분)

[금지]
  - 사람 이름으로 비난 ("@user 잘못")
  - "다음엔 잘 하자" 추상적 결론
  - owner 없는 action item
  - 60분 초과

[산출물]
  - postmortem.md (PR로 GitOps repo 등록)
  - Action items issue tracker 등록
  - (SEV1만) 외부 블로그 / 메일 / 학부모 푸시
```

---

## 8. Postmortem Corpus 검색

```
postmortems/
  2026/
    2026-04-15-tracking-sse-disconnect.md
    2026-04-22-fcm-push-fail-spike.md
    2026-05-03-pg-replica-lag.md
  2025/
    ...
  index.yaml   # tag, severity, service, root_cause_category
  README.md    # 검색·기여 가이드
```

검색 도구:
- ripgrep + frontmatter tag
- LLM RAG (corpus 임베딩) — 비슷한 사고 lookup 자동
- Slack `/postmortem search`
- Linear / Jira label 검색

---

## 9. 도메인 매핑 — 통학차량 플랫폼 사례

| 사고 카테고리 | SEV | 회고 SLA | 외부 통신 | 법적 신고 |
|---|---|---|---|---|
| 전체 서비스 다운 | SEV1 | 24h | status + 푸시 + 블로그 | - |
| **위치 데이터 유출** | SEV1 | 24h + KISA 24h | 학부모 직접 통지 | 위치정보법 |
| **개인정보 유출 1천명+** | SEV1 | 24h + PIPA 24h | 학부모 + 정부 신고 | PIPA |
| 보안 침해 (인증 우회) | SEV1 | 24h | 학부모 + 블로그 | KISA + PIPA |
| SSE 단절 5%+ | SEV2 | 48h | status | - |
| MQTT broker 다운 | SEV2 | 48h | status | - |
| FCM 발송 실패 5%+ | SEV2 | 48h | (영향 적으면 생략) | - |
| Kafka consumer lag 폭주 | SEV2 | 48h | status | - |
| 한 노선 추적 지연 | SEV3 | 1주 | 해당 학부모만 | - |
| 대시보드 오류 | SEV3 | 1주 (선택) | 관리자 채널 | - |
| 채팅 일부 지연 | SEV3 | 1주 (선택) | - | - |

---

## 10. 함정 (자주 빠뜨리는 것)

| 함정 | 결과 | 대응 |
|---|---|---|
| 사람 이름으로 RCA 끝냄 | Blameless 위반, 학습 정체 | 5 Whys + 시스템 신호 검토 |
| Action items가 owner/due 없음 | 실현 X | CI block (frontmatter 검증) |
| Repeating incident 패턴 무시 | 같은 사고 반복 | 90일 RCA 카테고리 모니터링 |
| 외부 통신 지연 | 사용자 신뢰 손상 | 5분 내 1차 status page |
| "이번엔 운이 좋았다" 인식 누락 | 우연 의존 운영 | "Where we got lucky" 섹션 강제 |
| 회고 후 30일 AI 미완 alert 없음 | 70% 룰 무력화 | 주간 Discord 알림 |
| SEV1만 회고하고 SEV2 무시 | 장기 학습 손실 | SEV2 회고 필수화 |
| Postmortem이 wiki에 묻혀 검색 불가 | corpus 가치 소멸 | GitOps repo + index |
| 법적 신고 (24h KISA / PIPA) 누락 | 형사처벌 | 침해 트리거 SOP 자동 발동 |
| 회고 파일이 너무 길어 readers 안 읽음 | 학습 X | Summary 1~2줄 강제 |
| 미팅에 너무 많은 사람 참석 | 회고 무력화 | 최소 인원 룰 (4~6명) |
| 5 Whys를 3까지만 하고 멈춤 | RCA 얕음 | 5 Whys 의제 시간 박스 강제 |
| Action item을 회고 작성자가 모두 가져감 | 분산 책임 X | 영향 서비스 owner에 분산 |
| chaos engineering 결과가 회고로 안 옴 | game-day 효과 반감 | game-day 산출물 = postmortem 동일 템플릿 |

---

## 11. 운영 체크리스트

### Severity / SLA
- [ ] SEV1~4 정의 + eodini 매핑 표 공유
- [ ] 회고 SLA (SEV1=24h, SEV2=48h, SEV3=1주) 자동 reminder
- [ ] **위치정보법/PIPA 24h 신고 SOP** 침해 트리거 자동

### 회고 표준
- [ ] markdown 표준 template (frontmatter + 9개 섹션)
- [ ] Blameless 5 questions 의제 시간 박스
- [ ] Action items owner+due 강제 (CI block)
- [ ] postmortem GitOps repo + index.yaml

### Action Item 추적
- [ ] 모든 AI를 issue tracker
- [ ] 70% 룰 모니터링 (30일 내 70% 완료)
- [ ] AI → runbook PR 환류 (`operations/runbook-driven-ops.md`)
- [ ] Repeating 시 SEV 자동 격상 + P0 AI 발행

### 외부 통신
- [ ] Status page 4단계 표준 메시지
- [ ] 학부모 푸시 톤 가이드 (사실+사과+후속)
- [ ] SEV1 블로그/메일 발행 SOP
- [ ] **KISA / PIPA 24h 신고 SOP**

### Repeating
- [ ] postmortem corpus 검색 (LLM RAG 권장)
- [ ] 90일 RCA 카테고리 모니터링
- [ ] Repeating 시 자동 SEV 격상

### 환류
- [ ] chaos engineering 산출물 = postmortem 동일 템플릿
- [ ] AI → runbook PR 자동화 (`operations/runbook-driven-ops.md`)
- [ ] 분기 회고 trends 발표 (tech-lead → 전체 팀)

---

## 부록 A: 자주 묻는 질문

**Q. 작은 SEV3 / SEV4도 매번 회고?**
A. SEV3은 선택, SEV4는 X (issue로만). 단 SEV3·4가 같은 RCA로 반복되면 회고 필수. Repeating 분석에서 자동 검출.

**Q. 회고 작성자 누가?**
A. on-call (사고 대응 직접 수행자) — 가장 정확한 timeline 보유. tech-lead가 facilitator로 검토.

**Q. Action item 70% 룰 어겨도 OK한 케이스?**
A. (1) 우선순위가 더 높은 인시던트 발생, (2) 외부 의존 (벤더 패치 대기), (3) action item 자체가 무효화 됨 (스펙 변경). 어느 경우든 명시 코멘트 + tech-lead 승인 필수.

**Q. 익명 회고 가능?**
A. 작성자는 owner 명시(audit). 단 RCA 본문은 시스템 표현 → 사실상 익명. "사용자 이름"만 들어갈 곳은 Owner / Reviewer 메타데이터.

**Q. 외주팀이 발생시킨 사고는 누가 회고?**
A. 회사 측 owner가 회고 작성 (외주 책임 전가 X). 외주 측 협력 받아 timeline 보강. Action items은 회사가 갖고 외주 SLA 개선 포함.

**Q. LLM으로 RCA 자동 생성 가능?**
A. Timeline·alert log·runbook 실행 audit를 입력으로 1차 초안 가능. 단 5 Whys와 Blameless 검증은 사람 facilitator 필수. LLM이 사람 책임으로 결론 내는 것 검증해야 함.

**Q. 회고 영문/한문 표준?**
A. 한국 팀 디폴트 한글. 글로벌 외주·법적 자료는 영문 병기. 본문은 한글, 인용 시 원문 유지.

**Q. SEV1 회고 24h 데드라인이 너무 짧지 않나?**
A. 24h 안엔 초안 + Timeline + 1차 Action items면 충분. RCA 5 Whys와 Lessons는 72h까지 보강 가능. 외부 통신은 24h 안에 우선 발행.

**Q. 회고 미팅에서 격한 토론이 일어나면?**
A. Facilitator가 시간박스 유지. 결론 안 나는 항목은 "follow-up agenda"로 분리. 60분 초과는 회고 무력화 신호.

---

## 참고 자료

- Google SRE Book — Chapter 15 "Postmortem Culture: Learning from Failure"
- John Allspaw (Etsy) — "Blameless PostMortems and a Just Culture"
- "The Site Reliability Workbook" — Chapter 8 (Postmortem Culture)
- PagerDuty Postmortem Templates (오픈소스)
- 「위치정보의 보호 및 이용 등에 관한 법률」 (24h 신고 의무)
- 「개인정보 보호법」 (PIPA 24h 신고 의무)
