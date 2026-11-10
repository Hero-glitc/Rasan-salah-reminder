import 'dart:async';
import 'package:flutter/material.dart';
import 'db.dart';
import 'models.dart';
import 'notif.dart';
import 'schedule.dart';
import 'strings.dart';

String t(String k) => Str.get(AppState.i.cfg.lang, k);

class Entry {
  final String date;
  final int p;
  final Win win;
  final Rec? rec;
  final PS ps;
  const Entry(this.date, this.p, this.win, this.rec, this.ps);
}

class AppState extends ChangeNotifier {
  static final AppState i = AppState._();
  AppState._();

  Cfg cfg = const Cfg({});
  final ValueNotifier<DateTime> clock = ValueNotifier(DateTime.now());
  String loadedKey = '';
  List<Win> wins = [];
  Win? yIsha;
  Map<String, Rec> recs = {};
  bool notifOk = true, exactOk = true;
  Timer? _timer;

  ThemeMode get themeMode {
    switch (cfg.s('theme', 'system')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> init() async {
    await load();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      clock.value = DateTime.now();
      if (dkey(clock.value) != loadedKey) {
        load();
        Notif.rescheduleAll();
      }
    });
  }

  Future<void> load() async {
    cfg = Cfg(await Db.settings());
    final n = DateTime.now();
    loadedKey = dkey(n);
    wins = Sched.day(cfg, n);
    yIsha = Sched.day(cfg, dayOf(n, -1))[4];
    final list = await Db.range(dkey(dayOf(n, -1)), dkey(n));
    recs = {for (final r in list) '${r.date}#${r.prayer}': r};
    final p = await Notif.perms();
    notifOk = p[0];
    exactOk = p[1];
    notifyListeners();
  }

  Rec? rec(String date, int p) => recs['$date#$p'];

  List<Entry> entries(DateTime now) {
    final out = <Entry>[];
    final y = yIsha;
    final yk = dkey(dayOf(now, -1));
    if (y != null && y.end.isAfter(now)) {
      out.add(Entry(yk, 4, y, rec(yk, 4), derive(y, rec(yk, 4), now)));
    }
    final tk = dkey(now);
    for (var p = 0; p < wins.length; p++) {
      out.add(Entry(tk, p, wins[p], rec(tk, p), derive(wins[p], rec(tk, p), now)));
    }
    return out;
  }

  Future<void> save(Map<String, String> m, {bool resched = true}) async {
    await Db.setSettings(m);
    await load();
    if (resched) await Notif.rescheduleAll();
  }

  Future<void> setStatus(String date, int p, int st) async {
    if (st == stNone) {
      await Db.deleteRecord(date, p);
    } else {
      await Db.setRecord(date, p, st);
    }
    // Refresh the screen first so the change shows immediately.
    await load();
    // Notification work must never block or break the screen update.
    try {
      if (st == stNone) {
        await Notif.rescheduleAll();
      } else {
        await Notif.cancelPrayer(date, p);
      }
    } catch (_) {}
  }
}
