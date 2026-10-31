#!/usr/bin/env python3
"""
GitHub App Device Flow - User-to-Server Token Generation.

This script demonstrates how to obtain a user access token using the
OAuth Device Flow, which is ideal for CLI applications.

WARNING: This script is for demonstration and testing purposes only.
Do not use in production. The access token is printed to stdout which
may expose it in logs or shell history.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
import webbrowser

import requests

# Note: For GitHub Apps, permissions are defined in the App's settings,
# not requested via scope parameter (that's for OAuth Apps only).

DEFAULT_HOSTNAME = "github.com"
DEFAULT_POLL_INTERVAL = 5
SLOW_DOWN_INCREMENT = 5
TOKEN_MIN_LENGTH_FOR_TRUNCATION = 30
TOKEN_SUFFIX_LENGTH = 8
REQUEST_TIMEOUT_SECONDS = 30
API_VERSION = "2022-11-28"
USER_AGENT = "github-device-flow-examples"
CLIENT_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")
HOSTNAME_PATTERN = re.compile(r"^[A-Za-z0-9.-]+(:[0-9]+)?$")


class DeviceFlowError(Exception):
    """Base exception for Device Flow errors."""

    pass


class DeviceCodeExpiredError(DeviceFlowError):
    """Raised when the device code has expired."""

    pass


class AuthorizationDeniedError(DeviceFlowError):
    """Raised when the user denies authorisation."""

    pass


def normalise_hostname(hostname: str) -> str:
    """Strip optional http(s):// scheme and trailing slash from hostname."""
    h = (hostname or "").strip()
    for prefix in ("https://", "http://"):
        if h.lower().startswith(prefix):
            h = h[len(prefix):]
            break
    return h.rstrip("/")


def resolve_endpoints(hostname: str) -> tuple[str, str, str]:
    """
    Resolve Device Flow and REST API endpoints for a GitHub hostname.

    Supports github.com, GHEC with data residency (*.ghe.com), and
    GitHub Enterprise Server (GHES).
    """
    lower = hostname.lower()
    device_code_url = f"https://{hostname}/login/device/code"
    access_token_url = f"https://{hostname}/login/oauth/access_token"
    if lower == "github.com":
        user_api_url = "https://api.github.com/user"
    elif lower.endswith(".ghe.com"):
        user_api_url = f"https://api.{hostname}/user"
    else:
        user_api_url = f"https://{hostname}/api/v3/user"
    return device_code_url, access_token_url, user_api_url


def parse_json_response(response: requests.Response, context: str) -> dict:
    """Validate HTTP status and parse JSON response safely."""
    try:
        response.raise_for_status()
    except requests.HTTPError as exc:
        body = response.text.strip()
        detail = f": {body}" if body else ""
        raise DeviceFlowError(
            f"{context} (HTTP {response.status_code}){detail}"
        ) from exc

    try:
        data = response.json()
    except ValueError as exc:
        raise DeviceFlowError(
            f"{context}: received non-JSON response from GitHub"
        ) from exc

    if not isinstance(data, dict):
        raise DeviceFlowError(
            f"{context}: unexpected JSON payload type ({type(data).__name__})"
        )
    return data


def request_device_code(
    client_id: str, device_code_url: str = f"https://{DEFAULT_HOSTNAME}/login/device/code"
) -> dict:
    """
    Request a device code from GitHub.

    Parameters
    ----------
    client_id : str
        The GitHub App's Client ID.
    device_code_url : str
        The device code endpoint URL.

    Returns
    -------
    dict
        Response containing device_code, user_code, and verification_uri.
    """
    response = requests.post(
        device_code_url,
        data={"client_id": client_id},
        headers={
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    return parse_json_response(response, "Failed to get device code")


def poll_for_token(
    client_id: str,
    device_code: str,
    interval: int,
    access_token_url: str = f"https://{DEFAULT_HOSTNAME}/login/oauth/access_token",
) -> dict:
    """
    Poll GitHub until the user authorizes or an error occurs.

    Parameters
    ----------
    client_id : str
        The GitHub App's Client ID.
    device_code : str
        The device code from the initial request.
    interval : int
        Polling interval in seconds.
    access_token_url : str
        The OAuth access token endpoint URL.

    Returns
    -------
    dict
        Response containing access_token, token_type, and scope.

    Raises
    ------
    DeviceCodeExpiredError
        If the device code expires before authorisation.
    AuthorizationDeniedError
        If the user denies authorisation.
    DeviceFlowError
        For other unexpected errors.
    """
    while True:
        response = requests.post(
            access_token_url,
            data={
                "client_id": client_id,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            },
            headers={
                "Accept": "application/json",
                "User-Agent": USER_AGENT,
            },
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        data = parse_json_response(response, "Failed to poll for token")

        if "access_token" in data:
            return data

        error = data.get("error")
        if error == "authorization_pending":
            # User hasn't authorized yet, keep polling
            time.sleep(interval)
        elif error == "slow_down":
            # We're polling too fast, increase interval
            interval += SLOW_DOWN_INCREMENT
            time.sleep(interval)
        elif error == "expired_token":
            raise DeviceCodeExpiredError(
                "Device code expired. Please restart the process."
            )
        elif error == "access_denied":
            raise AuthorizationDeniedError("User denied authorisation.")
        elif error is None:
            raise DeviceFlowError(
                "Received invalid response from GitHub (no access_token or error field)"
            )
        else:
            description = data.get("error_description", error)
            raise DeviceFlowError(f"Unexpected error: {description}")


def test_token(
    access_token: str, user_api_url: str = "https://api.github.com/user"
) -> dict:
    """
    Test the token by fetching the authenticated user's info.

    Parameters
    ----------
    access_token : str
        The user access token to test.
    user_api_url : str
        The `/user` REST API endpoint URL.

    Returns
    -------
    dict
        User information from the GitHub API.
    """
    response = requests.get(
        user_api_url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": API_VERSION,
            "User-Agent": USER_AGENT,
        },
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    return parse_json_response(response, "Failed to fetch user info")


def main() -> None:
    """Run the Device Flow authentication process."""
    parser = argparse.ArgumentParser(
        description="GitHub App Device Flow - User Access Token"
    )
    parser.add_argument(
        "-c", "--client-id",
        default=os.environ.get("GITHUB_CLIENT_ID", "").strip(),
        help="GitHub App Client ID (or set GITHUB_CLIENT_ID env var)",
    )
    parser.add_argument(
        "-H", "--hostname",
        default=os.environ.get("GITHUB_HOST", DEFAULT_HOSTNAME).strip() or DEFAULT_HOSTNAME,
        help=f"GitHub hostname (default: {DEFAULT_HOSTNAME}, or set GITHUB_HOST env var)",
    )
    args = parser.parse_args()

    client_id = (args.client_id or "").strip()
    if not client_id:
        parser.error(
            "Client ID required. Use --client-id or set "
            "GITHUB_CLIENT_ID env var."
        )

    if not CLIENT_ID_PATTERN.match(client_id):
        parser.error(
            f"GITHUB_CLIENT_ID contains unexpected characters.\n"
            f"   Got: [{client_id}] ({len(client_id)} chars)\n"
            f"   Re-export cleanly to fail fast on stray prefixes."
        )

    hostname = normalise_hostname(args.hostname)
    if not hostname or not HOSTNAME_PATTERN.match(hostname):
        parser.error(f"Invalid GitHub hostname: [{hostname}]")

    device_code_url, access_token_url, user_api_url = resolve_endpoints(hostname)

    print("=" * 50)
    print("GitHub Device Flow - User Access Token")
    print("=" * 50)
    print("\n⚠️  WARNING: For demonstration/testing only. "
          "Not for production use.")
    print(f"\nClient ID: {client_id}")
    if hostname.lower() != DEFAULT_HOSTNAME:
        print(f"Hostname:  {hostname}")
    print()

    # Step 1: Get device code
    print("Requesting device code...")
    device_data = request_device_code(client_id, device_code_url)

    user_code = device_data["user_code"]
    verification_uri = device_data["verification_uri"]
    device_code = device_data["device_code"]
    interval = device_data.get("interval", DEFAULT_POLL_INTERVAL)

    # Step 2: Prompt user to authorize
    print("\n" + "=" * 50)
    print("ACTION REQUIRED")
    print("=" * 50)
    print(f"\n1. Open: {verification_uri}")
    print(f"2. Enter code: {user_code}")
    print()

    # Auto-open browser via stdlib (cross-platform) and copy code to
    # clipboard via pbcopy (macOS-only). Both are graceful no-ops where
    # unsupported (Linux without pbcopy, headless CI, SSH sessions, etc.).
    # Success messages are gated on the underlying call so we don't claim
    # "copied" / "opening" when the tool fails.
    if shutil.which("pbcopy"):
        result = subprocess.run(["pbcopy"], input=user_code, text=True, check=False)
        if result.returncode == 0:
            print("📋 Code copied to clipboard.")
    if webbrowser.open(verification_uri, new=2):
        print("🌐 Opening browser...")

    print("\nWaiting for authorisation...")

    # Step 3: Poll for token
    token_data = poll_for_token(client_id, device_code, interval, access_token_url)

    access_token = token_data["access_token"]
    token_type = token_data.get("token_type", "bearer")
    scope = token_data.get("scope", "")

    print("\n" + "=" * 50)
    print("SUCCESS!")
    print("=" * 50)
    print(f"\nToken Type:   {token_type}")
    print(f"Scope:        {scope}")
    if len(access_token) >= TOKEN_MIN_LENGTH_FOR_TRUNCATION:
        if "_" in access_token:
            prefix = access_token.split("_", 1)[0] + "_"
        else:
            prefix = access_token[:4]
        print(f"Access Token: {prefix}***{access_token[-TOKEN_SUFFIX_LENGTH:]}")
    else:
        print(f"Access Token: {access_token}")

    # Step 4: Test the token
    print("\nTesting token by fetching user info...")
    user_info = test_token(access_token, user_api_url)
    print(f"\nAuthenticated as: {user_info['login']}")
    print(f"Name:             {user_info.get('name', 'N/A')}")
    print(f"Email:            {user_info.get('email', 'N/A')}")

    # NOTE: Printing the full token is intentional for demo/testing purposes.
    # This allows token capture via: export TOKEN=$(python device_flow.py ... | tail -1)
    # For production use, store tokens securely rather than printing to stdout.
    print("\n" + "=" * 50)
    print("FULL ACCESS TOKEN (for use in other applications):")
    print("=" * 50)
    print(access_token)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCancelled by user.")
        sys.exit(1)
    except (DeviceFlowError, requests.RequestException) as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)
