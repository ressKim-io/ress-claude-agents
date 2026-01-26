# TODO - DevOps/SRE Skills 로드맵

## 개요

현재 skills (46개) 기반으로 추가 필요한 영역 정리.

---

## 🔴 높음 (바로 필요)

### 1. SRE - SLI/SLO 정의
- [x] `sre-sli-slo.md` 작성 ✅
- SLI (Service Level Indicator) 정의
- SLO (Service Level Objective) 설정
- 에러 버짓 계산
- 알림 기준 설정

### 2. CI/CD & DevSecOps
- [ ] `cicd-devsecops.md` 작성
- GitHub Actions / Jenkins 파이프라인
- Kyverno 정책 (Policy as Code)
- Trivy (컨테이너 취약점 스캔)
- SonarQube (코드 품질)

### 3. K8S Autoscaling (KEDA)
- [ ] `k8s-autoscaling.md` 작성
- HPA (Horizontal Pod Autoscaler)
- VPA (Vertical Pod Autoscaler)
- KEDA (이벤트 기반 스케일링)
- Kafka 연동 스케일링

### 4. GitOps (ArgoCD)
- [ ] `gitops-argocd.md` 작성
- ArgoCD 설정 및 App of Apps
- Kustomize 패턴
- Umbrella Helm Chart
- Sync 전략

### 5. 배포 전략
- [ ] `deployment-strategies.md` 작성
- 카나리 배포
- Blue-Green 배포
- Rolling Update
- A/B 테스트 (프론트/기획 협업)

---

## 🟡 중간 (곧 필요)

### 6. K8S Scheduling
- [ ] `k8s-scheduling.md` 작성
- Node Affinity / Anti-Affinity
- Pod Affinity
- Taint & Toleration
- 노드 배치 전략

### 7. 부하 테스트
- [ ] `load-testing.md` 작성
- K6 스크립트 작성
- nGrinder 설정
- 트래픽 버티는 거 증명
- 결과 시각화 및 보고서

### 8. Kafka
- [ ] `kafka.md` 작성
- Kafka 클러스터 설정
- Producer/Consumer 패턴
- KEDA 연동
- 모니터링 (Kafka Exporter)

### 9. Istio Security
- [ ] `istio-security.md` 작성
- JWT 인증
- mTLS 강제 (PeerAuthentication)
- AuthorizationPolicy (통신 허용)
- Rate Limiting (API 속도 제한)

### 10. FinOps
- [ ] `finops.md` 작성
- 클라우드 비용 최적화
- 리소스 Right-sizing
- Spot Instance 활용
- 비용 모니터링 대시보드

---

## 🟢 낮음 (나중에)

### 11. Chaos Engineering
- [ ] `chaos-engineering.md` 작성
- Litmus Chaos
- Chaos Monkey
- GameDay 시나리오
- 복구 검증

### 12. AWS EKS
- [ ] `aws-eks.md` 작성
- EKS 클러스터 구성
- VPC/Subnet 설계
- IAM Role for Service Account (IRSA)
- Add-ons (CoreDNS, kube-proxy, VPC CNI)

### 13. Disaster Recovery
- [ ] `disaster-recovery.md` 작성
- DR 전략 (Active-Passive, Active-Active)
- RTO/RPO 정의
- 백업/복구 절차
- 사이버보안 대응

### 14. Alerting & Discord
- [ ] `alerting-discord.md` 작성
- AlertManager 설정
- Discord 웹훅 연동
- Pod 알림 설정
- 알림 라우팅

---

## 기존 Skills 보강

### istio-core.md
- [ ] mTLS 강제 설정 추가
- [ ] PeerAuthentication 예제

### k8s-security.md
- [ ] Kyverno 정책 예제 추가
- [ ] Trivy 스캔 연동

### monitoring-troubleshoot.md
- [ ] Pod 알림 설정
- [ ] Discord 웹훅 예제

---

## 추가 작업

### 인프라
- [ ] CloudFront Pro 검토
- [ ] EKS 구성

### 협업
- [ ] 백엔드팀 소통 - 트래픽 시각자료
- [ ] 프론트/기획 - A/B 테스트 논의

### 보안
- [ ] 내부 K8S 보안검사
- [ ] DR 사이버보안 대응

---

## 진행 상황

| 카테고리 | 전체 | 완료 | 진행률 |
|---------|------|------|--------|
| 높음 (신규) | 5 | 1 | 20% |
| 중간 (신규) | 5 | 0 | 0% |
| 낮음 (신규) | 4 | 0 | 0% |
| 기존 보강 | 3 | 0 | 0% |
| **합계** | **17** | **1** | **6%** |

---

## 참고

### 현재 커버되는 영역 (46 skills)
- Istio 기본 (8 files)
- 모니터링 (4 files)
- 로깅 (4 files)
- K8S 보안/Helm/트래픽 (5 files)
- Go/Spring 개발 (13 files)
- Terraform (2 files)
- 기타 (10 files)

### 목표
- 신규 14개 skill 추가 → 총 60개 (현재 47개)
- 기존 3개 보강
