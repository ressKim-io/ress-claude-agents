# Supply Chain Security 가이드

SBOM, 이미지 서명 (Cosign), SLSA Framework, Kyverno 이미지 검증

## Quick Reference (결정 트리)

```
공급망 보안 도구 선택?
    │
    ├─ SBOM 생성 ─────────> Syft (CLI) 또는 Trivy (통합)
    │       │
    │       ├─ SPDX 포맷 → 규정 준수 (ISO/IEC 5962)
    │       └─ CycloneDX → 보안 분석 최적화
    │
    ├─ 이미지 서명 ───────> Cosign (Keyless/OIDC 추천)
    │       │
    │       ├─ CI 환경 → Keyless (OIDC Provider)
    │       └─ 에어갭 환경 → Key-pair 방식
    │
    ├─ 정책 검증 ─────────> Kyverno verifyImages
    │
    └─ Provenance ───────> SLSA (slsa-verifier)
```

---

## CRITICAL: 공급망 보안 레이어

```
┌─────────────────────────────────────────────────────────────────┐
│                 Software Supply Chain Security                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Source ──> Build ──> Package ──> Deploy ──> Runtime            │
│     │         │          │          │           │               │
│   Code      SLSA       SBOM      Verify      Monitor            │
│  Review   Provenance  Generate   Signature   Admission          │
│   Scan     Level 3    Attach     Kyverno     Runtime            │
│                       Sign                    Policy            │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Trust Chain: Source → Build → Artifact → Registry → K8s │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**핵심 원칙**:
| 원칙 | 설명 |
|------|------|
| **불변성** | 아티팩트는 빌드 후 변경 불가 |
| **추적성** | 모든 컴포넌트의 출처 추적 가능 |
| **검증** | 배포 전 서명 및 정책 검증 |
| **투명성** | SBOM으로 구성요소 공개 |

---

## SBOM (Software Bill of Materials)

### SBOM 포맷 비교

| 포맷 | 장점 | 사용처 |
|------|------|--------|
| **SPDX** | ISO 표준, 라이선스 중심 | 법적 컴플라이언스 |
| **CycloneDX** | 보안 중심, VEX 지원 | 취약점 관리 |

### Syft로 SBOM 생성

```bash
# 이미지 SBOM 생성 (SPDX JSON)
syft myapp:latest -o spdx-json > sbom.spdx.json

# 이미지 SBOM 생성 (CycloneDX)
syft myapp:latest -o cyclonedx-json > sbom.cdx.json

# 디렉토리에서 SBOM 생성
syft dir:./src -o spdx-json > source-sbom.json

# OCI 레지스트리에 SBOM 첨부
syft myapp:latest -o spdx-json | \
  cosign attach sbom --sbom - ghcr.io/myorg/myapp:latest
```

### Trivy로 SBOM 생성

```bash
# Trivy SBOM 생성 (SPDX)
trivy image --format spdx-json -o sbom.spdx.json myapp:latest

# Trivy SBOM 생성 (CycloneDX)
trivy image --format cyclonedx -o sbom.cdx.json myapp:latest

# SBOM 기반 취약점 스캔
trivy sbom sbom.spdx.json
```

### GitHub Actions SBOM 워크플로우

```yaml
# .github/workflows/sbom.yaml
name: SBOM Generation

on:
  push:
    branches: [main]

jobs:
  sbom:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # Keyless signing

    steps:
      - uses: actions/checkout@v4

      - name: Build Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

      - name: Generate SBOM with Syft
        uses: anchore/sbom-action@v0
        with:
          image: ghcr.io/${{ github.repository }}:${{ github.sha }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Attach SBOM to Image
        run: |
          cosign attach sbom \
            --sbom sbom.spdx.json \
            ghcr.io/${{ github.repository }}:${{ github.sha }}

      - name: Upload SBOM as Artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.spdx.json
```

---

## Cosign 이미지 서명

### CRITICAL: Keyless Signing (권장)

```bash
# OIDC 기반 Keyless 서명 (GitHub Actions, GitLab CI 등)
# 별도 키 관리 불필요, Sigstore 인프라 사용
cosign sign --yes ghcr.io/myorg/myapp:v1.0.0

# 서명 검증
cosign verify \
  --certificate-identity-regexp="https://github.com/myorg/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/myorg/myapp:v1.0.0
```

### Key-pair Signing (에어갭 환경)

```bash
# 키 쌍 생성
cosign generate-key-pair

# 이미지 서명
cosign sign --key cosign.key ghcr.io/myorg/myapp:v1.0.0

# 서명 검증
cosign verify --key cosign.pub ghcr.io/myorg/myapp:v1.0.0
```

### GitHub Actions Keyless 서명

```yaml
# .github/workflows/sign.yaml
name: Build and Sign

on:
  push:
    tags: ['v*']

jobs:
  sign:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # OIDC token for keyless signing

    steps:
      - uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}

      - name: Sign Image (Keyless)
        run: |
          cosign sign --yes \
            ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}

      - name: Generate and Attach SBOM
        run: |
          syft ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }} \
            -o spdx-json > sbom.json
          cosign attach sbom \
            --sbom sbom.json \
            ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}

      - name: Sign SBOM
        run: |
          cosign sign --yes \
            --attachment sbom \
            ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
```

### Attestation (증명서)

```bash
# SLSA Provenance attestation 생성
cosign attest --yes \
  --predicate provenance.json \
  --type slsaprovenance \
  ghcr.io/myorg/myapp:v1.0.0

# Attestation 검증
cosign verify-attestation \
  --certificate-identity-regexp="https://github.com/myorg/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --type slsaprovenance \
  ghcr.io/myorg/myapp:v1.0.0
```

---

## SLSA Framework

### SLSA Levels

| Level | 요구사항 | 설명 |
|-------|----------|------|
| **SLSA 1** | 빌드 문서화 | Provenance 존재 |
| **SLSA 2** | 호스티드 빌드 | 신뢰할 수 있는 빌드 환경 |
| **SLSA 3** | 소스 검증 | 변조 불가능한 빌드 |
| **SLSA 4** | 2인 리뷰 | 완전한 소스 무결성 |

### GitHub Actions SLSA 3 달성

```yaml
# .github/workflows/slsa.yaml
name: SLSA Build

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write

    steps:
      - uses: actions/checkout@v4

      - name: Build Image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}

      - name: Generate SLSA Provenance
        uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.0.0
        with:
          image: ghcr.io/${{ github.repository }}
          digest: ${{ steps.build.outputs.digest }}
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.GITHUB_TOKEN }}

      - name: Verify Provenance
        run: |
          slsa-verifier verify-image \
            ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }} \
            --source-uri github.com/${{ github.repository }} \
            --source-tag ${{ github.ref_name }}
```

### Provenance 검증

```bash
# slsa-verifier 설치
go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@latest

# 이미지 Provenance 검증
slsa-verifier verify-image \
  ghcr.io/myorg/myapp:v1.0.0 \
  --source-uri github.com/myorg/myapp \
  --source-tag v1.0.0

# 아티팩트 Provenance 검증
slsa-verifier verify-artifact \
  ./myapp.tar.gz \
  --provenance-path ./provenance.intoto.jsonl \
  --source-uri github.com/myorg/myapp
```

---

## Kyverno 이미지 검증

### CRITICAL: verifyImages 정책

```yaml
# verify-signed-images.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-signed-images
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

### 레지스트리별 검증 정책

```yaml
# multi-registry-verification.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-multi-registry
spec:
  validationFailureAction: Enforce
  rules:
    # 내부 레지스트리 - 키 기반 서명
    - name: verify-internal-images
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "registry.internal.com/*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                      -----END PUBLIC KEY-----

    # GitHub Container Registry - Keyless
    - name: verify-ghcr-images
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

### SBOM 검증 정책

```yaml
# verify-sbom.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-sbom
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-sbom-attestation
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestations:
            - type: https://spdx.dev/Document
              attestors:
                - entries:
                    - keyless:
                        subject: "https://github.com/myorg/*"
                        issuer: "https://token.actions.githubusercontent.com"
              conditions:
                - all:
                    # SBOM에 CRITICAL 취약점이 없어야 함
                    - key: "{{ sbom.packages[?vulnerabilities[?severity=='CRITICAL']] | length(@) }}"
                      operator: Equals
                      value: "0"
```

### Provenance 검증 정책

```yaml
# verify-provenance.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-slsa-provenance
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-slsa-level
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestations:
            - type: https://slsa.dev/provenance/v0.2
              attestors:
                - entries:
                    - keyless:
                        subject: "https://github.com/myorg/*"
                        issuer: "https://token.actions.githubusercontent.com"
              conditions:
                - all:
                    # 신뢰할 수 있는 빌더에서 빌드됨
                    - key: "{{ buildDefinition.buildType }}"
                      operator: Equals
                      value: "https://github.com/slsa-framework/slsa-github-generator/container@v1"
```

---

## Dependency-Track 연동

### 설치 (Helm)

```bash
helm repo add dependency-track https://dependencytrack.github.io/helm-charts
helm install dependency-track dependency-track/dependency-track \
  --namespace dependency-track \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hostname=dependency-track.example.com
```

### CI에서 SBOM 업로드

```yaml
# .github/workflows/dependency-track.yaml
- name: Generate SBOM
  run: |
    syft ghcr.io/${{ github.repository }}:${{ github.sha }} \
      -o cyclonedx-json > sbom.cdx.json

- name: Upload to Dependency-Track
  run: |
    curl -X POST \
      -H "X-Api-Key: ${{ secrets.DEPENDENCY_TRACK_API_KEY }}" \
      -H "Content-Type: application/json" \
      -d @sbom.cdx.json \
      "${{ secrets.DEPENDENCY_TRACK_URL }}/api/v1/bom"
```

### Policy Violation 알림

```yaml
# prometheus-rules.yaml
groups:
  - name: supply-chain-security
    rules:
      - alert: CriticalVulnerabilityFound
        expr: |
          dependency_track_policy_violations{severity="CRITICAL"} > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Critical vulnerability found in {{ $labels.project }}"

      - alert: SBOMStale
        expr: |
          time() - dependency_track_project_last_bom_import > 86400 * 7
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "SBOM not updated for 7 days: {{ $labels.project }}"
```

---

## 완전한 공급망 보안 워크플로우

```yaml
# .github/workflows/supply-chain-security.yaml
name: Supply Chain Security

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-sign-attest:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write

    outputs:
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Install Syft
        uses: anchore/sbom-action/download-syft@v0

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha
            type=ref,event=tag

      # 1. Build and Push
      - name: Build and Push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          provenance: true
          sbom: true

      # 2. Sign Image (Keyless)
      - name: Sign Image
        run: |
          cosign sign --yes \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

      # 3. Generate and Attach SBOM
      - name: Generate SBOM
        run: |
          syft ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }} \
            -o spdx-json > sbom.spdx.json

      - name: Attach SBOM
        run: |
          cosign attach sbom \
            --sbom sbom.spdx.json \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

      # 4. Sign SBOM
      - name: Sign SBOM
        run: |
          cosign sign --yes \
            --attachment sbom \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

      # 5. Scan for Vulnerabilities
      - name: Scan Vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy Results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-results.sarif

  verify:
    needs: build-sign-attest
    runs-on: ubuntu-latest
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Verify Signature
        run: |
          cosign verify \
            --certificate-identity-regexp="https://github.com/${{ github.repository }}/.*" \
            --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build-sign-attest.outputs.digest }}

      - name: Verify SBOM
        run: |
          cosign verify \
            --certificate-identity-regexp="https://github.com/${{ github.repository }}/.*" \
            --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
            --attachment sbom \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build-sign-attest.outputs.digest }}
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 서명 없이 배포 | 변조 감지 불가 | Cosign + Kyverno |
| SBOM 미생성 | 취약점 추적 불가 | 빌드 시 자동 생성 |
| Key 하드코딩 | 키 유출 위험 | Keyless 또는 Secret Manager |
| Audit 모드만 사용 | 정책 우회 가능 | Enforce 모드 전환 |
| 태그 기반 서명 | 태그 변경 시 무효화 | Digest 기반 서명 |
| SBOM 미갱신 | 오래된 취약점 정보 | 빌드마다 갱신 |

---

## 체크리스트

### SBOM
- [ ] Syft 또는 Trivy로 SBOM 생성 자동화
- [ ] SBOM 포맷 선택 (SPDX/CycloneDX)
- [ ] 이미지에 SBOM 첨부
- [ ] Dependency-Track 연동

### 이미지 서명
- [ ] Cosign 설치
- [ ] Keyless 서명 설정 (OIDC)
- [ ] CI/CD에 서명 단계 추가
- [ ] 서명 검증 자동화

### Kyverno 정책
- [ ] verifyImages 정책 적용
- [ ] SBOM attestation 검증
- [ ] Provenance 검증
- [ ] Enforce 모드 활성화

### SLSA
- [ ] SLSA Level 목표 설정
- [ ] Provenance 생성 자동화
- [ ] slsa-verifier로 검증
- [ ] Rekor 투명성 로그 활용

**관련 skill**: `/cicd-devsecops`, `/k8s-security`, `/gitops-argocd`
