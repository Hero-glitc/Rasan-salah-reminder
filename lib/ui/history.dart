import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/models.dart';
import '../core/schedule.dart';
import '../core/state.dart';
import 'widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late DateTime month;
  late DateTime sel;
  Map<String, Rec> recs = {};

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    month = DateTime(n.year, n.month);
    sel = DateTime(n.year, n.month, n.day);
    AppState.i.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AppState.i.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await Db.range(dkey(DateTime(month.year, month.month, 1)), dkey(DateTime(month.year, month.month + 1, 0)));
    if (!mounted) return;
    setState(() => recs = {for (final r in list) '${r.date}#${r.prayer}': r});
  }

  void _shift(int d) {
    month = DateTime(month.year, month.month + d);
    _load();
  }

  int _doneCount(DateTime d) {
    var n = 0;
    for (var p = 0; p < 5; p++) {
      final st = recs['${dkey(d)}#$p']?.status ?? 0;
      if (st == stPrayed || st == stQada) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final wd = t('wd').split(',');
    final cfg = AppState.i.cfg;
    final wins = Sched.day(cfg, sel);
    final now = DateTime.now();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
        Text('${month.year}-${two(month.month)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
      ]),
      Row(children: [for (final w in wd) Expanded(child: Center(child: Text(w, style: TextStyle(color: cs.outline, fontSize: 12))))]),
      const SizedBox(height: 6),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < lead; i++) const SizedBox(),
          for (var d = 1; d <= days; d++)
            Builder(builder: (_) {
              final date = DateTime(month.year, month.month, d);
              final n = _doneCount(date);
              final isSel = dkey(date) == dkey(sel);
              return GestureDetector(
                onTap: () => setState(() => sel = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08 + 0.17 * n),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSel ? cs.primary : Colors.transparent, width: 2),
                  ),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$d', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('$n/5', style: TextStyle(fontSize: 10, color: cs.outline)),
                  ])),
                ),
              );
            }),
        ],
      ),
      const SizedBox(height: 12),
      Text(dkey(sel), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      for (var p = 0; p < 5; p++)
        Builder(builder: (ctx) {
          final r = recs['${dkey(sel)}#$p'];
          final ps = derive(wins[p], r, now);
          final c = psColor(ps);
          String extra = '';
          if (r?.doneAt != null) extra += '\n${t('prayedOn')}: ${_ts(r!.doneAt!)}';
          if (r?.qadaAt != null) extra += '\n${t('qadaOn')}: ${_ts(r!.qadaAt!)}';
          return Card(
            child: ListTile(
              onTap: () => statusSheet(ctx, dkey(sel), p),
              leading: Icon(ps == PS.prayed || ps == PS.qada ? Icons.check_circle : Icons.circle_outlined, color: c),
              title: Text(t(prayerKeys[p])),
              subtitle: Text('${hm(wins[p].start)} – ${hm(wins[p].end)}$extra'),
              trailing: Text(psLabel(ps), style: TextStyle(color: c)),
            ),
          );
        }),
    ]);
  }

  String _ts(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dkey(d)} ${hm(d)}';
  }
}
