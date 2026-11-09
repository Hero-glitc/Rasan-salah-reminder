import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../core/db.dart';
import '../core/models.dart';
import '../core/notif.dart';
import '../core/schedule.dart';
import '../core/state.dart';
import '../core/strings.dart';
import 'widgets.dart';

const _methodNames = {
  'mwl': 'Muslim World League',
  'isna': 'ISNA (North America)',
  'egypt': 'Egyptian General Authority',
  'makkah': 'Umm al-Qura (Makkah)',
  'karachi': 'Karachi (Univ. of Islamic Sciences)',
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

  TimeOfDay _tod(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  Future<void> _editTimes(int i) async {
    final c = AppState.i.cfg;
    final a = await showTimePicker(
        context: context, initialTime: _tod(c.ms(i)), helpText: '${t(prayerKeys[i])} - ${t('pickStart')}');
    if (a == null || !mounted) return;
    final b = await showTimePicker(
        context: context, initialTime: _tod(c.me(i)), helpText: '${t(prayerKeys[i])} - ${t('pickEnd')}');
    if (b == null) return;
    await AppState.i.save({
      'ms$i': '${two(a.hour)}:${two(a.minute)}',
      'me$i': '${two(b.hour)}:${two(b.minute)}',
    });
  }

  Future<void> _editLoc() async {
    final c = AppState.i.cfg;
    final la = await askText(context, t('lat'), c.hasLoc ? '${c.lat}' : '');
    if (la == null || !mounted) return;
    final lo = await askText(context, t('lon'), c.hasLoc ? '${c.lon}' : '');
    if (lo == null) return;
    final a = double.tryParse(la), b = double.tryParse(lo);
    if (a == null || b == null || a.abs() > 90 || b.abs() > 180) {
      if (mounted) snack(context, t('invalid'));
      return;
    }
    await AppState.i.save({'lat': '$a', 'lon': '$b'});
  }

  Future<void> _useLoc() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('denied');
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 25));
      await AppState.i.save({'lat': pos.latitude.toStringAsFixed(4), 'lon': pos.longitude.toStringAsFixed(4)});
    } catch (_) {
      if (mounted) snack(context, t('locFailed'));
    }
  }

  Future<void> _angle(String key, String title) async {
    final v = await askText(context, title, AppState.i.cfg.s(key, ''));
    if (v == null) return;
    await AppState.i.save({key: v});
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

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final c = s.cfg;
    final mode = c.s('mode', 'manual');
    final iv = c.intervals;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
      _sec(t('mode')),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'manual', label: Text(t('manual'))),
          ButtonSegment(value: 'auto', label: Text(t('auto'))),
        ],
        selected: {mode},
        onSelectionChanged: (v) => s.save({'mode': v.first}),
      ),
      if (mode == 'manual') ...[
        for (var i = 0; i < 5; i++)
          ListTile(
            title: Text(t(prayerKeys[i])),
            subtitle: Text('${c.ms(i)}  →  ${c.me(i)}'),
            trailing: const Icon(Icons.edit),
            onTap: () => _editTimes(i),
          ),
      ] else ...[
        if (!c.hasLoc) Padding(padding: const EdgeInsets.all(8), child: Text(t('noLocation'))),
        ListTile(
          title: Text(t('location')),
          subtitle: Text(c.hasLoc ? '${c.lat}, ${c.lon}' : '-'),
          trailing: const Icon(Icons.edit_location_alt),
          onTap: _editLoc,
        ),
        ListTile(title: Text(t('useLocation')), trailing: const Icon(Icons.my_location), onTap: _useLoc),
        ListTile(
          title: Text(t('method')),
          trailing: DropdownButton<String>(
            value: Sched.methods.containsKey(c.s('method', 'mwl')) ? c.s('method', 'mwl') : 'mwl',
            items: [for (final k in Sched.methods.keys) DropdownMenuItem(value: k, child: Text(_methodNames[k] ?? k))],
            onChanged: (v) => s.save({'method': v ?? 'mwl'}),
          ),
        ),
        ListTile(
          title: Text(t('asrMethod')),
          trailing: DropdownButton<String>(
            value: c.s('asr', 'standard'),
            items: [
              DropdownMenuItem(value: 'standard', child: Text(t('standard'))),
              DropdownMenuItem(value: 'hanafi', child: Text(t('hanafi'))),
            ],
            onChanged: (v) => s.save({'asr': v ?? 'standard'}),
          ),
        ),
        ListTile(
          title: Text(t('fajrAngle')),
          subtitle: Text(c.fajrAngle?.toString() ?? '-'),
          onTap: () => _angle('fajr_angle', t('fajrAngle')),
        ),
        ListTile(
          title: Text(t('ishaAngle')),
          subtitle: Text(c.ishaAngle?.toString() ?? '-'),
          onTap: () => _angle('isha_angle', t('ishaAngle')),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(t('adjust'))),
        for (var i = 0; i < 5; i++)
          Row(children: [
            Expanded(child: Text(t(prayerKeys[i]))),
            IconButton(onPressed: () => s.save({'adj$i': '${c.adj(i) - 1}'}), icon: const Icon(Icons.remove_circle_outline)),
            SizedBox(width: 36, child: Center(child: Text('${c.adj(i)}'))),
            IconButton(onPressed: () => s.save({'adj$i': '${c.adj(i) + 1}'}), icon: const Icon(Icons.add_circle_outline)),
          ]),
        for (var i = 0; i < 5; i++)
          if (s.wins.length == 5)
            ListTile(dense: true, title: Text(t(prayerKeys[i])), trailing: Text('${hm(s.wins[i].start)} – ${hm(s.wins[i].end)}')),
      ],
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
        title: Text(t('notifPerm')),
        subtitle: Text(perm[0] ? t('granted') : t('notGranted')),
        trailing: perm[0]
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: () async {
                  await Notif.requestPerms();
                  await _perm();
                  await s.load();
                  await Notif.rescheduleAll();
                },
                child: Text(t('allow'))),
      ),
      ListTile(
        title: Text(t('exactPerm')),
        subtitle: Text(perm[1] ? t('granted') : t('notGranted')),
        trailing: perm[1]
            ? const Icon(Icons.check_circle, color: Colors.green)
            : TextButton(
                onPressed: () async {
                  await Notif.requestPerms();
                  await _perm();
                  await s.load();
                  await Notif.rescheduleAll();
                },
                child: Text(t('allow'))),
      ),
      ListTile(title: Text(t('testNotif')), trailing: const Icon(Icons.notifications_active), onTap: () => Notif.test()),
      ListTile(
        title: Text(t('scheduled')),
        trailing: const Icon(Icons.refresh),
        onTap: () async {
          final n = await Notif.rescheduleAll();
          if (mounted) snack(context, '${t('scheduled')}: $n');
        },
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
      ListTile(
        title: Text(t('backup')),
        leading: const Icon(Icons.backup),
        onTap: () async => _copy(await Db.exportAll()),
      ),
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
