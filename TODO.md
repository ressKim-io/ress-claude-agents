# TODO - DevOps/SRE Skills 로드맵

## 개요

현재 skills (60개) 기반으로 추가 필요한 영역 정리.

---

## 🔴 높음 (바로 필요)

### 1. SRE - SLI/SLO 정의
- [x] `sre-sli-slo.md` 작성 ✅
- SLI (Service Level Indicator) 정의
- SLO (Service Level Objective) 설정
- 에러 버짓 계산
- 알림 기준 설정

### 2. CI/CD & DevSecOps
- [x] `cicd-devsecops.md` 작성 ✅
- GitHub Actions / Jenkins 파이프라인
- Kyverno 정책 (Policy as Code)
- Trivy (컨테이너 취약점 스캔)
- SonarQube (코드 품질)

### 3. K8S Autoscaling (KEDA)
- [x] `k8s-autoscaling.md` 작성 ✅
- HPA (Horizontal Pod Autoscaler)
- VPA (Vertical Pod Autoscaler)
- KEDA (이벤트 기반 스케일링)
- Karpenter (노드 오토스케일링)
- Kafka 연동 스케일링

### 4. GitOps (ArgoCD)
- [x] `gitops-argocd.md` 작성 ✅
- ArgoCD 설정 및 App of Apps
- ApplicationSet (멀티 클러스터/환경)
- Kustomize 패턴
- Umbrella Helm Chart
- Sync 전략

### 5. 배포 전략
- [x] `deployment-strategies.md` 작성 ✅
- 카나리 배포 (Argo Rollouts)
- Blue-Green 배포
- Rolling Update
- A/B 테스트 (프론트/기획 협업)

---

## 🟡 중간 (곧 필요)

### 6. K8S Scheduling
- [x] `k8s-scheduling.md` 작성 ✅
- Node Affinity / Anti-Affinity
- Pod Affinity
- Taint & Toleration
- TopologySpreadConstraints
- 노드 배치 전략

### 7. 부하 테스트
- [x] `load-testing.md` 작성 ✅
- K6 스크립트 작성 (시나리오, Thresholds)
- K6 Operator (K8S 분산 테스트)
- nGrinder 설정
- 트래픽 버티는 거 증명
- 결과 시각화 및 보고서

### 8. Kafka
- [x] `kafka.md` 작성 ✅
- Strimzi Operator (Kafka 클러스터)
- Producer/Consumer 패턴 (Go, Java)
- KEDA 연동 (Lag 기반 스케일링)
- 모니터링 (Kafka Exporter)

### 9. Istio Security
- [x] `istio-security.md` 작성 ✅
- JWT 인증 (RequestAuthentication)
- mTLS 강제 (PeerAuthentication)
- AuthorizationPolicy (통신 허용)
- Rate Limiting (EnvoyFilter)
- Zero Trust 구현

### 10. FinOps
- [x] `finops.md` 작성 ✅
- 클라우드 비용 최적화
- Kubecost 설치 및 설정
- 리소스 Right-sizing (VPA)
- Spot Instance 활용 (Karpenter)
- Savings Plans 전략
- 비용 모니터링 대시보드

---

## 🟢 낮음 (나중에)

### 11. Chaos Engineering
- [x] `chaos-engineering.md` 작성 ✅
- LitmusChaos 설치 및 설정
- ChaosEngine / ChaosExperiment CRDs
- Pod-Delete, Container-Kill, Network-Chaos
- Probes (HTTP, Prometheus, Command)
- GameDay 시나리오

### 12. AWS EKS
- [x] `aws-eks.md` 작성 ✅
- EKS 클러스터 구성 (Terraform)
- VPC/Subnet 설계 (3-Tier)
- IAM Role for Service Account (IRSA)
- Add-ons 관리 (vpc-cni, coredns, kube-proxy)
- Karpenter 노드 프로비저닝

### 13. Disaster Recovery
- [x] `disaster-recovery.md` 작성 ✅
- DR 전략 (Active-Passive, Active-Active, Pilot Light)
- RTO/RPO 정의
- Velero 백업/복구
- 멀티 클러스터 DR
- DR 테스트 자동화

### 14. Alerting & Discord
- [x] `alerting-discord.md` 작성 ✅
- AlertManager 설정
- Discord 웹훅 연동 (v0.25+ 네이티브)
- PrometheusRule (Pod/Node/SLO 알림)
- 알림 라우팅 (팀별, 시간대별)
- Silencing 절차

---

## 기존 Skills 보강

### istio-core.md
- [x] mTLS 강제 설정 추가 ✅
- [x] PeerAuthentication 예제 ✅
- STRICT/PERMISSIVE 모드
- 포트별 예외 설정 (메트릭)
- mTLS 마이그레이션 단계

### k8s-security.md
- [x] Kyverno 정책 예제 추가 ✅
- [x] Trivy 스캔 연동 ✅
- 이미지 레지스트리 제한
- 리소스 제한 필수
- 필수 라벨 강제
- CI/CD 통합 (GitHub Actions)

### monitoring-troubleshoot.md
- [x] Pod 알림 설정 ✅
- [x] Discord 웹훅 예제 ✅
- PrometheusRule CRD
- AlertManager Discord 설정

---

## 추가 작업

### 인프라
- [ ] CloudFront Pro 검토
- [x] EKS 구성 → `aws-eks.md` 참조

### 협업
- [ ] 백엔드팀 소통 - 트래픽 시각자료
- [ ] 프론트/기획 - A/B 테스트 논의

### 보안
- [ ] 내부 K8S 보안검사
- [x] DR 사이버보안 대응 → `disaster-recovery.md` 참조

---

## 진행 상황

| 카테고리 | 전체 | 완료 | 진행률 |
|---------|------|------|--------|
| 높음 (신규) | 5 | 5 | 100% |
| 중간 (신규) | 5 | 5 | 100% |
| 낮음 (신규) | 4 | 4 | 100% |
| 기존 보강 | 3 | 3 | 100% |
| **합계** | **17** | **17** | **100%** |

---

## 참고

### 현재 커버되는 영역 (60 skills)
- Istio (9 files) - core, gateway, observability, traffic, security
- 모니터링 (4 files) - metrics, logs, grafana, troubleshoot
- 로깅 (4 files) - loki, fluentbit, opensearch
- K8S (8 files) - security, helm, autoscaling, scheduling, traffic
- Go/Spring 개발 (13 files)
- Terraform (2 files)
- DevOps/SRE (12 files) - argocd, deployment, chaos, dr, alerting, finops, load-testing
- 기타 (8 files) - kafka, aws-eks, docker 등

### 완료된 작업 (2026-01-27)
- 신규 12개 skill 파일 생성
- 기존 3개 skill 파일 보강
- 총 skills: 48개 → 60개

### 향후 검토 사항
- CloudFront Pro 도입
- 팀 협업 문서화
- 내부 보안 검사 자동화
