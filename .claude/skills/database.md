# Database Patterns

인덱스 최적화, 쿼리 성능, 마이그레이션 패턴

## 인덱스 기본

### 인덱스 종류

| 타입 | PostgreSQL | MySQL | 용도 |
|------|------------|-------|------|
| B-Tree | ✅ (기본) | ✅ (기본) | 일반 조회, 범위, 정렬 |
| Hash | ✅ | ✅ (Memory) | 정확한 일치만 |
| GIN | ✅ | ❌ | 배열, JSONB, 전문검색 |
| GiST | ✅ | ❌ | 지리 데이터, 범위 |
| BRIN | ✅ | ❌ | 대용량 시계열 데이터 |
| Full-Text | ✅ | ✅ | 전문 검색 |

### B-Tree 동작 원리

```
                    [50]
                   /    \
            [20,30]      [70,80]
           /  |  \      /  |   \
        [10] [25] [35] [60] [75] [90]
```

- **조회**: O(log n) - 트리 탐색
- **범위**: 리프 노드 순차 스캔
- **정렬**: 이미 정렬된 상태

---

## 인덱스 설계 원칙

### 1. 선택도 (Selectivity)

```sql
-- 선택도 = 유니크 값 / 전체 행
-- 높을수록 인덱스 효과적 (>10% 권장)

-- 좋은 인덱스: 선택도 높음
CREATE INDEX idx_users_email ON users(email);      -- 거의 유니크
CREATE INDEX idx_orders_number ON orders(order_no); -- 유니크

-- 나쁜 인덱스: 선택도 낮음
CREATE INDEX idx_users_gender ON users(gender);    -- M/F 2개뿐
CREATE INDEX idx_users_status ON users(status);    -- 5개 상태
```

### 2. 복합 인덱스 순서

```sql
-- 순서 중요: 선택도 높은 것 → 낮은 것
-- 또는: WHERE 절 등호(=) → 범위(<, >) → ORDER BY

-- 쿼리: WHERE tenant_id = ? AND status = ? AND created_at > ?
CREATE INDEX idx_orders_search
ON orders(tenant_id, status, created_at);
--         └─ 등호    └─ 등호   └─ 범위

-- 복합 인덱스는 왼쪽부터 사용
-- (tenant_id) ✅
-- (tenant_id, status) ✅
-- (tenant_id, status, created_at) ✅
-- (status) ❌ 인덱스 사용 불가
-- (status, created_at) ❌ 인덱스 사용 불가
```

### 3. 커버링 인덱스

```sql
-- 테이블 접근 없이 인덱스만으로 조회 (Index-Only Scan)

-- 쿼리: SELECT id, name FROM users WHERE email = ?
CREATE INDEX idx_users_email_covering
ON users(email) INCLUDE (id, name);

-- PostgreSQL EXPLAIN 확인
EXPLAIN ANALYZE SELECT id, name FROM users WHERE email = 'test@test.com';
-- Index Only Scan 확인
```

### 4. 부분 인덱스

```sql
-- 조건에 맞는 행만 인덱스 (크기 감소, 성능 향상)

-- 활성 사용자만
CREATE INDEX idx_users_active
ON users(email) WHERE status = 'active';

-- 최근 주문만
CREATE INDEX idx_orders_recent
ON orders(user_id, created_at)
WHERE created_at > NOW() - INTERVAL '30 days';

-- NULL 제외
CREATE INDEX idx_users_phone
ON users(phone) WHERE phone IS NOT NULL;
```

### 5. 표현식 인덱스

```sql
-- 함수/표현식 결과에 인덱스

-- 대소문자 무시 검색
CREATE INDEX idx_users_email_lower
ON users(LOWER(email));

SELECT * FROM users WHERE LOWER(email) = 'test@test.com';

-- 날짜 부분 검색
CREATE INDEX idx_orders_year_month
ON orders(DATE_TRUNC('month', created_at));
```

---

## N+1 문제 해결

### 문제 상황

```java
// Bad: N+1 쿼리 발생
List<User> users = userRepository.findAll();  // 1번 쿼리
for (User user : users) {
    List<Order> orders = user.getOrders();    // N번 쿼리
}
// 사용자 100명 = 101번 쿼리 실행
```

### 해결 1: Fetch Join

```java
// JPA
@Query("SELECT u FROM User u JOIN FETCH u.orders")
List<User> findAllWithOrders();

// QueryDSL
queryFactory
    .selectFrom(user)
    .join(user.orders, order).fetchJoin()
    .fetch();
```

### 해결 2: EntityGraph

```java
@EntityGraph(attributePaths = {"orders", "orders.items"})
@Query("SELECT u FROM User u")
List<User> findAllWithOrdersAndItems();
```

### 해결 3: Batch Size

```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        default_batch_fetch_size: 100
```

```java
@Entity
public class User {
    @BatchSize(size = 100)
    @OneToMany(mappedBy = "user")
    private List<Order> orders;
}
```

### 해결 4: 서브쿼리 (Go/GORM)

```go
// Bad: N+1
var users []User
db.Find(&users)
for _, user := range users {
    db.Where("user_id = ?", user.ID).Find(&user.Orders)
}

// Good: Preload
var users []User
db.Preload("Orders").Find(&users)

// Good: 커스텀 프리로드
db.Preload("Orders", func(db *gorm.DB) *gorm.DB {
    return db.Where("status = ?", "active").Order("created_at DESC")
}).Find(&users)
```

---

## 쿼리 최적화

### EXPLAIN 분석

```sql
-- PostgreSQL
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 123 AND status = 'pending';

-- 확인 포인트:
-- 1. Seq Scan → Index Scan으로 변경 필요
-- 2. actual time: 실제 실행 시간
-- 3. rows: 예상 vs 실제 행 수
-- 4. Buffers: 읽은 블록 수
```

### 느린 쿼리 패턴

| 문제 | 원인 | 해결 |
|------|------|------|
| `Seq Scan` | 인덱스 없음/미사용 | 인덱스 추가 |
| `Sort` 비용 높음 | ORDER BY 인덱스 없음 | 정렬 컬럼 인덱스 |
| `Nested Loop` 느림 | 작은 테이블 조인 비효율 | 인덱스 또는 Hash Join |
| `Hash Join` 메모리 초과 | work_mem 부족 | 설정 증가 또는 쿼리 개선 |

### SELECT 최적화

```sql
-- Bad: 모든 컬럼
SELECT * FROM users WHERE status = 'active';

-- Good: 필요한 컬럼만
SELECT id, name, email FROM users WHERE status = 'active';

-- Bad: DISTINCT 남용
SELECT DISTINCT user_id FROM orders;

-- Good: EXISTS 사용
SELECT id FROM users u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

### JOIN 최적화

```sql
-- 작은 테이블을 먼저 (옵티마이저가 보통 처리하지만)
-- 인덱스가 있는 컬럼으로 조인

-- Bad: 조인 후 필터
SELECT * FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.created_at > '2025-01-01';

-- Good: 필터 후 조인 (조건이 많이 줄이는 경우)
SELECT * FROM (
    SELECT * FROM orders WHERE created_at > '2025-01-01'
) o
JOIN users u ON o.user_id = u.id;
```

### 페이지네이션 최적화

```sql
-- Bad: OFFSET 큰 경우 느림
SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 100000;
-- 100,000개 스캔 후 버림

-- Good: Cursor 기반
SELECT * FROM orders
WHERE id > :last_id
ORDER BY id
LIMIT 20;

-- Good: Keyset Pagination
SELECT * FROM orders
WHERE (created_at, id) > (:last_created_at, :last_id)
ORDER BY created_at, id
LIMIT 20;
```

---

## 마이그레이션

### Flyway (권장: 단순함)

**네이밍 규칙:**
```
V{version}__{description}.sql
├── V1__Create_users_table.sql
├── V2__Add_email_to_users.sql
├── V3__Create_orders_table.sql
└── R__Refresh_views.sql (Repeatable)
```

**Spring Boot 설정:**
```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
```

**마이그레이션 예시:**
```sql
-- V1__Create_users_table.sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status) WHERE status = 'active';
```

### Liquibase (권장: 복잡한 환경)

```yaml
# db/changelog/db.changelog-master.yaml
databaseChangeLog:
  - include:
      file: db/changelog/changes/001-create-users.yaml
  - include:
      file: db/changelog/changes/002-add-orders.yaml
```

```yaml
# db/changelog/changes/001-create-users.yaml
databaseChangeLog:
  - changeSet:
      id: 1
      author: developer
      changes:
        - createTable:
            tableName: users
            columns:
              - column:
                  name: id
                  type: bigint
                  autoIncrement: true
                  constraints:
                    primaryKey: true
              - column:
                  name: email
                  type: varchar(255)
                  constraints:
                    nullable: false
                    unique: true
```

### Go 마이그레이션 (golang-migrate)

```bash
# 설치
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# 마이그레이션 생성
migrate create -ext sql -dir migrations -seq create_users_table
```

```sql
-- migrations/000001_create_users_table.up.sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- migrations/000001_create_users_table.down.sql
DROP TABLE IF EXISTS users;
```

```go
// 코드에서 실행
import "github.com/golang-migrate/migrate/v4"

m, err := migrate.New(
    "file://migrations",
    "postgres://user:pass@localhost:5432/mydb?sslmode=disable",
)
if err != nil {
    log.Fatal(err)
}

if err := m.Up(); err != nil && err != migrate.ErrNoChange {
    log.Fatal(err)
}
```

### 안전한 마이그레이션 패턴

```sql
-- 1. 컬럼 추가 (안전)
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- 2. 인덱스 생성 (CONCURRENTLY - 락 없이)
CREATE INDEX CONCURRENTLY idx_users_phone ON users(phone);

-- 3. NOT NULL 추가 (3단계)
-- Step 1: 컬럼 추가 (nullable)
ALTER TABLE users ADD COLUMN country VARCHAR(50);
-- Step 2: 기존 데이터 업데이트
UPDATE users SET country = 'KR' WHERE country IS NULL;
-- Step 3: NOT NULL 제약 추가
ALTER TABLE users ALTER COLUMN country SET NOT NULL;

-- 4. 컬럼 삭제 (역순)
-- Step 1: 앱에서 사용 중지
-- Step 2: 마이그레이션에서 삭제
ALTER TABLE users DROP COLUMN old_column;
```

---

## 유지보수

### 통계 업데이트

```sql
-- PostgreSQL
ANALYZE users;
ANALYZE orders;

-- 전체 DB
ANALYZE;

-- 자동 설정 (postgresql.conf)
-- autovacuum = on
-- autovacuum_analyze_threshold = 50
-- autovacuum_analyze_scale_factor = 0.1
```

### 인덱스 사용량 확인

```sql
-- PostgreSQL: 사용되지 않는 인덱스
SELECT
    schemaname,
    relname AS table,
    indexrelname AS index,
    idx_scan AS scans,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexrelname NOT LIKE 'pg_%'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### 느린 쿼리 로그

```sql
-- PostgreSQL: 설정
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- 1초 이상
SELECT pg_reload_conf();

-- MySQL: 설정
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';
```

### 커넥션 풀 설정

```yaml
# Spring Boot (HikariCP)
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
```

```go
// Go
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(5)
db.SetConnMaxLifetime(5 * time.Minute)
db.SetConnMaxIdleTime(5 * time.Minute)
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| SELECT * | 불필요한 데이터 | 필요한 컬럼만 |
| 인덱스 없이 JOIN | Full Table Scan | 조인 컬럼 인덱스 |
| LIKE '%keyword%' | 인덱스 사용 불가 | Full-Text Search |
| OR 조건 남용 | 인덱스 비효율 | UNION 또는 재설계 |
| 함수 in WHERE | 인덱스 무효화 | 표현식 인덱스 |
| 모든 컬럼에 인덱스 | 쓰기 성능 저하 | 필요한 것만 |
| 큰 OFFSET | 느린 페이지네이션 | Cursor 기반 |
| N+1 쿼리 | 과도한 DB 호출 | Fetch Join/Preload |

---

## 체크리스트

### 인덱스
- [ ] WHERE, JOIN, ORDER BY 컬럼에 인덱스
- [ ] 복합 인덱스 순서 확인 (선택도, 조건 타입)
- [ ] 사용되지 않는 인덱스 정리
- [ ] 커버링 인덱스 검토

### 쿼리
- [ ] EXPLAIN으로 실행 계획 확인
- [ ] N+1 문제 없는지 확인
- [ ] 페이지네이션 최적화 (cursor 기반)
- [ ] 불필요한 SELECT * 제거

### 마이그레이션
- [ ] 버전 관리 도구 사용 (Flyway/Liquibase)
- [ ] 롤백 스크립트 준비
- [ ] 대용량 테이블 변경 시 CONCURRENTLY
- [ ] 프로덕션 전 스테이징 테스트

### 유지보수
- [ ] 느린 쿼리 로깅 활성화
- [ ] 정기적 ANALYZE/통계 업데이트
- [ ] 커넥션 풀 적절히 설정
- [ ] 인덱스 사용량 모니터링
