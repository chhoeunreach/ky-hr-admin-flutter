# App Security database schema

Migrations: `2026_11_19_160000_create_app_security_tables.php` creates 12 application tables plus `app_security_schema_migration_objects`, which records tables created by the migration so rollback does not drop pre-existing tables. Follow-up migrations add daily device intelligence, granular App Security permissions, browser-admin security role assignments, deduplicated risk alerts, and refresh-token reuse history, recording ownership so rollback preserves pre-existing application objects. `2026_11_19_162000_allow_account_scoped_app_security_devices.php` scopes an installation/key binding per authenticated user so staff and customer accounts can use the same installed app without sharing authorization records.

| Table | Purpose and key data |
| --- | --- |
| `app_security_releases` | Unique UUID and unique `(package_name, version_code)`; version name/code; separate APK SHA-256 and signer certificate SHA-256; size; private storage path; notes; minimum supported version; SDK metadata; status/mandatory flag; admin audit actor IDs and release time. |
| `app_registered_devices` | Unique device UUID, installation UUID and public-key fingerprint; nullable `users.id`; `user_type`; public key; package/signer/version; Android/device metadata; attestation level; status and previous blocked status; risk score; approval, activity, block and revoke timestamps. |
| `app_device_challenges` | User/device binding, purpose, SHA-256 challenge digest, expiration, used time and attempts. Challenges are not stored in plaintext. |
| `app_device_attestations` | Device/challenge foreign keys, encrypted evidence, verification status, security level, summary and verified time. Evidence stays pending when trust roots or fresh revocation data are unavailable; passing configured verification is recorded as verified. |
| `app_security_sessions` | Device/user foreign keys; UUID; unique SHA-256 access-token hash; unique nullable refresh-token hash; access/refresh expiration; last-used and revocation metadata. |
| `app_security_refresh_token_history` | SHA-256 hashes of rotated refresh tokens, linked to their session and retained only until the original refresh expiry; one-time reuse detection timestamp. No raw tokens are stored. |
| `app_device_integrity_checks` | Per-device server-observed signal or validated client heuristic, severity, server-assigned risk points, safe JSON context and event time. Client-submitted names are allowlisted; clients cannot assign points. |
| `app_device_risk_scores` | Per-device rolling-window score, level, policy version, grouped signal reasons and calculation time, populated by `DeviceRiskEngine`. |
| `app_security_logs` | Event type/severity, optional user/device, request UUID, server-observed IP, JSON details and event time. |
| `app_security_block_rules` | Active rule target type/value, reason, creator, optional expiry and timestamps. Middleware checks installation, device and signer targets. |
| `app_security_settings` | Unique setting key, JSON value and last updater. The admin settings form writes typed, validated operational policy overrides and audits each update. The global enforcement flag remains environment-only. |
| `app_security_audit_logs` | Actor, action, target, previous/new JSON state, reason, IP, user agent and time. Device/release actions use this table. |
| `app_security_nonces` | Device/session UUID, SHA-256 nonce, expiry/consumption time; unique `(session_uuid, nonce_sha256)` protects against concurrent replay. |
| `app_security_alerts` | Deduplicated security-event alerts for high-risk transitions, device registration/state changes and release changes; stores severity, safe context, acknowledgement actor/time/reason, and queued email delivery time. Rollback preserves non-empty alert history. |
| `app_device_intelligence` | One row per device/day: first/last authorized request, request count, app/Android version, count of server-observed public-IP hash changes and limited non-identifying observations. Raw client network identifiers and IP addresses are not stored here. |

## Relationships and constraints

- Devices reference `users` with `nullOnDelete`; sessions reference users and devices with cascade deletion; attestations reference devices with cascade deletion and optional challenge with `nullOnDelete`.
- Release creator/updater and device approver reference the existing `admins` table and become null on deletion.
- Device UUID remains globally unique. `(user_id, installation_uuid)` is unique, while public-key fingerprints are indexed but may recur across users. This allows the same app installation/Keystore key to have separate authorization records for a staff and customer account; each API session remains bound to one user and one device record.
- Public keys are public material. Private keys never enter this schema. Access/refresh token plaintext is returned only at session issue/refresh and is never stored.
- Submitted attestation evidence is encrypted using Laravel `Crypt`; `evidence_expires_at` is assigned from the configurable retention policy (default 90 days), including a creation-date-based backfill for existing evidence. Expiry erases only ciphertext while preserving the verification status and minimal summary.

Daily authorized-request intelligence is populated only after signature, session, release, and device checks pass. The scheduled `app-security:cleanup` command removes expired nonces/challenges and ages out logs, signals, risk scores, and daily summaries according to its configured retention windows. Expired attestation ciphertext is cleared by the scheduled cleanup while verification summaries remain available for audit. The account-scope migration rollback refuses to restore the former global installation UUID uniqueness if multiple accounts already share an installation; resolve/reconcile those rows before rolling back. Production migrations must be reviewed and run in staging before production.


Risk signal rows include nullable review disposition metadata (`review_status`, `reviewed_by`, `reviewed_at`, `review_reason`). The additive migration refuses rollback after decisions exist so human review history is not silently deleted.
