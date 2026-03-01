# State Management 가이드

Zustand, Jotai, TanStack Query, React Context 기반 상태관리 선택 및 패턴

## Quick Reference (결정 트리)

```
상태 유형 분류?
    │
    ├─ 서버 데이터 (API) ──────> TanStack Query (React Query v5)
    ├─ 글로벌 클라이언트 상태 ──> Zustand
    ├─ 원자적 상태 (세밀 제어) ─> Jotai
    ├─ 폼 상태 ────────────────> React Hook Form
    ├─ URL 상태 (필터/정렬) ───> nuqs / useSearchParams
    └─ 테마/로케일/인증 ───────> React Context

라이브러리 선택?
    │
    ├─ 단순함 우선 ────────> Zustand (최소 보일러플레이트)
    ├─ 세밀한 리렌더 제어 ─> Jotai (atom 기반)
    ├─ 대규모 앱 + DevTools > Redux Toolkit (time-travel)
    └─ 서버 상태만 필요 ──> TanStack Query 단독
```

---

## 상태 분류

| 유형 | 설명 | 도구 |
|------|------|------|
| **Server State** | API에서 가져온 비동기 데이터, 캐싱/동기화 필요 | TanStack Query |
| **Client State** | UI 상태, 사이드바 열림, 모달, 선택 항목 | Zustand, Jotai |
| **URL State** | 필터, 정렬, 페이지, 검색어 (공유 가능해야 함) | nuqs, searchParams |
| **Form State** | 입력값, 유효성 검사, 제출 상태 | React Hook Form |

**핵심 원칙**: Server State와 Client State를 분리하라. TanStack Query로 서버 상태를, Zustand/Jotai로 클라이언트 상태를 관리.

---

## TanStack Query (React Query v5)

### 기본 쿼리

```tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

function useProducts(categoryId: string) {
  return useQuery({
    queryKey: ['products', categoryId],
    queryFn: () => fetchProducts(categoryId),
    staleTime: 5 * 60 * 1000,    // 5분간 fresh
    gcTime: 30 * 60 * 1000,      // 30분간 캐시 유지
    placeholderData: keepPreviousData,
  });
}
```

### Optimistic Update

```tsx
function useUpdateProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (product: Product) => updateProduct(product),
    onMutate: async (newProduct) => {
      await queryClient.cancelQueries({ queryKey: ['products'] });
      const previous = queryClient.getQueryData(['products']);
      queryClient.setQueryData(['products'], (old: Product[]) =>
        old.map(p => p.id === newProduct.id ? newProduct : p)
      );
      return { previous };
    },
    onError: (_err, _new, context) => {
      queryClient.setQueryData(['products'], context?.previous);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['products'] });
    },
  });
}
```

### 무한 스크롤 + Prefetching

```tsx
// 무한 스크롤
function useInfiniteProducts() {
  return useInfiniteQuery({
    queryKey: ['products', 'infinite'],
    queryFn: ({ pageParam }) => fetchProducts({ cursor: pageParam, limit: 20 }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor,
  });
}

// Next.js App Router에서 프리페치
async function ProductsPage() {
  const queryClient = new QueryClient();
  await queryClient.prefetchQuery({
    queryKey: ['products'],
    queryFn: fetchProducts,
  });
  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <ProductList />
    </HydrationBoundary>
  );
}
```

---

## Zustand

### 기본 스토어

```tsx
import { create } from 'zustand';
import { persist, devtools } from 'zustand/middleware';

interface CartStore {
  items: CartItem[];
  addItem: (item: CartItem) => void;
  removeItem: (id: string) => void;
  clearCart: () => void;
  totalPrice: () => number;
}

const useCartStore = create<CartStore>()(
  devtools(
    persist(
      (set, get) => ({
        items: [],
        addItem: (item) => set(
          (state) => ({ items: [...state.items, item] }),
          false, 'cart/addItem'
        ),
        removeItem: (id) => set(
          (state) => ({ items: state.items.filter(i => i.id !== id) }),
          false, 'cart/removeItem'
        ),
        clearCart: () => set({ items: [] }, false, 'cart/clear'),
        totalPrice: () =>
          get().items.reduce((sum, item) => sum + item.price * item.quantity, 0),
      }),
      { name: 'cart-storage' }
    ),
    { name: 'CartStore' }
  )
);
```

### Slice 패턴 (대규모 앱)

```tsx
const createAuthSlice: StateCreator<AuthSlice> = (set) => ({
  user: null,
  login: (user) => set({ user }),
  logout: () => set({ user: null }),
});

const createUISlice: StateCreator<UISlice> = (set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
});

// 슬라이스 합성
const useStore = create<AuthSlice & UISlice>()((...args) => ({
  ...createAuthSlice(...args),
  ...createUISlice(...args),
}));
```

### 선택적 구독 (리렌더 최적화)

```tsx
// Bad: 전체 스토어 구독
const { items, totalPrice } = useCartStore();

// Good: 필요한 값만 선택
const items = useCartStore((state) => state.items);
const totalPrice = useCartStore((state) => state.totalPrice());
```

---

## Jotai

### Atom 기반 상태

```tsx
import { atom, useAtom, useAtomValue, useSetAtom } from 'jotai';

const countAtom = atom(0);
const doubleCountAtom = atom((get) => get(countAtom) * 2);

// Async atom
const userAtom = atom(async () => {
  const res = await fetch('/api/user');
  return res.json() as Promise<User>;
});

// Writable derived atom
const filterAtom = atom('all');
const todosAtom = atom<Todo[]>([]);
const filteredTodosAtom = atom(
  (get) => {
    const filter = get(filterAtom);
    const todos = get(todosAtom);
    if (filter === 'done') return todos.filter(t => t.done);
    if (filter === 'undone') return todos.filter(t => !t.done);
    return todos;
  },
  (get, set, newTodo: Todo) => {
    set(todosAtom, [...get(todosAtom), newTodo]);
  }
);
```

---

## React Context (적절한 사용)

```tsx
// 적합: 테마, 로케일, 인증 — 자주 변경되지 않는 값
function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  const toggle = useCallback(() =>
    setTheme(t => t === 'light' ? 'dark' : 'light'), []
  );
  const value = useMemo(() => ({ theme, toggle }), [theme, toggle]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

// 관심사별 분리 (변경 빈도가 다른 값 분리)
// Bad: 하나의 거대한 AppContext
// Good: AuthContext + ThemeContext + LocaleContext 분리
```

---

## URL State Management

```tsx
import { useQueryState, parseAsInteger, parseAsString } from 'nuqs';

function ProductFilters() {
  const [category, setCategory] = useQueryState('category', parseAsString);
  const [page, setPage] = useQueryState('page', parseAsInteger.withDefault(1));
  const [sort, setSort] = useQueryState('sort', parseAsString.withDefault('newest'));
  // URL: /products?category=shoes&page=2&sort=price — 뒤로가기/공유 가능
}
```

---

## 선택 가이드 요약

| 상황 | 추천 | 이유 |
|------|------|------|
| API 데이터 캐싱 | TanStack Query | 캐싱, 동기화, 중복 제거 |
| 간단한 글로벌 상태 | Zustand | 최소 보일러플레이트 |
| 세밀한 리렌더 제어 | Jotai | atom 단위 구독 |
| 테마/인증 | React Context | React 내장, 간단 |
| 폼 | React Hook Form | 비제어 기반, 성능 우수 |
| URL 필터/정렬 | nuqs | 공유 가능, SEO 친화 |
| 대규모 + DevTools | Redux Toolkit | time-travel, 미들웨어 |

---

## Anti-Patterns

### 1. 모든 상태를 글로벌로

```tsx
// Bad: 로컬이면 충분한 상태를 글로벌로
const useStore = create(() => ({ isDropdownOpen: false }));

// Good: 로컬 상태는 useState
function Dropdown() {
  const [isOpen, setIsOpen] = useState(false);
}
```

### 2. Server State를 Client Store에

```tsx
// Bad: API 데이터를 Zustand에 직접 저장
const useStore = create((set) => ({
  products: [],
  fetchProducts: async () => {
    const data = await fetch('/api/products');
    set({ products: await data.json() });
  },
}));

// Good: TanStack Query로 서버 상태 관리
const { data: products } = useQuery({
  queryKey: ['products'],
  queryFn: fetchProducts,
});
```

### 3. Context에 빈번히 변경되는 값

```tsx
// Bad: 매초 변경 → 모든 Consumer 리렌더
<TimerContext.Provider value={time}>{children}</TimerContext.Provider>

// Good: Jotai atom 또는 외부 스토어 사용
const timerAtom = atom(0);
```

---

## Sources

- TanStack Query v5 문서: tanstack.com/query
- Zustand 문서: docs.pmnd.rs/zustand
- Jotai 문서: jotai.org
- nuqs 문서: nuqs.47ng.com
- React Hook Form 문서: react-hook-form.com
