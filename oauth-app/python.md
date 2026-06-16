# Python Usage Guide

Complete guide to using the Python Device Flow script for generating
OAuth App user access tokens.

## Prerequisites

### Python 3.8+

Check if Python is installed:

```bash
python3 --version
```

If not installed:

- **macOS**: `brew install python3`
- **Ubuntu/Debian**: `sudo apt install python3 python3-venv`
- **Windows**: Download from [python.org](https://www.python.org/downloads/)

### OAuth App

Your OAuth App must have:

- **Device flow** enabled (registration page → tick the *Enable Device Flow* checkbox)
- **Callback URL** set (e.g., `http://localhost` — required even though Device Flow doesn't use it)
- A **Client Secret** generated (you'll need this for the token exchange)

For OAuth Apps in an EMU enterprise, see the [setup guide](setup.md) for
EMU-specific notes around organisation ownership and SSO behaviour.

## Setup

### 1. Create a Virtual Environment

```bash
python3 -m venv .venv
```

### 2. Activate the Virtual Environment

**macOS/Linux:**

```bash
source .venv/bin/activate
```

**Windows:**

```powershell
.venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Export the Client Secret

The script **does not accept secrets via CLI flags** because flags leak
into shell history, `ps` output, and audit logs. Export it as an env var
before running:

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
```

The Client ID is not sensitive and can be passed either way.

## Running the Script

### Using Command Line Argument

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
python device_flow.py --client-id YOUR_CLIENT_ID
```

Or using the short flag:

```bash
python device_flow.py -c YOUR_CLIENT_ID
```

### Using Environment Variable

```bash
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
export GITHUB_CLIENT_SECRET='your-client-secret'
python device_flow.py
```

### Custom Scopes

The default scope is `repo,read:org`. Pass any comma-separated combination via `--scope` (or `-s`):

```bash
python device_flow.py --client-id YOUR_CLIENT_ID --scope "repo,read:org,user"
```

### Show Help

```bash
python device_flow.py --help
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
export GITHUB_USER_TOKEN=$(python device_flow.py -c YOUR_CLIENT_ID | tail -1)

# Use the token
curl -H "Authorization: Bearer $GITHUB_USER_TOKEN" https://api.github.com/user
```

OAuth App tokens use the `gho_` prefix (versus `ghu_` for GitHub Apps).

## Deactivating the Virtual Environment

When done:

```bash
deactivate
```

## Troubleshooting

See [Common Issues](../common-issues.md) for troubleshooting help.
