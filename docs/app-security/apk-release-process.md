# APK release process

## What the current release pipeline verifies

The admin upload action accepts APK files up to 500 MiB, then runs configured Android SDK `aapt` and `apksigner`. It extracts package, version, minimum/target SDK and signer certificate; rejects the wrong package, invalid signer, missing tools/trusted signer list, and duplicate `(package, versionCode)`; and computes the APK SHA-256 and size. The APK is saved under a UUID filename on Laravel's private `local` storage disk, not in the web root. Release facts are immutable by version code.

Configure server environment values before upload:

```dotenv
KY_SECURITY_PACKAGE=com.kneayerng.hrms
KY_SECURITY_AAPT_PATH=/absolute/path/to/android-sdk/build-tools/<version>/aapt
KY_SECURITY_APKSIGNER_PATH=/absolute/path/to/android-sdk/build-tools/<version>/apksigner
KY_SECURITY_TRUSTED_SIGNING_SHA256=<active-certificate-sha256>[,<rotation-certificate-sha256>]
```

The trusted list is for signing-certificate SHA-256 fingerprints. It is distinct from each release's APK file SHA-256. Do not copy the development keystore or fingerprints into the web root, source control, or database.

The Android Gradle release compile task runs `validateReleaseSecurityConfiguration` first. It refuses release AOT compilation unless pinning is explicitly enabled, `KY_API_BASE_URL` is a plain HTTPS origin, its exact host appears in `KY_SECURITY_PINNED_HOSTS`, and `KY_SECURITY_SPKI_PINS` contains at least two distinct canonical `sha256/<base64>` encodings of 32-byte SHA-256 hashes. This preflight prevents creation of a signed release artifact that would be unable to make its pinned API calls. Debug builds are not subject to this gate. The check validates format only; the production TLS owner must still verify that the primary and backup values represent the live and planned server keys.

## Operator workflow

1. Build the release in the controlled Android signing environment.
2. Independently record the intended package ID, version code, version name, signing-certificate fingerprint and APK checksum.
3. Upload through the App Security admin page; the release is saved as `draft` only after inspection succeeds.
4. Compare Laravel's extracted metadata and checksum with the release artifact.
5. Enter release notes and `minimum_supported_version`, then activate with a reason. The old active release becomes archived.
6. Verify `/app`, latest metadata, checksum, and downloaded APK against the signed artifact.
7. If compromised, revoke the release with an audited reason and prepare a new signed release.

Statuses stored in the schema include draft/testing/active/suspended/revoked/archived, but the current UI directly supports draft upload, activation (archives prior active), and revoke. There is no testing/suspension workflow or certificate-rotation wizard.

## Update policy

The active release can mark updates mandatory with `is_mandatory`. That forces every lower recognized version to update. `minimum_supported_version` independently forces versions below its version-code floor. An older active or archived release remains usable when it is above the floor and the latest release is optional; the Flutter client presents an optional download prompt with a Later action. Draft, testing, suspended and revoked releases are not accepted for device identity checks. `minimum_android_sdk` is enforced during release checks and device registration: a device below its installed APK minimum receives HTTP 428 and the client shows an unsupported-Android gate. If an optional latest release requires a newer Android SDK, its update prompt is hidden for that device. A mandatory update that the device cannot run returns HTTP 428, so the server does not issue an impossible update requirement.

No signed production APK has been registered or activated in this project work. The site correctly shows no release until an administrator uploads one.

