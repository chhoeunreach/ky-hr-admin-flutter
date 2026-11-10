# Mobile POS dashboard and reporting

## Analysis and implementation

The mobile project is Flutter/Dart with Provider, Dio, flutter_translate, Get/Navigator routing, fl_chart, and the existing Preferences bearer-token/server resolver. The neighboring `hr-ky-admin` project is Laravel 10 with Passport authentication.

The existing `sell_out_reports` / `sell_out_report_lines` tables already represent Sell, Material, Iron, Repair, and Buy In. The implementation reuses these records, the authenticated reports URL, invoice creation and detail screens, and existing session and localization behavior. The HR dashboard and permission-controlled repair price catalog remain available.

The new entry point is **Dashboard in the Services drawer**, or the `/mobile-pos` route. It defaults to the business dashboard. Per the user’s final clarification, the approved Sell, Material, Iron, Repair, and Buy In screen layouts remain in use. Drawer items, dashboard shortcuts, category rows, and bottom-navigation buttons open those existing `SellOutReportScreen` module views. `/sell-out-report` and iCloud Cus retain their existing screens. No Mark Completed action or invented transaction status is added. HR login/attendance landing behavior is preserved: there is no existing POS-specific permission on which to base an app-wide HR-to-POS redirect.

On phones the bottom bar contains Dashboard, Sales, Material, Iron, and More. Repair and Buy In are in More. Dashboard quick access provides all six modules: Sell, Material, Iron, Repair, Buy In, and iCloud Cus. iCloud Cus remains available in More at every screen width, and all six module screens can return to Dashboard or switch modules using the bottom bar. Wider screens show all seven destinations.

## Confirmed financial and data boundaries

The user confirmed using the existing schema and displaying unavailable metrics instead of introducing financial fields or repair-order states.

- Recorded revenue sums **distinct report header amounts** for Sell, Material, Iron, and Repair. Each report has one type, so category subtotals are not added a second time.
- Buy In is separate purchase spending and never contributes to revenue. Its seeded commission rule is disabled; the admin can now explicitly configure it in Commission Settings.
- Dashboard sales-report and sold-quantity KPIs refer to Sell records. Module KPIs refer to that module's records. Total transactions counts all included records once.
- Qualification is a **commission condition**, not a transaction lifecycle/payment status. A failed commission condition does not establish that a sale was cancelled.
- There are no transaction-level COGS/direct-cost links or cancellation/refund/return/payment-state columns. Gross profit is therefore `null`/Unavailable. The UI does not claim recorded revenue is net recognized revenue or subtract purchases to invent profit.
- The existing Repair module is a repair **transaction report**, with customer, product/device lines, notes/problem description, amount and details. The repair price catalog is not a repair-order system. No technician, order workflow, payment status, or purchase-inventory matching is invented.
- Seeded invoice commission rates remain: Sell 0.25/item, Material 0.25/invoice (invoice total >= 10), Iron/Repair 0.20/invoice, Buy In zero by default. Per-service rates, bases and conditions can now be changed globally in the admin panel. Phone length > 6 is required with conditions.
- The previously requested report preview uses each seller's phone-qualified Sell quantity over the **complete searched/date/branch/employee/type scope**, grouped by authenticated owner, normalized seller name, and work category. Threshold is 50 for part-time, 100 otherwise. Status filtering and pagination follow that qualification step.
- Without conditions bypasses the phone, minimum amount and quantity tests, retaining each service rate. Preview calculations do not alter saved invoice/payroll commissions.
- The API returns the existing configured payment-currency symbol. The dashboard does not assume USD.

## API contract

Reuse: `GET /api/sell-out-reports?paginated=1`.

Older callers, including the approved module views, retain their existing response without `paginated=1`. The new dashboard explicitly rejects a response without reporting metadata rather than treating a legacy list as server-paginated data.

Parameters:

| Parameter | Values/default |
| --- | --- |
| `date_from`, `date_to` | `YYYY-MM-DD`; today by default, inclusive local business dates |
| `type` | `all`, `sell`, `material`, `iron`, `repair`, `buy_in` |
| `branch_name`, `seller_name` | Exact values from permitted filter options |
| `search` | Invoice/original reference, customer, phone, employee, product, SKU, IMEI, serial; max 160 chars |
| `report_status` | `all`, `qualified`, `failed`, `not_applicable` |
| `commission_mode` | `with_conditions` (default), `without_conditions` |
| `page` | Positive integer, default 1 |
| `per_page` | 20 (default), 25, 100, 250, 500 |
| `bucket` | `day`, `week`, `month`; automatic interval when omitted |
| `export` | `csv` streams all matching rows without loading them as mobile JSON |

Response: bounded `data`, `meta`, backend `summary`, `categories`, zero-filled aggregated `chart`, authorized filter `options`, `permissions`, explicit unsupported `capabilities`, currency symbol and branch/business label.

The new dashboard uses bounded server-side paging and filtered CSV export. The approved module views retain their existing Show 25 / 100 / 250 / 500 / All selector and layout. Search is debounced by 350 ms; stale requests cannot overwrite more recent filters. Changing filters or page size resets the page. Pull-to-refresh, errors/retry, loading skeletons, empty states, custom/calendar shortcuts and filter reset are implemented. Today, This Month, Last Month, and This Year are visible Dashboard shortcuts with the current range highlighted; the calendar button still opens a custom date-range picker.

## Access and performance

The mobile API preserves the existing **own-report** scope (`user_id = authenticated user`) for all roles. It does not introduce access to co-workers or other branches. Branch/employee options come from that same scope, and unowned filter values return 403. Existing `auth:api`/permission middleware remains in place; report/detail/edit calls still enforce server-side ownership. Menu permissions come from the API and initial/unauthorized states do not grant module actions.

Aggregation and pagination run in the database. Line quantities are grouped once per report, scoped to the owner/date range; photos are not joined into financial totals. A composite `(user_id, created_at, id)` index supports bounded date queries. Only daily aggregate scalar rows are bucketed in PHP, not transaction records. CSV uses a streamed database cursor with spreadsheet-formula escaping. Read aggregation runs in a database transaction for a consistent summary/page snapshot.

## Install and verify

Deploy the backend change before the mobile build. No financial or repair-workflow schema migration is included; the single migration adds a reporting index.

Backend (from `hr-ky-admin`):

```sh
php artisan migrate --path=database/migrations/2026_11_10_000001_add_mobile_reporting_index.php
php artisan route:list --path=sell-out-reports
php vendor/bin/phpunit tests/Feature/MobilePosReportingTest.php
```

Mobile (from `hrky-flutter`):

```sh
flutter pub get
flutter analyze lib/features/pos lib/services/sell_out_api_service.dart lib/main.dart lib/screen/dashboard/dashboard_screen.dart
flutter test test/pos_reporting_api_test.dart test/pos_reporting_provider_test.dart test/pos_workspace_test.dart
flutter test test/sell_out_report_test.dart test/report_commission_calculation_test.dart test/sales_dashboard_test.dart test/sell_out_sales_screen_test.dart
flutter run -d <device-id>
```

Open the Services drawer → Dashboard. Verify with an authorized employee account and its own records. Existing server selection and token handling are reused; no credentials are embedded in this feature.

Build checks:

```sh
flutter build apk --debug --no-pub
flutter build ios --simulator --no-codesign --no-pub
```

Backend tests use isolated in-memory SQLite tables and Passport test identities, not the configured business database. They cover scope restrictions, validation/auth, date/search/type/status composition, no double counting, exclusion of Buy In from revenue, service rules, CSV escaping, pagination and legacy response compatibility. Mobile tests use repository/HTTP fixtures to cover API contracts, debounce/race handling, server paging, filters, navigation, permissions, errors, loading/empty states and English/Khmer layouts at 320/390/768 widths. Fixtures are confined to tests.

## Verification on 10 November 2026

- Targeted Flutter analysis: no issues.
- All seven report/dashboard test files: 63 tests passed.
- Laravel reporting tests: 11 tests / 95 assertions passed (one existing PHPUnit configuration deprecation).
- Android debug APK build succeeded: `build/app/outputs/flutter-apk/app-debug.apk`.
- iOS simulator build succeeded using the existing Runner scheme; the app is `build/ios/Debug-iphonesimulator/KY CHECKIN.app`.

The first standard iOS build exhausted the local disk while compiling native dependencies. After removing only this workspace's generated DerivedData cache, the successful retry disabled generated native debug symbols and indexing to reduce disk usage. No persistent Xcode/Podfile settings were changed:

```sh
cd ios
xcodebuild -configuration Debug -quiet -workspace Runner.xcworkspace -scheme Runner \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -jobs 4 \
  BUILD_DIR="$PWD/../build/ios" CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY='' \
  GCC_GENERATE_DEBUGGING_SYMBOLS=NO CLANG_ENABLE_MODULE_DEBUGGING=NO \
  COMPILER_INDEX_STORE_ENABLE=NO FLUTTER_SUPPRESS_ANALYTICS=true
```

Production deployment, the reporting-index migration, and testing against a live employee account remain deployment steps; local verification does not alter business records.

### Six-module navigation follow-up

Dashboard now exposes six direct shortcuts, including iCloud Cus. The Dashboard More menu and quick access use the same module navigation behavior. More remains selected when iCloud Cus is active on both phones and tablets. Existing module layouts, financial rules, and the five-module reporting aggregate remain unchanged.

Follow-up checks: 31 Dashboard/module widget tests passed, including complete six-module navigation loops in English and Khmer at 390px and 768px; targeted Flutter analysis reported no issues.

### Flutter/backend audit follow-up

The audit verified create/detail/edit flows for Sell, Material, Iron, Repair, Buy In, and iCloud Cus, while retaining their approved screens. It fixed CSV validation/authentication errors returning redirects, reconciled Flutter pagination when the server clamps a requested page, kept report scroll restoration safe across request changes, sent original invoice references with submissions, bounded search to the API's 160-character limit, and added a 15-second API connection timeout. Custom date selection now clears the prior chart-bucket override.

Latest checks: 71 Flutter tests passed; targeted analysis reported no issues. Backend tests passed with real permission middleware on both isolated SQLite and temporary MySQL: 15 tests / 171 assertions. The checked-in test-only `pos_backend_contract.json` response was generated through Laravel's HTTP kernel against the MySQL fixture, and a Flutter API test checks that its totals, dates, currency, permissions, and transactions parse correctly. It contains synthetic records only.

Android debug and iOS simulator builds passed after these changes. The configured business MySQL server refused connections during this audit; no migration or business-data changes were applied. Live-account checks require the configured database/server to be available. Backend deployment and verification instructions are also in `hr-ky-admin/docs/mobile-pos-reporting.md`.

### Admin-managed commission

One global configuration is now available in **Payroll → Commission Settings** in `hr-ky-admin`. The administrator can edit each service rate, per-item/per-invoice basis, phone requirement, amount and part-time/full-time quantity minimums, earning enabled state, visibility, calculator availability, default mode, and per-role mobile controls. Buy In and iCloud Cus are disabled by default; enabling them requires an explicit admin settings change. Financial revenue definitions are unchanged.

Flutter uses effective `commission_policy` metadata from the authenticated APIs. It hides commission cards, qualification badges/counters, calculation menus, form previews, invoice details and local export columns when the server hides them. Without preview permission, the server returns saved commissions. Mode restrictions are enforced server-side. New screens fail closed when policy metadata is absent. Custom rule sheets display the configured values instead of fixed text.

The initial request defers to the administrator's default mode; a permitted user can subsequently choose another mode. Server resources return persisted invoice commissions. Rule updates do not rewrite existing invoices or payroll; new or explicitly edited transactions use the current policy. Draft edits clear fetched amount snapshots so minimum-amount conditions use current line totals.

Deploy the new backend code and apply `2026_11_10_000002_create_commission_settings.php` before using the controls. Details, role-permission setup, audit behavior, API fields, and test commands are in `hr-ky-admin/docs/commission-settings.md`. The configured business database was not modified during development.

Commission administration verification: 94 Flutter tests passed (including the policy/session-expiry checks); 43 backend cases / 423 assertions passed on both SQLite and temporary MySQL. Flutter analysis is clean, and current Android debug / iOS simulator builds succeeded. The business database remains unchanged; activation requires the new migration.

### Business breakdown and surface styling

Sales and Dashboard now share a neutral background, white dropdown/menu surfaces, muted borders, inherited app typography, and blue selection states. Business breakdown includes Sales alongside Material, Iron, Repair and Buy In, with aligned Amount and Commission columns. Category rows still open their existing module screens. The commission column is hidden by the effective server policy; an absent category commission is shown as unavailable instead of inventing a zero.

The API adds `categories[].commission` from the same filtered aggregate as the report summary, and omits that field for roles without commission visibility. Layout and navigation checks cover English/Khmer at phone and tablet widths. The current API fixture was regenerated from the isolated Laravel SQLite response.

Business breakdown/surface update verification: 55 targeted Flutter UI/API tests and 45 backend tests passed; analysis is clean. Visual review covered the new surfaces and aligned columns. Android debug and iOS simulator builds both succeeded.
