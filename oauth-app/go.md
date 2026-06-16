# Go Usage Guide

Complete guide to using the Go Device Flow script for generating
OAuth App user access tokens.

## Prerequisites

### Go 1.18+

The script uses only the Go standard library — no external dependencies!

Check if Go is installed:

```bash
go version
```

If not installed:

- **macOS**: `brew install go`
- **Ubuntu/Debian**: `sudo apt install golang-go` or download from [go.dev](https://go.dev/dl/)
- **Windows**: Download from [go.dev](https://go.dev/dl/)

### OAuth App

Your OAuth App must have:

- **Device flow** enabled (registration page → tick the *Enable Device Flow* checkbox)
- **Callback URL** set (e.g., `http://localhost` — required even though Device Flow doesn't use it)
- A **Client Secret** generated (you'll need this for the token exchange)

For OAuth Apps in an EMU enterprise, see the [setup guide](setup.md) for
EMU-specific notes around organisation ownership and SSO behaviour.

## Setup

No setup required — the script uses only the Go standard library.

Export the **Client Secret** as an environment variable. The script
**does not accept secrets via CLI flags** because flags leak into shell
history, `ps` output, and audit logs:

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
```

The Client ID is not sensitive and can be passed either way.

## Running the Script

### Using `go run`

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
go run device_flow.go --client-id YOUR_CLIENT_ID
```

Or using the short flag:

```bash
go run device_flow.go -c YOUR_CLIENT_ID
```

### Using Environment Variable

```bash
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
export GITHUB_CLIENT_SECRET='your-client-secret'
go run device_flow.go
```

### Custom Scopes

The default scope is `repo,read:org`. Pass any comma-separated combination via `--scope` (or `-s`):

```bash
go run device_flow.go --client-id YOUR_CLIENT_ID --scope "repo,read:org,user"
```

### Building a Binary

```bash
go build -o device_flow device_flow.go
export GITHUB_CLIENT_SECRET='your-client-secret'
./device_flow --client-id YOUR_CLIENT_ID
```

### Show Help

```bash
go run device_flow.go --help
```

## Example Session

```text
==================================================
OAuth App Device Flow - User Access Token
==================================================

⚠️  WARNING: For demonstration/testing only. Not for production use.

Client ID: Ov23liXXXXXXXXXXXXXX
Scope:     repo,read:org

Requesting device code...

==================================================
ACTION REQUIRED
==================================================

1. Open: https://github.com/login/device
2. Enter code: XXXX-XXXX

Waiting for authorisation...

==================================================
SUCCESS!
==================================================

Token Type:    bearer
Granted Scope: repo,read:org
Access Token:  gho_***xxxxxxxx

Testing token by fetching user info...

Authenticated as: your-username
Name:             Your Name
Email:            you@example.com

==================================================
FULL ACCESS TOKEN (for use in other applications):
==================================================
gho_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Capturing the Token

The script prints the full token as the last line of output, making it
easy to capture for use in other scripts or store as an environment
variable:

```bash
# Capture token into an environment variable
export GITHUB_USER_TOKEN=$(go run device_flow.go -c YOUR_CLIENT_ID | tail -1)

# Use the token
curl -H "Authorization: Bearer $GITHUB_USER_TOKEN" https://api.github.com/user
```

OAuth App tokens use the `gho_` prefix (versus `ghu_` for GitHub Apps).

## Troubleshooting

See [Common Issues](../common-issues.md) for troubleshooting help.
