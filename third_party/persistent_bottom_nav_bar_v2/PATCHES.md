Based on persistent_bottom_nav_bar_v2 5.3.0, with its original LICENSE preserved.

Local fixes:

- Keep dashboard tab build flags growable as permission-driven tabs change.
- Resize tab navigator keys and focus scopes with the tab count.
- Dispose the previous animation controller when reconfiguring tabs.
- Do not request dashboard focus while another root route covers it. The
  dashboard scaffold can be reparented during a background permission refresh;
  requesting focus then hides the active report field's keyboard.
- Prevent recreated tab navigators from requesting focus behind a root route.
- Disable focus requests for covered or inactive tab scopes so Navigator's
  own autofocus cannot steal focus from the visible report route.

Regression coverage: `test/dashboard_keyboard_focus_test.dart`.
