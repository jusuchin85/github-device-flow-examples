# Node.js Usage Guide

Complete guide to using the Node.js Device Flow script for generating
GitHub App user access tokens.

## Prerequisites

### Node.js 18+

The script uses the built-in `fetch` API (available in Node 18+). No
external dependencies required!

Check if Node.js is installed:

```bash
node --version
```

If not installed:

- **macOS**: `brew install node`
- **Ubuntu/Debian**: See [NodeSource](https://github.com/nodesource/distributions)
- **Windows**: Download from [nodejs.org](https://nodejs.org/)

### GitHub App

Your GitHub App must have:

- **Device flow** enabled (Settings → Optional features → Device flow)
- **Callback URL** set (e.g., `http://localhost` — required even though not used)
- **User permissions** configured as needed

## Setup

No setup required! The script has zero dependencies.

## Running the Script

### Using Command Line Argument

```bash
node device_flow.js --client-id YOUR_CLIENT_ID
```

Or using the short flag:

```bash
node device_flow.js -c YOUR_CLIENT_ID
```

### Using Environment Variable

```bash
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
node device_flow.js
```

### Show Help

```bash
node device_flow.js --help
```

## Example Session

```text
==================================================
GitHub Device Flow - User Access Token
==================================================

Client ID: Iv23liXXXXXXXXXXXXXX

Requesting device code...

==================================================
ACTION REQUIRED
==================================================

1. Go to: https://github.com/login/device
2. Enter code: XXXX-XXXX

📋 Code copied to clipboard.
🌐 Opening browser...

Waiting for authorisation...

==================================================
SUCCESS!
==================================================

Token Type: bearer
Scope: 
Access Token: ghu_***xxxxxxxx

Testing token by fetching user info...

Authenticated as: your-username
Name: Your Name
Email: you@example.com

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
export GITHUB_USER_TOKEN=$(node device_flow.js -c YOUR_CLIENT_ID | tail -1)

# Use the token
curl -H "Authorization: Bearer $GITHUB_USER_TOKEN" https://api.github.com/user
```

## Troubleshooting

See [Common Issues](../common-issues.md) for troubleshooting help.
