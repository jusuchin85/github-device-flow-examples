# OAuth App Device Flow

This subdir contains end-to-end OAuth Device Flow examples for **OAuth Apps** in four languages. Use any of them to obtain a `gho_…` user access token from a CLI without standing up a callback web server.

> [!WARNING]
> These scripts are for **demonstration and testing purposes only**. The full token is printed to stdout, which may expose it in logs and shell history. Do not use as-is in production.

## When you want this (vs the github-app/ subdir)

| Use **OAuth App** when… | Use **GitHub App** when… |
|---|---|
| You need OAuth scopes | You need fine-grained permissions |
| You need a non-expiring user token | You're OK with 8-hour tokens (refreshable) |
| You're integrating with an existing OAuth-only flow | You're starting fresh — Apps are the modern recommendation |
| You're reproducing an OAuth-specific support ticket | You want server-to-server installation tokens too |

For most modern integrations, GitHub Apps are preferred. See the sibling [`github-app/`](../github-app/) subdir.

## Prerequisites

1. An OAuth App registered on github.com (or your GHE/EMU enterprise) with **Device Flow** enabled — see [setup.md](setup.md).
2. A generated **Client Secret**.
3. The relevant runtime for your chosen language (`bash`+`jq`, Python 3.8+, Node.js 18+, or Go 1.18+).

## Quick start

Export the Client Secret as an env var. **The scripts never accept secrets via CLI flags** — flags leak to shell history, `ps` output, and audit logs.

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
```

Then pick your language:

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
| `-c`, `--client-id <id>` | `$GITHUB_CLIENT_ID` env var | OAuth App Client ID |
| `-s`, `--scope <scope>` | `repo,read:org` | Comma-separated OAuth scopes |
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

- [setup.md](setup.md) — Creating an OAuth App on github.com or an EMU enterprise
- [../common-issues.md](../common-issues.md) — Cross-mode troubleshooting
