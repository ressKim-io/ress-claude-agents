# Frontend Performance 가이드

Core Web Vitals 최적화, 번들 분석, Code Splitting, Image/Font 최적화 종합 가이드.

## Quick Reference

```
성능 문제 진단
    │
    ├─ LCP > 2.5s ──────────> Image 최적화, 서버 렌더링, preload
    ├─ INP > 200ms ─────────> 이벤트 핸들러 최적화, Web Worker
    ├─ CLS > 0.1 ──────────> 크기 명시, font-display, 레이아웃 안정화
    │
    번들 크기 문제
    │
    ├─ 초기 JS > 300KB ────> Code Splitting, dynamic import
    ├─ 특정 라이브러리 큰 경우 > Tree Shaking, 대안 라이브러리
    └─ Third-party 스크립트 > Partytown, defer/async

렌더링 전략
    │
    ├─ 정적 콘텐츠 ────────> SSG (빌드 시 생성)
    ├─ 주기적 갱신 ────────> ISR (revalidate)
    ├─ 개인화 콘텐츠 ──────> SSR + Streaming
    └─ 인터랙티브 위젯 ───> CSR (Client Component)
```

---

## Core Web Vitals

### LCP (Largest Contentful Paint)

페이지에서 가장 큰 콘텐츠 요소가 렌더링되는 시간.

| 등급 | 시간 |
|------|------|
| Good | <= 2.5s |
| Needs Improvement | 2.5s ~ 4.0s |
| Poor | > 4.0s |

**주요 원인 및 해결**

```
1. 느린 서버 응답 (TTFB)
   → CDN 사용, 서버 사이드 캐싱, ISR/SSG 활용

2. 렌더 블로킹 리소스
   → CSS 인라인화 (critical CSS), JS defer/async

3. 느린 이미지 로딩
   → next/image, AVIF/WebP, responsive sizes, priority

4. 클라이언트 사이드 렌더링
   → SSR/SSG로 전환, React Server Components 활용
```

```tsx
// LCP 이미지 최적화
import Image from 'next/image';

function HeroBanner() {
  return (
    <Image
      src="/hero.jpg"
      alt="메인 배너"
      width={1200}
      height={600}
      priority          // LCP 이미지는 반드시 priority
      sizes="100vw"
      quality={85}
    />
  );
}
```

### INP (Interaction to Next Paint)

사용자 인터랙션 후 다음 화면 업데이트까지의 시간. FID를 대체.

| 등급 | 시간 |
|------|------|
| Good | <= 200ms |
| Needs Improvement | 200ms ~ 500ms |
| Poor | > 500ms |

**최적화 전략**

```tsx
// Bad: 메인 스레드를 블로킹하는 무거운 연산
function handleClick() {
  const result = heavyComputation(data); // 200ms+ 블로킹
  setResult(result);
}

// Good: Web Worker로 오프로드
const worker = new Worker(new URL('./worker.ts', import.meta.url));

function handleClick() {
  worker.postMessage({ type: 'compute', data });
}

worker.onmessage = (e) => {
  setResult(e.data.result);
};
```

```tsx
// 긴 리스트: 가상화로 렌더링 최적화
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
    overscan: 5,
  });

  return (
    <div ref={parentRef} style={{ height: '400px', overflow: 'auto' }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              transform: `translateY(${virtualItem.start}px)`,
              height: `${virtualItem.size}px`,
              width: '100%',
            }}
          >
            {items[virtualItem.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

### CLS (Cumulative Layout Shift)

레이아웃이 예기치 않게 이동하는 정도.

| 등급 | 점수 |
|------|------|
| Good | <= 0.1 |
| Needs Improvement | 0.1 ~ 0.25 |
| Poor | > 0.25 |

**주요 원인 및 해결**

```tsx
// 원인 1: 이미지 크기 미지정
// Bad
<img src="/photo.jpg" />

// Good: width/height 명시 또는 aspect-ratio
<Image src="/photo.jpg" width={400} height={300} alt="사진" />
// 또는 CSS
<div style={{ aspectRatio: '4/3' }}>
  <img src="/photo.jpg" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
</div>

// 원인 2: 폰트 로딩 시 레이아웃 시프트
// Good: font-display: swap + size-adjust
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: swap;
  size-adjust: 105%; /* fallback 폰트와 크기 맞춤 */
}

// 원인 3: 동적 콘텐츠 삽입
// Bad: 광고/배너를 나중에 삽입
// Good: 미리 공간 확보
<div style={{ minHeight: '250px' }}>
  <AdBanner />
</div>
```

---

## Bundle Analysis

### Next.js 번들 분석

```bash
# @next/bundle-analyzer 설치
npm install -D @next/bundle-analyzer

# next.config.ts
import withBundleAnalyzer from '@next/bundle-analyzer';

const config = withBundleAnalyzer({
  enabled: process.env.ANALYZE === 'true',
})({
  // next config
});

export default config;

# 분석 실행
ANALYZE=true npm run build
```

### 번들 크기 예산

| 항목 | 예산 |
|------|------|
| First Load JS (전체) | < 300KB (gzip) |
| 개별 페이지 JS | < 100KB (gzip) |
| 개별 라이브러리 | < 50KB (gzip) |
| CSS (전체) | < 50KB (gzip) |

---

## Code Splitting

### Dynamic Import

```tsx
import dynamic from 'next/dynamic';

// 무거운 컴포넌트 지연 로딩
const RichTextEditor = dynamic(() => import('@/components/RichTextEditor'), {
  loading: () => <div className="h-64 bg-gray-100 animate-pulse" />,
  ssr: false, // 클라이언트에서만 렌더링 (브라우저 API 의존 시)
});

// 조건부 로딩
const AdminPanel = dynamic(() => import('@/components/AdminPanel'));

function Dashboard({ isAdmin }: { isAdmin: boolean }) {
  return (
    <div>
      <MainContent />
      {isAdmin && <AdminPanel />}
    </div>
  );
}
```

### Route-based Splitting (App Router 자동)

```
// Next.js App Router는 페이지별 자동 코드 스플리팅
app/
├── page.tsx          → /  (별도 번들)
├── products/
│   └── page.tsx      → /products (별도 번들)
└── checkout/
    └── page.tsx      → /checkout (별도 번들)
```

### Tree Shaking 최적화

```typescript
// Bad: 전체 라이브러리 import
import _ from 'lodash';          // ~70KB
const sorted = _.sortBy(arr, 'name');

// Good: 개별 함수 import
import sortBy from 'lodash/sortBy'; // ~2KB
const sorted = sortBy(arr, 'name');

// Best: 네이티브 메서드 사용
const sorted = [...arr].sort((a, b) => a.name.localeCompare(b.name));
```

---

## Image 최적화

### 포맷 선택

| 포맷 | 용도 | 압축률 |
|------|------|--------|
| AVIF | 사진, 복잡한 이미지 (최고 압축) | ~50% smaller than JPEG |
| WebP | 범용 (폭넓은 지원) | ~30% smaller than JPEG |
| PNG | 투명 배경, 아이콘 | 무손실 |
| SVG | 벡터 아이콘, 로고 | 해상도 무관 |

### Responsive Images

```tsx
// next/image 자동 최적화
<Image
  src="/product.jpg"
  alt="상품"
  width={800}
  height={600}
  sizes="(max-width: 640px) 100vw,
         (max-width: 1024px) 50vw,
         33vw"
  // Next.js가 자동으로 srcSet 생성
  // AVIF, WebP 자동 변환
/>
```

### Lazy Loading 전략

```tsx
// 뷰포트 밖 이미지: 자동 lazy loading (next/image 기본값)
<Image src="/below-fold.jpg" alt="..." width={400} height={300} />
// loading="lazy" 자동 적용

// LCP 이미지: priority로 즉시 로딩
<Image src="/hero.jpg" alt="..." width={1200} height={600} priority />
// fetchpriority="high" + preload 태그 자동 생성
```

---

## Font 최적화

```tsx
// next/font: 자동 셀프 호스팅 + CLS 방지
const notoSans = Noto_Sans_KR({
  subsets: ['latin'],
  weight: ['400', '700'],
  display: 'swap',
  variable: '--font-sans',
});
```

### Subsetting

```bash
# 한글 폰트 서브셋팅
pip install fonttools
pyftsubset font.ttf \
  --text-file=korean-chars.txt \
  --output-file=font-subset.woff2 \
  --flavor=woff2
```

---

## Script 최적화

### Third-party Script 관리

```tsx
import Script from 'next/script';

function Layout({ children }: { children: React.ReactNode }) {
  return (
    <>
      {/* 즉시 필요한 스크립트 */}
      <Script src="/critical.js" strategy="beforeInteractive" />

      {/* 페이지 로드 후 (기본값) */}
      <Script src="https://analytics.example.com/script.js" strategy="afterInteractive" />

      {/* 브라우저 idle 시 */}
      <Script src="https://chat-widget.example.com/widget.js" strategy="lazyOnload" />

      {/* Web Worker에서 실행 (메인 스레드 해방) */}
      <Script
        src="https://heavy-analytics.example.com/tracker.js"
        strategy="worker"  // Partytown 사용
      />
      {children}
    </>
  );
}
```

---

## Prefetching 전략

```tsx
// Next.js Link: 자동 prefetch (뷰포트에 보이면)
import Link from 'next/link';

<Link href="/products" prefetch={true}>
  상품 목록
</Link>

// DNS Prefetch + Preconnect
// app/layout.tsx
export default function Layout({ children }) {
  return (
    <html>
      <head>
        <link rel="dns-prefetch" href="https://cdn.example.com" />
        <link rel="preconnect" href="https://api.example.com" crossOrigin="" />
      </head>
      <body>{children}</body>
    </html>
  );
}
```

---

## Performance 측정

### Lighthouse CI

```yaml
# lighthouserc.js
module.exports = {
  ci: {
    collect: {
      url: ['http://localhost:3000/', 'http://localhost:3000/products'],
      numberOfRuns: 3,
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'categories:accessibility': ['error', { minScore: 0.9 }],
        'first-contentful-paint': ['warn', { maxNumericValue: 2000 }],
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'interactive': ['warn', { maxNumericValue: 3500 }],
      },
    },
  },
};
```

### Web Vitals API

```tsx
// app/components/WebVitals.tsx
'use client';

import { useReportWebVitals } from 'next/web-vitals';

export function WebVitals() {
  useReportWebVitals((metric) => {
    // 분석 서비스로 전송
    const body = {
      name: metric.name,     // CLS, FID, INP, LCP, TTFB, FCP
      value: metric.value,
      rating: metric.rating, // 'good' | 'needs-improvement' | 'poor'
      id: metric.id,
    };

    // Beacon API로 전송 (페이지 이탈 시에도 전송)
    navigator.sendBeacon('/api/vitals', JSON.stringify(body));
  });

  return null;
}
```

---

## Anti-Patterns

### 1. 불필요한 JS 번들

```tsx
// Bad: 서버에서만 필요한 코드가 클라이언트 번들에 포함
'use client';
import { prisma } from '@/lib/db'; // 서버 전용!

// Good: Server Component에서 데이터 fetch, Client Component에는 결과만 전달
// page.tsx (Server)
const data = await prisma.product.findMany();
return <ProductList products={data} />;
```

### 2. Layout Shift 유발

```tsx
// Bad: 동적 콘텐츠 크기 미지정 → 광고 로드 후 레이아웃 밀림
// Good: 미리 공간 확보
<div style={{ minHeight: 250, aspectRatio: '728/90' }}>
  {ad ? <img src={ad.url} width={728} height={90} /> : <Placeholder />}
</div>
```

### 3. Render-blocking Resources

```html
<!-- Bad: 동기 로딩 → Good: defer/async -->
<script src="tracker.js" defer></script>
```

---

## Sources

- web.dev — Core Web Vitals
- Next.js Performance Documentation
- Chrome DevTools Performance Panel
- CrUX (Chrome User Experience Report)
- Lighthouse CI Documentation
