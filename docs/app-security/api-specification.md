# App Security API specification (implemented surface)

Base path: `/api/app-security/v1`. All mobile endpoints use HTTPS in the Flutter client. Release builds pin the API host `hr.rvstechsolution.com` to a build-time primary/backup SPKI set, keep platform CA validation, and fail closed if the set is missing or the host is unlisted. The production owner selected this API hostname; verify it routes to the root Laravel application/database. The public release website remains `kneayerng.com`. Protected business routes still use the existing Passport guard and business permission middleware.

## Mobile endpoints

| Method and path | Authentication | Behavior |
| --- | --- | --- |
| `GET /config` | Public, throttled | Reports enabled flag, device approval, attestation preference, heartbeat/session/challenge TTL, and configured offline grace seconds. |
| `POST /releases/check` | Public, throttled | Body: `package_name`, `signing_sha256`, `version_code`, and required `android_sdk`. Returns recognized release, mandatory-update decision, minimum version, and latest-release metadata including `minimum_android_sdk` and `compatible_with_device`; returns `428` if the installed APK or a mandatory update cannot run on the device; older active/archived builds remain optional unless the latest release is marked mandatory or the client falls below the minimum version. Unknown, revoked, draft, testing and suspended releases are rejected. |
| `POST /challenge` | Passport bearer | Issues a one-use registration challenge UUID and plaintext challenge; DB stores only its SHA-256 and expiry. |
| `POST /devices/register` | Passport bearer | Submits challenge UUID/value/signature, installation UUID, public key, package/signer/version, required `android_sdk`, other Android/device facts and optional base64 attestation chain. Registration verifies challenge, release and P-256 proof; configured attestation roots and fresh revocation data enable additional Android Key Attestation checks. Server-observed registration signals initialize risk history. If a minimum attested Android OS or patch floor is configured, registration requires verified claims meeting those floors; missing, unverified, or old claims return `428`. A configurable short-window registration-velocity detector uses an HMAC-keyed cache counter derived from the trusted source IP (raw IP is not stored by this detector); threshold crossings add review risk and an admin alert and withhold customer auto-approval, but never auto-block. Response is `200` for approved or `202` for pending. |
| `POST /devices/status` | Passport bearer | Body: `installation_uuid`. Looks up the installation for the authenticated user and returns device UUID, status, type, attestation label, public-key fingerprint, risk score, authorization and last-seen time; `404` means this account needs its own registration. |
| `POST /integrity/report` | Passport bearer + approved device signature | Accepts only the native root/emulator/debugger/debug-build/instrumentation/runtime-hook/VPN/basic transport indicator names. Throttled to six reports/minute. These are weak client heuristics for review; the server assigns configured points and never auto-blocks from them. |
| `POST /heartbeat` | Passport bearer + approved device signature | Signed authorization heartbeat; returns current device authorization and session expiry. When offline grace is enabled and a server signing key is configured, it also returns `authorization_lease` with `key_id`, base64url `payload`, and base64url ECDSA `signature`. Flutter verifies and stores this lease using Android Keystore and allows offline app access only for its remaining monotonic lifetime. Grace defaults to zero. Flutter sends heartbeats at the server-configured interval and fails closed without a valid lease. |
| `POST /sessions` | Passport bearer | Body: `device_id`. Opens a session only for an approved device. Returns session UUID, access token, refresh token and expiration values once. |
| `POST /sessions/refresh` | Passport bearer | Body: `refresh_token`, `signature`. Verifies proof under device key, rotates both token hashes, and returns the rotated tokens. Reuse of the prior refresh token fails. |
| `POST /sessions/logout` | Passport bearer | Body: `session_id`. Revokes a session belonging to the authenticated user. Normal app logout instead revokes from the existing signed account logout transaction. |

The API does not implement separate `/devices/attestation` or `/devices/verify` endpoints; attestation is supplied during registration. `POST /devices/status` provides the per-account installation lookup. Registration stores supplied attestation encrypted and records verified state only when configured trust/revocation prerequisites pass; otherwise it stays pending. When OS/patch floors are enabled, their verified summary claims are checked at registration and rechecked at admin approval, session issue/refresh, and every protected request; failing devices receive `428` and cannot be manually approved. Risk signals include server-observed events and the limited signed client heuristics listed above. A single installation UUID and P-256 public-key fingerprint can be associated with separate device rows for different user accounts; these rows do not share approval status or sessions.

The existing `GET /api/logout` remains Passport-authenticated and rate-limited, but is explicitly exempt from device-signature and business-permission middleware so a pending, blocked, revoked or session-expired user can still revoke their own Passport token. When a valid `X-KY-Session` header is present, the controller also revokes that user's App Security session. The Flutter gate offers sign-out and tries a signed logout first, falling back to bearer-authenticated logout if local signing is unavailable.

## Signed protected business requests

When `KY_SECURITY_ENABLED=true`, authenticated API groups require headers `X-KY-Device`, `X-KY-Session`, `X-KY-Session-Token`, `X-KY-Timestamp`, `X-KY-Nonce`, and `X-KY-Signature`. Laravel verifies them before calling the business controller. Existing Passport bearer authorization remains required.

Common error shape:

```json
{"error":"app_security","message":"The device security session is invalid or expired."}
```

Relevant status codes: `401` for missing/invalid/expired proof or session, `403` for unknown release identity, `409` for replay or conflicting installation identity, `423` for blocked/unauthorized installation, `426` for mandatory update, `428` for an Android SDK too old for the installed release or mandatory update, or attested OS/patch claims below configured minimums (registration/session issue/refresh/protected routes); `503` for unavailable release configuration.

## Public website release routes

- `GET /app`
- `GET /app/download/android`
- `GET /app/releases/latest`
- `GET /app/releases/{version}`
- `GET /app/releases/{version}/checksum`
- `GET /app/releases/{version}/download`

The latest and version routes expose active release metadata; version lookup also allows archived releases. APK files are delivered from Laravel's private `local` storage disk.

## Admin routes

Browser routes are under `/admin/app-security`; the JSON read routes are under `/api/admin/app-security`. Both use the existing session-backed admin guard and permission middleware. The JSON API exposes dashboard, devices, releases, alerts, logs, risk reports and device intelligence. `GET /alerts` is audit-permission gated; `POST /alerts/{id}/acknowledge` requires the alert-acknowledgement permission and a reason. Granular permissions cover general view, staff device approval, full device control, releases, settings, audit logs, alert acknowledgement and customer support status. The legacy `app_security_manage` permission remains full access. Customer-support-only results are restricted to customer device status and omit risk, key, session and installation data. HR staff-approval permission cannot block/revoke or manage customer devices. Device actions require a reason and produce an audit row.


The session-authenticated JSON API also accepts device actions at `POST /api/admin/app-security/devices/{uuid}/{approve|reject|block|unblock|revoke|requireReregistration}`, an individual session revoke at `POST /api/admin/app-security/devices/{uuid}/sessions/{sessionUuid}/revoke`, APK upload at `POST /api/admin/app-security/releases`, and release activation/revocation at `POST /api/admin/app-security/releases/{uuid}/{activate|revoke}`. These use the same App Security permissions, reason validation, password step-up and audit behavior as the browser forms; JSON requests receive JSON responses. Browser forms remain under `/admin/app-security`.

Administrator risk review endpoints are available through the session-authenticated `/admin/app-security` route group: `GET /devices/{uuid}/review` renders the browser review page and `POST /risk-signals/{signalId}/review` accepts `disposition` (`false_positive` or `confirmed`) plus a required reason. The JSON admin route is `POST /api/admin/app-security/risk-signals/{signalId}/review`. General Manager and IT Admin can submit reviews; auditors can inspect details read-only. Critical severity cannot be marked false positive.

High-impact administrator mutations require a `step_up_password` field containing the current password for the authenticated admin account. This covers device approval/rejection/block/unblock/revocation, release activation/revocation, administrator role updates, runtime policy updates, and risk-signal review. Failed checks return validation errors; five failed attempts per actor/IP are rate-limited. Configure `KY_SECURITY_STEP_UP_REQUIRED=false` only for an explicitly approved emergency bypass; the default is required.
