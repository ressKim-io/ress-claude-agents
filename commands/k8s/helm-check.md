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

## Best Practices

### Helm Lint Integration

```bash
helm lint charts/myapp/
helm template myapp charts/myapp/ --debug
```
