import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/models.dart';
import '../core/schedule.dart';
import '../core/state.dart';

class Tally {
  int done = 0, missed = 0, total = 0;
  double get pct => total == 0 ? 0 : done * 100 / total;
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Tally day = Tally(), week = Tally(), month = Tally();
  List<double> trend = [];
  Map<int, int> counts = {};

  @override
  void initState() {
    super.initState();
    AppState.i.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppState.i.removeListener(_load);
    super.dispose();
  }

  Future<Tally> _tally(DateTime from, int days) async {
    final cfg = AppState.i.cfg;
    final now = DateTime.now();
    final list = await Db.range(dkey(from), dkey(dayOf(from, days - 1)));
    final m = {for (final r in list) '${r.date}#${r.prayer}': r};
    final t0 = Tally();
    for (var i = 0; i < days; i++) {
      final d = dayOf(from, i);
      final w = Sched.day(cfg, d);
      for (var p = 0; p < 5; p++) {
        if (w[p].start.isAfter(now)) continue;
        t0.total++;
        final st = m['${dkey(d)}#$p']?.status ?? 0;
        if (st == stPrayed) {
          t0.done++;
        } else if (st == stMissed || (st == stNone && w[p].end.isBefore(now))) {
          t0.missed++;
        }
      }
    }
    return t0;
  }

  Future<void> _load() async {
    final n = DateTime.now();
    final today = dayOf(n, 0);
    final d = await _tally(today, 1);
    final w = await _tally(dayOf(today, -6), 7);
    final mo = await _tally(DateTime(n.year, n.month, 1), n.day);
    final tr = <double>[];
    for (var i = 6; i >= 0; i--) {
      tr.add((await _tally(dayOf(today, -i), 1)).pct);
    }
    final c = await Db.counts();
    if (!mounted) return;
    setState(() {
      day = d;
      week = w;
      month = mo;
      trend = tr;
      counts = c;
    });
  }

  Widget _card(String title, Tally x, ColorScheme cs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${x.pct.round()}%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: cs.primary)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: x.pct / 100),
              duration: const Duration(milliseconds: 500),
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(height: 6),
            Text('${x.done}/${x.total}   •   ${t('missedExpired')}: ${x.missed}', style: TextStyle(color: cs.outline)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = DateTime.now();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card(t('today'), day, cs),
      _card(t('thisWeek'), week, cs),
      _card(t('thisMonth'), month, cs),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t('trend')} (${t('consistency')})', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < trend.length; i++)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${trend[i].round()}', style: const TextStyle(fontSize: 10)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        height: 4 + trend[i] * 0.7,
                        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(6)),
                      ),
                      Text('${dayOf(n, i - 6).day}', style: TextStyle(fontSize: 11, color: cs.outline)),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
      Card(
        child: Column(children: [
          ListTile(title: Text(t('totalPrayed')), trailing: Text('${counts[stPrayed] ?? 0}')),
          ListTile(title: Text(t('totalQada')), trailing: Text('${counts[stQada] ?? 0}')),
          ListTile(title: Text(t('totalMissed')), trailing: Text('${counts[stMissed] ?? 0}')),
        ]),
      ),
    ]);
  }
}
