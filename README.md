**English** | [한국어](README.ko.md)

# ress-claude-agents

Production-ready agents, skills, and rules for Claude Code.

[![CI](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Quick Start

```bash
git clone https://github.com/ressKim-io/ress-claude-agents.git
cd ress-claude-agents
```

That's it — the assets under `.claude/` load automatically when you work **in this repo**.

There is no installer. `install.sh` and its configuration surface (`plugins/`, `.claude/workflows/`)
were removed on 2026-08-26 ([ADR 0011](docs/adr/0011-remove-install-sh.md)) because nothing used them.
To reuse an asset in another project, copy the file you need:

```bash
cp -r .claude/skills/go-performance   /path/to/project/.claude/skills/
cp    .claude/agents/code-reviewer.md /path/to/project/.claude/agents/
cp    .claude/rules/security.md       /path/to/project/.claude/rules/
```

Skills must keep the `<skill-name>/SKILL.md` layout — Claude Code does not load any other shape.

## What's Inside

| | Count | Lines |
|---|---|---|
| Agents | 46 | ~18,800 |
| Skills | 254 | ~97,500 |
| Rules | 15 | ~1,840 |
| Commands | 43 | ~4,000 |
| Tests | 51 cases | - |
| Plugins | 12 bundles | - |
| Workflows | 10 scenarios | - |
| **Total** | | **122,000+** |

## Agents

46 autonomous AI agents across 10 categories.

| Category | Agents |
|---|---|
| Strategy | `tech-lead`, `product-engineer`, `migration-expert` |
| Frontend | `frontend-expert` |
| DevOps & SRE | `security-scanner`, `k8s-troubleshooter`, `terraform-reviewer`, `incident-responder`, `code-reviewer`, `cost-analyzer`, `finops-advisor`, `debugging-expert`, `compliance-auditor` |
| DevOps Reviewers | `k8s-reviewer`, `dockerfile-reviewer`, `cicd-reviewer`, `gitops-reviewer`, `observability-reviewer` |
| Security Reviewers | `k8s-security-reviewer`, `container-security-reviewer`, `cicd-security-reviewer`, `network-security-reviewer` |
| Architecture | `architect-agent` |
| Platform & MLOps | `platform-engineer`, `mlops-expert` |
| Service Mesh & Messaging | `service-mesh-expert` |
| Ticketing & Load Test | `load-tester` |
| Workflow | `git-workflow`, `ci-optimizer`, `dev-logger` |

## Skills

254 on-demand knowledge files organized in 20 categories.

| Category | Count | Topics |
|---|---|---|
| Go | 14 | Error handling, Gin, testing, microservice, AI integration, Effective Go |
| Spring | 12 | JPA, Security, OAuth2, Spring AI, testing, Effective Java |
| Python | 6 | FastAPI, Django, pytest, asyncio |
| Frontend | 7 | React 19, Next.js 15, TypeScript, Vitest, Tailwind |
| MSA | 15 | DDD, Saga, CQRS, Event Sourcing, gRPC, Contract-First |
| Architecture | 10 | Hexagonal, Cell-based, Modular Monolith, Data Mesh |
| Kubernetes | 20 | Security, Helm, HPA/VPA/KEDA, Gateway API, scheduling, autoscaling |
| Service Mesh | 17 | Istio (Ambient, mTLS, multi-cluster), Linkerd |
| Observability | 28 | OpenTelemetry, eBPF, Prometheus, Grafana, Pyroscope, AIOps |
| CI/CD | 12 | GitHub Actions, ArgoCD, Canary, Supply Chain |
| SRE | 15 | SLI/SLO, Chaos Engineering, DR, FinOps, GreenOps |
| Platform | 16 | Backstage, MLOps, WASM, GPU scheduling |
| DX | 26 | DORA, onboarding, RFC/ADR, SDD, Team Topologies, AI agents, token budget |
| Infrastructure | 16 | AWS EKS, Terraform, Crossplane, Docker, EC2 CD |
| Messaging | 9 | Kafka, RabbitMQ, NATS, Redis Streams |
| Security | 5 | OWASP, auth patterns, compliance frameworks |
| AI | 5 | RAG, prompt engineering, vector DB, LangChain, agentic coding |
| Business | 16 | Multi-tenancy, payment, auth, notifications, search/recommend, webhook, streaming |
| Legal | 3 | 한국 위치정보법/PIPA, 아동 보호, 글로벌 GDPR/SOC2 매핑 |
| Operations | 2 | Runbook 표준, Blameless postmortem |

## Development

```bash
make validate             # Documentation consistency
make validate-enforcement # settings.json <-> user-approval.md rule drift
make validate-links       # Internal markdown links resolve
make inventory            # Regenerate .claude/inventory.yml
make lint                 # ShellCheck static analysis
make all                  # validate + enforcement + links
make verify-enforcement   # Permission rules actually fire (needs claude CLI, local only)
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
