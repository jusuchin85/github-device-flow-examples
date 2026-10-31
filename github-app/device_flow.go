// GitHub App Device Flow - User-to-Server Token Generation
//
// This script demonstrates how to obtain a user access token using the
// OAuth Device Flow, which is ideal for CLI applications.
//
// WARNING: This script is for demonstration and testing purposes only.
// Do not use in production. The access token is printed to stdout which
// may expose it in logs or shell history.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strings"
	"time"
)

const (
	defaultHostname             = "github.com"
	defaultPollInterval         = 5
	slowDownIncrement           = 5
	tokenMinLengthForTruncation = 30
	tokenSuffixLength           = 8
	requestTimeout              = 30 * time.Second
	apiVersion                  = "2022-11-28"
	userAgent                   = "github-device-flow-examples"
)

var (
	clientIDPattern = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)
	hostnamePattern = regexp.MustCompile(`^[A-Za-z0-9.-]+(:[0-9]+)?$`)
	httpClient      = &http.Client{Timeout: requestTimeout}
)

// DeviceCodeResponse represents the response from the device code request.
type DeviceCodeResponse struct {
	DeviceCode      string `json:"device_code"`
	UserCode        string `json:"user_code"`
	VerificationURI string `json:"verification_uri"`
	ExpiresIn       int    `json:"expires_in"`
	Interval        int    `json:"interval"`
}

// TokenResponse represents the response from the token exchange request.
type TokenResponse struct {
	AccessToken      string `json:"access_token"`
	TokenType        string `json:"token_type"`
	Scope            string `json:"scope"`
	Error            string `json:"error"`
	ErrorDescription string `json:"error_description"`
}

// UserInfo represents the authenticated user's information.
type UserInfo struct {
	Login string  `json:"login"`
	Name  *string `json:"name"`
	Email *string `json:"email"`
}

func normaliseHostname(hostname string) string {
	h := strings.TrimSpace(hostname)
	lower := strings.ToLower(h)
	if strings.HasPrefix(lower, "https://") {
		h = h[len("https://"):]
	} else if strings.HasPrefix(lower, "http://") {
		h = h[len("http://"):]
	}
	return strings.TrimRight(h, "/")
}

func resolveEndpoints(hostname string) (deviceCodeURL, accessTokenURL, userAPIURL string) {
	hostOnly := strings.SplitN(strings.ToLower(hostname), ":", 2)[0]
	deviceCodeURL = fmt.Sprintf("https://%s/login/device/code", hostname)
	accessTokenURL = fmt.Sprintf("https://%s/login/oauth/access_token", hostname)
	if hostOnly == "github.com" || strings.HasSuffix(hostOnly, ".ghe.com") {
		userAPIURL = fmt.Sprintf("https://api.%s/user", hostname)
	} else {
		userAPIURL = fmt.Sprintf("https://%s/api/v3/user", hostname)
	}
	return deviceCodeURL, accessTokenURL, userAPIURL
}

// requestDeviceCode requests a device code from GitHub.
func requestDeviceCode(clientID, deviceCodeURL string) (*DeviceCodeResponse, error) {
	data := url.Values{"client_id": {clientID}}

	req, err := http.NewRequest("POST", deviceCodeURL, strings.NewReader(data.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("User-Agent", userAgent)

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get device code: %s - %s", resp.Status, strings.TrimSpace(string(body)))
	}

	var result DeviceCodeResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to get device code: received non-JSON response from GitHub")
	}

	return &result, nil
}

// pollForToken polls GitHub until the user authorizes or an error occurs.
func pollForToken(clientID, deviceCode string, interval int, accessTokenURL string) (*TokenResponse, error) {
	data := url.Values{
		"client_id":   {clientID},
		"device_code": {deviceCode},
		"grant_type":  {"urn:ietf:params:oauth:grant-type:device_code"},
	}

	for {
		req, err := http.NewRequest("POST", accessTokenURL, strings.NewReader(data.Encode()))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Accept", "application/json")
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		req.Header.Set("User-Agent", userAgent)

		resp, err := httpClient.Do(req)
		if err != nil {
			return nil, err
		}

		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			return nil, readErr
		}

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("GitHub API returned status %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
		}

		var result TokenResponse
		if err := json.Unmarshal(body, &result); err != nil {
			return nil, fmt.Errorf("failed to poll for token: received non-JSON response from GitHub")
		}

		if result.AccessToken != "" {
			return &result, nil
		}

		switch result.Error {
		case "authorization_pending":
			// User hasn't authorized yet, keep polling
			time.Sleep(time.Duration(interval) * time.Second)
		case "slow_down":
			// Polling too fast, increase interval
			interval += slowDownIncrement
			time.Sleep(time.Duration(interval) * time.Second)
		case "expired_token":
			return nil, fmt.Errorf("device code expired, please restart the process")
		case "access_denied":
			return nil, fmt.Errorf("user denied authorisation")
		case "":
			return nil, fmt.Errorf("received invalid response from GitHub (no access_token or error field)")
		default:
			description := result.ErrorDescription
			if description == "" {
				description = result.Error
			}
			return nil, fmt.Errorf("unexpected error: %s", description)
		}
	}
}

// testToken tests the token by fetching the authenticated user's info.
func testToken(accessToken, userAPIURL string) (*UserInfo, error) {
	req, err := http.NewRequest("GET", userAPIURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", apiVersion)
	req.Header.Set("User-Agent", userAgent)

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch user: %s - %s", resp.Status, strings.TrimSpace(string(body)))
	}

	var user UserInfo
	if err := json.Unmarshal(body, &user); err != nil {
		return nil, fmt.Errorf("failed to fetch user: received non-JSON response from GitHub")
	}

	return &user, nil
}

func main() {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt)
	go func() {
		<-sigChan
		fmt.Fprintln(os.Stderr, "\nCancelled by user.")
		os.Exit(130)
	}()

	var clientID, clientIDShort, hostname, hostnameShort string
	flag.StringVar(&clientID, "client-id", "", "GitHub App Client ID")
	flag.StringVar(&clientIDShort, "c", "", "GitHub App Client ID (shorthand)")
	flag.StringVar(&hostname, "hostname", "", fmt.Sprintf("GitHub hostname (default: %q)", defaultHostname))
	flag.StringVar(&hostnameShort, "H", "", "GitHub hostname (shorthand)")
	flag.Parse()

	// Merge flags: if both provided, prefer long form; otherwise use whichever is set
	if clientID == "" && clientIDShort != "" {
		clientID = clientIDShort
	} else if clientID != "" && clientIDShort != "" && clientID != clientIDShort {
		fmt.Fprintln(os.Stderr, "Error: Both --client-id and -c provided with different values. Use one or the other.")
		os.Exit(1)
	}

	// Fall back to environment variable if no flag provided
	if clientID == "" {
		clientID = os.Getenv("GITHUB_CLIENT_ID")
	}
	clientID = strings.TrimSpace(clientID)

	if clientID == "" {
		fmt.Fprintln(os.Stderr, "Error: Client ID required. Use --client-id or set GITHUB_CLIENT_ID env var.")
		os.Exit(1)
	}

	if !clientIDPattern.MatchString(clientID) {
		fmt.Fprintf(os.Stderr,
			"Error: GITHUB_CLIENT_ID contains unexpected characters.\n"+
				"   Got: [%s] (%d chars)\n"+
				"   Re-export cleanly to fail fast on stray prefixes.\n",
			clientID, len(clientID))
		os.Exit(1)
	}

	// Merge --hostname / -H flags
	if hostname == "" && hostnameShort != "" {
		hostname = hostnameShort
	} else if hostname != "" && hostnameShort != "" && hostname != hostnameShort {
		fmt.Fprintln(os.Stderr, "Error: Both --hostname and -H provided with different values. Use one or the other.")
		os.Exit(1)
	}
	if hostname == "" {
		hostname = os.Getenv("GITHUB_HOST")
	}
	if strings.TrimSpace(hostname) == "" {
		hostname = defaultHostname
	}
	hostname = normaliseHostname(hostname)
	if hostname == "" || !hostnamePattern.MatchString(hostname) {
		fmt.Fprintf(os.Stderr, "Error: Invalid GitHub hostname: [%s]\n", hostname)
		os.Exit(1)
	}

	deviceCodeURL, accessTokenURL, userAPIURL := resolveEndpoints(hostname)

	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("GitHub Device Flow - User Access Token")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("\n⚠️  WARNING: For demonstration/testing only. Not for production use.")
	fmt.Printf("\nClient ID: %s\n", clientID)
	if !strings.EqualFold(hostname, defaultHostname) {
		fmt.Printf("Hostname:  %s\n", hostname)
	}
	fmt.Println()

	// Step 1: Get device code
	fmt.Println("Requesting device code...")
	deviceData, err := requestDeviceCode(clientID, deviceCodeURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	// Step 2: Prompt user to authorize
	fmt.Println()
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("ACTION REQUIRED")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Printf("\n1. Open: %s\n", deviceData.VerificationURI)
	fmt.Printf("2. Enter code: %s\n", deviceData.UserCode)
	fmt.Println()

	// Auto-open browser and copy code to clipboard (macOS-only). Both are
	// graceful no-ops on non-macOS systems (Linux, BSD, headless CI, SSH
	// sessions, etc.) since they only check for `open` and `pbcopy`.
	if _, err := exec.LookPath("pbcopy"); err == nil {
		cmd := exec.Command("pbcopy")
		cmd.Stdin = strings.NewReader(deviceData.UserCode)
		if err := cmd.Run(); err == nil {
			fmt.Println("📋 Code copied to clipboard.")
		}
	}
	if _, err := exec.LookPath("open"); err == nil {
		if err := exec.Command("open", deviceData.VerificationURI).Run(); err == nil {
			fmt.Println("🌐 Opening browser...")
		}
	}

	fmt.Println("\nWaiting for authorisation...")

	// Step 3: Poll for token
	interval := deviceData.Interval
	if interval == 0 {
		interval = defaultPollInterval
	}
	tokenData, err := pollForToken(clientID, deviceData.DeviceCode, interval, accessTokenURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println()
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("SUCCESS!")
	fmt.Println(strings.Repeat("=", 50))
	tokenType := tokenData.TokenType
	if tokenType == "" {
		tokenType = "bearer"
	}
	fmt.Printf("\nToken Type:   %s\n", tokenType)
	fmt.Printf("Scope:        %s\n", tokenData.Scope)
	tokenLen := len(tokenData.AccessToken)
	if tokenLen >= tokenMinLengthForTruncation {
		var prefix string
		if idx := strings.Index(tokenData.AccessToken, "_"); idx > 0 {
			prefix = tokenData.AccessToken[:idx+1]
		} else {
			prefix = tokenData.AccessToken[:4]
		}
		fmt.Printf("Access Token: %s***%s\n", prefix,
			tokenData.AccessToken[tokenLen-tokenSuffixLength:])
	} else {
		fmt.Printf("Access Token: %s\n", tokenData.AccessToken)
	}

	// Step 4: Test the token
	fmt.Println("\nTesting token by fetching user info...")
	userInfo, err := testToken(tokenData.AccessToken, userAPIURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("\nAuthenticated as: %s\n", userInfo.Login)
	if userInfo.Name != nil {
		fmt.Printf("Name:             %s\n", *userInfo.Name)
	} else {
		fmt.Println("Name:             N/A")
	}
	if userInfo.Email != nil {
		fmt.Printf("Email:            %s\n", *userInfo.Email)
	} else {
		fmt.Println("Email:            N/A")
	}

	// NOTE: Printing the full token is intentional for demo/testing purposes.
	// This allows token capture via: export TOKEN=$(go run device_flow.go ... | tail -1)
	// For production use, store tokens securely rather than printing to stdout.
	fmt.Println()
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println("FULL ACCESS TOKEN (for use in other applications):")
	fmt.Println(strings.Repeat("=", 50))
	fmt.Println(tokenData.AccessToken)
}
