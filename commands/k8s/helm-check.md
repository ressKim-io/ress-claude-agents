# Helm Chart Validator

Helm chart의 best practice를 검증합니다.

## Contract

| Aspect | Description |
|--------|-------------|
| Input | Helm chart 디렉토리 |
| Output | 검증 리포트 및 개선 제안 |
| Required Tools | helm |
| Verification | `helm lint charts/` 통과 |

## Checklist

### Chart.yaml
- [ ] apiVersion: v2
- [ ] version: SemVer
- [ ] appVersion 존재
- [ ] description 존재

### values.yaml
- [ ] podSecurityContext 기본값
- [ ] securityContext 기본값
- [ ] resources 기본값
- [ ] image.tag (latest 아님)

### templates/
- [ ] _helpers.tpl 정의 (name, fullname, labels)
- [ ] securityContext 적용
- [ ] resources 적용
- [ ] probes 정의

### NOTES.txt
- [ ] 설치 후 안내 제공

## Output Format

```markdown
## Helm Chart Validation Report

### Chart: myapp

#### Critical Issues
- [values.yaml] securityContext 기본값 누락

#### Recommendations
1. values.yaml에 securityContext 추가
2. 모든 컨테이너에 probes 추가
```

## Usage

```
/helm-check charts/myapp/     # 특정 차트
/helm-check                   # 현재 디렉토리
/helm-check --fix             # 자동 수정
```

## Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `command not found: helm` | Helm 미설치 | `brew install helm` 또는 공식 스크립트로 설치 |
| `helm lint` 실패 | 템플릿 문법 오류 | `helm template --debug`로 상세 에러 확인 |
| values 파일 인식 안됨 | 파일 경로 오류 | `-f values.yaml` 옵션으로 명시적 지정 |
| Chart.yaml 버전 에러 | apiVersion 불일치 | `apiVersion: v2` (Helm 3) 확인 |
| 의존성 차트 다운로드 실패 | 저장소 미등록 | `helm repo add` 후 `helm dependency update` |
| `NOTES.txt` 렌더링 에러 | 템플릿 변수 오류 | `.Values` 참조 경로 확인 |

## Best Practices

### Helm Lint Integration

```bash
helm lint charts/myapp/
helm template myapp charts/myapp/ --debug
```
