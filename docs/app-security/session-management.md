# Device-bound session management

## Token lifecycle

Laravel creates a random 32-byte URL-safe session token and refresh token. Only SHA-256 token digests are stored. Access token lifetime defaults to 300 seconds; refresh token lifetime defaults to 2,592,000 seconds (30 days). Refresh requires the Passport user token plus a signature by the registered device key over:

```text
ky-session-refresh-v1
<session_uuid>
<refresh_token>
```

On successful refresh the server rotates both token values and their stored hashes. Old refresh tokens no longer match. The client keeps App Security token values in memory; the existing Passport token remains in the app's established preferences flow. Session opens enforce a per-device concurrent session limit (default 1); opening another session on that account/device revokes the oldest live session and replaces its token hashes. Other devices for the account are unaffected. The limit is configurable from 1 to 20 in the audited App Security settings dashboard or with `KY_SECURITY_MAX_SESSIONS_PER_DEVICE`.

## Account and device revocation

- Existing signed account logout revokes the current App Security session inside the existing Laravel logout transaction before revoking the Passport bearer token.
- The `sessions/logout` endpoint revokes a session for the authenticated user.
- Admin reject, block, revoke and require-re-registration actions revoke active sessions in the same database transition; middleware also checks current device status and block rules on each protected request. Require re-registration retires the old key fingerprint and accepts only a different newly attested key for that installation.
- A protected API response of `401`, `423`, or `426` invalidates the client's cached authorization state. `401` also clears local App Security tokens. The client does not automatically replay the failed business request; its next call rechecks policy/device and opens a replacement session only if still allowed.
- App logout clears only process-local App Security state; installation UUID and Android Keystore key remain for future sign-ins.

## Current policy gaps

The administrator device list now links to a paginated session view. Authorized device managers can revoke an individual live session with a mandatory reason and password step-up; the action invalidates both token hashes and creates an administrator audit record. Staff-approval-only administrators are limited to staff devices, and customer-support-only accounts cannot access session data. The server retains only SHA-256 hashes of rotated refresh tokens until their original refresh expiry. Refresh fails closed with HTTP 503 if the reuse-history migration is missing. Reuse with a valid device signature revokes the current session, invalidates both current tokens, and writes a security log, alert, and system audit event. Expired history hashes are removed by scheduled cleanup. Key-loss recovery is administrator-managed rather than self-service: use require-re-registration for a controlled rotation while the key is available; if the key is lost or the app reinstalled, verify account/device ownership, revoke the stale record, and allow the client to register its new installation identity. See the troubleshooting and admin-dashboard guides. Session rows remain for audit after expiration/revocation; the scheduled cleanup removes expired nonces/challenges and aged telemetry, but retains session rows. The heartbeat endpoint can issue an ECDSA-signed offline authorization lease when a private signing key and nonzero grace period are configured. Android verifies and encrypts the lease locally, binds it to the current user/install/release, and enforces its lifetime using monotonic elapsed time. Leases are disabled by default and are not real-device tested; a device reboot invalidates the cached lease, and server-side revocation reaches a disconnected device only after the lease expires or it reconnects. Laravel Passport tokens have existing app-wide expiration settings; App Security does not replace Passport or shorten its lifetime. Configure database retention and monitor table growth before rollout.

