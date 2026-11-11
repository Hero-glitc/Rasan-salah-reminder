import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/dates.dart';
import '../core/db.dart';
import '../core/models.dart';
import '../core/notif.dart';
import '../core/schedule.dart';
import '../core/state.dart';
import '../core/strings.dart';
import 'timeline.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const MethodChannel _ring = MethodChannel('salah/ringtone');
  List<bool> perm = [false, false];

  @override
  void initState() {
    super.initState();
    AppState.i.addListener(_rebuild);
    _perm();
  }

  @override
  void dispose() {
    AppState.i.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _perm() async {
    final p = await Notif.perms();
    if (mounted) setState(() => perm = p);
  }

  Future<void> _allow() async {
    await Notif.requestPerms();
    await _perm();
    await AppState.i.load();
    await Notif.rescheduleAll();
    _rebuild();
  }

  Future<void> _pickSound() async {
    try {
      final cur = AppState.i.cfg.soundUri;
      final uri = await _ring.invokeMethod<String>('pick', {'current': cur});
      if (uri == null) return;
      var name = '';
      if (uri.isNotEmpty) {
        name = (await _ring.invokeMethod<String>('title', {'uri': uri})) ?? '';
      }
      await AppState.i.save({'sound_uri': uri, 'sound_name': name});
    } catch (_) {
      if (mounted) snack(context, t('soundFail'));
    }
  }

  Future<void> _toggleCal(String id, bool on) async {
    final set = AppState.i.cfg.cals.toSet();
    if (on) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await AppState.i.save({'cals': [for (final k in calIds) if (set.contains(k)) k].join(',')}, resched: false);
  }

  Future<void> _copy(Map<String, Object?> data) async {
    await Clipboard.setData(ClipboardData(text: jsonEncode(data)));
    if (mounted) snack(context, t('copied'));
  }

  Future<void> _restore() async {
    final txt = await askText(context, t('pasteJson'), '', multiline: true);
    if (txt == null || txt.isEmpty || !mounted) return;
    try {
      final d = jsonDecode(txt);
      if (d is! Map) throw const FormatException('not a map');
      await Db.importAll(Map<String, dynamic>.from(d));
      await AppState.i.load();
      await Notif.rescheduleAll();
      if (mounted) snack(context, t('restored'));
    } catch (_) {
      if (mounted) snack(context, t('invalid'));
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        content: Text(t('confirmReset')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text(t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(t('delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await Db.resetAll();
    await AppState.i.load();
    await Notif.rescheduleAll();
    if (mounted) snack(context, t('resetDone'));
  }

  Widget _sec(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 6),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
      );

  Widget _permTile(String title, bool ok) => ListTile(
        title: Text(title),
        subtitle: Text(ok ? t('granted') : t('notGranted')),
        trailing: ok ? const Icon(Icons.check_circle, color: Colors.green) : TextButton(onPressed: _allow, child: Text(t('allow'))),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final c = s.cfg;
    final iv = c.intervals;
    final cals = c.cals.toSet();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
      _sec(t('timesTitle')),
      for (var i = 0; i < 5; i++)
        Card(
          child: ListTile(
            title: Text(t(prayerKeys[i])),
            subtitle: Text('${c.ms(i)}  →  ${c.me(i)}'),
            trailing: const Icon(Icons.linear_scale),
            onTap: () => editTimeline(context, i),
          ),
        ),
      _sec(t('datesTop')),
      for (final e in const [
        ['greg', 'calGreg'],
        ['hijri', 'calHijri'],
        ['afg', 'calAfg'],
        ['irn', 'calIrn'],
      ])
        SwitchListTile(title: Text(t(e[1])), value: cals.contains(e[0]), onChanged: (v) => _toggleCal(e[0], v)),
      SwitchListTile(
        title: Text(t('showWeekday')),
        value: c.showWeekday,
        onChanged: (v) => s.save({'weekday': v ? '1' : '0'}, resched: false),
      ),
      ListTile(
        title: Text(t('hijriAdj')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              onPressed: () => s.save({'hadj': '${(c.hijriAdj - 1).clamp(-2, 2)}'}, resched: false),
              icon: const Icon(Icons.remove_circle_outline)),
          Text('${c.hijriAdj}'),
          IconButton(
              onPressed: () => s.save({'hadj': '${(c.hijriAdj + 1).clamp(-2, 2)}'}, resched: false),
              icon: const Icon(Icons.add_circle_outline)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(DateFmt.lines(DateTime.now(), c).join('\n'), style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      ),
      _sec(t('reminders')),
      SwitchListTile(
        title: Text(t('enableReminders')),
        value: c.notifOn,
        onChanged: (v) => s.save({'notif': v ? '1' : '0'}),
      ),
      Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text(t('intervals'))),
      Wrap(spacing: 8, children: [
        for (final m in const [180, 150, 120, 90, 60, 45, 30, 20, 15, 10, 5])
          FilterChip(
            label: Text(leftText(m)),
            selected: iv.contains(m),
            onSelected: (on) {
              final next = {...iv};
              if (on) {
                next.add(m);
              } else {
                next.remove(m);
              }
              final l = next.toList()..sort((a, b) => b.compareTo(a));
              s.save({'intervals': l.take(8).join(',')});
            },
          ),
      ]),
      ListTile(
        title: Text(t('snooze')),
        trailing: DropdownButton<int>(
          value: const [5, 10, 15, 20, 30].contains(c.snooze) ? c.snooze : 10,
          items: [for (final m in const [5, 10, 15, 20, 30]) DropdownMenuItem(value: m, child: Text('$m'))],
          onChanged: (v) => s.save({'snooze': '${v ?? 10}'}),
        ),
      ),
      SwitchListTile(title: Text(t('sound')), value: c.sound, onChanged: (v) => s.save({'sound': v ? '1' : '0'})),
      ListTile(
        title: Text(t('soundPick')),
        subtitle: Text(c.soundUri.isEmpty ? t('soundDefault') : (c.soundName.isEmpty ? c.soundUri : c.soundName)),
        trailing: const Icon(Icons.library_music),
        onTap: _pickSound,
      ),
      _permTile(t('notifPerm'), perm[0]),
      _permTile(t('exactPerm'), perm[1]),
      ListTile(
        title: Text(t('testNow')),
        trailing: const Icon(Icons.notifications_active),
        onTap: () async {
          final ok = await Notif.test();
          if (mounted) snack(context, ok ? t('testSent') : Notif.lastError);
        },
      ),
      ListTile(
        title: Text(t('testIn1')),
        trailing: const Icon(Icons.timer),
        onTap: () async {
          final ok = await Notif.testScheduled();
          if (mounted) snack(context, ok ? t('testScheduled') : Notif.lastError);
        },
      ),
      ListTile(
        title: Text(t('scheduled')),
        trailing: const Icon(Icons.refresh),
        onTap: () async {
          final n = await Notif.rescheduleAll();
          await _perm();
          if (mounted) {
            snack(context, '${t('scheduled')}: $n');
            setState(() {});
          }
        },
      ),
      if (Notif.lastError.isNotEmpty)
        ListTile(
          leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          title: Text(t('lastError')),
          subtitle: Text(Notif.lastError),
        ),
      ListTile(title: Text(t('battery')), subtitle: Text(t('batteryText'))),
      _sec(t('appearance')),
      ListTile(
        title: Text(t('theme')),
        trailing: DropdownButton<String>(
          value: c.s('theme', 'system'),
          items: [
            DropdownMenuItem(value: 'system', child: Text(t('system'))),
            DropdownMenuItem(value: 'light', child: Text(t('light'))),
            DropdownMenuItem(value: 'dark', child: Text(t('dark'))),
          ],
          onChanged: (v) => s.save({'theme': v ?? 'system'}, resched: false),
        ),
      ),
      ListTile(
        title: Text(t('language')),
        trailing: DropdownButton<String>(
          value: Str.langNames.containsKey(c.lang) ? c.lang : 'en',
          items: [for (final e in Str.langNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => s.save({'lang': v ?? 'en'}),
        ),
      ),
      _sec(t('data')),
      ListTile(title: Text(t('backup')), leading: const Icon(Icons.backup), onTap: () async => _copy(await Db.exportAll())),
      ListTile(
        title: Text(t('exportHist')),
        leading: const Icon(Icons.ios_share),
        onTap: () async {
          final all = await Db.exportAll();
          await _copy({'version': 1, 'records': all['records']});
        },
      ),
      ListTile(title: Text(t('restore')), leading: const Icon(Icons.restore), onTap: _restore),
      ListTile(
        title: Text(t('reset'), style: const TextStyle(color: Colors.red)),
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        onTap: _reset,
      ),
    ]);
  }
}
