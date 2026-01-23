# Kubernetes Manifest Validator

Kubernetes manifest의 보안 및 best practice를 검증합니다.

## Instructions

1. 대상 manifest 파일을 분석합니다.
2. 아래 체크리스트에 따라 검증을 수행합니다.
3. 발견된 이슈를 심각도별로 분류하여 보고합니다.
4. 수정 제안을 함께 제공합니다.

## Validation Checklist

### Critical (즉시 수정 필요)

#### Security Context
- [ ] `runAsNonRoot: true` 설정 여부
- [ ] `allowPrivilegeEscalation: false` 설정 여부
- [ ] `readOnlyRootFilesystem: true` 설정 여부
- [ ] `capabilities.drop: ["ALL"]` 설정 여부
- [ ] `privileged: true` 사용 여부 (사용 시 Critical)

#### Image
- [ ] `latest` 태그 사용 여부 (사용 시 Critical)
- [ ] 이미지 태그 누락 여부
- [ ] imagePullPolicy 적절성

#### Secrets
- [ ] 환경변수에 민감 정보 하드코딩 여부
- [ ] Secret을 환경변수 대신 volume mount 사용 권장

### High (배포 전 수정 권장)

#### Resources
- [ ] requests/limits 설정 여부
- [ ] requests = limits 정책 준수 여부
- [ ] 메모리 제한 설정 여부

#### Probes
- [ ] livenessProbe 설정 여부
- [ ] readinessProbe 설정 여부
- [ ] Probe 설정값 적절성

#### Network
- [ ] hostNetwork: true 사용 여부
- [ ] hostPID: true 사용 여부
- [ ] hostIPC: true 사용 여부

### Medium (개선 권장)

#### Labels
- [ ] app.kubernetes.io/name 라벨 여부
- [ ] app.kubernetes.io/version 라벨 여부
- [ ] app.kubernetes.io/component 라벨 여부

#### ServiceAccount
- [ ] 기본 ServiceAccount 사용 여부
- [ ] automountServiceAccountToken 설정 여부

#### Pod Disruption Budget
- [ ] PDB 정의 여부 (replicas > 1인 경우)

### Low (향후 고려)

- [ ] 권장 어노테이션 (owner, description) 여부
- [ ] Pod anti-affinity 설정 (HA 구성)
- [ ] topologySpreadConstraints 설정

## Output Format

```markdown
## Manifest Validation Report

### File: deployment.yaml

#### Critical Issues
- [Line 15] `runAsNonRoot` 미설정
  - 현재: securityContext 없음
  - 수정: spec.securityContext.runAsNonRoot: true 추가

- [Line 22] latest 태그 사용
  - 현재: image: myapp:latest
  - 수정: image: myapp:v1.2.3 (특정 버전 사용)

#### High Priority
- [Line 30] resources.limits 미설정
  - 권장: requests와 동일하게 limits 설정

#### Summary
- Critical: 2
- High: 1
- Medium: 0
- Low: 0
```

## Usage

```
/validate                           # 모든 YAML 파일 검증
/validate deployment.yaml           # 특정 파일 검증
/validate charts/myapp/             # Helm chart 검증
/validate --fix                     # 자동 수정 (가능한 항목만)
```
