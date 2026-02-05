# Common Issues & Troubleshooting

## "Client ID required" error

Provide the Client ID via `--client-id` flag or `GITHUB_CLIENT_ID` environment variable.

```bash
# Using flag
python device_flow.py --client-id YOUR_CLIENT_ID
node device_flow.js --client-id YOUR_CLIENT_ID

# Using environment variable
export GITHUB_CLIENT_ID=YOUR_CLIENT_ID
python device_flow.py
node device_flow.js
```

## "Device code expired" error

The code expires after ~15 minutes. Run the script again to get a new code.

## 404 at github.com/login/device

- Ensure **Device flow** is enabled in your GitHub App settings
- Ensure a **Callback URL** is set (even `http://localhost` works)

## "Uh oh, we couldn't find anything" when entering code

The code may have expired. Run the script again to get a fresh code and
enter it promptly.

## Token not appearing in enterprise credentials

There may be a delay before tokens appear in the enterprise credentials
table. Wait a few minutes and refresh.

## Token permissions don't match expected

GitHub Apps define permissions in the **App's settings** (Permissions &
events), not at authorisation time. Update your GitHub App's user
permissions to change what the token can access.

## Using the Token

Once you have the token, you can use it for API calls:

```bash
export TOKEN=ghu_xxxxxxxx

# Get authenticated user info
curl -H "Authorization: Bearer $TOKEN" \
  https://api.github.com/user

# Access enterprise resources (if permitted)
curl -H "Authorization: Bearer $TOKEN" \
  https://api.github.com/enterprises/YOUR_ENTERPRISE/repos

# Access organization repos (if permitted)
curl -H "Authorization: Bearer $TOKEN" \
  https://api.github.com/orgs/YOUR_ORG/repos
```

## Token Details

| Property | Value |
| ---------- | ------- |
| **Prefix** | `ghu_` |
| **Type** | User access token (user-to-server) |
| **Acts as** | The user who authorised |
| **Permissions** | Defined in GitHub App settings (not in script) |
| **Expiration** | ~8 hours (shown in API response headers) |
