<!-- 자동 생성: scripts/generate-plugin-readmes.py. 직접 수정하지 않는다. -->
# frontend

Frontend — React, Next.js, TypeScript, 상태 관리, CSS, 성능, 테스트

## 설치

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install frontend@ress
```

하나만 필요하면 폴더를 복사해도 된다. 이때 호출명에 plugin 접두사가 붙지 않는다.

```
cp -r plugins/frontend/skills/<이름> <프로젝트>/.claude/skills/
```

## 설치본에 포함되지 않는 것

**권한 규칙** (`permissions.deny`) 도 실리지 않는다. agent 의 Permission Boundary 는 설치본에서 강제되지 않는 안내문이다.

## Skills (7)

| 이름 | 설명 |
|---|---|
| `/frontend:css-design-system` | CSS & Design System 가이드 — Tailwind CSS, Design System 구축, Radix UI, Shadcn/ui, 접근성 종합 가이드 |
| `/frontend:frontend-performance` | Frontend Performance 가이드 — Core Web Vitals 최적화, 번들 분석, Code Splitting, Image/Font 최적화 종합 가이드 |
| `/frontend:frontend-testing` | Frontend Testing 가이드 — Vitest, Playwright, Testing Library, MSW를 활용한 프론트엔드 테스트 전략 종합 가이드 |
| `/frontend:nextjs` | Next.js 가이드 — Next.js 15 App Router, React Server Components, ISR, Middleware, 라우팅 전략 종합 가이드 |
| `/frontend:react-patterns` | React Patterns 가이드 — React 19+, Server Components, Suspense, 상태관리, 컴포넌트 설계 패턴 종합 가이드 |
| `/frontend:state-management` | State Management 가이드 — Zustand, Jotai, TanStack Query, React Context 기반 상태관리 선택 및 패턴 |
| `/frontend:typescript` | TypeScript 심화 가이드 — TypeScript 5.x 타입 시스템 심화, 제네릭 패턴, Utility Types, 타입 안전성 종합 가이드 |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `frontend:frontend-expert` | Frontend 전문가 — React 19, Next.js 15/16 App Router, React Server Components, React Compiler, Core Web Vitals, … |
