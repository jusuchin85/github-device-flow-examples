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
import sys
import time

import requests

# Note: For GitHub Apps, permissions are defined in the App's settings,
# not requested via scope parameter (that's for OAuth Apps only).

DEVICE_CODE_URL = "https://github.com/login/device/code"
ACCESS_TOKEN_URL = "https://github.com/login/oauth/access_token"
DEFAULT_POLL_INTERVAL = 5
SLOW_DOWN_INCREMENT = 5
TOKEN_MIN_LENGTH_FOR_TRUNCATION = 30
TOKEN_PREFIX_LENGTH = 20
TOKEN_SUFFIX_LENGTH = 10


class DeviceFlowError(Exception):
    """Base exception for Device Flow errors."""

    pass


class DeviceCodeExpiredError(DeviceFlowError):
    """Raised when the device code has expired."""

    pass


class AuthorizationDeniedError(DeviceFlowError):
    """Raised when the user denies authorisation."""

    pass


def request_device_code(client_id: str) -> dict:
    """
    Request a device code from GitHub.

    Parameters
    ----------
    client_id : str
        The GitHub App's Client ID.

    Returns
    -------
    dict
        Response containing device_code, user_code, and verification_uri.
    """
    response = requests.post(
        DEVICE_CODE_URL,
        data={"client_id": client_id},
        headers={"Accept": "application/json"},
    )
    response.raise_for_status()
    return response.json()


def poll_for_token(client_id: str, device_code: str, interval: int) -> dict:
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
            ACCESS_TOKEN_URL,
            data={
                "client_id": client_id,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            },
            headers={"Accept": "application/json"},
        )
        response.raise_for_status()
        data = response.json()

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
            raise DeviceFlowError(f"Unexpected error: {error}")


def test_token(access_token: str) -> dict:
    """
    Test the token by fetching the authenticated user's info.

    Parameters
    ----------
    access_token : str
        The user access token to test.

    Returns
    -------
    dict
        User information from the GitHub API.
    """
    response = requests.get(
        "https://api.github.com/user",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/vnd.github+json",
        },
    )
    response.raise_for_status()
    return response.json()


def main() -> None:
    """Run the Device Flow authentication process."""
    parser = argparse.ArgumentParser(
        description="GitHub App Device Flow - User Access Token"
    )
    parser.add_argument(
        "-c", "--client-id",
        default=os.environ.get("GITHUB_CLIENT_ID"),
        help="GitHub App Client ID (or set GITHUB_CLIENT_ID env var)",
    )
    args = parser.parse_args()

    if not args.client_id:
        parser.error(
            "Client ID required. Use --client-id or set "
            "GITHUB_CLIENT_ID env var."
        )

    client_id = args.client_id

    print("=" * 50)
    print("GitHub Device Flow - User Access Token")
    print("=" * 50)
    print("\n⚠️  WARNING: For demonstration/testing only. "
          "Not for production use.")
    print(f"\nClient ID: {client_id}\n")

    # Step 1: Get device code
    print("Requesting device code...")
    device_data = request_device_code(client_id)

    user_code = device_data["user_code"]
    verification_uri = device_data["verification_uri"]
    device_code = device_data["device_code"]
    interval = device_data.get("interval", DEFAULT_POLL_INTERVAL)

    # Step 2: Prompt user to authorize
    print("\n" + "=" * 50)
    print("ACTION REQUIRED")
    print("=" * 50)
    print(f"\n1. Go to: {verification_uri}")
    print(f"2. Enter code: {user_code}")
    print("\nWaiting for authorisation...")

    # Step 3: Poll for token
    token_data = poll_for_token(client_id, device_code, interval)

    access_token = token_data["access_token"]
    token_type = token_data.get("token_type", "bearer")
    scope = token_data.get("scope", "")

    print("\n" + "=" * 50)
    print("SUCCESS!")
    print("=" * 50)
    print(f"\nToken Type: {token_type}")
    print(f"Scope: {scope}")
    if len(access_token) >= TOKEN_MIN_LENGTH_FOR_TRUNCATION:
        print(f"Access Token: {access_token[:TOKEN_PREFIX_LENGTH]}..."
              f"{access_token[-TOKEN_SUFFIX_LENGTH:]}")
    else:
        print(f"Access Token: {access_token}")

    # Step 4: Test the token
    print("\nTesting token by fetching user info...")
    user_info = test_token(access_token)
    print(f"\nAuthenticated as: {user_info['login']}")
    print(f"Name: {user_info.get('name', 'N/A')}")
    print(f"Email: {user_info.get('email', 'N/A')}")

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
