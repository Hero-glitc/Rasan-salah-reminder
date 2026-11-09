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

const _hmEn = ['Muharram', 'Safar', 'Rabi I', 'Rabi II', 'Jumada I', 'Jumada II', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhul Qadah', 'Dhul Hijjah'];
const _hmAr = ['محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'];

/// Tabular (civil) Hijri date. Can differ by about one day from moon sighting.
String hijriText(DateTime d, bool arabic) {
  final y = d.year, m = d.month, day = d.day;
  final jd = (1461 * (y + 4800 + (m - 14) ~/ 12)) ~/ 4 +
      (367 * (m - 2 - 12 * ((m - 14) ~/ 12))) ~/ 12 -
      (3 * ((y + 4900 + (m - 14) ~/ 12) ~/ 100)) ~/ 4 +
      day - 32075;
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final hmI = (24 * l) ~/ 709;
  final hd = l - (709 * hmI) ~/ 24;
  final hy = 30 * n + j - 30;
  final names = arabic ? _hmAr : _hmEn;
  final idx = (hmI - 1).clamp(0, 11);
  return '$hd ${names[idx]} $hy';
}
