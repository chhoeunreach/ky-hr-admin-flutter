# App Security disaster recovery

## Protected recovery assets

- Laravel database backups containing device bindings, challenges, token hashes, release records and audit history.
- Private `storage/app/app-security/releases` APK artifacts; record checksums and restore with permissions that keep files outside the public web root.
- Laravel `APP_KEY`, required to decrypt submitted attestation evidence. Protect it with the normal production secret backup/rotation process; rotating without a migration plan makes existing encrypted evidence unreadable.
- The production Android release-signing keystore and its passwords, backed up separately under controlled access. This keystore is never stored in the Laravel database, public website directory or Git.
- Release signer registry and build metadata, including version code/checksum mapping.

## Restore order

1. Restore application code and compatible dependencies.
2. Restore database and Laravel encryption key material from the same recovery point.
3. Restore private APK files and verify every file against `apk_sha256` in the release table.
4. Restore environment configuration without printing secrets; validate package name, signer list and SDK tool paths.
5. Keep `KY_SECURITY_ENABLED=false` while verifying routes, app release page and storage access.
6. Reconcile active release status and device/session data; expire or revoke sessions if token state is uncertain.
7. Run staging smoke tests before re-enabling production enforcement.

## Compromise response

- Signing key compromise: suspend rollout, revoke compromised signer trust and affected releases, generate a controlled replacement signing plan, publish a new independently verified release, and force update only after server/client compatibility is confirmed.
- Laravel `APP_KEY` loss: encrypted evidence may be unrecoverable. Preserve database records as unverified, rotate encryption material through a documented procedure, and require fresh registration/attestation according to policy.
- Device key compromise: block/revoke the device server-side; protected API middleware rejects its next request. Disconnected devices cannot be blocked instantly.
- Database or storage uncertainty: disable enforcement rather than allowing uncertain release data to authorize clients; preserve forensic copies and audit logs.

## Current recovery gaps

No tested backup/restore procedure, release keystore recovery drill, evidence re-encryption job, nonce cleanup schedule, incident notification integration or DR RTO/RPO has been defined. Establish these with infrastructure owners and test them in an isolated environment before production rollout.

