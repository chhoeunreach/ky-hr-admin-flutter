# Daily Work Records

## Architecture

Flutter 3.41.9 and Dart 3.11.5 use the existing floating button, navigation, theme provider, localization delegate, signed HTTP client, and file picker. Quick Create fetches capabilities as it opens. The earlier Daily Records actions remain available against a server that does not advertise the extended workflow.

Laravel 10 and PHP 8.3 use existing Passport and device-security middleware on mobile and the existing admin session on the web. The module reuses employee and department scope, task assignments, private storage, event history, queue notifications, and Excel and PDF libraries. MySQL is the configured application driver. The local test suite uses SQLite 3.53.0. Production engine version and query plans were outside the local verification.

## Repository changes

| Repository | Added | Extended |
|---|---|---|
| Flutter | In lib/features/daily_records, work_record_editor.dart, work_records_screen.dart, daily_summaries.dart, related_task_picker.dart, and work_labels.dart. Tests in test/daily_work_records_test.dart. | quick_create.dart, daily_records_api.dart, employee_records.dart, record_detail.dart, and my_tasks_screen.dart |
| Laravel | In app/Modules/DailyRecords, CategoryCatalog.php, WorkRecords.php, WorkInput.php, DailySubmissions.php, WorkRecordsApiController.php, WorkRecordsAdminController.php, work-api.php, and work-web.php. New incident, submission, and settings views in resources/views/admin/daily-records. | Module route files, config/mobile_permissions.php, existing Daily Records entry, scope, audit, read, reporting and admin integration, tests/Feature/DailyRecordsTest.php |
| Database | 2026_11_20_180000_extend_daily_work_records.php and catalog/daily_work_categories.php | Additive columns and indexes on daily_entries and daily_record_files |

The migration introduces the category tree, daily submissions, versioned report content, links to source records, and encrypted editor drafts. It preserves the earlier tables and rows. Legacy entries without an occurrence timestamp use their recorded date in reports. Existing classified records retain saved classification labels and validation definitions.

Laravel entry points also extend the existing DailyRecordsApiController, DailyRecordsAdminController, Entries, RecordAccess, RecordEvents, RecordInput, RecordRead, Reporting, ReportSpreadsheet, Tasks, and the existing report center index, results, and detail views.

## Mobile routes

Paths use the prefix /api/v1/daily-records. The response uses the existing data envelope. Lists are paginated. For work-record and summary uploads, the JSON inputs go in the multipart payload field and evidence in files[].

| Method and path | Operation |
|---|---|
| GET capabilities | Work Records, manager assignment, and report-review flags |
| GET catalog?kind=activity or kind=incident | Active department-visible categories, subcategories, fields, and suggested tags |
| GET work-records | Owner records or assigned incidents, with kind, search, tag, archive, assigned, and page filters |
| POST work-records | Create an activity, incident, or note. Supply request_id as a UUID to deduplicate retries |
| POST work-records/{id} | Edit an owned record with its current revision |
| POST work-records/{id}/note | Pin, unpin, archive, or restore |
| GET and POST drafts/{key} | Read or save encrypted account-scoped form text. An empty POST clears the draft |
| GET assigned-incidents/{id} | Read an incident explicitly assigned to the caller |
| POST assigned-incidents/{id}/actions | Add an incident response and optional evidence |
| GET assigned-incidents/{id}/files/{file} | Download evidence under the same incident authorization |
| GET records/{id} and records/{id}/files/{file} | Existing owner detail and file routes |
| GET summaries/preview?date=YYYY-MM-DD | Eligible activities, incidents, tasks, and an existing draft for the day |
| GET summaries and summaries/{id} | Owner submissions and version details |
| POST summaries | Save or submit using report_date, revision, action, record_ids, and summary fields |
| GET summary-inbox and summary-inbox/{id} | Scoped manager inbox and detail. Detail accepts version |
| POST summary-inbox/{id}/actions | Start review, approve, return, or comment. Supply the submitted version |
| GET summary-inbox/{id}/files/{file} | Download an attachment included in a submitted version |

Activity times and incident occurrences are interpreted in Asia/Phnom_Penh. Send dates as YYYY-MM-DD, times as HH:mm, and local date-times as YYYY-MM-DDTHH:mm. Stored timestamps are UTC. Stale edits or decisions return 409. WorkInput.php defines the fields, conditional requirements, and upload limits.

The web center stays under /admin/daily-records. Submissions, incident management, and category settings use the existing admin authentication and CSRF controls.

## Permissions and reporting rules

| Capability | Authorization |
|---|---|
| Create, edit, save drafts, and submit own records | Active employee with an authenticated company and ownership |
| Respond to assigned incidents | Explicit assignment, matching company and location, and a nonconfidential incident |
| Assign tasks, review submissions, manage incidents, and export | daily_records.manage and existing employee, company, branch, and department scope |
| Review confidential cases and verify findings | daily_records.sensitive plus management scope. Reporters have access to their reports. Investigation notes and restricted evidence have reviewer-only access |
| Configure categories and workflows | daily_records.categories or an existing system administrator |

Each employee has one submission per reporting date per company. Corrections create new versions. Manager actions validate the current submitted version. Source activities and incidents retain their own workflows. Private notes and confidential incidents are excluded from ordinary submission selection. Review screens recheck source visibility at read time.

Incident verification has its own status and history. Targeted notifications reuse the current mobile inbox and queue, and confidential notifications carry no allegations.

## Category seed and configuration

Activities start with Sales, Customer Service, Inventory, Repair, Administration and HR, Finance, and General Work. Incidents start with Customer, Employee, Product and Stock, Operational and System, Financial, and Other incidents. The migration seeds the subcategories and configurable buyback reason choices.

The settings page manages English and Khmer labels, department visibility, activation, ordering, confidentiality, icon keys, suggested tags, default follow-up time, and permitted incident destinations. The server validates JSON definitions for text, multiline, number, date, date-time, dropdown, and multi-select fields. Existing attachment controls handle evidence. Device, POS, and stock references are descriptive and require no cross-module data access.

## Verification

Laravel passed 811 regression tests with one PHPUnit configuration deprecation. The final Daily Records feature run passed 10 tests covering scope, ownership, occurrence dates, classification history, submission revisions, downloads, and exports. The full Flutter run passed 578 tests with 3 skips. The final targeted run passed 41 tests, including the themed launcher, Khmer screen labels, dynamic forms, evidence uploads, button placement, and mobile review. Targeted Flutter analysis reported no issues.

## Rollout

1. Back up the database and private attachment storage. Rehearse the additive migration on a staging copy with representative legacy Daily Records.
2. Apply the pending additive migration before serving traffic with the new Laravel release.
3. Grant management, sensitive-case, and catalog permissions to the intended roles. Verify branch and department access with both ordinary and privileged accounts.
4. Verify the scheduler, queue worker, private file disk and Firebase delivery in staging before releasing the Flutter build.
5. For an application rollback, retain the schema and employee evidence and roll back the application code.

Editor drafts store text on the server while connected. Unsaved attachment selections live for the current form session. Personal notes use reversible archive and restore. The unsubmitted-report view finds employees with eligible activity or incident records for a date, so reporting obligations based solely on attendance are outside that view.

Report exports retain the existing filtered limits of 10,000 Excel rows and 500 PDF rows. Admin catalog setup uses validated JSON for field definitions, tags and allowed destinations. Configurable employee, customer, and product references are text fields. The incident responsibility picker uses the existing scoped employee directory. The admin pages use English labels.

Production MySQL behavior, deployment-scale performance, physical-device rendering and live Firebase delivery require environment testing.
