# Website APK distribution

The root Laravel application serves the website and mobile API on the same host. The App Security download routes are defined in Laravel `routes/web.php`:

| Route | Behavior |
| --- | --- |
| `GET /app` | Public download page; shows the latest active release or a no-release message. |
| `GET /app/download/android` | Controlled download of the latest active APK from private `local` storage. |
| `GET /app/releases/latest` | JSON metadata for the latest active release. |
| `GET /app/releases/{version}` | JSON metadata for an active or archived version. |
| `GET /app/releases/{version}/checksum` | Plain-text APK SHA-256. |
| `GET /app/releases/{version}/download` | Controlled version-specific APK download. |

The page displays the existing KNEAYERNG app logo, app name, version name/code, APK size, minimum Android version/API level, target API, release notes, SHA-256, installation steps, security guidance, and `/privacy`. The admin login page’s Android app link points to `/app`, keeping the existing website entry point on the controlled publication flow. A vendor/device compatibility matrix and support contact have not been supplied. Website release synchronization is unnecessary because the site and API are the same Laravel application.

## Publication and storage controls

- Only admins with the existing `app_security_manage` permission can upload, activate or revoke a release.
- Upload processing validates APK contents and signing certificate against server configuration.
- Versioned files use UUID paths on the private Laravel `local` disk; the controller streams downloads through Laravel.
- Public pages only select an active release, except version history lookup also exposes archived metadata/downloads. Revoked releases are not returned by public metadata/download lookup.
- HTTPS, correct Laravel document root, private storage permissions, trusted signer list, and backup/restore for the storage disk remain deployment responsibilities.

## Website verification checklist

After a signed release is activated in staging, verify the page, metadata JSON, checksum and bytes of both latest and versioned downloads. Compare `sha256sum` output with the database and independently signed artifact. Also verify that draft/revoked artifacts cannot be fetched and that unauthenticated upload/activation attempts are rejected.

