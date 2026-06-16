# Common Issues & Troubleshooting

Cross-mode troubleshooting for both GitHub App and OAuth App device flow scripts.

## "Client ID required" error

Provide the Client ID via the `--client-id` flag or the `GITHUB_CLIENT_ID` environment variable:

```bash
# Using the flag
./oauth-app/device_flow.sh --client-id YOUR_CLIENT_ID
python oauth-app/device_flow.py --client-id YOUR_CLIENT_ID

# Using the env var
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
./oauth-app/device_flow.sh
```

## "GITHUB_CLIENT_SECRET env var is required for OAuth Apps"

Only the OAuth App scripts require a Client Secret. Export it before running — the scripts deliberately **never accept secrets via CLI flags** because flags leak to shell history, `ps` output, and audit logs:

```bash
export GITHUB_CLIENT_SECRET='your-client-secret'
./oauth-app/device_flow.sh --client-id YOUR_CLIENT_ID
```

GitHub Apps don't need a Client Secret — they're public clients in the OAuth sense.

## `{"error": "Not Found"}` from `/login/device/code`

GitHub returns a generic `Not Found` for several distinct causes:

1. **Wrong client ID format.** The most common foot-gun is a copy-paste that includes a stray prefix or whitespace. Verify the length and shape:
   - GitHub App Client IDs: start with `Iv` (e.g., `Iv23liXXXXXXXXXXXXXX`)
   - OAuth App Client IDs: start with `Ov` (newer) or `Iv` (older), commonly 20 chars
   - Check `echo "Length: ${#GITHUB_CLIENT_ID}"` — if it's longer than expected, you've got trailing whitespace
2. **Device Flow not enabled** on the app. Open the app's settings page and tick **Enable Device Flow**.
3. **Missing Authorization callback URL** on the app. Even though Device Flow doesn't use the callback, one must be configured (e.g., `http://localhost`).

The shell, Python, Node.js, and Go scripts all validate the Client ID shape with a regex before hitting GitHub, so you'll get a clear local error rather than this cryptic upstream response — but if you see `Not Found`, the four causes above are the place to look.

## "Device code expired" error

The user code expires after ~15 minutes. Run the script again to get a new code, and enter it promptly.

## 404 at `github.com/login/device`

- Ensure **Device Flow** is enabled on your app's settings page.
- Ensure an **Authorization callback URL** is set (even `http://localhost` works).

## "Uh oh, we couldn't find anything" when entering the code

The code may have expired. Run the script again to get a fresh code and enter it promptly.

## EMU vs classic GHEC differences

OAuth tokens minted on EMU enterprises behave fundamentally differently from those on classic GHEC orgs.

| Aspect | EMU | Classic GHEC |
|---|---|---|
| Identity source | IdP only (Entra/Okta) | GitHub.com account, optional SAML overlay |
| `x-github-sso: required` header on org endpoints | **Does not appear** — token issued post-IdP is already SSO-authorised | Appears on first call; user must visit the URL to authorise the token |
| OAuth App ownership | Org-owned only (no personal OAuth Apps) | Personal or org-owned |

If you're seeing a 403 on EMU org endpoints despite a fresh, valid token, **the cause is rarely missing SSO authorisation**. Investigate instead:

- Is the OAuth/GitHub App owned by an org **outside** the EMU enterprise?
- Does the destination org have *Restrict OAuth app access by users in the enterprise* enabled, with the app not yet approved?
- For cross-org access within the same EMU: did the destination org's owner approve the app?
- Has the IdP session expired? (Token still valid but underlying auth context lapsed.)

## Token not appearing in enterprise credentials (GitHub Apps)

There may be a short delay before tokens appear in the enterprise credentials table. Wait a few minutes and refresh.

## Token permissions don't match expected (GitHub Apps)

GitHub Apps define permissions on the App's settings page (**Permissions & events**), not in the script's request. Update the App's user permissions to change what the token can access. OAuth Apps work differently — they declare scopes at request time via the `--scope` flag.

## Using the Token

Once you have the token, you can use it for API calls:

```bash
export TOKEN=gho_xxxxxxxx   # or ghu_xxxxxxxx for GitHub Apps

# Get authenticated user info
curl -H "Authorization: Bearer $TOKEN" https://api.github.com/user

# Access organization repos (if permitted)
curl -H "Authorization: Bearer $TOKEN" https://api.github.com/orgs/YOUR_ORG/repos

# Check rate limit (EMU users get 15,000/hr by default — vs 5,000/hr on dotcom)
curl -H "Authorization: Bearer $TOKEN" https://api.github.com/rate_limit
```

## Token reference

| Property | GitHub App | OAuth App |
|---|---|---|
| **Prefix** | `ghu_` | `gho_` |
| **Type** | User-to-server | User access token |
| **Acts as** | The user who authorised | The user who authorised |
| **Permissions** | Defined in App settings | Scopes from `--scope` flag |
| **Default expiration** | ~8 hours (refreshable) | Non-expiring |
| **Client Secret needed?** | No | Yes (env var only) |
