**English** | [한국어](README.ko.md)

# ress-claude-agents

Claude Code plugins by domain: skills, agents and commands for backend, infrastructure, operations and SaaS work. Install only the domains you need.

[![CI](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml/badge.svg)](https://github.com/ressKim-io/ress-claude-agents/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Which plugin do I need?

Each plugin's README lists its skills, agents and commands, the plugins it pairs with, and the rules worth copying.

| Area | Plugin | Install it when you work on |
|---|---|---|
| Languages | [`go`](plugins/go/README.md) | Go concurrency, database access, Gin, microservices, performance, testing |
| | [`java`](plugins/java/README.md) | Java and Spring: Data, Security, Cache, jOOQ, JVM performance, testing |
| | [`python`](plugins/python/README.md) | FastAPI, Django, asyncio, performance, testing |
| | [`frontend`](plugins/frontend/README.md) | React, Next.js, TypeScript, state management, CSS, web performance |
| Design | [`architecture`](plugins/architecture/README.md) | MSA, DDD, Saga, CQRS, API design, gRPC, modular monoliths, high traffic |
| | [`messaging`](plugins/messaging/README.md) | Kafka, RabbitMQ, NATS, Redis Streams, AWS messaging, broker incidents |
| Infrastructure | [`k8s`](plugins/k8s/README.md) | Scheduling, autoscaling, traffic, Helm, security, GPUs, manifest review |
| | [`service-mesh`](plugins/service-mesh/README.md) | Istio core, Ambient, gateways, security, observability, and Linkerd |
| | [`infra`](plugins/infra/README.md) | Terraform, AWS and EKS, Docker, Crossplane, database operations, cloud CLI safety |
| | [`cicd`](plugins/cicd/README.md) | GitHub Actions, ArgoCD, deployment strategies, preview environments, pipeline review |
| Operations | [`observability`](plugins/observability/README.md) | OpenTelemetry, Prometheus, Grafana, Loki, eBPF, AIOps |
| | [`sre`](plugins/sre/README.md) | SLI/SLO, incident response, postmortems, chaos, DR, load testing, FinOps |
| | [`platform`](plugins/platform/README.md) | Backstage, golden paths, self-service, Kratix, IDP strategy |
| Security and product | [`security`](plugins/security/README.md) | OWASP, threat modeling, auth patterns, supply chain, secrets, PIPA, GDPR, SOC2 |
| | [`saas`](plugins/saas/README.md) | Multi-tenancy, social login, payments, subscriptions, notifications, webhooks |
| | [`ai`](plugins/ai/README.md) | RAG, vector databases, LLMOps, MLOps, model serving, agentic architecture |
| Common | [`dx`](plugins/dx/README.md) | Code review, Git and PR workflow, ADR and doc templates, token budgets |
| | [`devlog`](plugins/devlog/README.md) | Dev logs for troubleshooting, decisions, meta changes and feedback, tier upkeep |

Not sure where to start? See the [persona guides and scenarios](docs/guides/README.md).

## Install

Inside Claude Code:

```
/plugin marketplace add ressKim-io/ress-claude-agents
/plugin install go@ress
```

In a terminal, use `claude plugin marketplace add` and `claude plugin install` instead.

Skills are picked automatically from their descriptions, or you can call one directly: `/go:go-testing`. Agents are named `<plugin>:<agent>`.

**Install only what you use.** Every enabled plugin adds its skill list to each session (`claude plugin details <plugin>` shows the cost), and when the list outgrows its budget, skill descriptions start to drop out.

## Copy a single asset

```bash
cp -r plugins/go/skills/go-testing       /path/to/project/.claude/skills/
cp    plugins/dx/agents/code-reviewer.md /path/to/project/.claude/agents/
cp    .claude/rules/core/security.md     /path/to/project/.claude/rules/
```

Copied skills have no plugin prefix (`/go-testing`), and a copy does not follow updates. Skills must keep the `<skill-name>/SKILL.md` layout, because Claude Code does not load any other shape.

## What a plugin cannot carry

- **Rules.** Copy them from [`.claude/rules/`](.claude/rules/). Each plugin README names the relevant ones.
- **Permission rules** (`permissions.deny`). An agent's Permission Boundary section is advisory in an installed copy.

## Working in this repo

```bash
git clone https://github.com/ressKim-io/ress-claude-agents.git
cd ress-claude-agents
claude
```

The repo enables `dx` and `devlog`, once you trust the folder. To try another plugin here, run `claude --plugin-dir plugins/<plugin>`. Cloud sessions and uncommitted changes in a worktree also need `--plugin-dir plugins/dx`.

```bash
make all              # Catalog, enforcement and link gates
make test-gates       # Break a copy of the repo and check each gate fails for the right reason
make plugin-readmes   # Regenerate plugins/*/README.md from frontmatter
make inventory        # Regenerate .claude/inventory.yml
make lint             # ShellCheck
make verify-plugins   # Check what actually loads (needs the claude CLI, no model calls)
```

Why the repo is laid out this way: [ADR 0012](docs/adr/0012-native-plugin-structure.md).

## Resources

- [Claude Code docs](https://code.claude.com/docs)
- [Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)

## Contributing

Issues and PRs welcome. Skill and agent standards: [SKILL-SPEC](.claude/templates/SKILL-SPEC.md), [AGENT-SPEC](.claude/templates/AGENT-SPEC.md).

```bash
git clone https://github.com/YOUR_USERNAME/ress-claude-agents.git
git checkout -b feature/your-feature
make all    # Run before committing
```

## License

MIT
