import 'package:flutter/material.dart';
import '../core/dates.dart';
import '../core/models.dart';
import '../core/notif.dart';
import '../core/state.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: s,
      builder: (ctx, _) => ValueListenableBuilder<DateTime>(
        valueListenable: s.clock,
        builder: (ctx, now, _) {
          final es = s.entries(now);
          final tk = dkey(now);
          final todays = es.where((e) => e.date == tk).toList();
          final done = todays.where((e) => e.ps == PS.prayed || e.ps == PS.qada).length;
          final pct = todays.isEmpty ? 0.0 : done / 5;
          final active = es.where((e) => e.ps == PS.active).toList();
          final upcoming = es.where((e) => e.ps == PS.upcoming).toList();
          final cur = active.isNotEmpty ? active.first : null;
          final nx = upcoming.isNotEmpty ? upcoming.first : null;
          final dateLines = DateFmt.lines(now, s.cfg);
          String headLine = t('noneLeft');
          String countdown = '--:--:--';
          if (cur != null) {
            headLine = '${t(prayerKeys[cur.p])} • ${t('endsIn')}';
            countdown = hms(cur.win.end.difference(now));
          } else if (nx != null) {
            headLine = '${t(prayerKeys[nx.p])} • ${t('startsIn')}';
            countdown = hms(nx.win.start.difference(now));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.35)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CustomPaint(
                    painter: PatternPainter(Colors.white.withOpacity(0.10)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (final line in dateLines) Text(line, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text('${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w300, fontFamily: 'serif')),
                        const SizedBox(height: 14),
                        Text(headLine, style: const TextStyle(color: Colors.white, fontSize: 16)),
                        Text(countdown,
                            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                      ]),
                    ),
                  ),
                ),
              ),
              if (!s.notifOk || !s.exactOk) ...[
                const SizedBox(height: 12),
                Card(
                  color: cs.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
                    title: Text(!s.notifOk ? t('warnNotif') : t('warnExact'), style: TextStyle(color: cs.onErrorContainer)),
                    trailing: TextButton(
                      onPressed: () async {
                        await Notif.requestPerms();
                        await s.load();
                        await Notif.rescheduleAll();
                      },
                      child: Text(t('allow')),
                    ),
                  ),
                ),
              ],
              if (cur != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize: 18)),
                  onPressed: () => s.setStatus(cur.date, cur.p, stPrayed),
                  icon: const Icon(Icons.check_circle),
                  label: Text('${t('markPrayed')}  (${t(prayerKeys[cur.p])})'),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t('completion')}: ${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 600),
                      builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 10, borderRadius: BorderRadius.circular(8)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              for (final e in es) _tile(context, e, cs),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Entry e, ColorScheme cs) {
    final c = psColor(e.ps);
    final name = e.date != dkey(DateTime.now()) ? t('yesterdayIsha') : t(prayerKeys[e.p]);
    String extra = '';
    if (e.rec?.doneAt != null && e.ps == PS.prayed) {
      extra = '  •  ${t('prayedOn')} ${hm(DateTime.fromMillisecondsSinceEpoch(e.rec!.doneAt!))}';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: e.ps == PS.active ? c.withOpacity(0.12) : cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: e.ps == PS.active ? c : Colors.transparent, width: 1.5),
      ),
      child: ListTile(
        onTap: () => statusSheet(context, e.date, e.p),
        leading: Icon(e.ps == PS.prayed || e.ps == PS.qada ? Icons.check_circle : Icons.mosque_outlined, color: c),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${hm(e.win.start)} – ${hm(e.win.end)}$extra'),
        trailing: Chip(
          label: Text(psLabel(e.ps), style: TextStyle(color: c, fontSize: 12)),
          side: BorderSide(color: c),
          backgroundColor: Colors.transparent,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
