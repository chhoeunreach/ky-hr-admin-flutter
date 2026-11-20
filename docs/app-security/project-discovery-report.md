# Project discovery report

Facts below were inspected from the Flutter and Laravel repositories. Production secrets and the configured production database were not queried.

| Area | Inspected value |
| --- | --- |
| Flutter / Dart | Flutter 3.41.9 / Dart 3.11.5 |
| Android application ID | `com.kneayerng.hrms` |
| Android minimum / target / compile SDK | 28 / 36 / 36 |
| Android Gradle Plugin / Gradle | 8.9.1 / 8.11.1 |
| Kotlin | 2.1.0 |
| Laravel / PHP | Laravel 10.50.2 / PHP 8.3.30 |
| Mobile authentication | Existing Passport bearer tokens; `auth:api` guard |
| Browser admin authentication | Separate `admin` guard and existing permission middleware |
| User and role storage | `users`; roles and permissions are separate existing application records |
| Mobile API authorization | `auth:api`, `app.security`, `permission`, and `MobileFunctionPermission` on protected groups |
| Website/API host | Root Laravel application serves website and API, as confirmed by the user |
| Database | Local environment config uses MySQL. Production database engine/version was not queried. |
| Cache and queue | Inspected local configuration uses file cache and synchronous queue; Redis integration was not verified/configured. |
| Release signing | Existing ignored Android key configuration and local keystore. The build expects signer SHA-256 `6A275F4C91E2ACCF7654BA89C26514D9678FCDD1BAC30A4AD37D533CC2192AC9`; the production owner confirmed approval of this fingerprint on 2026-11-20. |

## Identity and role mapping in App Security

The server links a device to the authenticated `users` record. The current registration service derives `user_type` from the related role slug: `customer` or `client` becomes `customer`; `admin`, `super-admin`, `supper-admin`, or `super_admin` becomes `admin`; other slugs become `staff`. Confirm these exact slugs against the production role data before enabling enforcement. Device type does not grant business permissions; existing permission middleware still applies.

The requested `users` table with separate staff/customer roles is therefore supported without introducing a parallel customer account system.

## Compatibility and migration notes

- No broad Flutter, Android, Kotlin, Gradle, or Laravel framework upgrade was made for this work.
- App Security migrations create only App Security tables plus a migration-object tracking table. They were exercised on an isolated SQLite database; production MySQL was not migrated.
- The production `.env`, database, signing keystore, and release registry were not changed.
- Full discovery facts and current gaps are summarized in [implementation status](implementation-status.md).

