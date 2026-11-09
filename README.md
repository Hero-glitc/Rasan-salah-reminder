# Salah Reminder (Flutter, Android)

## Build the APK with GitHub (laptop)
1. On github.com create a NEW public repository, e.g. `salah-flutter` (do not reuse the old Capacitor one).
2. Unzip this project. Click "uploading an existing file" and drag in EVERYTHING inside the folder:
   `lib`, `test`, `tools`, `pubspec.yaml`, `README.md` and the hidden `.github` folder.
   (Windows: File Explorer > View > Show > Hidden items. Mac: press Cmd+Shift+. in Finder.)
   If `.github` will not upload, use Add file > Create new file, name it `.github/workflows/build-apk.yml`, and paste the file's text.
3. Commit. Open the Actions tab. "Build APK" runs (8-12 minutes).
4. Open the finished run > Summary > scroll to Artifacts > download `salah-reminder-apk`, unzip, install `app-release.apk`.
5. In the app allow notifications and exact alarms. Android Settings > Apps > Salah Reminder > Battery > Unrestricted.

If the run fails, open the failed step and send the last 30 lines of the log.

## File locations
- lib/main.dart - app start, theme, language, bottom navigation
- lib/core/models.dart - statuses, windows, date helpers, Hijri date
- lib/core/calc.dart - astronomical prayer time calculation (offline)
- lib/core/schedule.dart - settings model, manual and automatic prayer windows
- lib/core/db.dart - SQLite storage (settings, prayer records)
- lib/core/notif.dart - reminders, actions, background handler, reschedule
- lib/core/state.dart - app state, clock, status changes
- lib/core/strings.dart - English, Arabic, Dari, Pashto text
- lib/ui/home.dart, history.dart, stats.dart, settings.dart, widgets.dart - screens
- test/schedule_test.dart - unit tests
- tools/patch_android.py - adds permissions, boot receivers, desugaring to the generated Android project
- .github/workflows/build-apk.yml - cloud build

## Not verified (read this)
- Nothing here has been compiled or run on a device. Only the prayer-time math and Hijri conversion were checked separately (Makkah and Kabul sample times look right).
- Backup/restore/export use the clipboard (copy text, paste to restore), not files.
- Hijri date is the tabular calendar and can differ by one day from moon sighting.
- Changing timezone is picked up the next time the app opens (no native timezone listener).
- High-latitude locations use a simple fallback for Fajr/Isha.
- Dari and Pashto translations need review by a native speaker; untranslated labels show in English.
- Phones with aggressive battery managers may still delay alarms; the in-app battery guide explains the settings.
