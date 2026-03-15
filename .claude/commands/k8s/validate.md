# Kubernetes Manifest Validator

Kubernetes manifest의 보안 및 best practice를 검증합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | YAML manifest 파일 또는 디렉토리 |
| Output | 검증 리포트 (심각도별 이슈 목록) |
| Required Tools | kubectl (optional), kube-linter (optional) |
| Verification | 모든 Critical 이슈 해결 |

## Checklist

### Critical (즉시 수정 필요)
- [ ] `runAsNonRoot: true` 설정
- [ ] `allowPrivilegeEscalation: false` 설정
- [ ] `readOnlyRootFilesystem: true` 설정
- [ ] `capabilities.drop: ["ALL"]` 설정
- [ ] `privileged: true` 사용 여부
- [ ] `latest` 태그 사용 여부

### High (배포 전 수정 권장)
- [ ] resources.requests/limits 설정
- [ ] livenessProbe/readinessProbe 설정
- [ ] hostNetwork/hostPID/hostIPC 사용 여부

### Medium (개선 권장)
- [ ] app.kubernetes.io/* 라벨
- [ ] 기본 ServiceAccount 사용 여부
- [ ] PDB 정의 여부 (replicas > 1)

## Output Format

```markdown
## Manifest Validation Report

### File: deployment.yaml

#### Critical Issues
- [Line 15] `runAsNonRoot` 미설정
  수정: spec.securityContext.runAsNonRoot: true 추가

#### Summary
- Critical: 2
- High: 1
- Medium: 0
```

## Usage

```
/validate                    # 모든 YAML 검증
/validate deployment.yaml    # 특정 파일
/validate charts/myapp/      # Helm chart
/validate --fix              # 자동 수정
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `command not found: kubectl` | kubectl 미설치 | `brew install kubectl` 또는 공식 방법으로 설치 |
| YAML 파싱 에러 | 들여쓰기 또는 문법 오류 | `yamllint`로 문법 검사, 스페이스/탭 혼용 확인 |
| `kubectl apply --dry-run` 실패 | 클러스터 연결 문제 | `--dry-run=client` 사용 (서버 불필요) |
| kube-linter 설치 안됨 | 선택적 도구 | `brew install kube-linter` 또는 바이너리 다운로드 |
| 이미지 태그 검증 실패 | latest 태그 사용 | 명시적 버전 태그 (예: `v1.2.3`) 사용 |
| PDB 검증 오류 | replicas=1에서 PDB 불필요 | replicas > 1인 경우만 PDB 권장 |
