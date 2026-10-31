#!/usr/bin/env bash
#
# GitHub App Device Flow - User-to-Server Token Generation
#
# This script demonstrates how to obtain a user access token using the
# OAuth Device Flow, which is ideal for CLI applications.
#
# WARNING: This script is for demonstration and testing purposes only.
# Do not use in production. The access token is printed to stdout which
# may expose it in logs or shell history.
#

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly DEFAULT_HOSTNAME="github.com"
readonly DEFAULT_POLL_INTERVAL=5
readonly SLOW_DOWN_INCREMENT=5
readonly TOKEN_MIN_LENGTH_FOR_TRUNCATION=30
readonly TOKEN_SUFFIX_LENGTH=8
readonly CURL_CONNECT_TIMEOUT=10
readonly CURL_MAX_TIME=30
readonly API_VERSION="2022-11-28"
readonly USER_AGENT="github-device-flow-examples"

trap 'echo ""; echo "Cancelled by user." >&2; exit 130' INT

# Trim leading and trailing whitespace only — internal whitespace is preserved
# so a copy/paste like "abc def" still trips the regex check below instead of
# being silently rewritten to "abcdef".
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Normalise hostname by stripping optional scheme and trailing slashes.
normalise_hostname() {
    local h lower
    h="$(trim "$1")"
    lower="$(printf '%s' "$h" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower" == https://* ]]; then
        h="${h:8}"
    elif [[ "$lower" == http://* ]]; then
        h="${h:7}"
    fi
    while [[ "$h" == */ ]]; do
        h="${h%/}"
    done
    printf '%s' "$h"
}

# Display usage information
usage() {
    echo "Usage: $SCRIPT_NAME [options]"
    echo ""
    echo "Options:"
    echo "  -c, --client-id <id>   GitHub App Client ID (or set GITHUB_CLIENT_ID env var)"
    echo "  -H, --hostname <host>  GitHub hostname (default: $DEFAULT_HOSTNAME, or set GITHUB_HOST env var)"
    echo "  -h, --help             Show this help message"
    exit 0
}

# Parse arguments
CLIENT_ID="${GITHUB_CLIENT_ID:-}"
GITHUB_HOSTNAME="${GITHUB_HOST:-$DEFAULT_HOSTNAME}"

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--client-id)
            if [[ $# -lt 2 || -z "${2-}" || "${2-}" == -* ]]; then
                echo "Error: --client-id requires a non-empty argument." >&2
                exit 1
            fi
            CLIENT_ID="$2"
            shift 2
            ;;
        -H|--hostname)
            if [[ $# -lt 2 || -z "${2-}" || "${2-}" == -* ]]; then
                echo "Error: --hostname requires a non-empty argument." >&2
                exit 1
            fi
            GITHUB_HOSTNAME="$2"
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

# Trim trailing newlines/spaces from values (defensive — a common copy-paste
# foot-gun is a trailing newline that makes GitHub return a cryptic
# 'Not Found'). We only strip the ends so internal whitespace still trips the
# regex check below.
CLIENT_ID="$(trim "$CLIENT_ID")"
GITHUB_HOSTNAME="$(normalise_hostname "$GITHUB_HOSTNAME")"

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

if [[ -z "$GITHUB_HOSTNAME" || ! "$GITHUB_HOSTNAME" =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]]; then
    echo "Error: Invalid GitHub hostname: [$GITHUB_HOSTNAME]" >&2
    exit 1
fi

# Resolve endpoints for github.com, GHEC with data residency (*.ghe.com), or GHES
HOSTNAME_LOWER="$(printf '%s' "$GITHUB_HOSTNAME" | tr '[:upper:]' '[:lower:]')"
HOST_ONLY="${HOSTNAME_LOWER%%:*}"
readonly DEVICE_CODE_URL="https://${GITHUB_HOSTNAME}/login/device/code"
readonly ACCESS_TOKEN_URL="https://${GITHUB_HOSTNAME}/login/oauth/access_token"
if [[ "$HOST_ONLY" == "github.com" || "$HOST_ONLY" == *.ghe.com ]]; then
    readonly USER_API_URL="https://api.${GITHUB_HOSTNAME}/user"
else
    readonly USER_API_URL="https://${GITHUB_HOSTNAME}/api/v3/user"
fi

# Check for required tools
for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is required but not installed." >&2
        exit 1
    fi
done

echo "=================================================="
echo "GitHub Device Flow - User Access Token"
echo "=================================================="
echo ""
echo "⚠️  WARNING: For demonstration/testing only. Not for production use."
echo ""
echo "Client ID: $CLIENT_ID"
if [[ "$HOSTNAME_LOWER" != "github.com" ]]; then
    echo "Hostname:  $GITHUB_HOSTNAME"
fi
echo ""

# Step 1: Request device code
echo "Requesting device code..."
DEVICE_HTTP_RESPONSE=$(curl -sS --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" \
    -w "\n%{http_code}" -X POST "$DEVICE_CODE_URL" \
    -H "Accept: application/json" \
    -H "User-Agent: $USER_AGENT" \
    --data-urlencode "client_id=$CLIENT_ID")

DEVICE_HTTP_CODE=$(echo "$DEVICE_HTTP_RESPONSE" | tail -1)
DEVICE_RESPONSE=$(echo "$DEVICE_HTTP_RESPONSE" | sed '$d')

if [[ "$DEVICE_HTTP_CODE" != "200" ]] || ! echo "$DEVICE_RESPONSE" | jq -e . >/dev/null 2>&1; then
    echo "Error: Failed to get device code (HTTP $DEVICE_HTTP_CODE)" >&2
    echo "$DEVICE_RESPONSE" >&2
    exit 1
fi

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

# Auto-open browser and copy code to clipboard (macOS-only). Both are
# graceful no-ops on non-macOS systems (Linux, BSD, headless CI, SSH
# sessions, etc.) since they only check for `open` and `pbcopy`.
# Success messages are gated on command exit so we don't claim "copied"
# or "opening" when the underlying tool fails.
if command -v pbcopy >/dev/null 2>&1; then
    if printf '%s' "$USER_CODE" | pbcopy 2>/dev/null; then
        echo "📋 Code copied to clipboard."
    fi
fi
if command -v open >/dev/null 2>&1; then
    if open "$VERIFICATION_URI" 2>/dev/null; then
        echo "🌐 Opening browser..."
    fi
fi

echo ""
echo "Waiting for authorisation..."

# Step 3: Poll for token
while true; do
    TOKEN_HTTP_RESPONSE=$(curl -sS --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" \
        -w "\n%{http_code}" -X POST "$ACCESS_TOKEN_URL" \
        -H "Accept: application/json" \
        -H "User-Agent: $USER_AGENT" \
        --data-urlencode "client_id=$CLIENT_ID" \
        --data-urlencode "device_code=$DEVICE_CODE" \
        --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code")

    TOKEN_HTTP_CODE=$(echo "$TOKEN_HTTP_RESPONSE" | tail -1)
    TOKEN_RESPONSE=$(echo "$TOKEN_HTTP_RESPONSE" | sed '$d')

    if [[ "$TOKEN_HTTP_CODE" != "200" ]] || ! echo "$TOKEN_RESPONSE" | jq -e . >/dev/null 2>&1; then
        echo "Error: Failed to poll for token (HTTP $TOKEN_HTTP_CODE)" >&2
        echo "$TOKEN_RESPONSE" >&2
        exit 1
    fi

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
SCOPE=$(echo "$TOKEN_RESPONSE" | jq -r '.scope // ""')

echo ""
echo "=================================================="
echo "SUCCESS!"
echo "=================================================="
echo ""
echo "Token Type:   $TOKEN_TYPE"
echo "Scope:        $SCOPE"
TOKEN_LENGTH=${#ACCESS_TOKEN}
if (( TOKEN_LENGTH >= TOKEN_MIN_LENGTH_FOR_TRUNCATION )); then
    if [[ "$ACCESS_TOKEN" == *_* ]]; then
        TOKEN_PREFIX="${ACCESS_TOKEN%%_*}_"
    else
        TOKEN_PREFIX="${ACCESS_TOKEN:0:4}"
    fi
    echo "Access Token: ${TOKEN_PREFIX}***${ACCESS_TOKEN: -$TOKEN_SUFFIX_LENGTH}"
else
    echo "Access Token: $ACCESS_TOKEN"
fi

# Step 4: Test the token
echo ""
echo "Testing token by fetching user info..."

USER_RESPONSE=$(curl -sS --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" \
    -w "\n%{http_code}" "$USER_API_URL" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: $API_VERSION" \
    -H "User-Agent: $USER_AGENT")

HTTP_CODE=$(echo "$USER_RESPONSE" | tail -1)
USER_BODY=$(echo "$USER_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]] || ! echo "$USER_BODY" | jq -e . >/dev/null 2>&1; then
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
