# CSS & Design System 가이드

Tailwind CSS, Design System 구축, Radix UI, Shadcn/ui, 접근성 종합 가이드.

## Quick Reference

```
스타일링 전략 선택
    │
    ├─ 신규 프로젝트 ────────> Tailwind CSS (utility-first)
    ├─ 디자인 시스템 구축 ──> Radix UI + Tailwind + CVA
    ├─ 빠른 프로토타이핑 ──> Shadcn/ui (복사 기반)
    │
    ├─ Scoped 스타일 필요 ──> CSS Modules
    ├─ 레거시 CSS-in-JS ───> styled-components → Tailwind 마이그레이션 고려
    │
    컴포넌트 라이브러리
    │
    ├─ Headless (접근성 완전) > Radix UI
    ├─ 스타일 포함 (빠른 개발) > Shadcn/ui
    └─ 커스텀 디자인 시스템 ──> Radix Primitives + Tailwind + CVA
```

---

## Tailwind CSS 4.0

### CSS-first Configuration

```css
/* app.css — Tailwind 4.0은 CSS에서 직접 설정 */
@import "tailwindcss";

@theme {
  /* 색상 시스템 */
  --color-primary-50: oklch(0.97 0.01 250);
  --color-primary-100: oklch(0.93 0.03 250);
  --color-primary-500: oklch(0.55 0.2 250);
  --color-primary-600: oklch(0.48 0.2 250);
  --color-primary-700: oklch(0.4 0.18 250);

  /* 시맨틱 색상 */
  --color-background: var(--color-primary-50);
  --color-foreground: oklch(0.15 0.02 250);
  --color-muted: oklch(0.55 0.01 250);
  --color-border: oklch(0.85 0.01 250);

  /* 타이포그래피 */
  --font-sans: 'Pretendard', 'Noto Sans KR', system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;

  /* 간격 */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;

  /* 그림자 */
  --shadow-sm: 0 1px 2px oklch(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px oklch(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px oklch(0 0 0 / 0.15);

  /* 브레이크포인트 */
  --breakpoint-sm: 640px;
  --breakpoint-md: 768px;
  --breakpoint-lg: 1024px;
  --breakpoint-xl: 1280px;

  /* 애니메이션 */
  --animate-fade-in: fade-in 0.2s ease-out;
  --animate-slide-up: slide-up 0.3s ease-out;
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slide-up {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
```

### Container Queries

```tsx
// 부모 컨테이너 크기에 따라 반응
function ProductCard() {
  return (
    <div className="@container">
      <div className="flex flex-col @md:flex-row gap-4">
        <img className="w-full @md:w-48" src="/product.jpg" alt="상품" />
        <div>
          <h3 className="text-sm @md:text-lg font-bold">상품명</h3>
          <p className="hidden @md:block">상세 설명...</p>
        </div>
      </div>
    </div>
  );
}
```

---

## Design Token 체계

### 토큰 계층

```
Global Tokens (원시값)
  → color-blue-500, font-size-16, spacing-4

Semantic Tokens (의미)
  → color-primary, color-error, font-heading, spacing-card

Component Tokens (컴포넌트 전용)
  → button-bg, button-text, card-padding
```

### CSS Custom Properties로 구현

```css
/* tokens.css */
:root {
  /* Global Tokens */
  --blue-500: oklch(0.55 0.2 250);
  --red-500: oklch(0.55 0.22 25);
  --gray-100: oklch(0.95 0.005 250);
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;

  /* Semantic Tokens (Light) */
  --color-bg: white;
  --color-bg-subtle: var(--gray-100);
  --color-text: oklch(0.15 0.02 250);
  --color-text-muted: oklch(0.45 0.01 250);
  --color-primary: var(--blue-500);
  --color-error: var(--red-500);
  --color-border: oklch(0.88 0.005 250);
}

/* Dark Mode */
.dark {
  --color-bg: oklch(0.15 0.01 250);
  --color-bg-subtle: oklch(0.2 0.01 250);
  --color-text: oklch(0.95 0.005 250);
  --color-text-muted: oklch(0.65 0.01 250);
  --color-border: oklch(0.3 0.01 250);
}
```

---

## Shadcn/ui

### 핵심 개념

Shadcn/ui는 npm 패키지가 아니라 **복사 기반 컴포넌트**. CLI로 소스 코드를 프로젝트에 복사하고 직접 수정한다.

```bash
# 초기화
npx shadcn@latest init

# 컴포넌트 추가
npx shadcn@latest add button
npx shadcn@latest add dialog
npx shadcn@latest add form
```

### CVA (Class Variance Authority)로 커스터마이징

```tsx
// components/ui/button.tsx — cva로 variant 정의
import { cva, type VariantProps } from 'class-variance-authority';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
      },
      size: { default: 'h-10 px-4 py-2', sm: 'h-9 px-3', lg: 'h-11 px-8' },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  }
);
```

---

## Radix UI

접근성(WAI-ARIA)을 완전히 지원하는 headless 컴포넌트 라이브러리.

```tsx
import * as Dialog from '@radix-ui/react-dialog';

function ConfirmDialog({ onConfirm }: { onConfirm: () => void }) {
  return (
    <Dialog.Root>
      <Dialog.Trigger asChild>
        <button>삭제</button>
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-black/50 animate-fade-in" />
        <Dialog.Content className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-white p-6 rounded-lg shadow-lg animate-slide-up">
          <Dialog.Title className="text-lg font-bold">
            삭제 확인
          </Dialog.Title>
          <Dialog.Description className="mt-2 text-gray-600">
            이 작업은 되돌릴 수 없습니다. 정말 삭제하시겠습니까?
          </Dialog.Description>
          <div className="mt-4 flex justify-end gap-2">
            <Dialog.Close asChild>
              <button className="px-4 py-2 border rounded">취소</button>
            </Dialog.Close>
            <Dialog.Close asChild>
              <button
                onClick={onConfirm}
                className="px-4 py-2 bg-red-600 text-white rounded"
              >
                삭제
              </button>
            </Dialog.Close>
          </div>
          <Dialog.Close asChild>
            <button className="absolute top-2 right-2" aria-label="닫기">
              X
            </button>
          </Dialog.Close>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
```

---

## Atomic Design

```
atoms/       → Button, Input, Label, Badge, Avatar
molecules/   → SearchBar (Input + Button), FormField (Label + Input + Error)
organisms/   → Header (Logo + Nav + SearchBar), ProductCard
templates/   → PageLayout, DashboardLayout
pages/       → HomePage, ProductListPage
```

```
src/
├── components/
│   ├── ui/          # atoms (Shadcn/ui 기반)
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   └── badge.tsx
│   ├── forms/       # molecules
│   │   ├── SearchBar.tsx
│   │   └── LoginForm.tsx
│   ├── layout/      # organisms
│   │   ├── Header.tsx
│   │   ├── Sidebar.tsx
│   │   └── Footer.tsx
│   └── features/    # 도메인별 컴포넌트
│       ├── products/
│       └── orders/
```

---

## Dark Mode

### Class 전략 (Tailwind + Next.js)

```tsx
// app/layout.tsx
import { ThemeProvider } from 'next-themes';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko" suppressHydrationWarning>
      <body>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}

// 테마 토글 버튼
'use client';
import { useTheme } from 'next-themes';

function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  return (
    <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      {theme === 'dark' ? 'Light' : 'Dark'} Mode
    </button>
  );
}
```

```tsx
// Tailwind dark: 변형 사용
<div className="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
  <h1 className="text-primary dark:text-primary-foreground">제목</h1>
</div>
```

---

## 반응형 디자인

### Mobile-First

```tsx
// Tailwind: mobile-first (기본 = mobile)
<div className="
  flex flex-col           // mobile: 세로 배치
  md:flex-row             // tablet: 가로 배치
  lg:grid lg:grid-cols-3  // desktop: 3컬럼 그리드
  gap-4
">
  {/* ... */}
</div>
```

### Container Queries vs Media Queries

```css
/* Media Query: 뷰포트 기준 */
@media (min-width: 768px) { .card { flex-direction: row; } }

/* Container Query: 부모 컨테이너 기준 (권장) */
.card-container { container-type: inline-size; }
@container (min-width: 400px) { .card { flex-direction: row; } }
```

### Fluid Typography

```css
/* clamp()로 반응형 폰트 크기 */
h1 { font-size: clamp(1.5rem, 4vw, 3rem); }
h2 { font-size: clamp(1.25rem, 3vw, 2rem); }
p  { font-size: clamp(1rem, 1.5vw, 1.125rem); }
```

---

## 접근성 (a11y)

### WCAG 2.1 AA 필수 사항

| 항목 | 기준 |
|------|------|
| 색상 대비 | 텍스트 4.5:1, 대형 텍스트 3:1 |
| 키보드 접근 | 모든 인터랙션 키보드로 가능 |
| 포커스 표시 | 포커스 상태 시각적으로 명확 |
| 대체 텍스트 | 모든 이미지에 alt 속성 |
| ARIA | 시맨틱 HTML 우선, 필요시 ARIA 보충 |

### 키보드 네비게이션 + 스크린 리더

```tsx
// 모달: role="dialog" + aria-modal + Escape 키 + 포커스 관리
<div role="dialog" aria-modal="true" aria-label="확인 대화상자">

// 스크린 리더 전용 텍스트
<span className="sr-only">장바구니에 3개 항목</span>

// 동적 변경 알림
<div aria-live="polite" aria-atomic="true">{message}</div>

// 폼 에러 연결
<input id="email" aria-describedby="email-error" aria-invalid={!!errors.email} />
{errors.email && <p id="email-error" role="alert">{errors.email.message}</p>}
```

---

## Animation

### Framer Motion

```tsx
import { motion, AnimatePresence } from 'framer-motion';

function Toast({ message, isVisible }: { message: string; isVisible: boolean }) {
  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 50 }}
          transition={{ duration: 0.2 }}
          className="fixed bottom-4 right-4 p-4 bg-gray-900 text-white rounded-lg"
        >
          {message}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
```

### 성능 고려 CSS 애니메이션

```css
/* Good: GPU 가속 속성만 애니메이션 */
.animate-enter {
  transition: transform 0.2s ease, opacity 0.2s ease;
  /* transform, opacity는 레이아웃/페인트 건너뜀 */
}

/* Bad: 레이아웃 트리거 속성 */
.animate-bad {
  transition: width 0.2s, height 0.2s, margin 0.2s;
  /* width, height, margin은 매 프레임 레이아웃 재계산 */
}
```

---

## Anti-Patterns

### 1. !important 남용

```css
/* Bad */
.button { color: red !important; }
.button.primary { color: blue !important; } /* 위를 이기려면 또 !important */

/* Good: 스코프된 클래스 또는 CSS Layers */
@layer components {
  .button { color: var(--button-color, gray); }
  .button-primary { --button-color: blue; }
}
```

### 2. z-index 전쟁

```css
/* Bad */
.header { z-index: 9999; }
.modal { z-index: 99999; }
.tooltip { z-index: 999999; }

/* Good: 계층화된 z-index 시스템 */
:root {
  --z-dropdown: 100;
  --z-sticky: 200;
  --z-modal-backdrop: 300;
  --z-modal: 400;
  --z-tooltip: 500;
  --z-toast: 600;
}
```

### 3. 과도한 Custom CSS

```tsx
// Bad: Tailwind 사용하면서 custom CSS 과다
<div className="custom-card" style={{ borderRadius: '8px', padding: '16px' }}>

// Good: Tailwind utility 활용
<div className="rounded-lg p-4 bg-white shadow-md">
```

---

## Sources

- Tailwind CSS 4.0 문서: tailwindcss.com
- Radix UI 문서: radix-ui.com
- Shadcn/ui 문서: ui.shadcn.com
- WCAG 2.1: w3.org/TR/WCAG21
- Framer Motion 문서: framer.com/motion
