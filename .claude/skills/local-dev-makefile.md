# Local Dev with Makefile: make up으로 풀스택 실행

Docker를 몰라도 `make up` 하나로 프론트+백엔드+DB가 로컬에서 실행되는 환경 구축 가이드

## Quick Reference (결정 트리)

```
개발자가 하고 싶은 것?
    │
    ├─ 처음 프로젝트 받았다 ────> make up
    │       └─ 모든 서비스 빌드 + 실행 (FE+BE+DB+Redis)
    │
    ├─ 코드 수정 후 확인 ──────> 저장만 하면 됨 (Hot Reload)
    │       ├─ Frontend ──> WATCHPACK_POLLING / Vite usePolling
    │       └─ Backend ───> Air (Go) / DevTools (Spring)
    │
    ├─ 로그 확인 ──────────────> make logs
    │       └─ make logs-be (백엔드만)
    │
    ├─ DB 초기화 ──────────────> make db-reset
    │
    ├─ 테스트 실행 ─────────────> make test
    │
    ├─ 전부 정리 ──────────────> make down
    │
    └─ 뭐가 있는지 모르겠다 ──> make help
```

---

## CRITICAL: Self-Documenting Makefile

**IMPORTANT**: Makefile은 반드시 `make help`로 자기 문서화해야 함

### `##` / `##@` 패턴

```makefile
# ## 패턴: 타겟 옆에 주석 → help에서 자동 추출
up: ## 모든 서비스 시작 (FE+BE+DB+Redis)
down: ## 모든 서비스 중지 및 정리

# ##@ 패턴: 섹션 헤더 (그룹핑)
##@ Development
up: ## 모든 서비스 시작
down: ## 모든 서비스 중지

##@ Database
db-reset: ## DB 초기화 (데이터 삭제)
db-migrate: ## 마이그레이션 실행
```

### AWK help 타겟

```makefile
.DEFAULT_GOAL := help

.PHONY: help
help: ## 사용 가능한 명령어 목록
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1m사용법:\033[0m\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
```

### 철학

| 원칙 | 설명 |
|------|------|
| 진입장벽 제거 | Docker를 몰라도 `make up`으로 시작 |
| 자기 문서화 | `make help`가 곧 README |
| 멱등성 | 몇 번을 실행해도 같은 결과 |
| 빠른 피드백 | Hot Reload로 저장 즉시 반영 |

---

## Complete Makefile Template

```makefile
# ============================================================
# Project Local Dev Makefile
# ============================================================
# 사용법: make help
# ============================================================

.DEFAULT_GOAL := help

# ── 변수 ──────────────────────────────────────────────────
COMPOSE := docker compose -f docker-compose.yml
FE_SERVICE := frontend
BE_SERVICE := backend
DB_SERVICE := postgres
REDIS_SERVICE := redis

# ── Help ──────────────────────────────────────────────────
.PHONY: help
help: ## 사용 가능한 명령어 목록
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1m사용법:\033[0m\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

# ── Development ───────────────────────────────────────────
##@ Development

.PHONY: up down restart status logs logs-fe logs-be

up: check-env ## 모든 서비스 시작 (FE+BE+DB+Redis)
	$(COMPOSE) up -d --build
	@echo "\n✅ 서비스가 시작되었습니다"
	@echo "  Frontend : http://localhost:3000"
	@echo "  Backend  : http://localhost:8080"
	@echo "  DB       : localhost:5432"
	@echo ""

down: ## 모든 서비스 중지 (볼륨 유지)
	$(COMPOSE) down

restart: ## 모든 서비스 재시작
	$(COMPOSE) restart

status: ## 서비스 상태 확인
	$(COMPOSE) ps

logs: ## 모든 서비스 로그 (follow)
	$(COMPOSE) logs -f

logs-fe: ## 프론트엔드 로그
	$(COMPOSE) logs -f $(FE_SERVICE)

logs-be: ## 백엔드 로그
	$(COMPOSE) logs -f $(BE_SERVICE)

# ── Build ─────────────────────────────────────────────────
##@ Build

.PHONY: build build-fe build-be

build: ## 모든 이미지 리빌드
	$(COMPOSE) build --no-cache

build-fe: ## 프론트엔드 이미지만 리빌드
	$(COMPOSE) build --no-cache $(FE_SERVICE)

build-be: ## 백엔드 이미지만 리빌드
	$(COMPOSE) build --no-cache $(BE_SERVICE)

# ── Database ──────────────────────────────────────────────
##@ Database

.PHONY: db-reset db-migrate db-seed db-shell

db-reset: ## DB 초기화 (볼륨 삭제 후 재생성)
	$(COMPOSE) down -v
	$(COMPOSE) up -d $(DB_SERVICE)
	@echo "⏳ DB 준비 대기..."
	@sleep 3
	@$(MAKE) db-migrate
	@echo "✅ DB 초기화 완료"

db-migrate: ## 마이그레이션 실행
	$(COMPOSE) exec $(BE_SERVICE) sh -c 'make migrate 2>/dev/null || echo "마이그레이션 스크립트를 설정하세요"'

db-seed: ## 테스트 데이터 삽입
	$(COMPOSE) exec $(BE_SERVICE) sh -c 'make seed 2>/dev/null || echo "시드 스크립트를 설정하세요"'

db-shell: ## DB 쉘 접속
	$(COMPOSE) exec $(DB_SERVICE) psql -U $${POSTGRES_USER:-app} -d $${POSTGRES_DB:-app_dev}

# ── Test ──────────────────────────────────────────────────
##@ Test

.PHONY: test test-fe test-be lint

test: test-fe test-be ## 전체 테스트 실행

test-fe: ## 프론트엔드 테스트
	$(COMPOSE) exec $(FE_SERVICE) npm test -- --watchAll=false

test-be: ## 백엔드 테스트
	$(COMPOSE) exec $(BE_SERVICE) sh -c 'make test 2>/dev/null || go test ./...'

lint: ## 린트 실행
	$(COMPOSE) exec $(FE_SERVICE) npm run lint
	$(COMPOSE) exec $(BE_SERVICE) sh -c 'make lint 2>/dev/null || echo "린트 설정 필요"'

# ── Cleanup ───────────────────────────────────────────────
##@ Cleanup

.PHONY: clean nuke

clean: ## 컨테이너 + 이미지 정리 (볼륨 유지)
	$(COMPOSE) down --rmi local

nuke: ## 전부 삭제 (볼륨 포함, DB 데이터 사라짐)
	$(COMPOSE) down -v --rmi local --remove-orphans
	@echo "🧹 모든 컨테이너, 이미지, 볼륨이 삭제되었습니다"

# ── Env ───────────────────────────────────────────────────
##@ Environment

.PHONY: check-env setup-env

check-env: ## .env 파일 존재 확인
	@if [ ! -f .env ]; then \
		echo "⚠️  .env 파일이 없습니다. .env.example에서 복사합니다..."; \
		cp .env.example .env; \
		echo "✅ .env 파일이 생성되었습니다. 값을 확인하세요."; \
	fi

setup-env: ## .env.example → .env 복사 (기존 파일 보존)
	@if [ -f .env ]; then \
		echo "⚠️  .env 파일이 이미 있습니다. 덮어쓰려면 삭제 후 다시 실행하세요."; \
	else \
		cp .env.example .env; \
		echo "✅ .env 파일이 생성되었습니다."; \
	fi
```

---

## docker-compose.yml (Local Dev)

```yaml
# docker-compose.yml - 로컬 개발 전용
services:
  # ── Frontend (Next.js) ────────────────────────────────
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - ./frontend/src:/app/src          # 소스코드만 마운트
      - ./frontend/public:/app/public
      - /app/node_modules                # node_modules는 컨테이너 것 사용
    environment:
      - WATCHPACK_POLLING=true           # Docker 환경 Hot Reload 필수
      - NEXT_PUBLIC_API_URL=http://localhost:8080
    env_file:
      - .env
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - app-net

  # ── Backend (Go + Air) ───────────────────────────────
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    ports:
      - "8080:8080"
    volumes:
      - ./backend:/app
      - /app/tmp                         # Air 빌드 디렉토리 제외
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=${POSTGRES_USER:-app}
      - DB_PASSWORD=${POSTGRES_PASSWORD:-secret}
      - DB_NAME=${POSTGRES_DB:-app_dev}
      - REDIS_URL=redis://redis:6379
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    networks:
      - app-net

  # ── PostgreSQL ────────────────────────────────────────
  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-app}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-secret}
      POSTGRES_DB: ${POSTGRES_DB:-app_dev}
    volumes:
      - pg-data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d  # 초기 SQL
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-app}"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - app-net

  # ── Redis ─────────────────────────────────────────────
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - app-net

volumes:
  pg-data:
  redis-data:

networks:
  app-net:
    driver: bridge
```

### Spring Boot 백엔드 변형

```yaml
  # Backend를 Spring Boot로 교체할 경우
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    ports:
      - "8080:8080"
      - "5005:5005"                      # Remote Debug 포트
    volumes:
      - ./backend/src:/app/src           # 소스만 마운트
      - ./backend/build:/app/build
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/${POSTGRES_DB:-app_dev}
      - SPRING_DATASOURCE_USERNAME=${POSTGRES_USER:-app}
      - SPRING_DATASOURCE_PASSWORD=${POSTGRES_PASSWORD:-secret}
      - SPRING_DATA_REDIS_HOST=redis
    depends_on:
      postgres:
        condition: service_healthy
```

---

## Dockerfile.dev Examples

### Frontend (Next.js)

```dockerfile
# frontend/Dockerfile.dev
FROM node:20-alpine

WORKDIR /app

# 의존성 먼저 설치 (캐시 활용)
COPY package.json package-lock.json ./
RUN npm ci

# 소스는 volume mount로 들어옴
COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]
```

### Backend (Go + Air)

```dockerfile
# backend/Dockerfile.dev
FROM golang:1.23-alpine

RUN apk add --no-cache curl git
RUN go install github.com/air-verse/air@latest

WORKDIR /app

# 의존성 먼저 다운로드 (캐시 활용)
COPY go.mod go.sum ./
RUN go mod download

COPY . .

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]
```

### Backend (Spring Boot + DevTools)

```dockerfile
# backend/Dockerfile.dev
FROM eclipse-temurin:21-jdk-alpine

WORKDIR /app

# Gradle wrapper 복사
COPY gradlew build.gradle.kts settings.gradle.kts ./
COPY gradle ./gradle
RUN ./gradlew dependencies --no-daemon

COPY . .

EXPOSE 8080 5005

# DevTools + Remote Debug 활성화
CMD ["./gradlew", "bootRun", \
     "--args=--spring.devtools.restart.enabled=true", \
     "-Dagentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"]
```

---

## Frontend Hot Reload

### Next.js (WATCHPACK_POLLING)

Docker 볼륨 마운트에서는 파일 변경 이벤트가 전달되지 않으므로 polling 필수:

```yaml
# docker-compose.yml
environment:
  - WATCHPACK_POLLING=true     # Next.js 13+ 필수
  - CHOKIDAR_USEPOLLING=true   # Next.js 12 이하 (webpack 4)
```

```javascript
// next.config.js - polling 간격 조정 (선택사항)
module.exports = {
  webpack: (config) => {
    config.watchOptions = {
      poll: 1000,        // 1초마다 체크
      aggregateTimeout: 300,
    };
    return config;
  },
};
```

**주의사항**:
- `node_modules`는 반드시 anonymous volume으로 제외: `/app/node_modules`
- `src/` 폴더만 마운트하면 polling 대상이 줄어 성능 향상

### Vite (usePolling)

```javascript
// vite.config.ts
export default defineConfig({
  server: {
    host: '0.0.0.0',      // 컨테이너 외부 접근 허용
    port: 5173,
    watch: {
      usePolling: true,    // Docker 환경 필수
      interval: 1000,
    },
    hmr: {
      port: 5173,          // HMR WebSocket 포트
    },
  },
});
```

---

## Backend Hot Reload

### Go + Air

Air는 Go 파일 변경 감지 → 자동 빌드 → 재시작하는 도구:

```toml
# .air.toml
root = "."
tmp_dir = "tmp"

[build]
  cmd = "go build -o ./tmp/main ./cmd/server"
  bin = "./tmp/main"
  delay = 1000                    # ms, 빌드 전 대기
  exclude_dir = ["tmp", "vendor", "node_modules", ".git"]
  exclude_regex = ["_test.go"]
  include_ext = ["go", "tpl", "tmpl", "html", "yaml"]
  kill_delay = 500                # ms, 프로세스 종료 대기
  send_interrupt = true           # graceful shutdown

[log]
  time = false

[misc]
  clean_on_exit = true
```

**핵심 설정**:

| 항목 | 설명 | 권장값 |
|------|------|--------|
| `delay` | 파일 변경 후 빌드까지 대기 | 1000ms |
| `exclude_dir` | 감시 제외 디렉토리 | tmp, vendor, .git |
| `include_ext` | 감시할 확장자 | go, yaml, html |
| `send_interrupt` | SIGINT로 graceful 종료 | true |

### Spring Boot DevTools

```properties
# application-dev.properties
spring.devtools.restart.enabled=true
spring.devtools.restart.poll-interval=2s
spring.devtools.restart.quiet-period=1s
spring.devtools.livereload.enabled=true

# 리스타트에서 제외할 경로
spring.devtools.restart.exclude=static/**,public/**
```

```groovy
// build.gradle.kts
dependencies {
    developmentOnly("org.springframework.boot:spring-boot-devtools")
}
```

**DevTools 동작 원리**:
1. 클래스패스 내 파일 변경 감지
2. RestartClassLoader만 교체 (전체 재시작보다 빠름)
3. LiveReload 서버로 브라우저 자동 새로고침

---

## .env Management

### .env.example (커밋 대상)

```bash
# .env.example - 이 파일을 .env로 복사하여 사용
# cp .env.example .env

# ── Database ──────────────────────────
POSTGRES_USER=app
POSTGRES_PASSWORD=secret
POSTGRES_DB=app_dev

# ── Redis ─────────────────────────────
REDIS_URL=redis://redis:6379

# ── Application ───────────────────────
APP_ENV=development
APP_PORT=8080
LOG_LEVEL=debug

# ── Frontend ──────────────────────────
NEXT_PUBLIC_API_URL=http://localhost:8080
```

### .gitignore 추가 항목

```gitignore
# Local dev
.env
!.env.example
tmp/
```

### check-env 동작 흐름

```
make up
  └─ check-env (의존성)
       ├─ .env 있음? → 그대로 진행
       └─ .env 없음? → .env.example 자동 복사 → 안내 메시지
```

---

## Anti-Patterns

| # | 실수 | 올바른 방법 |
|---|------|------------|
| 1 | `volumes: - .:/app` (전체 마운트) | `src/` 폴더만 마운트하여 성능 확보 |
| 2 | `node_modules` 호스트와 공유 | anonymous volume `/app/node_modules`로 격리 |
| 3 | polling 없이 Hot Reload 기대 | `WATCHPACK_POLLING=true` 명시 설정 |
| 4 | `.env`를 git에 커밋 | `.env.example`만 커밋, `.env`는 gitignore |
| 5 | healthcheck 없이 depends_on | `condition: service_healthy`로 준비 대기 |
| 6 | Makefile에 `help` 미구현 | `##` 주석 + AWK help 타겟 필수 |
| 7 | production Dockerfile로 개발 | `Dockerfile.dev` 분리 (멀티스테이지 불필요) |

---

## 체크리스트

### Makefile

- [ ] `.DEFAULT_GOAL := help` 설정
- [ ] 모든 타겟에 `##` 주석 추가
- [ ] `##@` 섹션 그룹핑 적용
- [ ] `check-env`가 `up`의 의존성으로 설정
- [ ] `.PHONY` 선언 완료

### Docker Compose

- [ ] 모든 서비스에 `healthcheck` 정의
- [ ] `depends_on` + `condition: service_healthy` 사용
- [ ] DB 볼륨 `pg-data`로 데이터 영속화
- [ ] `networks`로 서비스 간 통신 격리
- [ ] `.env` 파일에서 변수 주입

### Hot Reload

- [ ] Frontend: `WATCHPACK_POLLING=true` 설정
- [ ] Frontend: `node_modules` anonymous volume 격리
- [ ] Backend (Go): `.air.toml` 설정 파일 존재
- [ ] Backend (Spring): `spring-boot-devtools` 의존성 추가
- [ ] 소스 디렉토리만 선택적으로 volume mount

### .env

- [ ] `.env.example` 파일 존재 (git 추적)
- [ ] `.env`는 `.gitignore`에 추가
- [ ] `check-env` 타겟이 자동 복사 처리

---

## 관련 Skills

- `/docker` — Production Dockerfile 최적화, 멀티스테이지 빌드
- `/dx-onboarding-environment` — VS Code Dev Container 기반 개발 환경
