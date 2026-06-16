#!/usr/bin/env node
/**
 * OAuth App Device Flow - User Access Token Generation
 *
 * This script demonstrates how to obtain a user access token using the
 * OAuth Device Flow with an OAuth App, which is ideal for CLI applications
 * that need user-attributed access without standing up a web server.
 *
 * WARNING: This script is for demonstration and testing purposes only.
 * Do not use in production. The access token is printed to stdout which
 * may expose it in logs or shell history.
 *
 * Why an OAuth App and not a GitHub App?
 *   - You need scopes (granular permissions are a GitHub App concept).
 *   - You need a non-expiring user token by default.
 *   - You're integrating with an existing OAuth-only flow.
 * For most modern use cases, GitHub Apps are preferred. See the sibling
 * github-app/ subdir.
 */

const DEVICE_CODE_URL = "https://github.com/login/device/code";
const ACCESS_TOKEN_URL = "https://github.com/login/oauth/access_token";
const DEFAULT_POLL_INTERVAL = 5;
const SLOW_DOWN_INCREMENT = 5;
const TOKEN_MIN_LENGTH_FOR_TRUNCATION = 30;
const TOKEN_SUFFIX_LENGTH = 8;
const DEFAULT_SCOPE = "repo,read:org";
const CLIENT_ID_PATTERN = /^[A-Za-z0-9._-]+$/;

const { spawnSync } = require("node:child_process");

function hasCommand(cmd) {
  const r = spawnSync("which", [cmd], { stdio: "ignore" });
  return r.status === 0;
}

/**
 * Step 1: Request a device code from GitHub.
 * Includes scope (OAuth App-specific — GitHub Apps use installation permissions).
 */
async function requestDeviceCode(clientId, scope) {
  const response = await fetch(DEVICE_CODE_URL, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({ client_id: clientId, scope }),
  });

  if (!response.ok) {
    throw new Error(`Failed to get device code: ${response.status}`);
  }

  return response.json();
}

/**
 * Step 2: Poll GitHub until the user authorizes or an error occurs.
 * OAuth Apps are confidential clients, so the token exchange requires
 * the client_secret in addition to the device_code.
 */
async function pollForToken(clientId, clientSecret, deviceCode, interval) {
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  while (true) {
    const response = await fetch(ACCESS_TOKEN_URL, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        device_code: deviceCode,
        grant_type: "urn:ietf:params:oauth:grant-type:device_code",
      }),
    });

    if (!response.ok) {
      throw new Error(`Failed to poll for token: ${response.status}`);
    }

    const data = await response.json();

    if (data.access_token) {
      return data;
    }

    switch (data.error) {
      case "authorization_pending":
        // User hasn't authorized yet, keep polling
        await sleep(interval * 1000);
        break;
      case "slow_down":
        // Polling too fast, increase interval
        interval += SLOW_DOWN_INCREMENT;
        await sleep(interval * 1000);
        break;
      case "expired_token":
        throw new Error("Device code expired. Please restart the process.");
      case "access_denied":
        throw new Error("User denied authorisation.");
      case undefined:
        throw new Error(
          "Received invalid response from GitHub (no access_token or error field)"
        );
      default: {
        const description = data.error_description || data.error;
        throw new Error(`Unexpected error: ${description}`);
      }
    }
  }
}

/**
 * Test the token by fetching the authenticated user's info.
 */
async function testToken(accessToken) {
  const response = await fetch("https://api.github.com/user", {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/vnd.github+json",
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch user: ${response.status}`);
  }

  return response.json();
}

/**
 * Parse command line arguments.
 */
function parseArgs() {
  const args = process.argv.slice(2);
  let clientId = (process.env.GITHUB_CLIENT_ID || "").trim();
  let scope = DEFAULT_SCOPE;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--client-id" || args[i] === "-c") {
      const next = args[i + 1];
      if (!next || next.startsWith("-")) {
        console.error(
          "Error: --client-id (or -c) flag requires a value. Usage: --client-id <id>"
        );
        process.exit(1);
      }
      clientId = next;
      i++;
    } else if (args[i] === "--scope" || args[i] === "-s") {
      const next = args[i + 1];
      if (!next || next.startsWith("-")) {
        console.error(
          "Error: --scope (or -s) flag requires a value. Usage: --scope <scope>"
        );
        process.exit(1);
      }
      scope = next;
      i++;
    } else if (args[i] === "--help" || args[i] === "-h") {
      console.log(`
Usage: node device_flow.js [options]

Options:
  -c, --client-id <id>  OAuth App Client ID (or set GITHUB_CLIENT_ID env var)
  -s, --scope <scope>   Comma-separated OAuth scopes (default: ${DEFAULT_SCOPE})
  -h, --help            Show this help message

Required env vars:
  GITHUB_CLIENT_SECRET  OAuth App Client Secret. Env-var only — we never
                        accept secrets as CLI flags because flags leak to
                        shell history and ps output.
      `);
      process.exit(0);
    } else if (args[i].startsWith("-")) {
      console.error(`Error: Unknown option: ${args[i]}`);
      console.error('Use "--help" or "-h" to see available options.');
      process.exit(1);
    }
  }

  if (!clientId) {
    console.error(
      "Error: Client ID required. Use --client-id or set GITHUB_CLIENT_ID env var."
    );
    process.exit(1);
  }

  if (!CLIENT_ID_PATTERN.test(clientId)) {
    console.error(
      `Error: GITHUB_CLIENT_ID contains unexpected characters.\n` +
      `   Got: [${clientId}] (${clientId.length} chars)\n` +
      `   Re-export cleanly to fail fast on stray prefixes.`
    );
    process.exit(1);
  }

  const clientSecret = (process.env.GITHUB_CLIENT_SECRET || "").trim();
  if (!clientSecret) {
    console.error(
      "Error: GITHUB_CLIENT_SECRET env var is required for OAuth Apps.\n" +
      "   Export it before running:\n" +
      "     export GITHUB_CLIENT_SECRET='your-secret'\n" +
      "   We never accept secrets via CLI flags — they leak to shell\n" +
      "   history, ps output, and audit logs."
    );
    process.exit(1);
  }

  return { clientId, clientSecret, scope };
}

async function main() {
  const { clientId, clientSecret, scope } = parseArgs();

  console.log("=".repeat(50));
  console.log("OAuth App Device Flow - User Access Token");
  console.log("=".repeat(50));
  console.log("\n⚠️  WARNING: For demonstration/testing only. Not for production use.");
  console.log(`\nClient ID: ${clientId}`);
  console.log(`Scope:     ${scope}\n`);

  // Step 1: Get device code
  console.log("Requesting device code...");
  const deviceData = await requestDeviceCode(clientId, scope);

  const { user_code, verification_uri, device_code, interval = DEFAULT_POLL_INTERVAL } = deviceData;

  // Step 2: Prompt user to authorize
  console.log("\n" + "=".repeat(50));
  console.log("ACTION REQUIRED");
  console.log("=".repeat(50));
  console.log(`\n1. Open: ${verification_uri}`);
  console.log(`2. Enter code: ${user_code}`);
  console.log();

  // Auto-open browser and copy code to clipboard (macOS-only). Both are
  // graceful no-ops on non-macOS systems (Linux, BSD, headless CI, SSH
  // sessions, etc.) since they only check for `open` and `pbcopy`.
  // Pbcopy success is gated on exit status so we don't claim "copied"
  // when the subprocess fails (e.g. permission denied in restricted CI).
  if (hasCommand("pbcopy")) {
    const r = spawnSync("pbcopy", { input: user_code });
    if (r.status === 0) {
      console.log("📋 Code copied to clipboard.");
    }
  }
  if (hasCommand("open")) {
    const r = spawnSync("open", [verification_uri], { stdio: "ignore" });
    if (r.status === 0) {
      console.log("🌐 Opening browser...");
    }
  }

  console.log("\nWaiting for authorisation...");

  // Step 3: Poll for token
  const tokenData = await pollForToken(clientId, clientSecret, device_code, interval);

  const { access_token, token_type = "bearer", scope: grantedScope = "" } = tokenData;

  console.log("\n" + "=".repeat(50));
  console.log("SUCCESS!");
  console.log("=".repeat(50));
  console.log(`\nToken Type:    ${token_type}`);
  console.log(`Granted Scope: ${grantedScope}`);
  if (access_token.length >= TOKEN_MIN_LENGTH_FOR_TRUNCATION) {
    const prefix = access_token.includes("_")
      ? access_token.split("_", 1)[0] + "_"
      : access_token.slice(0, 4);
    console.log(
      `Access Token:  ${prefix}***${access_token.slice(-TOKEN_SUFFIX_LENGTH)}`
    );
  } else {
    console.log(`Access Token:  ${access_token}`);
  }

  // Step 4: Test the token
  console.log("\nTesting token by fetching user info...");
  const userInfo = await testToken(access_token);
  console.log(`\nAuthenticated as: ${userInfo.login}`);
  console.log(`Name:             ${userInfo.name || "N/A"}`);
  console.log(`Email:            ${userInfo.email || "N/A"}`);

  // NOTE: Printing the full token is intentional for demo/testing purposes.
  // This allows token capture via: export TOKEN=$(node device_flow.js ... | tail -1)
  // For production use, store tokens securely rather than printing to stdout.
  console.log("\n" + "=".repeat(50));
  console.log("FULL ACCESS TOKEN (for use in other applications):");
  console.log("=".repeat(50));
  console.log(access_token);
}

main().catch((error) => {
  console.error(`\nError: ${error.message}`);
  process.exit(1);
});
