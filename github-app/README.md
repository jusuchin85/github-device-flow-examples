# GitHub App Device Flow

This subdir contains end-to-end OAuth Device Flow examples for **GitHub Apps** in four languages. Use any of them to obtain a `ghu_…` user-to-server access token from a CLI without standing up a callback web server.

> [!WARNING]
> These scripts are for **demonstration and testing purposes only**. The full token is printed to stdout, which may expose it in logs and shell history. Do not use as-is in production.

## When you want this (vs the oauth-app/ subdir)

| Use **GitHub App** when… | Use **OAuth App** when… |
|---|---|
| You need fine-grained permissions | You need OAuth scopes |
| You're OK with 8-hour tokens (refreshable) | You need a non-expiring user token |
| You're starting fresh — Apps are the modern recommendation | You're integrating with an existing OAuth-only flow |
| You want server-to-server installation tokens too | You're reproducing an OAuth-specific support ticket |

For most modern integrations, GitHub Apps are preferred. For OAuth-specific use cases, see the sibling [`oauth-app/`](../oauth-app/) subdir.

## Prerequisites

1. A GitHub App registered with **Device Flow** enabled — see [setup.md](setup.md).
2. The relevant runtime for your chosen language (`bash`+`jq`, Python 3.8+, Node.js 18+, or Go 1.18+).

GitHub Apps are public clients in the OAuth sense — **no Client Secret is needed** for the device-flow token exchange. Permissions are configured on the App's settings page, not requested at authorisation time.

## Quick start

Pick your language:

**Shell** (requires `curl` + `jq`):

```bash
./device_flow.sh --client-id YOUR_CLIENT_ID
```

**Python**:

```bash
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
python device_flow.py --client-id YOUR_CLIENT_ID
```

**Node.js** (no dependencies):

```bash
node device_flow.js --client-id YOUR_CLIENT_ID
```

**Go** (no dependencies):

```bash
go run device_flow.go --client-id YOUR_CLIENT_ID
```

All four scripts accept the same flags:

| Flag | Default | Purpose |
|---|---|---|
| `-c`, `--client-id <id>` | `$GITHUB_CLIENT_ID` env var | GitHub App Client ID |
| `-h`, `--help` | — | Show help |

## Per-language guides

Each language has a dedicated guide with full setup, examples, and gotchas:

| Guide | Description |
|---|---|
| [shell.md](shell.md) | Bash usage with `curl` and `jq` |
| [python.md](python.md) | Python with `requests` + virtualenv |
| [nodejs.md](nodejs.md) | Native `fetch`, no dependencies |
| [go.md](go.md) | Standard library only, no dependencies |

## Other docs

- [setup.md](setup.md) — Creating a GitHub App and enabling Device Flow
- [../common-issues.md](../common-issues.md) — Cross-mode troubleshooting
