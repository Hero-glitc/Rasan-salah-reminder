# Salah Reminder v1.1 (Flutter, Android) - manual prayer times

Update: copy everything in this folder into your GitHub repository (same paths overwrite old files), including the hidden .github folder. The "Build APK" run starts by itself; download salah-reminder-apk from the run's Summary page.

What changed in 1.1
- Notifications: reminders are scheduled one at a time (no overlapping runs), every failure is caught and shown in Settings > "Last problem", and two new test buttons were added (instant test and a scheduled test in 1 minute).
- Notification sound: pick any notification sound from your phone (Settings > Notification sound).
- Automatic prayer times removed; manual only.
- Timeline selector: Settings > tap a prayer > drag the Start and End markers along a 24-hour timeline (5-minute steps, plus -1/+1 minute buttons).
- Dates on the Home header: Gregorian, Hijri, Afghan Solar Hijri (Shamsi) and Iranian Solar Hijri; switch each on or off in Settings > Dates shown on top, plus weekday and Hijri +/-2 day adjustment.

Old file lib/core/calc.dart is no longer used; deleting it is optional.
Not compiled or run on a device here. Backup/restore uses the clipboard.
