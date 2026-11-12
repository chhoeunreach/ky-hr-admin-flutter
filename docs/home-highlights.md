# Home Highlights

Home Highlights is managed in Laravel at **Community → Home Highlights**
(`/admin/home-highlights`). Employees read it in Flutter under the clock card's
**Highlights** tab. The existing **Late & Bonus** tab remains available.

## Publishing

Create or edit a highlight with its title, formatted body, optional image,
optional HTTPS link/button, priority, and publication schedule. An unchecked
publication switch saves a draft. The index supports search and live, scheduled,
draft and expired filters. Use the edit, enable/disable and delete actions to
manage existing entries. Admin preview shows formatted, sanitized content.

Blank audience selections include everyone in the company who can access Home
Highlights. Role, branch, department and employee selections combine: an employee
must match each nonempty selection. The backend rejects branch, department and
employee IDs outside the administrator's company. Only the API supports legacy
company-neutral highlights; the company admin editor creates company-owned items.

Schedules use the backend's configured timezone. At the opening time a published
highlight enters the home carousel; at its closing time it leaves the carousel.
Expired published entries remain in **View all** history and can still be opened.
Drafts, future entries and entries outside the employee's audience are not returned.
Disable a highlight to remove it from the carousel, history and detail API.

**Send now** is optional and requires a currently live highlight. It targets active,
verified employees with registered push tokens, the required role permissions, and
the selected audience. Delivery results report Firebase acceptance, not guaranteed
device receipt. Opening a push alert or stored notification fetches the detail from
the authenticated API; inaccessible/deleted highlights show a retryable unavailable
screen instead of stale alert content. No live alerts were sent during verification.

## Flutter behavior

- The home carousel shows up to ten live highlights, ordered by priority/newest ID.
- Tap a slide to read the formatted article; **View all** opens paginated history.
- Auto-rotation pauses while the app is backgrounded, the user is swiping, another
  route is open, or reduced motion is enabled. Returning to Highlights or resuming
  the app refreshes the current list.
- History supports pull-to-refresh, explicit load-more and retry controls. An old
  page response cannot overwrite newer refresh results; duplicate IDs are removed.
- Invalid API responses produce an error instead of a misleading empty state.
- Uploaded images follow the selected API host after LAN/server address changes.
  External image URLs remain unchanged. HTML entities and emoji are preserved in
  snippets. External link failures show a message instead of an uncaught error.
- Orphan-file cleanup now protects images referenced by Home Highlights, including
  references saved under an earlier server hostname.

## Installation and permissions

The backend's `2026_11_13_000001_create_home_highlights.php` migration is already
installed in the configured development database. On a different deployment:

```sh
php artisan migrate --path=database/migrations/2026_11_13_000001_create_home_highlights.php --force
```

Grant **Manage Home Highlights** (`home_highlight.manage`) to editors. Employees
need **Home Highlights Feature** (`mobile.menu.home-highlights`) and **View Home
Highlights** (`home_highlight.view`). The migration seeds these permissions and
copies relevant existing community role assignments. Refresh/sign in again after
changing role permissions so Flutter receives the latest feature flags.

Serve uploaded images through the public storage symlink. Push requires the
existing Firebase configuration and device notification permission. Deploy both
Flutter and Laravel changes; platform notification delivery requires device testing.

## Verification

```sh
# Flutter
flutter test --no-pub test/home_highlights_test.dart test/home_monthly_attendance_summary_test.dart

# Laravel
php vendor/bin/phpunit --filter 'HomeHighlightTest|UploadedMediaUrlTest'
```

Latest verification: 25 Flutter tests and 25 backend tests passed. The changed
highlight API, screens, carousel, model and tests have no analyzer issues. The
backend checks cover permissions, company/audience isolation, schedule boundaries,
rich-text sanitization, admin CRUD, image cleanup, URL normalization and notification
recipient selection using a fake sender. Physical-device push delivery was not tested.

## Automatic switching with Late & Bonus

At **Admin → Community → Home Highlights → Home card automatic switching**,
turn automatic switching on/off and set separate durations for **Late & Bonus**
and **Highlights**. Each duration accepts 5–300 seconds. New companies default
to enabled, 15 seconds for each tab. These company settings are independent of
individual highlight publication dates and audience selections.

The authenticated index API returns `display_settings` alongside `data`:

```json
{
  "auto_switch_enabled": true,
  "late_bonus_seconds": 15,
  "highlights_seconds": 15
}
```

Flutter starts on Late & Bonus, then alternates using these durations. A manual
selection restarts the timer for the selected tab. When the company has no live
highlights, automatic switching stops and Late & Bonus stays visible. Background
apps pause their timer; returning to the app refreshes settings. No automatic
switch occurs while a detail/history route covers the Home page. Open apps check
for admin changes every minute without showing a loading spinner. Older servers
that omit `display_settings` retain manual tabs.

Install this additional migration when deploying the timing controls:

```sh
php artisan migrate --path=database/migrations/2026_11_13_000002_create_home_highlight_display_settings.php --force
```

This migration is installed in the configured development database. No existing
highlights or attendance records are changed. Only users with
`home_highlight.manage` can save timing settings, scoped to their company.

Timing verification: `flutter test --no-pub test/home_highlight_timing_test.dart
test/home_highlights_test.dart` passed 17 tests; Laravel `HomeHighlightTest` passed
24 tests, including company isolation, defaults, bounds and permission checks.
