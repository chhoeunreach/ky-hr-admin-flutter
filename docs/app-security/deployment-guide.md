# Deployment guide

## Preconditions

1. Deploy the Laravel code and Flutter/native client as a coordinated release; keep `KY_SECURITY_ENABLED=false` initially.
2. Confirm the production host serves the root Laravel app and `/app` plus `/api/app-security/v1/config` over valid HTTPS.
3. Confirm production role slugs and the intended admin permission assignment. Customer role detection currently accepts `customer` and `client`.
4. The owner confirmed the expected production signer SHA-256 as `6a275f4c91e2accf7654ba89c26514d9678fcdd1bac30a4ad37d533cc2192ac9`. Still verify the exact APK artifact before registering it.
5. Set absolute paths to compatible `aapt` and `apksigner`, configure trusted signer fingerprints, and ensure the Laravel process can execute those tools.
6. Verify private `storage/app` capacity, permissions and backups. The configured `.env` was not edited by this work.

## Environment settings

```dotenv
APP_URL=https://kneayerng.com
MOBILE_APP_URL=https://kneayerng.com
KY_SECURITY_ENABLED=false
KY_SECURITY_PACKAGE=com.kneayerng.hrms
KY_SECURITY_DEVICE_APPROVAL=true
KY_SECURITY_CUSTOMER_AUTO_APPROVAL=true
KY_SECURITY_HARDWARE_ATTESTATION=preferred
KY_SECURITY_HEARTBEAT=120
KY_SECURITY_SESSION_TTL=300
KY_SECURITY_MAX_SESSIONS_PER_DEVICE=1
KY_SECURITY_MAX_DEVICES_STAFF=0
KY_SECURITY_MAX_DEVICES_CUSTOMER=0
KY_SECURITY_MAX_DEVICES_ADMIN=0
KY_SECURITY_REFRESH_TTL=2592000
KY_SECURITY_CHALLENGE_TTL=120
KY_SECURITY_NONCE_TTL=300
KY_SECURITY_RISK_REVIEW=30
KY_SECURITY_RISK_BLOCK=60
KY_SECURITY_RISK_ENABLED=true
KY_SECURITY_RISK_WINDOW_HOURS=168
KY_SECURITY_RISK_POLICY_VERSION=1
KY_SECURITY_REGISTRATION_VELOCITY_WINDOW=900
KY_SECURITY_REGISTRATION_VELOCITY_THRESHOLD=5
KY_RISK_REGISTRATION_VELOCITY=20
KY_RISK_REPLAY=40
KY_RISK_MISSING_ATTESTATION=10
KY_RISK_FAILED_ATTESTATION=40
KY_RISK_ROOT_INDICATOR=15
KY_RISK_EMULATOR_INDICATOR=15
KY_RISK_INSTRUMENTATION_INDICATOR=25
KY_SECURITY_LOCATION_ENABLED=false
KY_SECURITY_AUDIT_ENABLED=true
KY_SECURITY_CERTIFICATE_PINNING=false
KY_SECURITY_OFFLINE_GRACE_SECONDS=0
KY_SECURITY_LEASE_PRIVATE_KEY_PATH=/private/path/to/app-security/lease-private.pem
KY_SECURITY_LEASE_KEY_ID=lease-2026-01
KY_SECURITY_AAPT_PATH=/absolute/path/to/android-sdk/build-tools/<version>/aapt
KY_SECURITY_APKSIGNER_PATH=/absolute/path/to/android-sdk/build-tools/<version>/apksigner
KY_SECURITY_TRUSTED_SIGNING_SHA256=<verified-fingerprint>[,<rotation-fingerprint>]
KY_SECURITY_ATTESTATION_ROOTS_PATH=/private/path/to/android-attestation-roots.pem
KY_SECURITY_ATTESTATION_CRL_PATH=/private/path/to/attestation-status.json
KY_SECURITY_ATTESTATION_CRL_MAX_AGE=86400
KY_SECURITY_ATTESTATION_MIN_SECURITY_LEVEL=1
KY_SECURITY_MIN_ANDROID_OS_VERSION=0
KY_SECURITY_MIN_ANDROID_PATCH_LEVEL=0
KY_RISK_ATTESTATION_OS_POLICY_FAILED=20
KY_SECURITY_ATTESTATION_EVIDENCE_RETENTION_DAYS=90
```

Keep attestation roots and status data outside the web root. Google publishes the current root certificates at `https://android.googleapis.com/attestation/root` as a JSON array of PEM certificates. Download over validated HTTPS, check the JSON and each certificate (active dates, CA constraint and key-cert-sign usage), retain the previous bundle for rollback, and atomically install the reviewed complete bundle at the path configured by `KY_SECURITY_ATTESTATION_ROOTS_PATH` with mode 0600. Include both roots listed by the [official Android guidance](https://developer.android.com/privacy-and-security/security-key-attestation); the newer root began signing chains on 2026-02-01. Do not enable required attestation until a real device chain validates against the installed set. The status snapshot defaults to `storage/app/private/app-security/attestation-status.json`; the Laravel scheduler refreshes the Google revocation status list every six hours. Configure the system scheduler (`schedule:run`) and verify a successful first refresh before setting hardware attestation to `required`. Encrypted chain evidence expires after the configured number of days (default 90); scheduled cleanup erases the ciphertext and retains verification summaries. Run `php artisan app-security:cleanup --dry-run` after migration to inspect eligible evidence before the scheduled cleanup first runs.

OS and OS security-patch floors are disabled when set to `0`. If enabled, configure `KY_SECURITY_MIN_ANDROID_OS_VERSION` as Android Key Attestation `MMmmss` (six-digit integer, e.g. `080100`) and `KY_SECURITY_MIN_ANDROID_PATCH_LEVEL` as `YYYYMM` (e.g. `201808`). The server requires a verified attestation claim meeting each configured floor for registration, admin approval, session issue/refresh, and protected API requests. An unsupported device receives HTTP 428. Set policy before rollout; existing records without stored verified claims will need fresh enrollment. Claim encodings follow [Android Key and ID attestation](https://source.android.com/docs/security/features/keystore/attestation).

Set `APP_URL` and `MOBILE_APP_URL` to the public website host. The owner selected `hr.rvstechsolution.com` as the production API hostname; configure it only after confirming it reaches the same root Laravel application and database as the website. Only configure a mobile fallback URL if it reaches that same Laravel application and database; an unrelated backup host can silently direct accounts to another service. The Flutter release build must set `KY_API_BASE_URL=https://hr.rvstechsolution.com/`. The Flutter HTTP and Dio transports implement HTTPS SPKI pinning. Release builds fail closed unless the approved API host and primary/backup pins are supplied at build time. The TLS owner confirmed `sha256/0DbDAbR7JYvhI/0wXGW346NQDHIT1r5iKC4niOiwePs=` as the primary pin and reported the API route was deployed and returning JSON. Fresh read-only GETs at 2026-11-20 06:55, 06:58, 06:59, 07:08, 07:13, and 07:38 UTC returned HTTP 200 with `text/html; charset=UTF-8` and an HTML 404 body on `hr.rvstechsolution.com`; the same path returned HTTP 404 on `kneayerng.com` and `www.kneayerng.com`. A further check at 08:19 UTC reached Cloudflare and also returned HTTP 200 HTML with title `404`. The local Laravel project lists all 10 App Security routes, but this checkout has no production deploy workflow or origin-server access, so the route cache and origin mapping could not be changed. The live TLS certificate previously passed hostname and system-root verification and its SPKI matched the confirmed primary. Check production route registration/cache and origin mapping. The planned backup pin remains pending; do not build a distributable release until the endpoint returns JSON and the backup-key verification succeeds. The custom PHP attestation parser has synthetic-chain tests but still needs review/fuzzing and current Android/OEM hardware tests before production enforcement.

The current observed HTML 404 indicates the request is reaching a web fallback, an origin without the route, or a stale/different release than the local API source. Rechecking the official website hostnames also returned HTTP 404 for this API path. On the production Laravel release that serves the host, check that the route is loaded and the route cache matches the deployed code:

```sh
php artisan route:list --path=app-security/v1
```

The output must include public `GET api/app-security/v1/config` and `POST api/app-security/v1/releases/check`. If either route is absent, deploy the matching Laravel release and refresh route cache using the normal release procedure; also confirm the `hr.rvstechsolution.com` web root and Cloudflare origin point to that same application and database. Then check the public config route from a network that resolves the host:

```sh
curl -sS -o /tmp/app-security-config.json -w 'HTTP %{http_code}; content type %{content_type}\n' -H 'Accept: application/json' https://hr.rvstechsolution.com/api/app-security/v1/config
python3 -m json.tool /tmp/app-security-config.json
```

Require a JSON content type and the documented configuration fields. An HTML page titled `404` is a failure even if the web server incorrectly returns HTTP 200.

For production readiness monitoring, `tool/check_api_tls.py` verifies the system-trusted chain and hostname, calculates the live leaf SPKI, confirms that it matches either configured pin, checks leaf-certificate expiry, and verifies that the public App Security config endpoint returns the expected JSON schema. It exits non-zero on any failure and emits one JSON status record for log collection. The certificate warning window defaults to 30 days. Run it from a scheduled monitor and alert on any non-zero exit:

```sh
KY_API_HOST=hr.rvstechsolution.com \
KY_SECURITY_SPKI_PINS=sha256/PRIMARY_BASE64,sha256/BACKUP_BASE64 \
  python3 tool/check_api_tls.py --warn-days 45
```

If the planned backup public certificate is available, pass `--backup-cert /path/to/next-server-leaf.pem`; the tool also verifies its SPKI is the configured non-live pin and checks its expiry. The script is implemented, but production scheduling and a successful run with the approved primary and backup values remain deployment tasks. Do not replace either configured pin based only on monitor output; confirm rotations with the TLS owner.

Use `--tls-only` when certificate monitoring should continue independently while the API route is under maintenance; production readiness still requires the default API JSON check to pass.

The background image queue has no matching Laravel upload route in the inspected project. Its target is intentionally unset by default; without a real deployed multipart endpoint, do not pass `KY_IMAGE_UPLOAD_URL` to the release build. Once the endpoint exists, configure it only on the pinned API host. The client requires HTTPS, two valid pins, an account bearer token, and the request-signing interceptor; failed preflight leaves the image in the local retry queue.

## Staged rollout

1. Back up database and private release storage; rehearse migrations on a restored staging database.
2. Run migrations in staging; inspect all 12 base App Security tables, `app_device_intelligence`, migration tracking entries, and permission keys. No production migration was performed during implementation.
3. Upload the exact signed production candidate; verify package, version, signer and APK checksum; activate and test private download paths.
4. Test registration and approval policy using one staff and one customer account with confirmed role slugs and supported Android devices. Confirm Laravel trusted-proxy settings produce the correct source IP and use a shared Redis cache across all app nodes for registration-velocity counters and the atomic public-key reuse lock; treat shared office/NAT networks as possible false positives.
5. Exercise protected requests, body tampering, duplicate nonce, session refresh/logout, device block/revoke and mandatory update.
6. Verify risk score thresholds, explanations, signal expiry and manual review; confirm high risk alone does not block a device.
   Submit test root/emulator/instrumentation heuristic reports and verify they add only server-assigned review points; confirm they never change device approval or block status.
7. Monitor App Security logs, Laravel logs, DB growth, storage, and support channels.
   Confirm `app-security:cleanup` is scheduled and review its dry-run counts before its first production execution.
8. Enable `KY_SECURITY_ENABLED=true` only after server-side attestation policy is decided, production release is active, client routes all use signing transports, and rollback is rehearsed.

## Rollback

Feature flag off allows existing authenticated API traffic through the middleware. Roll back by disabling the flag and clearing Laravel config cache through the normal deployment procedure. Do not drop App Security data during rollback; retain audit and evidence records. Re-enable only after the fault is understood.


## Security alert email delivery

High-risk transition alerts are persisted and visible in the admin dashboard even when email delivery is disabled. To enable queued email alerts, set `KY_SECURITY_ALERT_NOTIFICATIONS=true`, set `KY_SECURITY_ALERT_EMAILS` to comma-separated security recipients, configure Laravel mail, and use a durable queue such as Redis. Run a worker that consumes the `security` queue and monitor failed jobs. Do not enable this until delivery and retry behavior are confirmed in staging.

## API certificate pinning

Release builds enable pinning by default. Before building an APK, provision both a primary SPKI hash for the live API certificate and a backup SPKI hash for the next controlled certificate/key. Do not use a single pin. Verify the hashes out of band and test rotation in staging. Supply them at build time:

```sh
flutter build apk --release \
  --dart-define=KY_API_BASE_URL=https://hr.rvstechsolution.com/ \
  --dart-define=KY_SECURITY_PINNING_ENABLED=true \
  --dart-define=KY_SECURITY_PINNED_HOSTS=hr.rvstechsolution.com \
  --dart-define=KY_SECURITY_SPKI_PINS=sha256/PRIMARY_BASE64,sha256/BACKUP_BASE64
```

Each value is base64(SHA-256(DER SubjectPublicKeyInfo)); the client accepts the system-trusted TLS chain and then matches either configured key. A release with no pins or an unlisted API host refuses startup/API calls; it does not fall back to HTTP. Keep a signed recovery build procedure and test the backup before rotating the server certificate.

On macOS, first export the system trust roots and require a valid chain and hostname, then calculate the live leaf-key pin:

```sh
security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > /tmp/kneayerng-system-roots.pem
set -o pipefail
openssl s_client -connect hr.rvstechsolution.com:443 -servername hr.rvstechsolution.com \
  -verify_hostname hr.rvstechsolution.com -verify_return_error \
  -CAfile /tmp/kneayerng-system-roots.pem </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl base64 -A
rm -f /tmp/kneayerng-system-roots.pem
```

Prefix the output with `sha256/`. On 2026-11-20, the verified current leaf certificate produced candidate `sha256/0DbDAbR7JYvhI/0wXGW346NQDHIT1r5iKC4niOiwePs=` and was valid through 2027-01-30 05:31:38 UTC. The TLS owner subsequently confirmed this value as the primary pin. Calculate the backup from the exact public leaf certificate planned for the next TLS key rotation (for example, the staged replacement certificate), using `openssl x509 -in /path/to/next-server-leaf.pem -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | openssl base64 -A`. Check both fingerprints against the TLS deployment records before supplying them to the release build. The backup must represent the key the server will actually present after rotation, not an unrelated CA or a newly generated key that is not scheduled for deployment.


## Offline authorization leases

Offline access is disabled by default (`KY_SECURITY_OFFLINE_GRACE_SECONDS=0`). To enable it, provision a dedicated P-256 EC signing key outside the Laravel web root, source tree, and backups accessible to the app. The Laravel process needs read access to the private key; the APK contains only public keys. For example, on the server:

```sh
umask 077
openssl ecparam -name prime256v1 -genkey -noout -out /etc/kneayerng/app-security/lease-private.pem
openssl pkey -in /etc/kneayerng/app-security/lease-private.pem -pubout -outform DER | base64 | tr -d '\n'
```

Set the private path, matching key ID, and a short grace period (maximum 86,400 seconds) in Laravel's environment. The admin settings can set the grace to zero to stop issuing new leases. Add the matching base64 DER public key to the Android build environment as `KY_SECURITY_LEASE_VERIFY_KEYS='lease-2026-01=BASE64_DER[,next-key-id=NEXT_BASE64_DER]'`, then build the release APK. Keep the old public key in the APK during key rotation while Laravel switches to the new key ID; remove it only after old leases and supported app versions expire. Never put the private key in Flutter build arguments.

The heartbeat lease is bound to account, installation UUID, device, signer, package/version and active session. Android verifies the server signature, encrypts the lease using an Android Keystore AES key, tracks elapsed time monotonically, and invalidates the lease after device reboot. Offline access lasts only for the remaining lease period; Laravel can enforce a block/revocation immediately when the app reconnects, while a disconnected device may use its already issued lease until it expires. Exercise storage, clock changes, reboot, key rotation and revoked-device behavior on supported physical Android devices before enabling this in production.

Enable `KY_SECURITY_USER_NOTIFICATIONS=true` only after the existing `storage/firebase-adminsdk.json` service-account file is securely provisioned and workers consume the `security` queue. Inbox notifications are persisted through the existing `notifications`/`user_notifications` tables; the notification dedupe migration must run before dispatch. Delivery does not alter server-side enforcement if push delivery is unavailable.

`KY_SECURITY_STEP_UP_REQUIRED` defaults to `true`. Keep it enabled. High-impact App Security admin forms and JSON endpoints require the current admin password; verify each administrator account has a working password credential before rollout. The confirmation field is excluded from flashed form input. Use a shared Redis-backed rate limiter across multiple app nodes; the bypass flag exists for an approved emergency recovery only.
