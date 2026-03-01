# Plugin Bundles

역할별 에이전트/스킬 번들을 한 번에 설치하세요.

## 사용법

```bash
# 사용 가능한 플러그인 목록 확인
./install.sh --list-plugins

# 플러그인 번들 설치
./install.sh --global --plugin k8s-ops
./install.sh --global --plugin backend-java --with-skills
```

## 사용 가능한 플러그인

| Plugin | Description | Agents | Skill Categories |
|--------|-------------|--------|-----------------|
| k8s-ops | K8s 운영 번들 | 4 | 3 |
| backend-java | Java/Spring 백엔드 | 3 | 3 |
| backend-go | Go 백엔드 | 3 | 3 |
| backend-python | Python 백엔드 | 3 | 2 |
| sre-full | SRE 전체 툴킷 | 6 | 4 |
| ai-ml | AI/ML 번들 | 2 | 2 |
| messaging | 메시징 시스템 | 2 | 1 |

## Plugin Manifest 형식

```yaml
name: plugin-name
description: "Plugin description"
agents:
  - agent-name-1
  - agent-name-2
skills:
  categories:
    - category-1
    - category-2
```
