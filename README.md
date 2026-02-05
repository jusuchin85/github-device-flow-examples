# GitHub App User-to-Server Token (Device Flow)

Generate user access tokens (`ghu_`) via the OAuth Device Flow — ideal
for CLI apps, no web server needed.

> [!WARNING]
> These scripts are for **demonstration and testing purposes only**.
> Do not use in production. The scripts print the access token to stdout
> which may expose it in logs or shell history.

## Quick Start

**Python:**

```bash
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
python device_flow.py --client-id YOUR_CLIENT_ID
```

**Node.js:** (no dependencies!)

```bash
node device_flow.js --client-id YOUR_CLIENT_ID
```

**Go:** (no dependencies!)

```bash
go run device_flow.go --client-id YOUR_CLIENT_ID
```

**Shell:** (requires curl + jq)

```bash
./device_flow.sh --client-id YOUR_CLIENT_ID
```

## Documentation

| Guide | Description |
|-------|-------------|
| [Setup GitHub App](docs/setup-github-app.md) | Create and configure a GitHub App for Device Flow |
| [Python](docs/python.md) | Setup and usage for Python script |
| [Node.js](docs/nodejs.md) | Setup and usage for Node.js script |
| [Go](docs/go.md) | Setup and usage for Go script |
| [Shell](docs/shell.md) | Setup and usage for Shell script |
| [Common Issues](docs/common-issues.md) | Troubleshooting and token usage |

## Prerequisites

- A GitHub App with Device Flow enabled ([setup guide](docs/setup-github-app.md))

## How It Works

1. Script requests a device code from GitHub
2. You visit `github.com/login/device` and enter the displayed code
3. Script polls until you authorise
4. You get a user access token (`ghu_...`) that acts on your behalf

## Token Permissions

GitHub Apps define permissions in the **App's settings** (Permissions &
events), not at authorisation time. This differs from OAuth Apps where
you request scopes in the OAuth request.

## See Also

- [Registering a GitHub App](https://docs.github.com/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)
- [Installing your own GitHub App](https://docs.github.com/apps/using-github-apps/installing-your-own-github-app)
- [Authenticating on behalf of a user](https://docs.github.com/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-with-a-github-app-on-behalf-of-a-user)
- [Generating a user access token (Device Flow)](https://docs.github.com/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app#using-the-device-flow-to-generate-a-user-access-token)
- [Permissions required for GitHub Apps](https://docs.github.com/rest/authentication/permissions-required-for-github-apps)
