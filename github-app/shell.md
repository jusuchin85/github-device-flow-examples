# Shell (Bash) Usage Guide

Complete guide to using the Shell Device Flow script for generating
GitHub App user access tokens.

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

### GitHub App

Your GitHub App must have:

- **Device flow** enabled (Settings → Optional features → Device flow)
- **Callback URL** set (e.g., `http://localhost` — required even though not used)
- **User permissions** configured as needed

## Setup

Make the script executable:

```bash
chmod +x device_flow.sh
```

## Running the Script

### Using Command Line Argument

```bash
./device_flow.sh --client-id YOUR_CLIENT_ID
```

Or using the short flag:

```bash
./device_flow.sh -c YOUR_CLIENT_ID
```

### Using Environment Variable

```bash
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
./device_flow.sh
```

### GitHub Enterprise Server / GHEC with Data Residency

Target a custom hostname with `--hostname` (`-H`) or `GITHUB_HOST`:

```bash
./device_flow.sh --client-id YOUR_CLIENT_ID --hostname ghes.example.com
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
GitHub Device Flow - User Access Token
==================================================

⚠️  WARNING: For demonstration/testing only. Not for production use.

Client ID: Iv23liXXXXXXXXXXXXXX

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

Token Type:   bearer
Scope:        
Access Token: ghu_***xxxxxxxx

Testing token by fetching user info...

Authenticated as: your-username
Name:             Your Name
Email:            you@example.com

==================================================
FULL ACCESS TOKEN (for use in other applications):
==================================================
ghu_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Capturing the Token

The script prints the full token as the last line of output, making it easy to
capture for use in other scripts or store as an environment variable:

```bash
# Capture token into an environment variable
export GITHUB_USER_TOKEN=$(./device_flow.sh -c YOUR_CLIENT_ID | tail -1)

# Use the token
curl -H "Authorization: Bearer $GITHUB_USER_TOKEN" https://api.github.com/user

# Or use it in subsequent commands
echo "Token stored in \$GITHUB_USER_TOKEN"
```

## Troubleshooting

See [Common Issues](../common-issues.md) for troubleshooting help.
