import 'package:path/path.dart' as pth;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class Db {
  static Database? _db;
  static Future<Database> get _d async => _db ??= await _open();

  static Future<Database> _open() async {
    final path = pth.join(await getDatabasesPath(), 'salah.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT)');
      await db.execute(
          'CREATE TABLE records(date TEXT NOT NULL, prayer INTEGER NOT NULL, status INTEGER NOT NULL, done_at INTEGER, qada_at INTEGER, PRIMARY KEY(date, prayer))');
    });
  }

  static Future<Map<String, String>> settings() async {
    final db = await _d;
    final rows = await db.query('settings');
    return {for (final r in rows) r['k'] as String: (r['v'] as String?) ?? ''};
  }

  static Future<void> setSettings(Map<String, String> m) async {
    final db = await _d;
    final b = db.batch();
    m.forEach((k, v) => b.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace));
    await b.commit(noResult: true);
  }

  static Future<Rec?> record(String date, int prayer) async {
    final db = await _d;
    final r = await db.query('records', where: 'date = ? AND prayer = ?', whereArgs: [date, prayer]);
    return r.isEmpty ? null : Rec.fromMap(r.first);
  }

  static Future<List<Rec>> range(String from, String to) async {
    final db = await _d;
    final r = await db.query('records', where: 'date >= ? AND date <= ?', whereArgs: [from, to]);
    return r.map(Rec.fromMap).toList();
  }

  static Future<void> setRecord(String date, int prayer, int status) async {
    final db = await _d;
    final old = await record(date, prayer);
    final now = DateTime.now().millisecondsSinceEpoch;
    final rec = Rec(
      date,
      prayer,
      status,
      status == stPrayed ? now : (status == stQada ? old?.doneAt : null),
      status == stQada ? now : null,
    );
    await db.insert('records', rec.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteRecord(String date, int prayer) async {
    final db = await _d;
    await db.delete('records', where: 'date = ? AND prayer = ?', whereArgs: [date, prayer]);
  }

  static Future<Map<int, int>> counts() async {
    final db = await _d;
    final r = await db.rawQuery('SELECT status, COUNT(*) AS c FROM records GROUP BY status');
    return {for (final x in r) x['status'] as int: x['c'] as int};
  }

  static Future<Map<String, Object?>> exportAll() async {
    final db = await _d;
    return {
      'version': 1,
      'settings': await settings(),
      'records': (await db.query('records')),
    };
  }

  /// Throws FormatException on invalid input. Keeps existing data if validation fails.
  static Future<void> importAll(Map<String, dynamic> data) async {
    final recs = data['records'];
    if (recs is! List) throw const FormatException('records missing');
    final parsed = <Rec>[];
    for (final r in recs) {
      if (r is! Map) throw const FormatException('bad record');
      final date = r['date'];
      final prayer = r['prayer'];
      final status = r['status'];
      if (date is! String || prayer is! int || status is! int || prayer < 0 || prayer > 4 || status < 0 || status > 3) {
        throw const FormatException('bad record');
      }
      parseKey(date);
      parsed.add(Rec(date, prayer, status, r['done_at'] as int?, r['qada_at'] as int?));
    }
    final db = await _d;
    await db.transaction((txn) async {
      await txn.delete('records');
      for (final r in parsed) {
        await txn.insert('records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final s = data['settings'];
      if (s is Map) {
        await txn.delete('settings');
        for (final e in s.entries) {
          await txn.insert('settings', {'k': e.key.toString(), 'v': e.value.toString()});
        }
      }
    });
  }

  static Future<void> resetAll() async {
    final db = await _d;
    await db.delete('records');
    await db.delete('settings');
  }
}
