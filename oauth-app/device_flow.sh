#!/usr/bin/env bash
#
# OAuth App Device Flow - User Access Token Generation
#
# This script demonstrates how to obtain a user access token using the
# OAuth Device Flow with an OAuth App, which is ideal for CLI applications
# that need user-attributed access without standing up a web server.
#
# WARNING: This script is for demonstration and testing purposes only.
# Do not use in production. The access token is printed to stdout which
# may expose it in logs or shell history.
#
# Why an OAuth App and not a GitHub App?
#   - You need scopes (granular permissions are a GitHub App concept).
#   - You need a non-expiring user token by default.
#   - You're integrating with an existing OAuth-only flow.
#   For most modern use cases, GitHub Apps are preferred. See the sibling
#   github-app/ subdir.
#

set -euo pipefail

readonly DEVICE_CODE_URL="https://github.com/login/device/code"
readonly ACCESS_TOKEN_URL="https://github.com/login/oauth/access_token"
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_POLL_INTERVAL=5
readonly SLOW_DOWN_INCREMENT=5
readonly TOKEN_MIN_LENGTH_FOR_TRUNCATION=30
readonly TOKEN_SUFFIX_LENGTH=8
readonly DEFAULT_SCOPE="repo,read:org"

# Display usage information
usage() {
    echo "Usage: $SCRIPT_NAME [options]"
    echo ""
    echo "Options:"
    echo "  -c, --client-id <id>  OAuth App Client ID (or set GITHUB_CLIENT_ID env var)"
    echo "  -s, --scope <scope>   Comma-separated OAuth scopes (default: $DEFAULT_SCOPE)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Required env vars:"
    echo "  GITHUB_CLIENT_SECRET  OAuth App Client Secret. Env-var only — we never"
    echo "                        accept secrets as CLI flags because flags leak to"
    echo "                        shell history and ps output."
    exit 0
}

# Parse arguments
CLIENT_ID="${GITHUB_CLIENT_ID:-}"
SCOPE="$DEFAULT_SCOPE"

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--client-id)
            if [[ $# -lt 2 || -z "${2-}" ]]; then
                echo "Error: --client-id requires a non-empty argument." >&2
                exit 1
            fi
            CLIENT_ID="$2"
            shift 2
            ;;
        -s|--scope)
            if [[ $# -lt 2 || -z "${2-}" ]]; then
                echo "Error: --scope requires a non-empty argument." >&2
                exit 1
            fi
            SCOPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Strip whitespace from env-loaded values (defensive — common copy-paste foot-gun
# is a trailing newline or space that makes GitHub return a cryptic 'Not Found').
CLIENT_ID="${CLIENT_ID//[[:space:]]/}"
CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-}"
CLIENT_SECRET="${CLIENT_SECRET//[[:space:]]/}"

# Validate Client ID
if [[ -z "$CLIENT_ID" ]]; then
    echo "Error: Client ID required. Use --client-id or set GITHUB_CLIENT_ID env var." >&2
    exit 1
fi

if [[ ! "$CLIENT_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: GITHUB_CLIENT_ID contains unexpected characters." >&2
    echo "       Got: [$CLIENT_ID] (${#CLIENT_ID} chars)" >&2
    echo "       Re-export cleanly to fail fast on stray prefixes." >&2
    exit 1
fi

# Validate Client Secret (env var only, never a flag)
if [[ -z "$CLIENT_SECRET" ]]; then
    echo "Error: GITHUB_CLIENT_SECRET env var is required for OAuth Apps." >&2
    echo "       Export it before running:" >&2
    echo "         export GITHUB_CLIENT_SECRET='your-secret'" >&2
    echo "       We never accept secrets via CLI flags — they leak to shell" >&2
    echo "       history, ps output, and audit logs." >&2
    exit 1
fi

# Check for required tools
for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required but not installed." >&2
        exit 1
    fi
done

echo "=================================================="
echo "OAuth App Device Flow - User Access Token"
echo "=================================================="
echo ""
echo "⚠️  WARNING: For demonstration/testing only. Not for production use."
echo ""
echo "Client ID: $CLIENT_ID"
echo "Scope:     $SCOPE"
echo ""

# Step 1: Request device code (with scope, since OAuth Apps use scopes
# unlike GitHub Apps which use installation permissions)
echo "Requesting device code..."
DEVICE_RESPONSE=$(curl -s -X POST "$DEVICE_CODE_URL" \
    -H "Accept: application/json" \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "scope=$SCOPE")

DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.device_code')
USER_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.user_code')
VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | jq -r '.verification_uri')
INTERVAL=$(echo "$DEVICE_RESPONSE" | jq -r ".interval // $DEFAULT_POLL_INTERVAL")

if [[ "$DEVICE_CODE" == "null" || -z "$DEVICE_CODE" ]]; then
    echo "Error: Failed to get device code" >&2
    echo "$DEVICE_RESPONSE" >&2
    exit 1
fi

# Step 2: Prompt user to authorize
echo ""
echo "=================================================="
echo "ACTION REQUIRED"
echo "=================================================="
echo ""
echo "1. Open: $VERIFICATION_URI"
echo "2. Enter code: $USER_CODE"
echo ""

# macOS polish: auto-open the verification URL in the default browser and
# copy the user code to the clipboard. Both are graceful no-ops on Linux,
# Codespaces, SSH sessions, etc.
if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$USER_CODE" | pbcopy
    echo "📋 Code copied to clipboard."
fi
if command -v open >/dev/null 2>&1; then
    open "$VERIFICATION_URI" 2>/dev/null || true
    echo "🌐 Opening browser..."
fi

echo ""
echo "Waiting for authorisation..."

# Step 3: Poll for token. OAuth Apps require client_secret in the token
# exchange, unlike GitHub Apps which are public clients.
while true; do
    TOKEN_RESPONSE=$(curl -s -X POST "$ACCESS_TOKEN_URL" \
        -H "Accept: application/json" \
        -d "client_id=$CLIENT_ID" \
        -d "client_secret=$CLIENT_SECRET" \
        -d "device_code=$DEVICE_CODE" \
        -d "grant_type=urn:ietf:params:oauth:grant-type:device_code")

    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error')

    if [[ "$ACCESS_TOKEN" != "null" && -n "$ACCESS_TOKEN" ]]; then
        break
    fi

    case "$ERROR" in
        authorization_pending)
            # User hasn't authorized yet, keep polling
            sleep "$INTERVAL"
            ;;
        slow_down)
            # Polling too fast, increase interval
            INTERVAL=$((INTERVAL + SLOW_DOWN_INCREMENT))
            sleep "$INTERVAL"
            ;;
        expired_token)
            echo "Error: Device code expired. Please restart the process." >&2
            exit 1
            ;;
        access_denied)
            echo "Error: User denied authorisation." >&2
            exit 1
            ;;
        null)
            echo "Error: Received invalid response from GitHub (no access_token or error field)" >&2
            exit 1
            ;;
        *)
            ERROR_DESC=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description // .error')
            echo "Error: Unexpected error: $ERROR_DESC" >&2
            exit 1
            ;;
    esac
done

TOKEN_TYPE=$(echo "$TOKEN_RESPONSE" | jq -r '.token_type // "bearer"')
TOKEN_SCOPE=$(echo "$TOKEN_RESPONSE" | jq -r '.scope // ""')

echo ""
echo "=================================================="
echo "SUCCESS!"
echo "=================================================="
echo ""
echo "Token Type:    $TOKEN_TYPE"
echo "Granted Scope: $TOKEN_SCOPE"
TOKEN_LENGTH=${#ACCESS_TOKEN}
if (( TOKEN_LENGTH >= TOKEN_MIN_LENGTH_FOR_TRUNCATION )); then
    if [[ "$ACCESS_TOKEN" == *_* ]]; then
        TOKEN_PREFIX="${ACCESS_TOKEN%%_*}_"
    else
        TOKEN_PREFIX="${ACCESS_TOKEN:0:4}"
    fi
    echo "Access Token:  ${TOKEN_PREFIX}***${ACCESS_TOKEN: -$TOKEN_SUFFIX_LENGTH}"
else
    echo "Access Token:  $ACCESS_TOKEN"
fi

# Step 4: Test the token
echo ""
echo "Testing token by fetching user info..."

USER_RESPONSE=$(curl -s -w "\n%{http_code}" "https://api.github.com/user" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/vnd.github+json")

HTTP_CODE=$(echo "$USER_RESPONSE" | tail -1)
USER_BODY=$(echo "$USER_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
    echo "Error: Failed to fetch user info (HTTP $HTTP_CODE)" >&2
    echo "$USER_BODY" >&2
    exit 1
fi

LOGIN=$(echo "$USER_BODY" | jq -r '.login')
NAME=$(echo "$USER_BODY" | jq -r '.name // "N/A"')
EMAIL=$(echo "$USER_BODY" | jq -r '.email // "N/A"')

echo ""
echo "Authenticated as: $LOGIN"
echo "Name:             $NAME"
echo "Email:            $EMAIL"

# NOTE: Printing the full token is intentional for demo/testing purposes.
# This allows token capture via: export TOKEN=$(./device_flow.sh ... | tail -1)
# For production use, store tokens securely rather than printing to stdout.
echo ""
echo "=================================================="
echo "FULL ACCESS TOKEN (for use in other applications):"
echo "=================================================="
echo "$ACCESS_TOKEN"
