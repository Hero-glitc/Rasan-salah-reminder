const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
const int stNone = 0, stPrayed = 1, stMissed = 2, stQada = 3;

String two(int n) => n.toString().padLeft(2, '0');
String dkey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dayOf(DateTime d, int offset) => DateTime(d.year, d.month, d.day + offset);
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String hms(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${two(s ~/ 3600)}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
}

String leftText(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

class Win {
  final DateTime start, end;
  const Win(this.start, this.end);
}

class Rec {
  final String date;
  final int prayer, status;
  final int? doneAt, qadaAt;
  const Rec(this.date, this.prayer, this.status, this.doneAt, this.qadaAt);
  factory Rec.fromMap(Map<String, Object?> m) => Rec(m['date'] as String, m['prayer'] as int, m['status'] as int,
      m['done_at'] as int?, m['qada_at'] as int?);
  Map<String, Object?> toMap() =>
      {'date': date, 'prayer': prayer, 'status': status, 'done_at': doneAt, 'qada_at': qadaAt};
}

enum PS { upcoming, active, prayed, expired, missed, qada }

PS derive(Win w, Rec? r, DateTime now) {
  final st = r?.status ?? stNone;
  if (st == stPrayed) return PS.prayed;
  if (st == stQada) return PS.qada;
  if (st == stMissed) return PS.missed;
  if (now.isBefore(w.start)) return PS.upcoming;
  if (now.isBefore(w.end)) return PS.active;
  return PS.expired;
}
