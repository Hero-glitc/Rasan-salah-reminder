import 'schedule.dart';

/// Tabular (civil) Hijri date: [year, month, day]. Can differ by a day from moon sighting.
List<int> hijriParts(DateTime d) {
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
  final hm = (24 * l) ~/ 709;
  final hd = l - (709 * hm) ~/ 24;
  final hy = 30 * n + j - 30;
  return [hy, hm, hd];
}

/// Solar Hijri (Shamsi) date used in Afghanistan and Iran: [year, month, day].
List<int> solarParts(DateTime date) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy = date.year, gm = date.month, gd = date.day;
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days = 355666 + (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) + ((gy2 + 399) ~/ 400) + gd + gdm[gm - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  int jm, jd;
  if (days < 186) {
    jm = 1 + (days ~/ 31);
    jd = 1 + (days % 31);
  } else {
    jm = 7 + ((days - 186) ~/ 30);
    jd = 1 + ((days - 186) % 30);
  }
  return [jy, jm, jd];
}

class DateFmt {
  static const _gEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _gAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const _gFa = ['جنوری', 'فبروری', 'مارچ', 'اپریل', 'می', 'جون', 'جولای', 'اگست', 'سپتمبر', 'اکتوبر', 'نومبر', 'دسمبر'];
  static const _hEn = ['Muharram', 'Safar', 'Rabi I', 'Rabi II', 'Jumada I', 'Jumada II', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhul Qadah', 'Dhul Hijjah'];
  static const _hAr = ['محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'];
  static const _afEn = ['Hamal', 'Sawr', 'Jawza', 'Saratan', 'Asad', 'Sunbula', 'Mizan', 'Aqrab', 'Qaws', 'Jadi', 'Dalw', 'Hut'];
  static const _afFa = ['حمل', 'ثور', 'جوزا', 'سرطان', 'اسد', 'سنبله', 'میزان', 'عقرب', 'قوس', 'جدی', 'دلو', 'حوت'];
  static const _irEn = ['Farvardin', 'Ordibehesht', 'Khordad', 'Tir', 'Mordad', 'Shahrivar', 'Mehr', 'Aban', 'Azar', 'Dey', 'Bahman', 'Esfand'];
  static const _irFa = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
  static const _wdEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  static const _wdAr = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  static const _wdFa = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];

  /// One text line per calendar the user switched on (weekday is added to the first line).
  static List<String> lines(DateTime now, Cfg c) {
    final lang = c.lang;
    final en = lang == 'en';
    final out = <String>[];
    final cals = c.cals.isEmpty ? <String>['greg'] : c.cals;
    for (final id in cals) {
      if (id == 'greg') {
        final names = en ? _gEn : (lang == 'ar' ? _gAr : _gFa);
        out.add('${now.day} ${names[now.month - 1]} ${now.year}');
      } else if (id == 'hijri') {
        final h = hijriParts(DateTime(now.year, now.month, now.day + c.hijriAdj));
        final names = en ? _hEn : _hAr;
        out.add('${h[2]} ${names[(h[1] - 1).clamp(0, 11).toInt()]} ${h[0]}');
      } else if (id == 'afg') {
        final j = solarParts(now);
        out.add('${j[2]} ${(en ? _afEn : _afFa)[j[1] - 1]} ${j[0]}');
      } else if (id == 'irn') {
        final j = solarParts(now);
        out.add('${j[2]} ${(en ? _irEn : _irFa)[j[1] - 1]} ${j[0]}');
      }
    }
    if (c.showWeekday && out.isNotEmpty) {
      final names = en ? _wdEn : (lang == 'ar' ? _wdAr : _wdFa);
      out[0] = '${names[now.weekday % 7]}${en ? ', ' : '، '}${out[0]}';
    }
    return out;
  }
}
