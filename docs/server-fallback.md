The app reads `data.server_fallback_url` from `GET /api/app-version` and saves it
for the configured server. The backend supplies `MOBILE_APP_FALLBACK_URL`, using
`APP_FALLBACK_URL` when no mobile override is set.

No backup QR scan is required. Deploy both the backend and the updated mobile
app. Refresh Laravel configuration with `php artisan config:cache` during
deployment. Build Android with `bash tool/build_android.sh --debug` (omit
`--debug` for release). This exports only `APP_URL`/`MOBILE_APP_URL` and
`MOBILE_APP_FALLBACK_URL`/`APP_FALLBACK_URL` from the backend `.env` into
`lib/config/backend_server_defaults.dart` before building. No credentials or
other environment values are copied into the app. Set `HR_BACKEND_PATH` if the
backend is not in the sibling `hr-ky-admin` directory.

The configured mobile primary is `https://hr.kytech.info/`; its backup is
`https://hr.rvstechsolution.com/`. These come from the backend `.env` values
`MOBILE_APP_URL` and `MOBILE_APP_FALLBACK_URL`. Automatic connection works before
login as well as during an existing session; no backup QR scan is required.

Bundled backups apply only to their matching primary. A new build with changed
defaults refreshes the saved fallback once; later backend responses take precedence.

When a running backend changes its fallback setting, the app learns it from a
successful primary response without scanning or rebuilding. If none of the
addresses already known to an installed app can be reached, the app cannot
discover a new address on an unreachable server; rebuild with the current env
defaults in that situation. QR connection remains optional for choosing a
different server.

The login screen's Verify Company scan checks that the primary address answers
with a successful HR response before saving the company configuration. If the
primary is unavailable, verification fails without contacting the second server.
The QR can still save both addresses after primary verification succeeds. Login
success saves the session. Subsequent requests can use the same token on backup
when both servers share authentication. Manually verifying another company still
requires that company's primary to respond successfully.

Callers of `Preferences.getAppUrl()` resolve the server before sending their
request, including login. Checks are
shared across concurrent callers. The primary is rechecked
before each request; a backup selection is cached for 15 seconds, with the backup
itself checked before reuse so a new backup outage triggers a fresh primary check.
Connection failures, a five-second probe timeout, HTTP errors, or an invalid HR
health response trigger a check of the remembered backup. The backup must answer
with a successful HR app-version
response. The primary is checked again after the cache expires and is used when
it recovers. These checks use the public health endpoint; a business request's
validation or authentication error is not automatically replayed on backup.

The Test server connection button bypasses the selection cache, checks the primary
and backup immediately, and reports the selected server. Later API requests use
the selected backup automatically.

Business requests are not replayed automatically. If an outage starts between a
successful probe and the business request, that request can still fail; the next
request checks again. Both servers must serve the same users, authentication keys,
database, and uploaded files. Selecting another server uses that server's own saved
backup configuration. An explicit null backup from the primary clears its saved
backup.

When the primary and the backup are both unreachable, the resolver notifies
`ServerUrlResolver.onAllServersUnreachable` and `main()` shows a blocking
connection alert (`lib/services/connection_alert.dart`). The alert cannot be
dismissed by tapping outside or with the back button. Its Retry button and an
automatic re-check every 10 seconds run a fresh primary-then-backup probe
(`ServerStatusService.checkCurrentServer`), and the alert closes itself as soon
as either server responds, so the user is prompted to connect until the connection
error clears. Normal per-screen error handling (snackbars) still applies
underneath the alert.

The primary server remains saved when the backup is selected. Failed server scans
leave the previous configuration intact. QR codes accept base64 JSON with `server_url` and
`server_fallback_url`, as well as the previous base64 URL and plain URL formats.
The admin Print QR page encodes the host currently serving that page (for example
the LAN address of a local deployment), so scanning connects the app to the
server that printed the code; localhost requests fall back to the configured
`MOBILE_APP_URL`.

Verification:

```sh
flutter test test/connection_alert_test.dart test/server_configuration_test.dart test/server_url_resolver_test.dart test/server_status_service_test.dart
# Simulate primary failure and check the real public backup without changing production.
flutter test test/integration/server_failover_live_test.dart --dart-define=TEST_PUBLIC_FAILOVER=true
# Optional check with the real primary offline and backup online.
flutter test test/integration/server_failover_live_test.dart --dart-define=TEST_BACKEND_ENV=true
# From hr-ky-admin:
php vendor/bin/phpunit tests/Feature/AppVersionFallbackTest.php
```
