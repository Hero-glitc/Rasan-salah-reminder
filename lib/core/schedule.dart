import 'calc.dart';
import 'models.dart';

class Cfg {
  final Map<String, String> m;
  const Cfg(this.m);
  String s(String k, String d) => m[k] ?? d;

  double get lat => double.tryParse(s('lat', '')) ?? 0;
  double get lon => double.tryParse(s('lon', '')) ?? 0;
  bool get hasLoc => double.tryParse(s('lat', '')) != null && double.tryParse(s('lon', '')) != null;
  bool get manual => s('mode', 'manual') == 'manual' || !hasLoc;
  double? get fajrAngle => double.tryParse(s('fajr_angle', ''));
  double? get ishaAngle => double.tryParse(s('isha_angle', ''));
  int adj(int i) => int.tryParse(s('adj$i', '0')) ?? 0;

  static const defStart = ['05:00', '12:30', '15:30', '18:00', '19:30'];
  static const defEnd = ['06:30', '15:30', '18:00', '19:30', '04:30'];
  String ms(int i) => s('ms$i', defStart[i]);
  String me(int i) => s('me$i', defEnd[i]);

  List<int> get intervals {
    final l = s('intervals', '120,90,60,30,15')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .where((e) => e > 0)
        .toSet()
        .toList();
    l.sort((a, b) => b.compareTo(a));
    return l.take(8).toList();
  }

  bool get notifOn => s('notif', '1') == '1';
  bool get sound => s('sound', '1') == '1';
  int get snooze => int.tryParse(s('snooze', '10')) ?? 10;
  String get lang => s('lang', 'en');
}

class Sched {
  /// [fajrAngle, ishaAngle, ishaMinutesAfterMaghrib]
  static const methods = <String, List<double>>{
    'mwl': [18.0, 17.0, 0.0],
    'isna': [15.0, 15.0, 0.0],
    'egypt': [19.5, 17.5, 0.0],
    'makkah': [18.5, 0.0, 90.0],
    'karachi': [18.0, 18.0, 0.0],
  };

  static DateTime _at(DateTime d, String t, int plus) {
    final p = t.split(':');
    return DateTime(d.year, d.month, d.day + plus, int.parse(p[0]), int.parse(p[1]));
  }

  static List<DateTime> _auto(Cfg c, DateTime d) {
    final base = methods[c.s('method', 'mwl')] ?? methods['mwl']!;
    return Calc.day(d,
        lat: c.lat,
        lon: c.lon,
        fajrA: c.fajrAngle ?? base[0],
        ishaA: c.ishaAngle ?? base[1],
        ishaMin: c.ishaAngle != null ? 0 : base[2],
        hanafi: c.s('asr', 'standard') == 'hanafi');
  }

  /// The five prayer windows that START on [date]. Isha may end after midnight.
  static List<Win> day(Cfg c, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (c.manual) {
      return List.generate(5, (i) {
        final st = _at(d, c.ms(i), 0);
        var en = _at(d, c.me(i), 0);
        if (!en.isAfter(st)) en = _at(d, c.me(i), 1);
        return Win(st, en);
      });
    }
    final a = _auto(c, d);
    final b = _auto(c, DateTime(d.year, d.month, d.day + 1));
    DateTime ad(int i, DateTime t) => t.add(Duration(minutes: c.adj(i)));
    final s0 = ad(0, a[0]), s1 = ad(1, a[2]), s2 = ad(2, a[3]), s3 = ad(3, a[4]), s4 = ad(4, a[5]);
    final nextFajr = ad(0, b[0]);
    return [Win(s0, a[1]), Win(s1, s2), Win(s2, s3), Win(s3, s4), Win(s4, nextFajr)];
  }
}
