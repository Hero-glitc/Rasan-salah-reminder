import 'package:flutter_test/flutter_test.dart';
import 'package:salah_reminder/core/dates.dart';
import 'package:salah_reminder/core/models.dart';
import 'package:salah_reminder/core/notif.dart';
import 'package:salah_reminder/core/schedule.dart';

void main() {
  test('manual Isha crosses midnight', () {
    final w = Sched.day(const Cfg({}), DateTime(2026, 11, 9));
    expect(w[4].end.isAfter(w[4].start), true);
    expect(w[4].end.day, 10);
  });

  test('notification ids are unique and stable', () {
    final ids = <int>{};
    for (var d = 0; d < 5; d++) {
      final key = dkey(DateTime(2026, 11, 9 + d));
      for (var p = 0; p < 5; p++) {
        for (var s = 0; s < 9; s++) {
          expect(ids.add(Notif.nid(key, p, s)), true);
        }
      }
    }
    expect(Notif.nid('2026-11-09', 2, 3), Notif.nid('2026-11-09', 2, 3));
  });

  test('status derives from time and record', () {
    final w = Win(DateTime(2026, 1, 1, 12), DateTime(2026, 1, 1, 15));
    expect(derive(w, null, DateTime(2026, 1, 1, 11)), PS.upcoming);
    expect(derive(w, null, DateTime(2026, 1, 1, 13)), PS.active);
    expect(derive(w, null, DateTime(2026, 1, 1, 16)), PS.expired);
    expect(derive(w, const Rec('2026-01-01', 1, stPrayed, null, null), DateTime(2026, 1, 1, 16)), PS.prayed);
  });

  test('Afghan solar and Hijri dates', () {
    expect(solarParts(DateTime(2024, 3, 20)), [1403, 1, 1]);
    expect(solarParts(DateTime(2026, 3, 21)), [1405, 1, 1]);
    expect(hijriParts(DateTime(2024, 3, 11)), [1445, 9, 1]);
  });
}
