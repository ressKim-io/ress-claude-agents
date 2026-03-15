**English** | [한국어](README.ko.md)

# ress-claude-agents

Production-ready agents, skills, and rules for Claude Code.

[![CI](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Quick Start

```bash
git clone https://github.com/ressKim-io/ress-claude-agents.git
cd ress-claude-agents

# Install globally (all projects)
./install.sh --global --all --with-skills

# Or install by role
./install.sh --global --plugin backend-java

# Or install by scenario (NEW)
./install.sh --global --workflow eks-gitops-setup
```

## What's Inside

| | Count | Lines |
|---|---|---|
| Agents | 46 | ~18,700 |
| Skills | 199 | ~75,200 |
| Rules | 9 | ~1,020 |
| Commands | 40 | - |
| Tests | 51 cases | - |
| Plugins | 9 bundles | - |
| Workflows | 7 scenarios | - |
| **Total** | | **91,000+** |

## Agents

46 autonomous AI agents across 10 categories.

| Category | Agents |
|---|---|
| Strategy | `tech-lead`, `product-engineer`, `migration-expert` |
| Frontend | `frontend-expert` |
| DevOps & SRE | `security-scanner`, `k8s-troubleshooter`, `terraform-reviewer`, `incident-responder`, `code-reviewer`, `cost-analyzer`, `finops-advisor`, `otel-expert`, `debugging-expert`, `compliance-auditor` |
| DevOps Reviewers | `k8s-reviewer`, `dockerfile-reviewer`, `cicd-reviewer`, `gitops-reviewer`, `observability-reviewer` |
| Security Reviewers | `k8s-security-reviewer`, `container-security-reviewer`, `cicd-security-reviewer`, `network-security-reviewer` |
| Architecture | `architect-agent`, `saga-agent` |
| Platform & MLOps | `platform-engineer`, `mlops-expert`, `database-expert`, `database-expert-mysql`, `redis-expert` |
| Service Mesh & Messaging | `service-mesh-expert`, `messaging-expert` |
| Language Experts | `go-expert`, `java-expert`, `python-expert` |
| Ticketing & Load Test | `ticketing-expert`, `anti-bot`, `load-tester`, `load-tester-k6`, `load-tester-gatling`, `load-tester-ngrinder` |
| Workflow | `git-workflow`, `ci-optimizer`, `pr-review-bot`, `dev-logger` |

## Skills

198 on-demand knowledge files organized in 17 categories.

| Category | Count | Topics |
|---|---|---|
| Go | 8 | Error handling, Gin, testing, microservice patterns |
| Spring | 11 | JPA, Security, OAuth2, testing, Effective Java |
| Python | 6 | FastAPI, Django, pytest, asyncio |
| Frontend | 7 | React 19, Next.js 15, TypeScript, Vitest, Tailwind |
| MSA | 15 | DDD, Saga, CQRS, Event Sourcing, gRPC, Contract-First |
| Architecture | 10 | Hexagonal, Cell-based, Modular Monolith, Data Mesh |
| Kubernetes | 10 | Security, Helm, HPA/VPA/KEDA, Gateway API |
| Service Mesh | 16 | Istio (Ambient, mTLS, multi-cluster), Linkerd |
| Observability | 17 | OpenTelemetry, eBPF, Prometheus, Grafana, AIOps |
| CI/CD | 11 | GitHub Actions, ArgoCD, Canary, Supply Chain |
| SRE | 14 | SLI/SLO, Chaos Engineering, DR, FinOps |
| Platform | 16 | Backstage, MLOps, WASM, GPU scheduling |
| DX | 20 | DORA metrics, onboarding, RFC/ADR, SDD, Team Topologies |
| Infrastructure | 11 | AWS EKS, Terraform, Crossplane, Docker |
| Messaging | 8 | Kafka, RabbitMQ, NATS, Redis Streams |
| Security | 5 | OWASP, auth patterns, compliance frameworks |
| AI | 4 | RAG, prompt engineering, vector DB, LangChain |

## Plugin Bundles

Install agents and skills by role:

```bash
./install.sh --list-plugins    # Show available bundles
./install.sh --global --plugin k8s-ops
```

| Plugin | Agents | Focus |
|---|---|---|
| `k8s-ops` | 4 | Kubernetes, service mesh, observability |
| `backend-java` | 3 | Spring Boot, MSA, architecture |
| `backend-go` | 3 | Go, MSA, architecture |
| `backend-python` | 3 | FastAPI/Django, MSA, architecture |
| `sre-full` | 6 | SRE, observability, Kubernetes |
| `ai-ml` | 2 | Kubeflow, KServe, RAG |
| `messaging` | 2 | Kafka, RabbitMQ, NATS |
| `frontend` | 2 | React, Next.js, TypeScript |
| `strategy` | 3 | Tech strategy, product engineering |

## Scenario Workflows

Install everything needed for a specific scenario. Every workflow auto-includes `_base` (planning tools: SDD, RFC/ADR, docs-as-code).

```bash
./install.sh --list-workflows     # Show available workflows
./install.sh --global --workflow eks-gitops-setup
```

| Workflow | Scenario | Key Components |
|---|---|---|
| `eks-gitops-setup` | EC2/kind -> EKS with ArgoCD, Terraform, Istio | 3 agents, 3 cat + 7 skills |
| `gke-gitops-setup` | Local dev -> GKE with ArgoCD, Terraform | 3 agents, 3 cat + 7 skills |
| `msa-migration` | Monolith -> MSA (DDD, Saga, CQRS) | 4 agents, 3 cat + 6 skills |
| `compose-to-k8s` | Docker Compose -> Kubernetes | 2 agents, 2 cat + 4 skills |
| `observability-full` | Full observability stack (Prometheus, OTel) | 2 agents, 2 cat + 2 skills |
| `kafka-event-driven` | Kafka event-driven architecture | 3 agents, 2 cat + 4 skills |
| `full-platform` | Complete platform setup (all combined) | 8 agents, 9 cat + 10 skills |

> **Plugin vs Workflow**: Plugins are role-based ("I'm a Java developer"), Workflows are scenario-based ("I want to set up EKS GitOps").

## Development

```bash
make test       # Run 51 BATS test cases
make validate   # Verify file consistency
make inventory  # Regenerate .claude/inventory.yml
make lint       # ShellCheck static analysis
make all        # Full verification
```

## Resources

- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Claude Code Docs](https://docs.anthropic.com/claude-code)
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)

## Contributing

Issues and PRs welcome.

```bash
git clone https://github.com/YOUR_USERNAME/ress-claude-agents.git
git checkout -b feature/your-feature
make all    # Run before committing
```

## License

MIT
