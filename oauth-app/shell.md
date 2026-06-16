# Shell (Bash) Usage Guide

Complete guide to using the Shell Device Flow script for generating
OAuth App user access tokens.

## Prerequisites

### curl and jq

The script requires `curl` and `jq`. Both are commonly pre-installed on most systems.

Check if installed:

```bash
curl --version
jq --version
```

If not installed:

- **macOS**: `brew install curl jq`
- **Ubuntu/Debian**: `sudo apt install curl jq`
- **Windows (WSL)**: `sudo apt install curl jq`

### OAuth App

Your OAuth App must have:

- **Device flow** enabled (registration page → tick the *Enable Device Flow* checkbox)
- **Callback URL** set (e.g., `http://localhost` — required even though Device Flow doesn't use it)
- A **Client Secret** generated (you'll need this for the token exchange)

For OAuth Apps in an EMU enterprise, see the [setup guide](setup.md) for
EMU-specific notes around organisation ownership and SSO behaviour.

## Setup

Make the script executable:

```bash
chmod +x device_flow.sh
```

Export the **Client Secret** as an environment variable. The script
**does not accept secrets via CLI flags** because flags leak into shell
history, `ps` output, and audit logs:

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
```

The Client ID is not sensitive and can be passed either way.

## Running the Script

### Using Command Line Argument

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
./device_flow.sh --client-id YOUR_CLIENT_ID
```

Or using the short flag:

```bash
./device_flow.sh -c YOUR_CLIENT_ID
```

### Using Environment Variable

```bash
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
export GITHUB_CLIENT_SECRET='your-client-secret'
./device_flow.sh
```

### Custom Scopes

The default scope is `repo,read:org`. Pass any comma-separated combination via `--scope` (or `-s`):

```bash
./device_flow.sh --client-id YOUR_CLIENT_ID --scope "repo,read:org,user"
```

### Show Help

```bash
./device_flow.sh --help
```

## macOS Polish

On macOS, the script auto-opens the verification URL in your default
browser and copies the user code to your clipboard so you can paste
straight in. On other systems (Linux, WSL, SSH, Codespaces), both
features are graceful no-ops — you copy the URL and code from the
terminal instead.

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

📋 Code copied to clipboard.
🌐 Opening browser...

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
export GITHUB_USER_TOKEN=$(./device_flow.sh -c YOUR_CLIENT_ID | tail -1)

# Use the token
curl -H "Authorization: Bearer $GITHUB_USER_TOKEN" https://api.github.com/user

# Or use it in subsequent commands
echo "Token stored in \$GITHUB_USER_TOKEN"
```

OAuth App tokens use the `gho_` prefix (versus `ghu_` for GitHub Apps).

## Troubleshooting

See [Common Issues](../common-issues.md) for troubleshooting help.
