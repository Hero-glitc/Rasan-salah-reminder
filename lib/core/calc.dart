import 'dart:math';

double _r(double d) => d * pi / 180;
double _d(double r) => r * 180 / pi;
double _sin(double d) => sin(_r(d));
double _cos(double d) => cos(_r(d));
double _tan(double d) => tan(_r(d));
double _asin(double x) => _d(asin(x));
double _acos(double x) => _d(acos(x));
double _atan2(double y, double x) => _d(atan2(y, x));
double _acot(double x) => _d(atan(1 / x));
double _fa(double a) => a - 360 * (a / 360).floor();
double _fh(double a) => a - 24 * (a / 24).floor();

double _julian(int y, int m, int d) {
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b - 1524.5;
}

class _Sun {
  final double decl, eqt;
  _Sun(this.decl, this.eqt);
}

_Sun _sun(double jd) {
  final dd = jd - 2451545.0;
  final g = _fa(357.529 + 0.98560028 * dd);
  final q = _fa(280.459 + 0.98564736 * dd);
  final l = _fa(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
  final e = 23.439 - 0.00000036 * dd;
  final ra = _fh(_atan2(_cos(e) * _sin(l), _cos(l)) / 15);
  return _Sun(_asin(_sin(e) * _sin(l)), q / 15 - ra);
}

/// Astronomical prayer time calculation (same algorithm as praytimes.org).
/// Returns [fajr, sunrise, dhuhr, asr, maghrib, isha] as real instants (local DateTime).
class Calc {
  static List<DateTime> day(DateTime date,
      {required double lat,
      required double lon,
      required double fajrA,
      required double ishaA,
      double ishaMin = 0,
      bool hanafi = false}) {
    final jd = _julian(date.year, date.month, date.day) - lon / 360;
    double mid(double t) => _fh(12 - _sun(jd + t).eqt);
    double ang(double a, double t, bool ccw) {
      final s = _sun(jd + t);
      final x = (-_sin(a) - _sin(s.decl) * _sin(lat)) / (_cos(s.decl) * _cos(lat));
      if (x < -1 || x > 1) return double.nan;
      final h = _acos(x) / 15;
      final n = mid(t);
      return ccw ? n - h : n + h;
    }

    double asrT(double t) {
      final s = _sun(jd + t);
      final a = -_acot((hanafi ? 2 : 1) + _tan((lat - s.decl).abs()));
      return ang(a, t, false);
    }

    const rs = 0.833;
    var f = ang(fajrA, 5 / 24, true);
    final sr = ang(rs, 6 / 24, true);
    final dh = mid(12 / 24);
    final asr = asrT(13 / 24);
    final ss = ang(rs, 18 / 24, false);
    var isha = ishaMin > 0 ? ss + ishaMin / 60 : ang(ishaA, 18 / 24, false);
    if (f.isNaN) f = sr - 1.5;
    if (isha.isNaN) isha = ss + 1.5;
    final base = DateTime.utc(date.year, date.month, date.day);
    DateTime inst(double h) =>
        base.add(Duration(milliseconds: ((h - lon / 15) * 3600000).round())).toLocal();
    return [inst(f), inst(sr), inst(dh), inst(asr), inst(ss), inst(isha)];
  }
}
