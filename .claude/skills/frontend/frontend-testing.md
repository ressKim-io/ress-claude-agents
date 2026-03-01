# Frontend Testing 가이드

Vitest, Playwright, Testing Library, MSW를 활용한 프론트엔드 테스트 전략 종합 가이드.

## Quick Reference

```
테스트 레벨 선택
    │
    ├─ 단일 함수/hook ────────> Vitest (Unit)
    ├─ 컴포넌트 렌더링 ──────> Vitest + Testing Library (Unit)
    ├─ API 연동 컴포넌트 ────> Testing Library + MSW (Integration)
    ├─ 사용자 플로우 ────────> Playwright (E2E)
    └─ UI 시각적 검증 ──────> Chromatic / Storybook (Visual)

Testing Trophy (권장 비율)
    │
    ├─ E2E        ── 10% (핵심 플로우만)
    ├─ Integration ── 50% (가장 많이)
    ├─ Unit        ── 30% (유틸, 훅, 순수 로직)
    └─ Static      ── 10% (TypeScript, ESLint)
```

---

## Vitest 설정 및 패턴

### 기본 설정

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      exclude: ['**/*.config.*', '**/*.d.ts', '**/types/**'],
      thresholds: {
        statements: 80,
        branches: 80,
        functions: 80,
        lines: 80,
      },
    },
    // 병렬 실행
    pool: 'threads',
    poolOptions: { threads: { maxThreads: 4 } },
  },
});
```

### Setup 파일

```typescript
// tests/setup.ts
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, beforeAll, afterAll } from 'vitest';
import { server } from './mocks/server';

// MSW 서버 설정
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => {
  cleanup();
  server.resetHandlers();
});
afterAll(() => server.close());
```

### Mocking 패턴

```typescript
import { vi, describe, it, expect, beforeEach } from 'vitest';

// 모듈 mock
vi.mock('@/lib/analytics', () => ({
  track: vi.fn(),
  identify: vi.fn(),
}));

// 함수 mock
const mockFetch = vi.fn();

describe('OrderService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should_createOrder_when_validInput', async () => {
    // Given
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve({ id: '1', status: 'created' }),
    });

    // When
    const result = await createOrder({ productId: 'p1', quantity: 2 });

    // Then
    expect(result.status).toBe('created');
    expect(mockFetch).toHaveBeenCalledOnce();
  });
});
```

---

## Testing Library

### 핵심 철학: "사용자가 상호작용하는 방식으로 테스트"

### 쿼리 우선순위

| 우선순위 | 쿼리 | 용도 |
|---------|-------|------|
| 1 | `getByRole` | 접근성 역할 기반 (가장 권장) |
| 2 | `getByLabelText` | 폼 요소 |
| 3 | `getByPlaceholderText` | 입력 필드 |
| 4 | `getByText` | 텍스트 콘텐츠 |
| 5 | `getByDisplayValue` | 현재 입력값 |
| 6 | `getByAltText` | 이미지 |
| 7 | `getByTestId` | 최후의 수단 |

### 컴포넌트 테스트

```tsx
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect } from 'vitest';
import { ProductCard } from '@/components/ProductCard';

describe('ProductCard', () => {
  const product = {
    id: '1',
    name: '무선 키보드',
    price: 59000,
    inStock: true,
  };

  it('should_displayProductInfo_when_rendered', () => {
    // Given & When
    render(<ProductCard product={product} />);

    // Then
    expect(screen.getByRole('heading', { name: '무선 키보드' })).toBeInTheDocument();
    expect(screen.getByText('59,000원')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '장바구니 담기' })).toBeEnabled();
  });

  it('should_disableButton_when_outOfStock', () => {
    // Given
    const outOfStock = { ...product, inStock: false };

    // When
    render(<ProductCard product={outOfStock} />);

    // Then
    expect(screen.getByRole('button', { name: '품절' })).toBeDisabled();
  });

  it('should_callOnAddToCart_when_buttonClicked', async () => {
    // Given
    const user = userEvent.setup();
    const onAddToCart = vi.fn();
    render(<ProductCard product={product} onAddToCart={onAddToCart} />);

    // When
    await user.click(screen.getByRole('button', { name: '장바구니 담기' }));

    // Then
    expect(onAddToCart).toHaveBeenCalledWith(product.id);
  });
});
```

### userEvent vs fireEvent

```tsx
// fireEvent: DOM 이벤트를 직접 디스패치 (동기적)
fireEvent.click(button);      // 클릭 이벤트만 발생
fireEvent.change(input, { target: { value: 'hello' } });

// userEvent: 실제 사용자 행동 시뮬레이션 (비동기, 권장)
const user = userEvent.setup();
await user.click(button);     // focus → pointerdown → mousedown → click 등 모두 발생
await user.type(input, 'hello'); // 한 글자씩 입력 + keydown/keyup 이벤트
await user.tab();              // Tab 키 네비게이션
await user.selectOptions(select, 'option1'); // 드롭다운 선택
await user.upload(fileInput, file);          // 파일 업로드
```

---

## MSW (Mock Service Worker)

### Handler 설정

```typescript
// tests/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/products', () => {
    return HttpResponse.json([
      { id: '1', name: '키보드', category: 'electronics' },
    ]);
  }),
  http.post('/api/orders', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: 'ord_1', ...body }, { status: 201 });
  }),
];

// tests/mocks/server.ts
import { setupServer } from 'msw/node';
export const server = setupServer(...handlers);
```

### 테스트별 Handler 오버라이드

```tsx
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server';

it('should_showError_when_apiFails', async () => {
  // Given: 이 테스트에서만 에러 응답
  server.use(
    http.get('/api/products', () => {
      return HttpResponse.json(
        { error: 'Internal Server Error' },
        { status: 500 }
      );
    })
  );

  // When
  render(<ProductList />);

  // Then
  expect(await screen.findByText('상품을 불러올 수 없습니다')).toBeInTheDocument();
});
```

---

## Playwright E2E

### 기본 설정

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [['html', { open: 'never' }]],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['iPhone 15'] } },
  ],
  webServer: {
    command: 'npm run dev',
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
});
```

### Page Object Model

```typescript
// e2e/pages/LoginPage.ts
import { type Page, type Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel('이메일');
    this.passwordInput = page.getByLabel('비밀번호');
    this.submitButton = page.getByRole('button', { name: '로그인' });
    this.errorMessage = page.getByRole('alert');
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string) {
    await expect(this.errorMessage).toContainText(message);
  }
}
```

### E2E 테스트

```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';
import { LoginPage } from './pages/LoginPage';

test.describe('인증 플로우', () => {
  test('should_redirectToDashboard_when_loginSuccess', async ({ page }) => {
    // Given
    const loginPage = new LoginPage(page);
    await loginPage.goto();

    // When
    await loginPage.login('user@example.com', 'password123');

    // Then
    await expect(page).toHaveURL('/dashboard');
    await expect(page.getByRole('heading', { name: '대시보드' })).toBeVisible();
  });

  test('should_showError_when_invalidCredentials', async ({ page }) => {
    // Given
    const loginPage = new LoginPage(page);
    await loginPage.goto();

    // When
    await loginPage.login('wrong@example.com', 'wrongpassword');

    // Then
    await loginPage.expectError('이메일 또는 비밀번호가 올바르지 않습니다');
    await expect(page).toHaveURL('/login');
  });
});
```

---

## React Server Component 테스트

```tsx
// RSC는 async 컴포넌트이므로 별도 전략 필요
import { render, screen } from '@testing-library/react';

// 방법 1: 데이터 의존성을 mock하고 렌더링
vi.mock('@/lib/db', () => ({
  getProducts: vi.fn().mockResolvedValue([
    { id: '1', name: '키보드', price: 59000 },
  ]),
}));

it('should_renderProducts_when_dataLoaded', async () => {
  // Given & When
  const Component = await ProductsPage();
  render(Component);

  // Then
  expect(screen.getByText('키보드')).toBeInTheDocument();
});

// 방법 2: E2E로 테스트 (권장 — 서버 환경까지 포함)
test('products page renders with data', async ({ page }) => {
  await page.goto('/products');
  await expect(page.getByText('키보드')).toBeVisible();
});
```

---

## Test ID 전략

```tsx
// data-testid는 최후의 수단으로만 사용
// 접근성 속성으로 쿼리 불가능할 때만 사용

// 네이밍 규칙: component-element-modifier
<div data-testid="product-card-featured" />
<button data-testid="checkout-submit" />
<input data-testid="search-input" />

// 프로덕션 빌드에서 제거 (선택)
// babel 또는 SWC 플러그인으로 data-testid 속성 strip
```

---

## CI 통합

```yaml
# .github/workflows/test.yml
name: Frontend Tests
on: [push, pull_request]

jobs:
  unit-integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm ci
      - run: npx vitest run --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
```

---

## Anti-Patterns

### 1. Implementation Detail 테스트

```tsx
// Bad: 내부 구현(state, ref)을 직접 테스트
expect(component.state.isOpen).toBe(true);
expect(wrapper.find('.dropdown-inner').exists()).toBe(true);

// Good: 사용자가 보는 결과를 테스트
expect(screen.getByRole('listbox')).toBeVisible();
expect(screen.getByRole('option', { name: '서울' })).toBeInTheDocument();
```

### 2. 과도한 Snapshot 테스트

```tsx
// Bad: 전체 컴포넌트 스냅샷 → 작은 변경에도 깨짐
expect(container).toMatchSnapshot();

// Good: 중요한 부분만 인라인 스냅샷
expect(screen.getByRole('heading')).toHaveTextContent('상품 목록');
```

### 3. Sleep / 테스트 간 상태 공유

```tsx
// Bad: sleep → Good: findByText / waitFor 사용
expect(await screen.findByText('완료')).toBeInTheDocument();

// Bad: 전역 변수로 상태 공유 → Good: 각 테스트에서 독립 생성
it('test', () => { const user = createUser(); });
```

---

## Sources

- Vitest 공식 문서: vitest.dev
- Testing Library 공식 문서: testing-library.com
- Playwright 공식 문서: playwright.dev
- MSW 공식 문서: mswjs.io
- Kent C. Dodds — Testing Trophy
