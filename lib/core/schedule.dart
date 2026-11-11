import 'models.dart';

const calIds = ['greg', 'hijri', 'afg', 'irn'];

class Cfg {
  final Map<String, String> m;
  const Cfg(this.m);
  String s(String k, String d) => m[k] ?? d;

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
  String get soundUri => s('sound_uri', '');
  String get soundName => s('sound_name', '');
  int get snooze => int.tryParse(s('snooze', '10')) ?? 10;
  String get lang => s('lang', 'en');

  List<String> get cals =>
      s('cals', 'greg,hijri,afg').split(',').where((e) => calIds.contains(e)).toList();
  bool get showWeekday => s('weekday', '1') == '1';
  int get hijriAdj => int.tryParse(s('hadj', '0')) ?? 0;
}

class Sched {
  static DateTime _at(DateTime d, String t, int plus) {
    final p = t.split(':');
    return DateTime(d.year, d.month, d.day + plus, int.parse(p[0]), int.parse(p[1]));
  }

  /// The five prayer windows that START on [date]. A window may end after midnight.
  static List<Win> day(Cfg c, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return List.generate(5, (i) {
      final st = _at(d, c.ms(i), 0);
      var en = _at(d, c.me(i), 0);
      if (!en.isAfter(st)) en = _at(d, c.me(i), 1);
      return Win(st, en);
    });
  }
}
