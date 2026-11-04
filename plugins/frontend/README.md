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
| `/frontend:css-design-system` | CSS 와 디자인 시스템 — Tailwind CSS 4, Design Token, Shadcn/ui, Radix UI, Atomic Design, Dark Mode, 반응형, a11y |
| `/frontend:frontend-performance` | 프론트엔드 성능 — Core Web Vitals(LCP·INP·CLS), 번들 분석, Code Splitting, 이미지·폰트·스크립트 최적화, Prefetching |
| `/frontend:frontend-testing` | 프론트엔드 테스트 — Vitest, Testing Library, MSW, Playwright E2E, React Server Component 테스트, Test ID 전략, CI |
| `/frontend:nextjs` | Next.js App Router — React Server Components, Data Fetching, ISR, Route Handlers, Middleware, … |
| `/frontend:react-patterns` | React 설계 패턴 — React 19 기능, Server vs Client Component, Suspense·Error Boundary, 컴포넌트 설계, Form 처리 |
| `/frontend:state-management` | React 상태관리 — TanStack Query, Zustand, Jotai, Context, URL state 선택 기준 |
| `/frontend:typescript` | TypeScript 타입 시스템 — Generic, Utility Types, Discriminated Union, Type Narrowing, Branded Type, Zod 스키마 검증, … |

## Agents (1)

| 이름 | 설명 |
|---|---|
| `frontend:frontend-expert` | Frontend 전문가 — React 19, Next.js 15/16 App Router, React Server Components, React Compiler, Core Web Vitals, … |
