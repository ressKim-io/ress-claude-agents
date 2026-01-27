# 부하 테스트 가이드

K6, nGrinder를 활용한 성능 테스트 및 결과 분석

## Quick Reference (결정 트리)

```
테스트 도구 선택?
    │
    ├─ 코드 기반 (DevOps 친화) ──> K6 (추천)
    ├─ GUI 기반 (비개발자) ─────> nGrinder
    ├─ 엔터프라이즈 ────────────> LoadRunner / Gatling
    └─ 간단한 HTTP ────────────> Apache Bench (ab)

테스트 유형?
    │
    ├─ Smoke Test ────────> 기본 동작 확인 (낮은 부하)
    ├─ Load Test ─────────> 예상 부하 검증
    ├─ Stress Test ───────> 한계점 확인
    ├─ Spike Test ────────> 급격한 부하 대응
    └─ Soak Test ─────────> 장시간 안정성
```

---

## CRITICAL: 테스트 유형

| 테스트 | 목적 | VU | 시간 |
|--------|------|-----|------|
| **Smoke** | 기본 동작 확인 | 1-5 | 1분 |
| **Load** | 예상 트래픽 검증 | 예상 VU | 10-30분 |
| **Stress** | 한계점 발견 | 점진적 증가 | 무제한 |
| **Spike** | 급격한 부하 대응 | 갑자기 증가 | 5-10분 |
| **Soak** | 장시간 안정성 | 예상 VU | 수 시간 |

```
┌─────────────────────────────────────────────────────────────┐
│                    Load Test Patterns                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Smoke:    ▁▁▁▁▁▁▁▁▁▁                                       │
│                                                              │
│  Load:     ╱▔▔▔▔▔▔▔▔▔╲                                      │
│                                                              │
│  Stress:   ╱╱╱╱╱╱╱╱╱╱╱ (계속 증가)                          │
│                                                              │
│  Spike:    ▁▁▁█████▁▁▁                                      │
│                                                              │
│  Soak:     ╱▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔╲ (장시간)                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## K6 기본

### 설치

```bash
# macOS
brew install k6

# Docker
docker run --rm -i grafana/k6 run - <script.js

# Kubernetes Operator
helm repo add grafana https://grafana.github.io/helm-charts
helm install k6-operator grafana/k6-operator -n k6-operator-system --create-namespace
```

### 기본 스크립트

```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  // 단계별 부하
  stages: [
    { duration: '2m', target: 100 },  // 2분간 100 VU까지 증가
    { duration: '5m', target: 100 },  // 5분간 100 VU 유지
    { duration: '2m', target: 200 },  // 2분간 200 VU까지 증가
    { duration: '5m', target: 200 },  // 5분간 200 VU 유지
    { duration: '2m', target: 0 },    // 2분간 0으로 감소
  ],

  // 임계값 (SLO 기반)
  thresholds: {
    http_req_duration: ['p(95)<500'],  // p95 응답시간 500ms 이하
    http_req_failed: ['rate<0.01'],     // 에러율 1% 이하
    http_reqs: ['rate>100'],            // 초당 100 RPS 이상
  },
};

export default function () {
  const res = http.get('https://api.example.com/users');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
    'body contains users': (r) => r.body.includes('users'),
  });

  sleep(1);  // 1초 대기 (Think Time)
}
```

### 실행

```bash
# 기본 실행
k6 run load-test.js

# VU/시간 오버라이드
k6 run --vus 50 --duration 30s load-test.js

# 결과 출력
k6 run --out json=results.json load-test.js
k6 run --out influxdb=http://localhost:8086/k6 load-test.js
```

---

## K6 고급 시나리오

### 시나리오 기반 테스트

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    // 시나리오 1: 일반 사용자 브라우징
    browse: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '5m', target: 100 },
        { duration: '10m', target: 100 },
        { duration: '5m', target: 0 },
      ],
      exec: 'browseScenario',
    },

    // 시나리오 2: API 집중 호출
    api_heavy: {
      executor: 'constant-arrival-rate',
      rate: 50,           // 초당 50 요청
      timeUnit: '1s',
      duration: '10m',
      preAllocatedVUs: 50,
      maxVUs: 100,
      exec: 'apiScenario',
    },

    // 시나리오 3: 스파이크 테스트
    spike: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      stages: [
        { duration: '2m', target: 10 },
        { duration: '1m', target: 200 },  // 스파이크!
        { duration: '2m', target: 10 },
      ],
      preAllocatedVUs: 200,
      exec: 'spikeScenario',
    },
  },

  thresholds: {
    'http_req_duration{scenario:browse}': ['p(95)<1000'],
    'http_req_duration{scenario:api_heavy}': ['p(95)<500'],
    'http_req_failed': ['rate<0.01'],
  },
};

export function browseScenario() {
  http.get('https://api.example.com/products');
  sleep(Math.random() * 3 + 1);  // 1-4초 랜덤
}

export function apiScenario() {
  const payload = JSON.stringify({ item: 'test', quantity: 1 });
  http.post('https://api.example.com/orders', payload, {
    headers: { 'Content-Type': 'application/json' },
  });
}

export function spikeScenario() {
  http.get('https://api.example.com/');
}
```

### 인증 처리

```javascript
import http from 'k6/http';
import { check } from 'k6';

// Setup: 테스트 시작 전 1회 실행
export function setup() {
  const loginRes = http.post('https://api.example.com/login', {
    username: 'testuser',
    password: 'testpass',
  });

  const token = loginRes.json('token');
  return { token };
}

export default function (data) {
  const params = {
    headers: {
      Authorization: `Bearer ${data.token}`,
      'Content-Type': 'application/json',
    },
  };

  const res = http.get('https://api.example.com/protected', params);
  check(res, { 'status is 200': (r) => r.status === 200 });
}

// Teardown: 테스트 종료 후 1회 실행
export function teardown(data) {
  http.post('https://api.example.com/logout', null, {
    headers: { Authorization: `Bearer ${data.token}` },
  });
}
```

### 데이터 파일 사용

```javascript
import http from 'k6/http';
import { SharedArray } from 'k6/data';
import papaparse from 'https://jslib.k6.io/papaparse/5.1.1/index.js';

// CSV 데이터 로드 (모든 VU가 공유)
const users = new SharedArray('users', function () {
  return papaparse.parse(open('./users.csv'), { header: true }).data;
});

export default function () {
  // 랜덤 사용자 선택
  const user = users[Math.floor(Math.random() * users.length)];

  const payload = JSON.stringify({
    username: user.username,
    email: user.email,
  });

  http.post('https://api.example.com/users', payload, {
    headers: { 'Content-Type': 'application/json' },
  });
}
```

---

## K6 on Kubernetes

### K6 Operator TestRun

```yaml
apiVersion: k6.io/v1alpha1
kind: TestRun
metadata:
  name: load-test
spec:
  parallelism: 4  # 4개 Pod에서 분산 실행
  script:
    configMap:
      name: k6-test-script
      file: load-test.js
  arguments: --out influxdb=http://influxdb:8086/k6
  runner:
    image: grafana/k6:latest
    resources:
      limits:
        cpu: "1"
        memory: "1Gi"
      requests:
        cpu: "500m"
        memory: "512Mi"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: k6-test-script
data:
  load-test.js: |
    import http from 'k6/http';
    import { check } from 'k6';

    export const options = {
      vus: 50,
      duration: '5m',
    };

    export default function () {
      const res = http.get('http://my-service.default.svc.cluster.local/api');
      check(res, { 'status is 200': (r) => r.status === 200 });
    }
```

### CI/CD 통합

```yaml
# .github/workflows/load-test.yaml
name: Load Test

on:
  workflow_dispatch:
  schedule:
    - cron: '0 2 * * *'  # 매일 새벽 2시

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install k6
        run: |
          curl https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz -L | tar xvz
          sudo mv k6-v0.47.0-linux-amd64/k6 /usr/local/bin/

      - name: Run Load Test
        run: k6 run --out json=results.json tests/load-test.js

      - name: Check Thresholds
        run: |
          if grep -q '"thresholds":{".*":{"ok":false' results.json; then
            echo "Threshold failed!"
            exit 1
          fi

      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: k6-results
          path: results.json
```

---

## nGrinder

### 설치 (Docker)

```bash
# Controller
docker run -d --name ngrinder-controller \
  -p 80:80 -p 16001:16001 -p 12000-12009:12000-12009 \
  ngrinder/controller

# Agent
docker run -d --name ngrinder-agent \
  ngrinder/agent controller-host:80
```

### Groovy 스크립트

```groovy
import static net.grinder.script.Grinder.grinder
import static org.junit.Assert.*
import static org.hamcrest.Matchers.*
import net.grinder.script.GTest
import net.grinder.script.Grinder
import net.grinder.scriptengine.groovy.junit.GrinderRunner
import net.grinder.scriptengine.groovy.junit.annotation.BeforeProcess
import net.grinder.scriptengine.groovy.junit.annotation.BeforeThread
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.ngrinder.http.HTTPRequest
import org.ngrinder.http.HTTPResponse

@RunWith(GrinderRunner)
class TestRunner {
    public static GTest test
    public static HTTPRequest request
    public static Map<String, String> headers = [:]

    @BeforeProcess
    public static void beforeProcess() {
        test = new GTest(1, "API Test")
        request = new HTTPRequest()
        headers.put("Content-Type", "application/json")
        grinder.logger.info("Process initialized")
    }

    @BeforeThread
    public void beforeThread() {
        test.record(this, "testAPI")
        grinder.statistics.delayReports = true
        grinder.logger.info("Thread initialized")
    }

    @Test
    public void testAPI() {
        HTTPResponse response = request.GET(
            "https://api.example.com/users",
            headers
        )

        if (response.statusCode == 200) {
            grinder.logger.info("Success: ${response.statusCode}")
        } else {
            grinder.logger.warn("Failed: ${response.statusCode}")
            grinder.statistics.forLastTest.success = false
        }

        assertThat(response.statusCode, is(200))
    }
}
```

---

## 결과 분석

### 핵심 메트릭

| 메트릭 | 설명 | 목표 예시 |
|--------|------|----------|
| **RPS** | 초당 요청 수 | 서비스별 다름 |
| **Response Time (p50)** | 중간값 응답시간 | < 200ms |
| **Response Time (p95)** | 95% 응답시간 | < 500ms |
| **Response Time (p99)** | 99% 응답시간 | < 1s |
| **Error Rate** | 에러 비율 | < 1% |
| **Throughput** | 처리량 (bytes/s) | 병목 확인 |

### Grafana 대시보드 (K6 + InfluxDB)

```bash
# InfluxDB + Grafana 설치
docker-compose up -d

# K6 실행 (InfluxDB 출력)
k6 run --out influxdb=http://localhost:8086/k6 load-test.js
```

```yaml
# docker-compose.yml
version: '3'
services:
  influxdb:
    image: influxdb:1.8
    ports:
      - "8086:8086"
    environment:
      - INFLUXDB_DB=k6

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
```

### 결과 보고서 작성

```markdown
# 부하 테스트 결과 보고서

## 테스트 개요
- 일시: 2024-01-15 14:00 KST
- 대상: Order API (https://api.example.com/orders)
- 시나리오: 100 VU, 10분간 지속

## 결과 요약

| 메트릭 | 결과 | 목표 | 상태 |
|--------|------|------|------|
| p95 응답시간 | 320ms | < 500ms | ✅ Pass |
| p99 응답시간 | 890ms | < 1s | ✅ Pass |
| 에러율 | 0.3% | < 1% | ✅ Pass |
| 최대 RPS | 1,250 | > 1,000 | ✅ Pass |

## 병목 지점
- DB 커넥션 풀 (150 VU 이상에서 대기 발생)
- Redis 캐시 미스율 증가 (p99 지연 원인)

## 권장 사항
1. DB 커넥션 풀 50 → 100 증가
2. Redis 캐시 TTL 조정 (300s → 600s)
3. HPA 트리거 CPU 70% → 60%로 조정
```

---

## SLO 기반 Threshold

```javascript
export const options = {
  thresholds: {
    // 가용성 SLO: 99.9%
    http_req_failed: ['rate<0.001'],

    // 응답시간 SLO
    http_req_duration: [
      'p(50)<200',   // p50 < 200ms
      'p(95)<500',   // p95 < 500ms
      'p(99)<1000',  // p99 < 1s
    ],

    // 특정 엔드포인트 SLO
    'http_req_duration{endpoint:orders}': ['p(95)<300'],
    'http_req_duration{endpoint:search}': ['p(95)<1000'],

    // 시나리오별 SLO
    'http_req_duration{scenario:checkout}': ['p(99)<2000'],
  },
};
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| Think Time 없음 | 비현실적 부하 | sleep() 추가 |
| 단일 엔드포인트만 | 실제 시나리오 미반영 | 다양한 API 조합 |
| 로컬에서 대규모 테스트 | 네트워크 병목 | K6 Operator 분산 |
| Threshold 없이 실행 | Pass/Fail 기준 없음 | SLO 기반 threshold |
| 프로덕션 직접 테스트 | 서비스 영향 | 스테이징 환경 사용 |

---

## 체크리스트

### 테스트 준비
- [ ] 테스트 환경 격리 (스테이징)
- [ ] 모니터링 설정 (Prometheus, Grafana)
- [ ] 기준선(Baseline) 측정
- [ ] 테스트 시나리오 정의

### K6 스크립트
- [ ] 현실적 시나리오 구성
- [ ] Think Time 추가
- [ ] SLO 기반 Threshold 설정
- [ ] 인증/데이터 처리

### 실행 & 분석
- [ ] Smoke → Load → Stress 순서
- [ ] 결과 수집 (InfluxDB/JSON)
- [ ] 병목 지점 분석
- [ ] 보고서 작성

**관련 skill**: `/sre-sli-slo`, `/k8s-autoscaling`, `/monitoring-metrics`
