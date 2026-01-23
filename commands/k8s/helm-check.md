# Helm Chart Validator

Helm chart의 best practice를 검증합니다.

## Instructions

1. Helm chart 디렉토리를 분석합니다.
2. Chart.yaml, values.yaml, templates/ 검증
3. best practice 위반 사항 보고
4. 개선 제안 제공

## Validation Checklist

### Chart.yaml

#### Required Fields
- [ ] apiVersion: v2
- [ ] name: 차트 이름
- [ ] version: 차트 버전 (SemVer)
- [ ] appVersion: 앱 버전

#### Recommended Fields
- [ ] description: 차트 설명
- [ ] type: application 또는 library
- [ ] maintainers: 관리자 정보
- [ ] keywords: 검색용 키워드

### values.yaml

#### Structure
- [ ] 중첩 구조 일관성 (flat vs nested)
- [ ] 주석으로 각 값 설명
- [ ] 기본값 제공

#### Security Defaults
```yaml
# 필수 기본값
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

# 이미지 설정
image:
  repository: ""
  tag: ""           # latest 아님
  pullPolicy: IfNotPresent

# 리소스 설정 (기본값 제공)
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

#### Required Values
- [ ] image.repository
- [ ] image.tag (latest 아님)
- [ ] resources.requests/limits
- [ ] podSecurityContext
- [ ] securityContext

### templates/

#### _helpers.tpl
- [ ] chart.name 정의
- [ ] chart.fullname 정의
- [ ] chart.labels 정의
- [ ] chart.selectorLabels 정의

#### Deployment/StatefulSet
- [ ] labels 적용 (app.kubernetes.io/*)
- [ ] securityContext 적용
- [ ] resources 적용
- [ ] probes 정의
- [ ] serviceAccountName 설정

#### Service
- [ ] selector가 deployment와 일치
- [ ] port 이름 정의

#### Ingress (있는 경우)
- [ ] TLS 설정 옵션
- [ ] className 설정

### NOTES.txt
- [ ] 설치 후 안내 메시지 제공
- [ ] 접속 방법 안내

## Template Best Practices

### 올바른 패턴
```yaml
# 라벨 적용
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}

# selector
selector:
  matchLabels:
    {{- include "mychart.selectorLabels" . | nindent 6 }}

# 조건부 리소스
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
...
{{- end }}

# 기본값 처리
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

### 피해야 할 패턴
```yaml
# Bad: 하드코딩된 이름
metadata:
  name: myapp

# Good: 템플릿 함수 사용
metadata:
  name: {{ include "mychart.fullname" . }}

# Bad: 조건 없는 선택적 리소스
# Good: {{- if .Values.xxx.enabled }}
```

## Helm Lint Integration

```bash
# 기본 lint
helm lint charts/myapp/

# 값 파일과 함께
helm lint charts/myapp/ -f values-prod.yaml

# 템플릿 렌더링 확인
helm template myapp charts/myapp/ --debug
```

## Output Format

```markdown
## Helm Chart Validation Report

### Chart: myapp

#### Chart.yaml Issues
- [Warning] description 필드 누락
- [Warning] maintainers 필드 누락

#### values.yaml Issues
- [Critical] securityContext 기본값 누락
- [Critical] resources 기본값 누락
- [Warning] 값에 대한 주석 부족

#### templates/ Issues
- [High] deployment.yaml: livenessProbe 누락
- [High] deployment.yaml: readinessProbe 누락
- [Medium] _helpers.tpl: chart.labels 정의 누락

#### Recommendations
1. values.yaml에 securityContext 기본값 추가
2. 모든 컨테이너에 probes 추가
3. NOTES.txt 개선

### Helm Lint Output
[INFO] Chart.yaml: icon is recommended
[WARNING] templates/: directory not found
```

## Usage

```
/helm-check charts/myapp/           # 특정 차트 검증
/helm-check                         # 현재 디렉토리 차트 검증
/helm-check --fix                   # 자동 수정 (가능한 항목)
/helm-check --values values-prod.yaml  # 특정 values로 검증
```
