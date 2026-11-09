import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'db.dart';
import 'models.dart';
import 'schedule.dart';
import 'strings.dart';
import 'state.dart';

@pragma('vm:entry-point')
void notifBackground(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  await Notif.handle(r);
}

Future<void> _foreground(NotificationResponse r) async {
  await Notif.handle(r);
  await AppState.i.load();
}

class Notif {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  /// Stable id: (day number % 20000) * 100 + prayer * 10 + slot. Slots 0-7 = reminders, 8 = "remind me later".
  static int nid(String date, int prayer, int slot) {
    final d = parseKey(date);
    final day = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
    return (day % 20000) * 100 + prayer * 10 + slot;
  }

  static Future<void> init() async {
    const init = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await plugin.initialize(init,
        onDidReceiveNotificationResponse: _foreground,
        onDidReceiveBackgroundNotificationResponse: notifBackground);
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// [notificationsAllowed, exactAlarmsAllowed]
  static Future<List<bool>> perms() async {
    try {
      final a = _android;
      final n = await a?.areNotificationsEnabled() ?? false;
      final e = await a?.canScheduleExactNotifications() ?? false;
      return [n, e];
    } catch (_) {
      return [false, false];
    }
  }

  static Future<void> requestPerms() async {
    try {
      final a = _android;
      await a?.requestNotificationsPermission();
      await a?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  static NotificationDetails _details(Cfg c) {
    final l = c.lang;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        c.sound ? 'salah_sound' : 'salah_quiet',
        'Salah reminders',
        channelDescription: 'Reminders before a prayer time ends',
        importance: Importance.max,
        priority: Priority.high,
        playSound: c.sound,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('prayed', Str.get(l, 'markPrayed'), cancelNotification: true),
          AndroidNotificationAction('later', Str.get(l, 'remindLater'), cancelNotification: true),
          AndroidNotificationAction('open', Str.get(l, 'openApp'), showsUserInterface: true, cancelNotification: true),
        ],
      ),
    );
  }

  static String _fill(String s, String p, String t) => s.replaceAll('{p}', p).replaceAll('{t}', t);

  static Future<void> _schedule(Cfg c, String date, int prayer, int slot, DateTime at, int minutesLeft, AndroidScheduleMode mode) async {
    final l = c.lang;
    final name = Str.get(l, prayerKeys[prayer]);
    await plugin.zonedSchedule(
      nid(date, prayer, slot),
      _fill(Str.get(l, 'notifTitle'), name, leftText(minutesLeft)),
      _fill(Str.get(l, 'notifBody'), name, leftText(minutesLeft)),
      tz.TZDateTime.from(at, tz.UTC),
      _details(c),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: '$prayer|$date',
    );
  }

  static Future<void> cancelPrayer(String date, int prayer) async {
    for (var s = 0; s <= 8; s++) {
      await plugin.cancel(nid(date, prayer, s));
    }
  }

  /// Cancels reminder slots for the window, then schedules every future reminder again.
  /// Stable ids guarantee no duplicates. Prayed/missed/qada prayers get no reminders.
  static Future<int> rescheduleAll() async {
    final c = Cfg(await Db.settings());
    final now = DateTime.now();
    final dates = [for (var i = -1; i <= 3; i++) dayOf(now, i)];
    for (final d in dates) {
      for (var p = 0; p < 5; p++) {
        for (var s = 0; s < 8; s++) {
          await plugin.cancel(nid(dkey(d), p, s));
        }
      }
    }
    if (!c.notifOn) return 0;
    final perm = await perms();
    if (!perm[0]) return 0;
    final mode = perm[1] ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    var count = 0;
    for (final d in dates) {
      final key = dkey(d);
      final wins = Sched.day(c, d);
      for (var p = 0; p < 5; p++) {
        final rec = await Db.record(key, p);
        if (rec != null && rec.status != stNone) continue;
        final w = wins[p];
        final iv = c.intervals;
        for (var s = 0; s < iv.length; s++) {
          final at = w.end.subtract(Duration(minutes: iv[s]));
          if (at.isAfter(now) && !at.isBefore(w.start)) {
            await _schedule(c, key, p, s, at, iv[s], mode);
            count++;
          }
        }
      }
    }
    return count;
  }

  static Future<void> snooze(String date, int prayer) async {
    final c = Cfg(await Db.settings());
    final w = Sched.day(c, parseKey(date))[prayer];
    final at = DateTime.now().add(Duration(minutes: c.snooze));
    if (!at.isBefore(w.end)) return;
    final left = w.end.difference(at).inMinutes;
    final perm = await perms();
    final mode = perm[1] ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    await _schedule(c, date, prayer, 8, at, left, mode);
  }

  /// Runs in the app OR in a background isolate (app closed). Only touches the database and notifications.
  static Future<void> handle(NotificationResponse r) async {
    final parts = (r.payload ?? '').split('|');
    if (parts.length != 2) return;
    final p = int.tryParse(parts[0]);
    if (p == null || p < 0 || p > 4) return;
    final date = parts[1];
    if (r.actionId == 'prayed') {
      await Db.setRecord(date, p, stPrayed);
      await cancelPrayer(date, p);
    } else if (r.actionId == 'later') {
      await snooze(date, p);
    }
  }

  static Future<void> test() async {
    final c = Cfg(await Db.settings());
    await plugin.show(1999999, Str.get(c.lang, 'app'), Str.get(c.lang, 'testBody'), _details(c));
  }
}
