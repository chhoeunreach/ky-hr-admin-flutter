# Mobile roles and permissions

The Flutter app and sibling `hr-ky-admin` backend now share role-controlled business menus and API functions. The backend catalog is `config/mobile_permissions.php`; it lists 40 mobile menu/action groups and 168 authenticated API functions and four direct-chat operations, including explicit exemptions for session bootstrap, logout, device-token updates, required location updates, and legal content. Repair Price keeps its existing separate permission checks and permissions endpoint. Device kiosk authentication remains separate.

## Admin configuration and rollout

Deploy the backend changes together with the Flutter changes. In the admin backend, run:

```sh
php artisan migrate
php artisan config:clear
```

If deployment uses cached configuration, rebuild it afterward with `php artisan config:cache`.

Open the existing **Roles → Permissions → API** tab. Each **Mobile …** group contains its menu permission and newly added function permissions. Grant the menu plus the functions the role needs. Existing function permissions retain their existing groups and assignments. For example, Profile also requires the existing `view_profile` permission; editing requires `update_profile`. Salary approval continues to use `advance-salary-approve`.

**New permissions are denied until an administrator assigns them.** Configure employee roles during rollout before distributing the new app. The migration does not grant new access automatically or change existing assignments. Recognized admin roles and authenticated admin-panel accounts retain their existing bypass; numeric role IDs alone no longer confer admin access.

The backend checks both menu access and the exact function permission before running the controller. Existing ownership checks and domain-specific permissions still apply. A role allowed to list data cannot mutate it without the corresponding function permission. New routes added to the protected mobile API group are denied until listed in the catalog.

## Flutter behavior

Business entries in More, the drawer, dashboard tabs, home cards, profile/card shortcuts, and notification navigation follow the server's feature snapshot. Selected action controls (profile edit and leave submission) also use function grants. Other action buttons can remain visible, but the backend rejects unauthorized requests with HTTP 403. Fixed attendance/leave tab shortcuts now open their screens directly because available tabs vary by role.

Permissions refresh with the dashboard. An already open app can display the previous menu snapshot until refresh, but server-side authorization applies to each request immediately. The cache preserves all returned keys, replaces the entire snapshot when refreshed, denies missing/corrupt data, and clears on login/logout. Old enabled-by-default preferences are ignored. Global feature switches still restrict menu visibility in addition to role permissions.

Home, account logout, legal/help content, language, local animation preferences, and server connection diagnostics remain available as app infrastructure. Employee-to-employee chat writes directly to Firestore. Its client controller now checks view/send/edit/delete permissions, but authoritative enforcement and immediate revocation of existing Firestore listeners require corresponding Firebase security rules. No Firebase rules are checked into this repository; that external configuration still needs review.

This change targets the mobile app and its API; it is not a full audit of every web-admin controller.

## Verification

- Backend tests cover route-catalog completeness, denied direct requests, menu/function separation, read-versus-write access, feature switches, migration registration/rollback, and numeric-role bypass prevention.
- Flutter tests cover cache replacement, revocation, malformed/missing snapshots, logout clearing, and boolean/numeric status parsing.
- Existing employee-function and salary-approval regression tests also run with uncached test configuration.
