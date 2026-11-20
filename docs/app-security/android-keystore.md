# Android identity and Keystore integration

## Implemented native bridge

`MainActivity.kt` attaches `KySecurityMethodChannels`, which exposes the existing device-clock and app-integrity flows plus `kneayerng/ky_security` methods. Security method calls are routed to `AndroidAppIdentity`, `AndroidDeviceKeyStore`, `AndroidRuntimeRiskSignals`, and `AndroidAuthorizationLeaseStore`; security logic is not implemented in the activity:

- `identity`: package name, installed signing certificate SHA-256, app version, Android SDK/version and device model.
- `installationIdentity`: returns a random per-install UUID stored in a dedicated Android preferences file excluded from cloud backup and device transfer. On upgrade, it migrates the previous Flutter preference only when an existing Android Keystore device key confirms this is the same install; it then removes the legacy value. A reinstall or unavailable server-bound key gets a new identity.
- `ensureKey`: creates an account-scoped EC key alias in Android Keystore when absent and returns the encoded public key plus certificate chain. A forced registration replaces that account's alias with a fresh challenge-bound key.
- `selectKeyAlias`: selects only an alias whose public key matches the server-bound fingerprint and whose private key remains usable. A missing or permanently invalidated key rotates the per-install identity and routes to administrator-managed recovery; the client does not silently substitute a new key for the old server registration.
- `sign`: signs caller bytes with `SHA256withECDSA`; the private key is retrieved only inside the Android Keystore provider.

The key uses `secp256r1`/P-256 and SHA-256, prefers StrongBox on API 28+, and falls back to a TEE/default Android Keystore key if StrongBox generation fails. User authentication is not required for each signature. Attestation challenge is attached at initial key generation on API 24+.

Android app backup stays enabled for existing app preferences, but the dedicated `ky_install_identity.xml` file is excluded from both cloud backup and device transfer. This lets a restore/reinstall get a fresh app-scoped identity without discarding the app's other backed-up settings.

## Existing APK integrity check

The separate `cnattendance/app_integrity` bridge compares installed package/certificate against build-time `BuildConfig` values. Flutter fails closed on Android if the check errors. This is best-effort re-sign/repackage detection; an attacker with the original signing key can produce an APK that passes, and client checks do not replace Laravel authorization.

## Rotation, recovery and provisioning

- Admin-triggered key rotation and key-loss recovery are implemented: an administrator verifies account/device ownership, requires re-registration for a controlled rotation while the old key is usable, or revokes the stale record after the client creates a new identity following key loss/reinstall. The administrator records a reason with password step-up; the new key uses a fresh server challenge. This is intentionally not a self-service reset; see the troubleshooting guide.
- Release builds accept an explicit comma-separated signer fingerprint allowlist using the Gradle property `kyTrustedSigningSha256` or environment variable `KY_TRUSTED_SIGNING_SHA256`; the current production signer is the default. Coordinate rotation by allowing both old and new fingerprints in client builds and Laravel `KY_SECURITY_TRUSTED_SIGNING_SHA256`, registering/activating a release signed by the new key, then removing the old fingerprint only after the minimum supported release no longer needs it. The fingerprints are public identifiers, not signing keys.
- Hardware attestation certificates are verified by Laravel only when the root bundle and fresh revocation snapshot are configured; StrongBox presence is not separately reported as a trusted server fact.
- Best-effort root/emulator/instrumentation and network indicators are implemented as review signals; API SPKI pinning is implemented with primary/backup build configuration. Play Integrity remains optional and unimplemented, and no selected-screen `FLAG_SECURE` policy is currently applied.

Do not interpret `attestationSupported` or a non-empty certificate chain as server-verified hardware trust.

