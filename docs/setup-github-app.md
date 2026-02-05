# Setting Up a GitHub App for Device Flow

This guide walks you through creating a GitHub App and configuring it
for the OAuth Device Flow.

## Step 1: Create a GitHub App

1. Go to your GitHub settings:
   - **Personal account**: Settings → Developer settings → GitHub Apps
   - **Organization**: Organization Settings → Developer settings → GitHub Apps

2. Click **New GitHub App**

3. Fill in the required fields:
   - **GitHub App name**: A unique name (e.g., `my-cli-tool`)
   - **Homepage URL**: Your app's homepage (can be a GitHub repo URL)

## Step 2: Configure Callback URL

Even though Device Flow doesn't use a callback URL, **one must be
configured** for the Device Flow option to work.

1. In the **Callback URL** field, enter: `http://localhost`

   ⚠️ **Important:** Without a Callback URL, you'll get a 404 error
   when visiting `github.com/login/device`.

## Step 3: Enable Device Flow

1. Look for **Enable Device Flow** checkbox (usually under "Post installation"
   or "Optional features" depending on your GitHub version)
2. Check ✅ **Enable Device Flow**

## Step 4: Set Permissions

Configure the permissions your app needs:

1. Scroll to **Permissions & events**
2. Expand **Account permissions** and/or **Repository permissions**
3. Select the access level needed for each permission

Common permissions for user access tokens:

| Permission | Access | Use Case |
| ------------ | -------- | ---------- |
| **Contents** | Read | Read repository files |
| **Metadata** | Read | Basic repo info (usually required) |
| **Pull requests** | Read/Write | Create or manage PRs |
| **Issues** | Read/Write | Create or manage issues |

## Step 5: Choose Installation Scope

Under **Where can this GitHub App be installed?**:

- **Only on this account**: Restricts to your account/org only
- **Any account**: Allows anyone to install your app

For personal/internal tools, "Only on this account" is usually sufficient.

## Step 6: Create the App

1. Click **Create GitHub App**
2. You'll be redirected to your new app's settings page

## Step 7: Find Your Client ID

On your app's settings page, locate the **Client ID**:

```text
App ID:       123456          ← Not this one!
Client ID:    Iv23liXXXXXXXX  ← Use this one!
```

> [!NOTE]
> The **Client ID** (starts with `Iv`) is different from the **App ID**
> (numeric). Device Flow uses the Client ID.

## Step 8: Install the App

You must install the app before generating user tokens:

1. Go to your app's settings page
2. Click **Install App** in the left sidebar
3. Select the account/organisation to install on
4. Choose **All repositories** or **Only select repositories**
5. Click **Install**

## Quick Reference

| Setting | Value |
|---------|-------|
| Callback URL | `http://localhost` (required) |
| Device Flow | ✅ Enabled |
| Client ID | Starts with `Iv` (not the numeric App ID) |

## Next Steps

Once you configure your app, use the Client ID with any of the
Device Flow scripts:

```bash
# Python
python device_flow.py --client-id YOUR_CLIENT_ID

# Node.js
node device_flow.js --client-id YOUR_CLIENT_ID

# Go
go run device_flow.go --client-id YOUR_CLIENT_ID

# Shell
./device_flow.sh --client-id YOUR_CLIENT_ID
```

## See Also

- [Registering a GitHub App](https://docs.github.com/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)
- [Installing your own GitHub App](https://docs.github.com/apps/using-github-apps/installing-your-own-github-app)
- [Permissions required for GitHub Apps](https://docs.github.com/rest/authentication/permissions-required-for-github-apps)
