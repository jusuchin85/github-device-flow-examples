# Setting Up an OAuth App for Device Flow

This guide walks you through creating an OAuth App and configuring it for the Device Flow.

> [!NOTE]
> Looking for **GitHub App** setup instead? See [`../github-app/setup.md`](../github-app/setup.md). The two app types are distinct and use different protocol details.

## Step 1: Create an OAuth App

1. Go to your GitHub settings:
   - **Personal account**: Settings → Developer settings → OAuth Apps
   - **Organization**: Organization Settings → Developer settings → OAuth Apps
   - **Enterprise (EMU)**: Settings inside an organisation owned by your EMU enterprise — OAuth Apps are always org-owned in EMU

2. Click **New OAuth App**

3. Fill in the required fields:
   - **Application name**: A unique name (e.g., `my-cli-tool-test`)
   - **Homepage URL**: Your app's homepage (can be a GitHub repo URL)

## Step 2: Configure Callback URL

Even though Device Flow doesn't use a callback URL, **one must be configured** for the Device Flow option to work.

1. In the **Authorization callback URL** field, enter: `http://localhost`

   ⚠️ **Important:** Without a Callback URL, you'll get a 404 error when visiting `github.com/login/device`.

## Step 3: Enable Device Flow

1. Tick the ✅ **Enable Device Flow** checkbox.

## Step 4: Register and Generate Client Secret

1. Click **Register application** to create the OAuth App.
2. On the next page, locate the **Client ID** (e.g. `Ov23liXXXXXXXXXXXXXX`).
3. Click **Generate a new client secret** — copy the value immediately. You won't be able to read it again.

## Step 5: Configure Scopes (at runtime, not registration time)

Unlike GitHub Apps, OAuth Apps don't declare permissions on the App registration page. Instead, the **scopes** the user grants are declared in the device-flow request itself, via the `--scope` flag of the script.

The default scope set in these examples is `repo,read:org`. Override with `--scope`:

```bash
./device_flow.sh --client-id "$GITHUB_CLIENT_ID" --scope "repo,read:org,user"
```

A full list of scopes is in [Scopes for OAuth Apps](https://docs.github.com/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps).

## EMU-specific notes

OAuth Apps on EMU enterprises behave differently from classic GHEC:

| Aspect | EMU | Classic GHEC |
|---|---|---|
| App ownership | Org-owned only (no personal-account OAuth Apps) | Personal or org-owned |
| User authorisation | Always routes through your IdP (Entra/Okta) | Optional SAML SSO step depending on org policy |
| `x-github-sso: required` header on org endpoints | **Does not appear** — tokens are SSO-authorised at issuance | Appears on the first call after token issuance; user must follow the URL to SSO-authorise |
| Restrict OAuth app access policy | May block the app until org owner approves | Same — may need org-level approval |

The most common ticket symptom on EMU is **403 on org endpoints despite a fresh token** — but it's almost never a missing SSO authorisation. More likely causes:

- App owned by an org outside the EMU enterprise
- Org's *Restrict OAuth app access* policy blocking the app
- Cross-org access where the destination org owner hasn't approved
- IdP session expired (token still valid but underlying IdP context lapsed)

## Quick Reference

| Setting | Value |
|---|---|
| Authorization callback URL | `http://localhost` (required) |
| Enable Device Flow | ✅ Ticked |
| Client ID | Starts with `Ov` (newer) or `Iv` (older) |
| Client Secret | 40-char hex; generate from app settings page |

## Next Steps

Set the Client Secret as an env var (never a CLI flag), then run the device flow script:

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'

# Shell
./device_flow.sh --client-id YOUR_CLIENT_ID

# Python
python device_flow.py --client-id YOUR_CLIENT_ID

# Node.js
node device_flow.js --client-id YOUR_CLIENT_ID

# Go
go run device_flow.go --client-id YOUR_CLIENT_ID
```

## See Also

- [Creating an OAuth app](https://docs.github.com/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app)
- [Authorising OAuth Apps](https://docs.github.com/apps/oauth-apps/authorizing-oauth-apps)
- [Scopes for OAuth Apps](https://docs.github.com/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
- [Device Flow specification (RFC 8628)](https://datatracker.ietf.org/doc/html/rfc8628)
- [`../common-issues.md`](../common-issues.md) — cross-mode troubleshooting
