# Project audit — 14 November 2026

## Corrected behavior

- Missing API strings now use their intended fallback values rather than displaying `null` (99 fallbacks across 21 model files).
- Leave types tolerate missing numeric allocations, convert lists without fixed-length-list errors, and read the correct slug field.
- Profile date formatting tolerates empty or malformed optional dates in Nepali-calendar mode.
- Login and Change Password no longer dispose framework-owned Form state. Their asynchronous completion paths avoid updating closed pages and reliably dismiss loading overlays.
- Gallery file-read failures display an error and allow retry instead of leaving selection stuck. Media selection is copied before asynchronous conversion.
- Create Post audience labels fit narrow screens; gallery tests verify attached media through the current image preview UI.
- Three imports now match filename casing for case-sensitive build environments.
- Removed redundant null checks and unused imports; widget inputs and loading state now follow Flutter lifecycle ownership.
- Declared directly imported dependencies with version constraints.

## Verification

- `flutter test --no-pub --exclude-tags integration`: **367 passed, 3 skipped**. The skipped tests require opt-in live backend configuration.
- `flutter analyze --no-fatal-infos`: **passed; no errors or warnings**. There are 564 existing informational style/deprecation notices.
- Android manifest XML and iOS Info.plist validate.
- `git diff --check`: passed.
- `flutter build apk --debug --no-pub --target-platform android-arm64`: **passed**; output is `build/app/outputs/flutter-apk/app-debug.apk`. Native plugins emit Java compatibility/deprecation notices.

## Remaining validation

Full iOS compilation and physical-device checks are not verified by the unit/widget suite. The standalone PHPicker Swift implementation type-checked, but the full Xcode device build stopped before compiling Runner because the Mac ran out of disk space while writing its DerivedData manifest. The interrupted build left less than 1 GB free. Live backend, camera, gallery permissions, notifications, NFC, and attendance-location behavior require configured devices and services.
