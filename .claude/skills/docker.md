# Docker & Dockerfile Patterns

Dockerfile 최적화, 멀티스테이지 빌드, Go/Java 컨테이너 패턴

## Quick Reference (결정 트리)

```
베이스 이미지 선택
    │
    ├─ Go ──────────> scratch (12MB) 또는 distroless
    │
    └─ Java ────────> eclipse-temurin:21-jre-alpine
                      └─ 빠른 시작 필요 ──> GraalVM Native

빌드 최적화
    │
    ├─ 캐시 ────────> BuildKit --mount=type=cache
    │
    └─ 이미지 크기 ──> 멀티스테이지 + .dockerignore
```

---

## CRITICAL: 멀티스테이지 빌드

**IMPORTANT**: 반드시 멀티스테이지 사용 (이미지 크기 90% 감소)

| | 단일 스테이지 | 멀티스테이지 |
|---|-------------|-------------|
| Go | ~800MB | ~12MB |
| Java | ~600MB | ~150MB |

---

## Go Dockerfile (Production-Ready)

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app
COPY go.mod go.sum ./

# CRITICAL: BuildKit 캐시 (12배 빌드 속도)
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /app/server ./cmd/api

# scratch = 0MB 베이스 (보안 최우선)
FROM scratch
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /etc/passwd /etc/passwd
USER nobody
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### Go 빌드 옵션

| 옵션 | 설명 |
|------|------|
| `CGO_ENABLED=0` | 순수 Go (C 라이브러리 불필요) |
| `-ldflags="-w -s"` | 디버그 정보 제거 (30% 감소) |

### 베이스 이미지 비교

| 이미지 | 크기 | 쉘 | 용도 |
|--------|------|-----|------|
| `scratch` | 0MB | ❌ | 프로덕션 (보안 최우선) |
| `distroless` | 2MB | ❌ | 프로덕션 |
| `alpine` | 5MB | ✅ | 디버깅 필요 시 |

---

## Java/Spring Boot Dockerfile

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app
COPY gradle gradle
COPY gradlew build.gradle.kts settings.gradle.kts ./

RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew dependencies --no-daemon

COPY src src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew bootJar --no-daemon -x test

# Spring Boot 3+ 레이어 추출
RUN java -Djarmode=layertools -jar build/libs/*.jar extract

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
WORKDIR /app

# 레이어 순서 (변경 빈도 낮은 것 먼저)
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/snapshot-dependencies/ ./
COPY --from=builder /app/application/ ./

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
```

### JVM vs Native

| | JVM | Native (GraalVM) |
|---|-----|------------------|
| 시작 시간 | ~2초 | ~50ms |
| 메모리 | ~300MB | ~50MB |
| 빌드 시간 | ~30초 | ~5분 |
| 용도 | 일반 서비스 | 서버리스 |

### GraalVM Native Image Dockerfile

```dockerfile
FROM ghcr.io/graalvm/graalvm-community:21 AS builder
WORKDIR /app
COPY gradle gradle
COPY gradlew build.gradle.kts settings.gradle.kts ./
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew dependencies --no-daemon
COPY src src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew nativeCompile --no-daemon  # 3-10분 소요

FROM gcr.io/distroless/base-debian12
COPY --from=builder /app/build/native/nativeCompile/app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
```

---

## 레이어 최적화

**IMPORTANT**: 변경 빈도 낮은 것 → 높은 것 순서

```dockerfile
# 1. 시스템 패키지 (거의 안 변함)
RUN apt-get update && apt-get install -y ...

# 2. 의존성 (가끔 변함)
COPY go.mod go.sum ./
RUN go mod download

# 3. 소스 코드 (자주 변함)
COPY . .
RUN go build
```

### .dockerignore

```
.git
.idea
.vscode
bin/
build/
target/
*_test.go
Dockerfile*
.env
*.log
```

---

## 보안 Best Practices

```dockerfile
# 1. 논루트 유저
RUN addgroup -S app && adduser -S app -G app
USER app

# 2. 태그 명시 (latest 금지)
FROM golang:1.23-alpine  # ✅
FROM golang:latest       # ❌
```

### 시크릿 처리

```dockerfile
# Bad: 이미지에 포함
COPY .env /app/.env

# Good: 런타임 주입
# docker run -e DATABASE_URL=... myapp

# Good: BuildKit 시크릿
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm install
```

---

## Docker Compose

```yaml
services:
  app:
    build:
      context: .
      target: builder  # 개발용
    volumes:
      - .:/app
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user"]
      interval: 5s
      retries: 5
```

---

## 멀티 플랫폼 빌드

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:latest --push .
```

---

## Anti-Patterns

| 실수 | 올바른 방법 |
|------|------------|
| `FROM ubuntu` | `FROM ubuntu:22.04` (태그 명시) |
| `latest` 태그 | 구체적 버전 |
| Root로 실행 | `USER nobody` |
| 빌드 도구 포함 | 멀티스테이지 분리 |
| `COPY . .` 먼저 | 의존성 파일 먼저 |
| apt 캐시 남김 | `rm -rf /var/lib/apt/lists/*` |

---

## 체크리스트

### 이미지 최적화
- [ ] 멀티스테이지 빌드
- [ ] 적절한 베이스 이미지
- [ ] .dockerignore 설정
- [ ] 레이어 순서 최적화
- [ ] BuildKit 캐시 활용

### 보안
- [ ] 논루트 유저
- [ ] 태그 버전 명시
- [ ] 시크릿 이미지에 포함 X

### Go 특화
- [ ] `CGO_ENABLED=0`
- [ ] `-ldflags="-w -s"`
- [ ] scratch/distroless 사용

### Java 특화
- [ ] JRE 이미지 (JDK X)
- [ ] Spring Boot layered JAR
- [ ] `-XX:MaxRAMPercentage`
