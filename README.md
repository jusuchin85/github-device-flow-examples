# GitHub Device Flow Examples

End-to-end OAuth Device Flow examples for **both GitHub Apps** (`ghu_` tokens) and **OAuth Apps** (`gho_` tokens), in four languages — perfect for CLI applications that need user-attributed access without standing up a callback web server.

> [!WARNING]
> These scripts are for **demonstration and testing purposes only**. The full token is printed to stdout, which may expose it in logs and shell history. Do not use as-is in production.

## Which one do I need?

| | GitHub App ([`github-app/`](github-app/)) | OAuth App ([`oauth-app/`](oauth-app/)) |
|---|---|---|
| Token prefix | `ghu_` | `gho_` |
| Permission model | Fine-grained app-level permissions | OAuth scopes |
| Client Secret on token exchange? | ❌ Not used (public client) | ✅ Required (confidential client) |
| `scope` parameter? | ❌ Ignored | ✅ Honoured |
| Default token TTL | ~8 hours, refreshable | Non-expiring |
| Server-to-server installation tokens? | ✅ Yes (separate flow, not in this repo) | ❌ No |
| Recommended for new builds? | ✅ Yes | Use only when you need scopes / non-expiring tokens |

If you're starting fresh, **prefer GitHub Apps**. If you're reproducing an OAuth-specific issue or integrating with an existing OAuth-only flow, **use OAuth Apps**.

## Repository layout

```
.
├── github-app/                # GitHub App device flow (ghu_ tokens)
│   ├── README.md              ← start here for github-app
│   ├── setup.md               ← creating a GitHub App
│   ├── device_flow.{sh,py,js,go}
│   ├── shell.md / python.md / nodejs.md / go.md
│   └── requirements.txt       ← Python deps
│
├── oauth-app/                 # OAuth App device flow (gho_ tokens)
│   ├── README.md              ← start here for oauth-app
│   ├── setup.md               ← creating an OAuth App + EMU notes
│   ├── device_flow.{sh,py,js,go}
│   ├── shell.md / python.md / nodejs.md / go.md
│   └── requirements.txt       ← Python deps
│
└── common-issues.md           ← cross-mode troubleshooting
```

## How Device Flow works

The same four-step OAuth 2.0 Device Authorization Grant ([RFC 8628](https://datatracker.ietf.org/doc/html/rfc8628)) underpins both flows:

1. The CLI calls `POST /login/device/code` to obtain a `user_code` and a `verification_uri`.
2. You visit `github.com/login/device`, enter the user code, and authorise.
3. The CLI polls `POST /login/oauth/access_token` until the user authorises (or denies / expires).
4. GitHub returns the user access token.

The differences between the two flows live in the parameters of those two calls — see the comparison table above and the per-subdir READMEs for protocol detail.

## Quick start

Pick a subdir based on the table above, then follow that subdir's README.

**OAuth App example:**

```bash
cd oauth-app
export GITHUB_CLIENT_SECRET='your-client-secret'
./device_flow.sh --client-id YOUR_CLIENT_ID
```

**GitHub App example:**

```bash
cd github-app
./device_flow.sh --client-id YOUR_CLIENT_ID
```

## Secret hygiene

For OAuth Apps, the **Client Secret is read from the `GITHUB_CLIENT_SECRET` env var only** — never from a CLI flag. Flags leak to shell history, `ps` output, and audit logs, so we deliberately don't accept them. The Client ID is public and can be passed either way.

## Troubleshooting

See [common-issues.md](common-issues.md) for cross-mode gotchas (Client ID format mismatches, EMU SSO behaviour, common 403 causes, and more).

## See Also

- [Authorising OAuth Apps](https://docs.github.com/apps/oauth-apps/authorizing-oauth-apps)
- [Authenticating on behalf of a user (GitHub Apps)](https://docs.github.com/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-with-a-github-app-on-behalf-of-a-user)
- [Generating a user access token (Device Flow)](https://docs.github.com/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app#using-the-device-flow-to-generate-a-user-access-token)
- [Device Flow specification (RFC 8628)](https://datatracker.ietf.org/doc/html/rfc8628)
