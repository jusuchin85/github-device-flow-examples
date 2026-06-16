# Python Usage Guide

Complete guide to using the Python Device Flow script for generating
GitHub App user access tokens.

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

### GitHub App

Your GitHub App must have:

- **Device flow** enabled (Settings → Optional features → Device flow)
- **Callback URL** set (e.g., `http://localhost` — required even though not used)
- **User permissions** configured as needed

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

## Running the Script

### Using Command Line Argument

```bash
python device_flow.py --client-id YOUR_CLIENT_ID
```

Or using the short flag:

```bash
python device_flow.py -c YOUR_CLIENT_ID
```

### Using Environment Variable

```bash
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
python device_flow.py
```

### Show Help

```bash
python device_flow.py --help
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
export GITHUB_USER_TOKEN=$(python device_flow.py -c YOUR_CLIENT_ID | tail -1)

# Use the token
curl -H "Authorization: Bearer $GITHUB_USER_TOKEN" https://api.github.com/user
```

## Deactivating the Virtual Environment

When done:

```bash
deactivate
```

## Troubleshooting

See [Common Issues](../common-issues.md) for troubleshooting help.
