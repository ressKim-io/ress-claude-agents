# React Patterns 가이드

React 19+, Server Components, Suspense, 상태관리, 컴포넌트 설계 패턴 종합 가이드.

## Quick Reference

```
React 컴포넌트 선택
    │
    ├─ 데이터 fetch만? ────────> Server Component (default)
    │
    ├─ 인터랙션 필요? ─────────> Client Component ('use client')
    │   ├─ 폼 제출 ──────────> Server Actions + useActionState
    │   ├─ 실시간 UI ────────> useState/useReducer
    │   └─ 외부 상태 ────────> Zustand / Jotai
    │
    ├─ 비동기 데이터 로딩? ────> Suspense + use() hook
    │
    └─ 에러 처리? ────────────> Error Boundary + fallback UI

상태관리 선택
    │
    ├─ Server State ──────────> TanStack Query (캐싱, 재검증)
    ├─ Client Global ─────────> Zustand (심플) / Jotai (원자적)
    ├─ URL State ─────────────> nuqs / useSearchParams
    └─ Form State ────────────> React Hook Form / useActionState
```

---

## React 19 핵심 기능

### React Compiler (자동 메모이제이션)

React Compiler는 빌드 타임에 자동으로 메모이제이션을 적용한다.
수동 `useMemo`, `useCallback`, `React.memo`가 대부분 불필요해진다.

```tsx
// React 19+ with Compiler: 수동 메모이제이션 불필요
function ProductList({ products, onSelect }: Props) {
  // Compiler가 자동으로 최적화 — useMemo/useCallback 제거
  const sorted = products.sort((a, b) => a.price - b.price);
  const handleClick = (id: string) => onSelect(id);

  return (
    <ul>
      {sorted.map((p) => (
        <li key={p.id} onClick={() => handleClick(p.id)}>
          {p.name} - ${p.price}
        </li>
      ))}
    </ul>
  );
}
```

### use() Hook

Promise나 Context를 컴포넌트 내 어디서든 읽을 수 있는 새 hook.

```tsx
import { use, Suspense } from 'react';

// Promise를 직접 use()로 읽기
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise);
  return <h1>{user.name}</h1>;
}

// Context를 조건부로 읽기 (기존 useContext는 불가)
function ThemeButton({ showIcon }: { showIcon: boolean }) {
  if (showIcon) {
    const theme = use(ThemeContext);
    return <Icon color={theme.primary} />;
  }
  return <button>Click</button>;
}

// 부모에서 Suspense로 감싸기
function Page() {
  const userPromise = fetchUser(userId);
  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile userPromise={userPromise} />
    </Suspense>
  );
}
```

### ref as Prop

`forwardRef` 없이 ref를 일반 prop으로 전달.

```tsx
// React 19+: forwardRef 불필요
function Input({ ref, ...props }: { ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} {...props} />;
}

// 사용
function Form() {
  const inputRef = useRef<HTMLInputElement>(null);
  return <Input ref={inputRef} placeholder="이름" />;
}
```

### Actions 및 useActionState

```tsx
'use client';

import { useActionState } from 'react';
import { createOrder } from '@/actions/order';

function OrderForm() {
  const [state, formAction, isPending] = useActionState(createOrder, {
    error: null,
    success: false,
  });

  return (
    <form action={formAction}>
      <input name="productId" required />
      <input name="quantity" type="number" min={1} required />
      <button type="submit" disabled={isPending}>
        {isPending ? '처리 중...' : '주문하기'}
      </button>
      {state.error && <p className="text-red-500">{state.error}</p>}
      {state.success && <p className="text-green-600">주문 완료!</p>}
    </form>
  );
}
```

---

## Server Components vs Client Components

### 선택 기준

| 기준 | Server Component | Client Component |
|------|-----------------|------------------|
| 데이터 fetch | O (직접 async/await) | X (useQuery 필요) |
| DB 직접 접근 | O | X |
| 이벤트 핸들러 | X | O (onClick 등) |
| useState/useEffect | X | O |
| 브라우저 API | X | O (window, localStorage) |
| 번들 크기 영향 | X (JS 미포함) | O (JS 번들에 포함) |

### 'use client' 경계 전략

```
// 경계를 최대한 잎(leaf) 노드로 내린다
// Server Component (default)
app/
├── layout.tsx          ← Server (변경 거의 없음)
├── page.tsx            ← Server (데이터 fetch)
├── components/
│   ├── ProductList.tsx  ← Server (목록 렌더링)
│   ├── ProductCard.tsx  ← Server (정적 표시)
│   ├── AddToCart.tsx    ← 'use client' (인터랙션)
│   └── SearchBar.tsx   ← 'use client' (입력 처리)
```

```tsx
// 잘못된 예: 최상위에 'use client' 선언
'use client'; // 하위 모든 컴포넌트가 Client Component가 됨
export default function ProductPage() { ... }

// 올바른 예: 인터랙션이 필요한 부분만 분리
// ProductPage.tsx (Server Component)
export default async function ProductPage() {
  const products = await getProducts(); // 서버에서 데이터 fetch
  return (
    <div>
      <h1>상품 목록</h1>
      <SearchBar /> {/* Client Component */}
      <ProductList products={products} /> {/* Server Component */}
    </div>
  );
}
```

---

## Suspense + Error Boundary 패턴

### 계층적 로딩 UI

```tsx
import { Suspense } from 'react';
import { ErrorBoundary } from 'react-error-boundary';

function Dashboard() {
  return (
    <ErrorBoundary fallback={<ErrorFallback />}>
      <h1>대시보드</h1>
      {/* 독립적인 Suspense 경계 → 병렬 로딩 */}
      <div className="grid grid-cols-2 gap-4">
        <Suspense fallback={<CardSkeleton />}>
          <RevenueChart />
        </Suspense>
        <Suspense fallback={<CardSkeleton />}>
          <RecentOrders />
        </Suspense>
      </div>
      {/* 중첩 Suspense → 단계별 로딩 */}
      <Suspense fallback={<TableSkeleton />}>
        <UserTable />
        <Suspense fallback={<PaginationSkeleton />}>
          <Pagination />
        </Suspense>
      </Suspense>
    </ErrorBoundary>
  );
}
```

### Error Boundary with Recovery

```tsx
// react-error-boundary 사용
<ErrorBoundary
  FallbackComponent={({ error, resetErrorBoundary }) => (
    <div role="alert">
      <p>{error.message}</p>
      <button onClick={resetErrorBoundary}>다시 시도</button>
    </div>
  )}
  onReset={() => { /* 에러 상태 초기화 */ }}
>
  <Dashboard />
</ErrorBoundary>
```

---

## Component 설계 패턴

### Compound Components

```tsx
// 유연한 API를 제공하는 합성 컴포넌트 패턴
import { createContext, use, useState, type ReactNode } from 'react';

// Context 정의
interface TabsContextType {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}
const TabsContext = createContext<TabsContextType | null>(null);

function useTabs() {
  const context = use(TabsContext);
  if (!context) throw new Error('Tabs 컴포넌트 내부에서 사용해야 합니다');
  return context;
}

// 부모 컴포넌트
function Tabs({ defaultTab, children }: { defaultTab: string; children: ReactNode }) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return (
    <TabsContext value={{ activeTab, setActiveTab }}>
      <div role="tablist">{children}</div>
    </TabsContext>
  );
}

// 자식 컴포넌트들
function TabTrigger({ value, children }: { value: string; children: ReactNode }) {
  const { activeTab, setActiveTab } = useTabs();
  return (
    <button
      role="tab"
      aria-selected={activeTab === value}
      onClick={() => setActiveTab(value)}
    >
      {children}
    </button>
  );
}

function TabContent({ value, children }: { value: string; children: ReactNode }) {
  const { activeTab } = useTabs();
  if (activeTab !== value) return null;
  return <div role="tabpanel">{children}</div>;
}

// 합성 API
Tabs.Trigger = TabTrigger;
Tabs.Content = TabContent;

// 사용 예시
function Settings() {
  return (
    <Tabs defaultTab="general">
      <Tabs.Trigger value="general">일반</Tabs.Trigger>
      <Tabs.Trigger value="security">보안</Tabs.Trigger>
      <Tabs.Content value="general"><GeneralSettings /></Tabs.Content>
      <Tabs.Content value="security"><SecuritySettings /></Tabs.Content>
    </Tabs>
  );
}
```

### Custom Hooks 패턴

```tsx
// TanStack Query 사용 시 (권장)
function useProducts(category: string) {
  return useQuery({
    queryKey: ['products', category],
    queryFn: () => getProducts(category),
    staleTime: 5 * 60 * 1000, // 5분
  });
}

// 직접 구현 시 (useEffect + AbortController + error/loading 상태)
function useProducts(category: string) {
  const [products, setProducts] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  // ... useEffect 내에서 fetch + cleanup
  return { products, isLoading };
}
```

---

## Form Handling

### React Hook Form + Server Action

```tsx
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { createProduct } from '@/actions/product';

const schema = z.object({
  name: z.string().min(1, '상품명을 입력하세요'),
  price: z.number().min(0, '가격은 0 이상이어야 합니다'),
  category: z.enum(['electronics', 'clothing', 'food']),
});

type FormData = z.infer<typeof schema>;

function ProductForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  const onSubmit = async (data: FormData) => {
    const result = await createProduct(data);
    if (result.error) {
      // 서버 에러 처리
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label htmlFor="name">상품명</label>
        <input id="name" {...register('name')} />
        {errors.name && <span>{errors.name.message}</span>}
      </div>
      <div>
        <label htmlFor="price">가격</label>
        <input
          id="price"
          type="number"
          {...register('price', { valueAsNumber: true })}
        />
        {errors.price && <span>{errors.price.message}</span>}
      </div>
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? '저장 중...' : '저장'}
      </button>
    </form>
  );
}
```

---

## Anti-Patterns

### 1. Prop Drilling

```tsx
// Bad: 여러 레벨을 거쳐 prop 전달
function App() {
  const [user, setUser] = useState<User | null>(null);
  return <Layout user={user} setUser={setUser} />;
  // → Layout → Sidebar → UserMenu → user, setUser 전달
}

// Good: Context 또는 Zustand로 전역 상태 관리
const useAuthStore = create<AuthStore>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
}));

function UserMenu() {
  const user = useAuthStore((s) => s.user); // 어디서든 직접 접근
  return user ? <span>{user.name}</span> : <LoginButton />;
}
```

### 2. useEffect 남용

```tsx
// Bad: 파생 상태를 useEffect로 계산
function FilteredList({ items, query }: Props) {
  const [filtered, setFiltered] = useState(items);
  useEffect(() => {
    setFiltered(items.filter((i) => i.name.includes(query)));
  }, [items, query]);
  // 불필요한 리렌더링 발생!
}

// Good: 렌더링 중 계산 (React Compiler가 자동 최적화)
function FilteredList({ items, query }: Props) {
  const filtered = items.filter((i) => i.name.includes(query));
  return <ul>{filtered.map((i) => <li key={i.id}>{i.name}</li>)}</ul>;
}
```

### 3. 불필요한 Client Component

```tsx
// Bad: 인터랙션 없는데 'use client' 선언
'use client';
export function ProductCard({ product }: { product: Product }) {
  return (
    <div>
      <h3>{product.name}</h3>
      <p>{product.price}원</p>
    </div>
  );
}

// Good: Server Component로 유지 (JS 번들 크기 절감)
export function ProductCard({ product }: { product: Product }) {
  return (
    <div>
      <h3>{product.name}</h3>
      <p>{product.price}원</p>
    </div>
  );
}
```

### 4. Premature Optimization

```tsx
// Bad: React Compiler가 있는데 수동 메모이제이션
const MemoizedChild = React.memo(({ data }: Props) => { ... });
const sortedData = useMemo(() => data.sort(), [data]);
const handleClick = useCallback(() => onClick(id), [id, onClick]);

// Good: React Compiler에게 맡기기
function Parent({ data, onClick }: Props) {
  const sortedData = data.sort();
  return <Child data={sortedData} onClick={() => onClick(data.id)} />;
}
```

---

## Sources

- React 19 공식 문서: react.dev
- React Compiler RFC / Patterns.dev
- TanStack Query v5 / React Hook Form Documentation
