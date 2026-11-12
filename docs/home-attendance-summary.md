# Home attendance indicators

The employee home clock now has a compact current-month attendance card. It shows the signed-in employee's unexcused late count, estimated deduction, and progress toward the attendance bonus target configured in Admin → Attendance Settings (default $20). Tap the card for the month, qualifying-day counts, and calculation explanation. Narrow screens and larger accessibility text place the card below the clock.

The card also shows approved late days and approved time-leave days this month through today. Only approved requests contribute to these totals; pending/review requests are not labelled approved. Duplicate requests on the same date count once. A date can appear in both totals when approved time leave also excuses lateness. The existing deduction/excuse rules remain unchanged. Older API responses without these fields show dashes for approval totals.

The dashboard response contains `data.monthly_attendance_summary`. After successful online check-in/out, Flutter refreshes it using authenticated `GET /api/dashboard/attendance-summary`. Home refresh, resume, and date rollover also update it. Requests carry the existing token and use the configured API host. Old responses cannot overwrite newer summary requests. Unavailable, malformed, or stale-month data displays dashes rather than invented amounts.

Backend calculations share `MonthlyAttendanceRules` with the admin monthly attendance report. Deduction uses its standard **minute-based** rule (not the separate Count export), including excused lateness and the existing warning threshold. This is an estimate, not a new payroll deduction. No new per-role rates or payroll mutations were introduced.

Bonus progress = qualifying completed workdays / all scheduled working days in the current month. Company weekends and active company holidays are excluded. Future days remain in the denominator, so an early-month perfect record does not display 100%. Qualifying-day conditions are the same as the admin monthly report: complete check-in/out, punctual arrival, full checkout, and no applicable leave/time-leave request. The configured target is not shown as an earned or prorated payout.

Deploy the backend changes before distributing the updated Flutter app. This feature uses existing tables and needs no database migration.

Verification: backend summary/authentication tests plus existing monthly attendance/bonus/deduction regression tests; Flutter request/error/race/disposal, parsing, English/Khmer phone/tablet layouts, and large-text/dark-theme tests.

The home card explicitly shows `total late - excused late = late to deduct`. Total late is the sum of the server-provided unexcused and excused late counts. The separate approved time-leave total is not subtracted because it may include days without lateness.
