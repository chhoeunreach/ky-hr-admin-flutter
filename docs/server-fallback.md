The app reads `data.server_fallback_url` from `GET /api/app-version` and saves it
for the configured server. The backend supplies `MOBILE_APP_FALLBACK_URL`, using
`APP_FALLBACK_URL` when no mobile override is set.

Deploy both the backend and the updated mobile app. Refresh Laravel configuration
with `php artisan config:cache` during deployment. In the admin QR page, scan
**Connect with automatic backup** with the updated app. It saves both addresses
and works even when the primary is already offline. The original QR remains on
the page for older apps. Existing installations can also learn the backup from
one successful primary connection without scanning again.

All callers of `Preferences.getAppUrl()` resolve the server before sending their
request. Checks are shared across concurrent callers. The primary is rechecked
before each request; a backup selection is cached for 15 seconds, with the backup
itself checked before reuse so a new backup outage triggers a fresh primary check.
Connection failures, a five-second probe timeout, or HTTP 5xx trigger a check of
the remembered backup. The backup must answer with a successful HR app-version
response. The primary is checked again after the cache expires and is used when
it recovers. HTTP 4xx responses do not trigger switching.

The Test server connection button bypasses the selection cache, checks the primary
and backup immediately, and reports the selected server. Later API requests use
the selected backup automatically.

Business requests are not replayed automatically. If an outage starts between a
successful probe and the business request, that request can still fail; the next
request checks again. Both servers must serve the same users, authentication keys,
database, and uploaded files. When both servers are unavailable, normal request
error handling applies. Selecting another server uses that server's own saved
backup configuration. An explicit null backup from the primary clears its saved
backup.

The primary server remains saved when the backup is selected, including when
scanning while the primary is offline. Failed server scans leave the previous
configuration intact. QR codes accept base64 JSON with `server_url` and
`server_fallback_url`, as well as the previous base64 URL and plain URL formats.

Verification:

```sh
flutter test test/server_configuration_test.dart test/server_url_resolver_test.dart test/server_status_service_test.dart
# Optional live check: stop primary, keep backup running, use the backend QR payload.
flutter test test/integration/server_failover_live_test.dart --dart-define=SERVER_QR=<base64-payload>
# From hr-ky-admin:
php vendor/bin/phpunit tests/Feature/AppVersionFallbackTest.php
```
