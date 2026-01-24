# Docker & Dockerfile Patterns

Dockerfile 최적화, 멀티스테이지 빌드, Go/Java 컨테이너 패턴

## 멀티스테이지 빌드 기본

### 왜 필요한가?

| | 단일 스테이지 | 멀티스테이지 |
|---|-------------|-------------|
| Go 이미지 크기 | ~800MB | ~12MB |
| Java 이미지 크기 | ~600MB | ~150MB |
| 빌드 도구 포함 | ✅ | ❌ |
| 보안 취약점 | 많음 | 최소화 |

### 기본 구조

```dockerfile
# Stage 1: Build
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o main .

# Stage 2: Runtime
FROM alpine:3.19
COPY --from=builder /app/main /main
CMD ["/main"]
```

---

## Go Dockerfile (최적화)

### Production-Ready

```dockerfile
# syntax=docker/dockerfile:1

# ============================================
# Stage 1: Build
# ============================================
FROM golang:1.23-alpine AS builder

# 빌드에 필요한 도구 (git for private modules, ca-certs for HTTPS)
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

# 의존성 먼저 (캐시 최적화)
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# 소스 복사 및 빌드
COPY . .

# 정적 바이너리 빌드
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s -X main.version=${VERSION}" \
    -o /app/server ./cmd/api

# ============================================
# Stage 2: Runtime (Scratch - 최소 이미지)
# ============================================
FROM scratch

# 타임존, 인증서
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 논루트 유저 (보안)
COPY --from=builder /etc/passwd /etc/passwd
USER nobody

# 바이너리
COPY --from=builder /app/server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
```

### 빌드 옵션 설명

| 옵션 | 설명 |
|------|------|
| `CGO_ENABLED=0` | 순수 Go 바이너리 (C 라이브러리 불필요) |
| `GOOS=linux` | Linux 타겟 |
| `-ldflags="-w -s"` | 디버그 정보 제거 (30% 크기 감소) |
| `-X main.version=...` | 빌드 타임 변수 주입 |

### 베이스 이미지 선택

| 이미지 | 크기 | 쉘 | 디버깅 | 용도 |
|--------|------|-----|--------|------|
| `scratch` | 0MB | ❌ | ❌ | 프로덕션 (보안 최우선) |
| `distroless` | 2MB | ❌ | ❌ | 프로덕션 (약간의 도구) |
| `alpine` | 5MB | ✅ | ✅ | 개발/디버깅 필요 시 |
| `debian-slim` | 25MB | ✅ | ✅ | DNS 이슈 방지 필요 시 |

### 캐시 마운트 (BuildKit)

```dockerfile
# go mod 캐시
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# go build 캐시 (12x 빌드 속도 향상)
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app/server .
```

**효과:**
- 첫 빌드: ~60초
- 코드만 변경 후: ~5초

---

## Java/Spring Boot Dockerfile (최적화)

### JVM 기반 (일반)

```dockerfile
# syntax=docker/dockerfile:1

# ============================================
# Stage 1: Build
# ============================================
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Gradle 캐시 최적화
COPY gradle gradle
COPY gradlew build.gradle.kts settings.gradle.kts ./
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew dependencies --no-daemon

# 소스 빌드
COPY src src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew bootJar --no-daemon -x test

# JAR 레이어 추출 (Spring Boot 3+)
RUN java -Djarmode=layertools -jar build/libs/*.jar extract

# ============================================
# Stage 2: Runtime
# ============================================
FROM eclipse-temurin:21-jre-alpine

# 보안: 논루트 유저
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

WORKDIR /app

# 레이어 순서 (변경 빈도 낮은 것 먼저)
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/snapshot-dependencies/ ./
COPY --from=builder /app/application/ ./

# JVM 튜닝
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:InitialRAMPercentage=50.0 \
               -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
```

### GraalVM Native Image (빠른 시작)

```dockerfile
# syntax=docker/dockerfile:1

# ============================================
# Stage 1: Build Native Image
# ============================================
FROM ghcr.io/graalvm/graalvm-community:21 AS builder

WORKDIR /app

# Gradle
COPY gradle gradle
COPY gradlew build.gradle.kts settings.gradle.kts ./
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew dependencies --no-daemon

# Native 빌드 (시간 오래 걸림: 3-10분)
COPY src src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew nativeCompile --no-daemon

# ============================================
# Stage 2: Runtime (매우 작은 이미지)
# ============================================
FROM gcr.io/distroless/base-debian12

COPY --from=builder /app/build/native/nativeCompile/app /app

EXPOSE 8080

ENTRYPOINT ["/app"]
```

### JVM vs Native 비교

| | JVM | Native |
|---|-----|--------|
| 시작 시간 | ~2초 | ~50ms |
| 메모리 | ~300MB | ~50MB |
| 이미지 크기 | ~300MB | ~80MB |
| 빌드 시간 | ~30초 | ~5분 |
| 장기 처리량 | 높음 (JIT) | 보통 |
| 용도 | 일반 서비스 | 서버리스, 스케일 |

---

## 레이어 최적화

### 순서 원칙

```dockerfile
# 변경 빈도: 낮음 → 높음

# 1. 시스템 패키지 (거의 안 변함)
RUN apt-get update && apt-get install -y ...

# 2. 의존성 파일 (가끔 변함)
COPY go.mod go.sum ./
RUN go mod download

# 3. 소스 코드 (자주 변함)
COPY . .
RUN go build
```

### 레이어 합치기

```dockerfile
# Bad: 3개 레이어
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*

# Good: 1개 레이어 + 정리
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*
```

### .dockerignore

```
# Git
.git
.gitignore

# IDE
.idea
.vscode
*.swp

# 빌드 산출물
bin/
build/
dist/
target/

# 테스트
*_test.go
**/*_test.go
testdata/

# 문서
*.md
docs/

# Docker
Dockerfile*
docker-compose*

# 기타
.env
*.log
```

---

## 보안 Best Practices

### 1. 논루트 유저

```dockerfile
# Alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Debian
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
USER appuser
```

### 2. 읽기 전용 파일시스템

```yaml
# docker-compose.yml
services:
  app:
    read_only: true
    tmpfs:
      - /tmp
```

### 3. 취약점 스캔

```bash
# Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image myapp:latest

# Docker Scout
docker scout cves myapp:latest
```

### 4. 시크릿 처리

```dockerfile
# Bad: 이미지에 시크릿 포함
COPY .env /app/.env

# Good: 런타임에 주입
# docker run -e DATABASE_URL=... myapp

# Good: BuildKit 시크릿 (빌드 시에만)
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm install
```

---

## Docker Compose 패턴

### 개발 환경

```yaml
# docker-compose.yml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: builder  # 개발 스테이지
    volumes:
      - .:/app
      - go-mod-cache:/go/pkg/mod
    ports:
      - "8080:8080"
    environment:
      - ENV=development
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d myapp"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  go-mod-cache:
  postgres-data:
```

### 프로덕션 환경

```yaml
# docker-compose.prod.yml
services:
  app:
    image: myapp:${VERSION:-latest}
    restart: always
    read_only: true
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

---

## 멀티 플랫폼 빌드

```bash
# Buildx 설정
docker buildx create --name mybuilder --use

# AMD64 + ARM64 빌드
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push \
  .
```

```dockerfile
# Dockerfile에서 플랫폼 인식
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

ARG TARGETOS TARGETARCH

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -o /app/server .
```

---

## 디버깅 팁

### 중간 스테이지 확인

```bash
# 특정 스테이지까지만 빌드
docker build --target builder -t myapp:debug .

# 들어가서 확인
docker run -it myapp:debug sh
```

### 레이어 분석

```bash
# 레이어별 크기
docker history myapp:latest

# 상세 분석 (dive 도구)
dive myapp:latest
```

### 빌드 캐시 확인

```bash
# 캐시 상태
docker builder prune --dry-run

# 캐시 삭제
docker builder prune -af
```

---

## Anti-Patterns

| 실수 | 올바른 방법 |
|------|------------|
| `FROM ubuntu` | `FROM ubuntu:22.04` (태그 명시) |
| `latest` 태그 사용 | 구체적 버전 태그 |
| Root 유저로 실행 | `USER nobody` |
| 빌드 도구 포함 | 멀티스테이지로 분리 |
| COPY . . 먼저 | 의존성 파일 먼저 복사 |
| apt 캐시 남김 | `rm -rf /var/lib/apt/lists/*` |
| 시크릿 COPY | 환경변수 또는 BuildKit secret |

---

## 체크리스트

### 이미지 최적화
- [ ] 멀티스테이지 빌드 사용
- [ ] 적절한 베이스 이미지 선택
- [ ] .dockerignore 설정
- [ ] 레이어 순서 최적화 (변경 빈도순)
- [ ] BuildKit 캐시 마운트 활용

### 보안
- [ ] 논루트 유저로 실행
- [ ] 태그 버전 명시 (latest 금지)
- [ ] 취약점 스캔
- [ ] 시크릿 이미지에 포함 X

### 빌드
- [ ] 태그에 버전/커밋 포함
- [ ] Health check 설정
- [ ] 리소스 제한 설정

### Go 특화
- [ ] `CGO_ENABLED=0` (정적 빌드)
- [ ] `-ldflags="-w -s"` (크기 최적화)
- [ ] scratch 또는 distroless 사용

### Java 특화
- [ ] JRE 이미지 사용 (JDK X)
- [ ] Spring Boot layered JAR 활용
- [ ] JVM 메모리 설정 (`-XX:MaxRAMPercentage`)
- [ ] 필요시 Native Image 검토
