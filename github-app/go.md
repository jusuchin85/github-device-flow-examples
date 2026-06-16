# Go Usage Guide

Complete guide to using the Go Device Flow script for generating GitHub
App user access tokens.

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

### GitHub App

Your GitHub App must have:

- **Device flow** enabled (Settings → Optional features → Device flow)
- **Callback URL** set (e.g., `http://localhost` — required even though not used)
- **User permissions** configured as needed

## Setup

No setup required! The script uses only the Go standard library.

## Running the Script

### Using `go run`

```bash
go run device_flow.go --client-id YOUR_CLIENT_ID
```

Or using the short flag:

```bash
go run device_flow.go -c YOUR_CLIENT_ID
```

### Using Environment Variable

```bash
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
go run device_flow.go
```

### Show Help

```bash
go run device_flow.go --help
```

### Building a Binary

For repeated use or distribution, build a standalone binary:

```bash
# Build
go build -o device_flow_go device_flow.go

# Run
./device_flow_go --client-id YOUR_CLIENT_ID
```

Cross-compile for other platforms:

```bash
# Linux
GOOS=linux GOARCH=amd64 go build -o device_flow_linux device_flow.go

# Windows
GOOS=windows GOARCH=amd64 go build -o device_flow.exe device_flow.go
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

The script prints the full token as the last line of output, making it
easy to capture for use in other scripts or store as an environment
variable:

```bash
# Capture token into an environment variable
export GITHUB_USER_TOKEN=$(go run device_flow.go -c YOUR_CLIENT_ID | tail -1)

# Use the token
curl -H "Authorization: Bearer $GITHUB_USER_TOKEN" https://api.github.com/user
```

## Troubleshooting

See [Common Issues](../common-issues.md) for troubleshooting help.
