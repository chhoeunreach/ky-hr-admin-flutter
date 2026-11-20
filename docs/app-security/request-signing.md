# Request signing and replay prevention

## Canonical bytes

Flutter and Laravel use UTF-8 text with newline separators:

```text
UPPERCASE_METHOD
REQUEST_URI_PATH_AND_QUERY
lowercase_hex_sha256_of_exact_body_bytes
unix_timestamp_seconds
base64url_nonce_without_padding
device_uuid
session_uuid
```

The signature is Android Keystore `SHA256withECDSA` over those bytes. The public key is P-256. Laravel decodes the signature and verifies it against the registered public key. Query parameter order is part of the URI and therefore must be preserved exactly; body bytes, not decoded JSON/form values, are hashed.

Protected request headers:

```text
X-KY-Device
X-KY-Session
X-KY-Session-Token
X-KY-Timestamp
X-KY-Nonce
X-KY-Signature
Authorization: Bearer <existing Passport token>
```

Exception: the existing authenticated `GET /api/logout` is throttled but exempt from device-signature and business-permission checks. It exists so a blocked or revoked user can terminate their Passport token; the client attempts the normal signed request first and sends only the bearer token if local signing cannot proceed. No business-data route receives this exemption.

## Client transport coverage

- `KyHttp` signs buffered top-level and injected-client calls.
- Multipart requests are serialized to a private temporary directory, hashed, then streamed with the same serialized bytes.
- Generic `http.Request` sends are signed through `KyHttp.sendRequest`.
- `Connect` signs its GET, form POST and JSON POST paths.
- The POS reporting Dio client uses `KyDioSecurityInterceptor`; FormData is spooled to disk before signing.

Review newly added authenticated transports before server enforcement. Any raw client that bypasses these helpers must receive an equivalent interceptor.

## Laravel verification order

`VerifyAppSecurityAccess` checks required header formats and timestamp tolerance, authenticates the Passport user, loads that user's approved/non-revoked device, checks active block rules and registered release, checks active unexpired session and token hash, reconstructs the canonical request from Laravel's request URI/raw body, verifies ECDSA, and inserts the nonce in a DB transaction with a unique `(session_uuid, nonce_sha256)` index. A duplicate insert is rejected, including concurrent replay attempts. The scheduled `app-security:cleanup` command removes expired nonce and challenge rows; it runs daily at 02:20 through Laravel Scheduler.

Client behavior: server `401`, `423`, or `426` invalidates cached authorization for the next call; `401` also clears local session tokens. The failed business request is not automatically replayed. Session recovery is verified server-side on the next request; interactive UI handling still depends on the calling screen.

## Security limits to close

The nonce write currently uses the relational DB, not Redis. Device signatures do not include arbitrary HTTP headers; preserve the documented method/URI/body/session canonical form and avoid adding authorization-relevant request data in unsigned headers. Test exact body parity for each multipart/Dio upload class on a real Android client before enabling the middleware.

