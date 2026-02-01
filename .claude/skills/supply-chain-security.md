# Supply Chain Security 가이드

SBOM, SLSA, Sigstore를 활용한 소프트웨어 공급망 보안

## Quick Reference (결정 트리)

```
Supply Chain 보안 단계?
    │
    ├─ 1단계: 투명성 ─────────> SBOM 생성
    │       │
    │       ├─ Syft ──────────> 컨테이너/소스 스캔
    │       └─ Trivy ─────────> 취약점 + SBOM
    │
    ├─ 2단계: 서명 ───────────> Sigstore/Cosign
    │       │
    │       ├─ Keyless ───────> OIDC (GitHub/GitLab)
    │       └─ Key-based ─────> HSM/KMS
    │
    ├─ 3단계: 출처 증명 ──────> SLSA Provenance
    │       │
    │       └─ in-toto ───────> 빌드 증명
    │
    └─ 4단계: 정책 적용 ──────> Admission Control
            │
            ├─ Kyverno ───────> 서명 검증
            └─ Gatekeeper ────> OPA 정책
```

---

## CRITICAL: SLSA 레벨

| Level | 요구사항 | 보장 |
|-------|----------|------|
| **L0** | 없음 | 없음 |
| **L1** | Provenance 존재 | 패키지가 어떻게 빌드되었는지 문서화 |
| **L2** | 서명된 Provenance | 신뢰할 수 있는 빌드 서비스에서 생성 |
| **L3** | 검증된 소스, 격리 빌드 | 빌드 프로세스 변조 방지 |

### 규제 요건

| 규제 | 지역 | 요구사항 |
|------|------|----------|
| EO 14028 | 미국 | SBOM 제출 필수 |
| Cyber Resilience Act | EU | 출처 증명 의무화 |
| NIST SSDF | 미국 | 보안 개발 프레임워크 준수 |

---

## SBOM (Software Bill of Materials)

### 포맷 비교

| 포맷 | 장점 | 사용 |
|------|------|------|
| **SPDX 3.0** | ISO 표준, 법적 준수 | 규제 제출 |
| **CycloneDX** | 보안 특화, VEX 지원 | 취약점 관리 |

### Syft로 SBOM 생성

```bash
# 컨테이너 이미지 스캔
syft packages myimage:latest -o spdx-json > sbom.spdx.json

# 소스 디렉토리 스캔
syft dir:./src -o cyclonedx-json > sbom.cdx.json

# OCI 레지스트리에 SBOM 첨부
syft packages myimage:latest -o spdx-json | \
  cosign attach sbom --sbom /dev/stdin myimage:latest
```

### Trivy로 SBOM + 취약점 스캔

```bash
# SBOM 생성
trivy image --format spdx-json -o sbom.json myimage:latest

# SBOM에서 취약점 스캔
trivy sbom sbom.json

# CI 통합 (CRITICAL/HIGH 발견 시 실패)
trivy image --exit-code 1 --severity CRITICAL,HIGH myimage:latest
```

### GitHub Actions 통합

```yaml
name: SBOM Generation
on: [push]

jobs:
  sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.IMAGE_NAME }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.spdx.json
```

---

## Sigstore / Cosign

### Keyless 서명 (권장)

```bash
# OIDC 기반 keyless 서명
cosign sign ghcr.io/myorg/myimage:latest

# 브라우저에서 OIDC 인증 수행
# 인증서가 Fulcio에서 발급되고 Rekor에 기록됨

# 서명 검증
cosign verify ghcr.io/myorg/myimage:latest \
  --certificate-identity=user@example.com \
  --certificate-oidc-issuer=https://github.com/login/oauth
```

### CI/CD Keyless 서명

```yaml
# GitHub Actions
name: Sign Image
on:
  push:
    branches: [main]

jobs:
  sign:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # OIDC 토큰 필요
      packages: write
    steps:
      - uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}:${{ github.sha }}

      - name: Sign Image (Keyless)
        run: |
          cosign sign --yes ghcr.io/${{ github.repository }}:${{ github.sha }}
        env:
          COSIGN_EXPERIMENTAL: 1
```

### Key 기반 서명 (오프라인 환경)

```bash
# 키 쌍 생성
cosign generate-key-pair

# 서명
cosign sign --key cosign.key myimage:latest

# 검증
cosign verify --key cosign.pub myimage:latest
```

---

## SLSA Provenance

### GitHub Actions으로 SLSA L3 달성

```yaml
name: SLSA Build
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4

      - name: Build Image
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

  provenance:
    needs: build
    permissions:
      actions: read
      id-token: write
      packages: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.1.0
    with:
      image: ghcr.io/${{ github.repository }}
      digest: ${{ needs.build.outputs.digest }}
    secrets:
      registry-username: ${{ github.actor }}
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### Tekton Chains (Kubernetes CI)

```yaml
# Tekton Chains 설치
kubectl apply -f https://storage.googleapis.com/tekton-releases/chains/latest/release.yaml

# Chains 설정 (cosign 서명 + SLSA provenance)
kubectl patch configmap chains-config -n tekton-chains -p '
{
  "data": {
    "artifacts.taskrun.format": "slsa/v1",
    "artifacts.taskrun.storage": "oci",
    "artifacts.oci.storage": "oci",
    "signers.x509.fulcio.enabled": "true",
    "transparency.enabled": "true"
  }
}'
```

---

## Kubernetes 정책 적용

### Kyverno 서명 검증

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  background: false
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

### Kyverno SBOM 검증

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-sbom
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-sbom
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "*"
          attestations:
            - type: https://spdx.dev/Document
              conditions:
                - all:
                    - key: "{{ creationInfo.creators[] }}"
                      operator: AnyIn
                      value: ["Tool: syft-*", "Tool: trivy-*"]
```

### OPA Gatekeeper

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredigestsignature
spec:
  crd:
    spec:
      names:
        kind: K8sRequireDigestSignature
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredigestsignature

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not contains(container.image, "@sha256:")
          msg := sprintf("Container %v must use image digest", [container.name])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireDigestSignature
metadata:
  name: require-digest
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
```

---

## 전체 파이프라인 예시

```yaml
name: Secure Supply Chain Pipeline
on:
  push:
    branches: [main]

env:
  IMAGE: ghcr.io/${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4

      # 1. 빌드
      - name: Build Image
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ env.IMAGE }}:${{ github.sha }}

      # 2. SBOM 생성
      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.IMAGE }}:${{ github.sha }}
          format: spdx-json
          output-file: sbom.spdx.json

      # 3. 취약점 스캔
      - name: Scan Vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE }}:${{ github.sha }}
          exit-code: 1
          severity: CRITICAL,HIGH

      # 4. 이미지 서명 (Keyless)
      - name: Sign Image
        uses: sigstore/cosign-installer@v3
      - run: cosign sign --yes ${{ env.IMAGE }}@${{ steps.build.outputs.digest }}

      # 5. SBOM 첨부
      - name: Attach SBOM
        run: cosign attach sbom --sbom sbom.spdx.json ${{ env.IMAGE }}@${{ steps.build.outputs.digest }}

  # 6. SLSA Provenance 생성
  provenance:
    needs: build
    permissions:
      actions: read
      id-token: write
      packages: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.1.0
    with:
      image: ${{ needs.build.env.IMAGE }}
      digest: ${{ needs.build.outputs.digest }}
```

---

## Anti-Patterns

| 실수 | 문제 | 해결 |
|------|------|------|
| 태그로 서명 | 변조 가능 | digest로 서명 |
| SBOM 미생성 | 규제 미준수 | CI에서 자동 생성 |
| 서명 검증 미적용 | 무의미한 서명 | Admission 정책 |
| 장기 키 사용 | 키 유출 위험 | Keyless 채택 |
| 수동 SBOM | 누락/불일치 | 자동화 파이프라인 |

---

## 체크리스트

### SLSA Level 1
- [ ] 빌드 스크립트 버전 관리
- [ ] SBOM 생성 자동화
- [ ] Provenance 문서화

### SLSA Level 2
- [ ] Sigstore로 서명
- [ ] Rekor 투명성 로그 기록
- [ ] 신뢰할 수 있는 빌드 서비스 (GitHub Actions/Tekton)

### SLSA Level 3
- [ ] 소스 검증 (signed commits)
- [ ] 격리된 빌드 환경
- [ ] Kubernetes Admission 정책 적용

**관련 agent**: `security-scanner`
**관련 skill**: `/k8s-security`

---

---

## SBOM 자동화 & EU CRA 컴플라이언스

### EU Cyber Resilience Act (CRA) 요구사항

```
EU CRA 컴플라이언스 타임라인:
    |
    2024 ------> CRA 최종 승인
    |
    2025 ------> 전환 기간 시작
    |
    2026-2027 -> 의무화 시작
    |
    요구사항:
        +-- SBOM 제공 의무
        +-- 취약점 공개 의무 (24시간 내)
        +-- 보안 업데이트 제공 (5년+)
        +-- CE 마킹 요구
```

### SBOM 포맷 비교 상세

| 항목 | SPDX 3.0 | CycloneDX 1.6 |
|------|----------|---------------|
| **표준화** | ISO/IEC 5962:2021 | OWASP 표준 |
| **주요 용도** | 라이선스 컴플라이언스 | 보안/취약점 관리 |
| **VEX 지원** | 제한적 | 네이티브 |
| **Attestation** | 별도 | 내장 |
| **EU CRA** | 인정 | 인정 |
| **도구 생태계** | 넓음 | 보안 특화 |

### Syft SBOM 생성 자동화

```yaml
# .github/workflows/sbom-pipeline.yaml
name: SBOM Generation Pipeline

on:
  push:
    branches: [main]
  release:
    types: [published]

env:
  IMAGE: ghcr.io/${{ github.repository }}

jobs:
  build-and-sbom:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      id-token: write
      security-events: write

    steps:
      - uses: actions/checkout@v4

      - name: Build Image
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ env.IMAGE }}:${{ github.sha }}

      # SPDX SBOM (라이선스 컴플라이언스)
      - name: Generate SPDX SBOM
        run: |
          syft packages ${{ env.IMAGE }}:${{ github.sha }} \
            -o spdx-json=sbom-spdx.json \
            --source-name="${{ github.repository }}" \
            --source-version="${{ github.sha }}"

      # CycloneDX SBOM (보안 분석)
      - name: Generate CycloneDX SBOM
        run: |
          syft packages ${{ env.IMAGE }}:${{ github.sha }} \
            -o cyclonedx-json=sbom-cyclonedx.json

      # SBOM 서명
      - name: Sign SBOM
        run: |
          cosign sign-blob --yes \
            --output-signature sbom-spdx.json.sig \
            --output-certificate sbom-spdx.json.crt \
            sbom-spdx.json

      # SBOM을 이미지에 첨부
      - name: Attach SBOM to Image
        run: |
          cosign attach sbom \
            --sbom sbom-spdx.json \
            ${{ env.IMAGE }}@${{ steps.build.outputs.digest }}

      # 취약점 스캔 (SBOM 기반)
      - name: Vulnerability Scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'sbom'
          scan-ref: 'sbom-cyclonedx.json'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      # GitHub Security에 결과 업로드
      - name: Upload to Security Tab
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      # SBOM 아티팩트 저장
      - name: Upload SBOM Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: sbom-${{ github.sha }}
          path: |
            sbom-spdx.json
            sbom-spdx.json.sig
            sbom-cyclonedx.json
          retention-days: 90

      # 릴리즈에 SBOM 첨부
      - name: Attach to Release
        if: github.event_name == 'release'
        uses: softprops/action-gh-release@v1
        with:
          files: |
            sbom-spdx.json
            sbom-cyclonedx.json
```

### SBOM 중앙 저장소

```yaml
# SBOM 저장소 구성
apiVersion: v1
kind: ConfigMap
metadata:
  name: sbom-config
  namespace: security
data:
  config.yaml: |
    storage:
      type: s3
      bucket: company-sbom-repository
      region: ap-northeast-2
      prefix: sboms/

    retention:
      days: 365  # EU CRA 요구사항

    indexing:
      # 빠른 검색을 위한 인덱싱
      fields:
        - name
        - version
        - purl
        - license
        - vulnerabilities

    notifications:
      # 새 취약점 발견 시 알림
      onVulnerability:
        slack: "#security-alerts"
        severity: ["critical", "high"]
```

### VEX (Vulnerability Exploitability eXchange)

```json
// vex-statement.json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://example.com/vex/2024/001",
  "author": "security@example.com",
  "timestamp": "2024-01-15T10:00:00Z",
  "version": 1,
  "statements": [
    {
      "vulnerability": {
        "@id": "https://nvd.nist.gov/vuln/detail/CVE-2024-1234"
      },
      "products": [
        {
          "@id": "pkg:docker/myorg/myapp@1.0.0"
        }
      ],
      "status": "not_affected",
      "justification": "vulnerable_code_not_present",
      "statement": "이 취약점은 OpenSSL 3.0에 영향을 주지만, 우리 이미지는 1.1.1을 사용합니다."
    },
    {
      "vulnerability": {
        "@id": "https://nvd.nist.gov/vuln/detail/CVE-2024-5678"
      },
      "products": [
        {
          "@id": "pkg:docker/myorg/myapp@1.0.0"
        }
      ],
      "status": "fixed",
      "statement": "버전 1.0.1에서 수정됨"
    }
  ]
}
```

### SBOM 검증 정책

```yaml
# Kyverno SBOM 검증 정책
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-valid-sbom
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-sbom-exists
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
                    # SBOM이 최근 30일 이내 생성
                    - key: "{{ creationInfo.created }}"
                      operator: NotEquals
                      value: ""

    - name: check-critical-vulnerabilities
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestations:
            - type: https://cosign.sigstore.dev/attestation/vuln/v1
              conditions:
                - all:
                    # Critical 취약점 없음
                    - key: "{{ scanner.result.criticalCount }}"
                      operator: Equals
                      value: 0
```

### 자동 SBOM 갱신 파이프라인

```yaml
# .github/workflows/sbom-refresh.yaml
name: SBOM Refresh

on:
  schedule:
    - cron: '0 0 * * *'  # 매일 자정
  workflow_dispatch:

jobs:
  refresh-sbom:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        image:
          - myorg/app-a:latest
          - myorg/app-b:latest
          - myorg/app-c:latest

    steps:
      - name: Generate Fresh SBOM
        run: |
          syft packages ${{ matrix.image }} \
            -o spdx-json=sbom.json

      - name: Scan for New Vulnerabilities
        run: |
          grype sbom:sbom.json \
            --output json \
            --file vulns.json

      - name: Check for Changes
        id: diff
        run: |
          # 이전 SBOM과 비교
          aws s3 cp s3://sbom-repo/${{ matrix.image }}/latest.json previous.json || true
          if ! diff -q sbom.json previous.json > /dev/null 2>&1; then
            echo "changed=true" >> $GITHUB_OUTPUT
          fi

      - name: Upload and Notify
        if: steps.diff.outputs.changed == 'true'
        run: |
          # 새 SBOM 업로드
          aws s3 cp sbom.json s3://sbom-repo/${{ matrix.image }}/latest.json

          # 슬랙 알림
          curl -X POST $SLACK_WEBHOOK \
            -H 'Content-type: application/json' \
            -d "{\"text\": \"SBOM updated for ${{ matrix.image }}\"}"
```

---

## SBOM 자동화 체크리스트

### 생성
- [ ] CI/CD에 Syft 통합
- [ ] SPDX + CycloneDX 양쪽 생성
- [ ] SBOM 서명 (Cosign)
- [ ] 이미지에 SBOM 첨부

### 저장
- [ ] 중앙 SBOM 저장소 구축
- [ ] 보존 기간 설정 (1년+)
- [ ] 버전별 SBOM 관리
- [ ] 검색 인덱싱

### 검증
- [ ] Kubernetes Admission 정책
- [ ] 취약점 스캔 연동
- [ ] VEX 문서 관리

### 컴플라이언스
- [ ] EU CRA 요구사항 검토
- [ ] 취약점 공개 프로세스
- [ ] 고객 SBOM 제공 절차

## Sources

- [Sigstore Documentation](https://docs.sigstore.dev/)
- [SLSA Framework](https://slsa.dev/)
- [OpenSSF Supply Chain Security](https://openssf.org/blog/2024/02/16/scaling-up-supply-chain-security-implementing-sigstore-for-seamless-container-image-signing/)
- [Kyverno Image Verification](https://kyverno.io/docs/writing-policies/verify-images/)
- [DevSecOps Trends 2026](https://www.practical-devsecops.com/devsecops-trends-2026/)
- [Chainguard SLSA Guide](https://edu.chainguard.dev/compliance/slsa/what-is-slsa/)
- [EU Cyber Resilience Act](https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act)
- [SBOM Guide](https://devdiligent.com/blog/future-open-source-security-devsecops-sbom-2026/)
- [OpenVEX](https://openvex.dev/)
