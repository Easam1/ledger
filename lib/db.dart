import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// SQLite 資料層。圖片檔存在 attachments 資料夾，資料庫只存路徑。
class AppDb {
  late Database _db;
  late Directory root;
  late Directory attachDir;

  String get dbPath => p.join(root.path, 'ledger.db');

  Future<void> open() async {
    final base = await getApplicationSupportDirectory();
    root = Directory(p.join(base.path, 'Ledger'));
    attachDir = Directory(p.join(root.path, 'attachments'));
    await attachDir.create(recursive: true);
    _db = await openDatabase(dbPath, version: 1, onCreate: _create);
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''CREATE TABLE categories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      color INTEGER NOT NULL,
      icon TEXT NOT NULL,
      sort INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      grp TEXT NOT NULL,
      initial REAL NOT NULL DEFAULT 0,
      sort INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE projects(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sort INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      category_id INTEGER,
      account_id INTEGER,
      to_account_id INTEGER,
      project_id INTEGER,
      merchant TEXT,
      note TEXT,
      ts INTEGER NOT NULL)''');
    await db.execute('CREATE INDEX idx_entries_ts ON entries(ts)');
    await db.execute('''CREATE TABLE entry_images(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entry_id INTEGER NOT NULL,
      path TEXT NOT NULL)''');

    const expense = [
      ['飲食', 0xFFF2B84B, 'restaurant'],
      ['交通', 0xFF5BA8F5, 'bus'],
      ['娛樂', 0xFFA98BFF, 'movie'],
      ['購物', 0xFFF07A9A, 'bag'],
      ['個人', 0xFFB9BA9E, 'person'],
      ['醫療', 0xFFFF6B5E, 'medical'],
      ['家居', 0xFF6C8CD5, 'home'],
      ['家庭', 0xFFE3B5DB, 'family'],
      ['生活', 0xFF7FD18B, 'bulb'],
      ['學習', 0xFFFF9A4D, 'book'],
    ];
    const income = [
      ['薪水', 0xFFE3C15A, 'salary'],
      ['獎金', 0xFFE3C15A, 'gift'],
      ['投資', 0xFFE3C15A, 'invest'],
      ['利息', 0xFFE3C15A, 'savings'],
    ];
    var i = 0;
    for (final c in expense) {
      await db.insert('categories', {'name': c[0], 'type': 'expense', 'color': c[1], 'icon': c[2], 'sort': i++});
    }
    for (final c in income) {
      await db.insert('categories', {'name': c[0], 'type': 'income', 'color': c[1], 'icon': c[2], 'sort': i++});
    }
    await db.insert('accounts', {'name': '錢包', 'grp': '現金', 'initial': 0, 'sort': 0});
    await db.insert('accounts', {'name': '銀行存款', 'grp': '銀行', 'initial': 0, 'sort': 1});
    await db.insert('accounts', {'name': '信用卡', 'grp': '信用卡', 'initial': 0, 'sort': 2});
    var j = 0;
    for (final n in ['生活開銷', '投資理財', '工作', '旅遊', '家用']) {
      await db.insert('projects', {'name': n, 'sort': j++});
    }
  }

  // ---------- 讀取 ----------

  Future<List<Category>> categories() async {
    final rows = await _db.query('categories', orderBy: 'sort ASC, id ASC');
    return [
      for (final r in rows)
        Category(
          id: r['id'] as int,
          name: r['name'] as String,
          type: r['type'] as String,
          color: r['color'] as int,
          icon: r['icon'] as String,
        )
    ];
  }

  Future<List<Account>> accounts() async {
    final rows = await _db.query('accounts', orderBy: 'sort ASC, id ASC');
    return [
      for (final r in rows)
        Account(
          id: r['id'] as int,
          name: r['name'] as String,
          group: r['grp'] as String,
          initial: (r['initial'] as num).toDouble(),
        )
    ];
  }

  Future<List<Project>> projects() async {
    final rows = await _db.query('projects', orderBy: 'sort ASC, id ASC');
    return [for (final r in rows) Project(id: r['id'] as int, name: r['name'] as String)];
  }

  Future<List<Entry>> entries() async {
    final rows = await _db.query('entries', orderBy: 'ts DESC, id DESC');
    final imgRows = await _db.query('entry_images', orderBy: 'id ASC');
    final byEntry = <int, List<String>>{};
    for (final r in imgRows) {
      final id = r['entry_id'] as int;
      (byEntry[id] ??= <String>[]).add(r['path'] as String);
    }
    return [
      for (final r in rows)
        Entry(
          id: r['id'] as int,
          type: r['type'] as String,
          amount: (r['amount'] as num).toDouble(),
          title: (r['title'] as String?) ?? '',
          categoryId: r['category_id'] as int?,
          accountId: r['account_id'] as int?,
          toAccountId: r['to_account_id'] as int?,
          projectId: r['project_id'] as int?,
          merchant: r['merchant'] as String?,
          note: r['note'] as String?,
          ts: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
          images: byEntry[r['id'] as int] ?? const <String>[],
        )
    ];
  }

  // ---------- 記錄 ----------

  Map<String, Object?> _entryMap(Entry e) => {
        'type': e.type,
        'amount': e.amount,
        'title': e.title,
        'category_id': e.categoryId,
        'account_id': e.accountId,
        'to_account_id': e.toAccountId,
        'project_id': e.projectId,
        'merchant': e.merchant,
        'note': e.note,
        'ts': e.ts.millisecondsSinceEpoch,
      };

  Future<int> insertEntry(Entry e) {
    return _db.transaction((txn) async {
      final id = await txn.insert('entries', _entryMap(e));
      for (final path in e.images) {
        await txn.insert('entry_images', {'entry_id': id, 'path': path});
      }
      return id;
    });
  }

  Future<void> updateEntry(Entry e) {
    return _db.transaction((txn) async {
      await txn.update('entries', _entryMap(e), where: 'id = ?', whereArgs: [e.id]);
      await txn.delete('entry_images', where: 'entry_id = ?', whereArgs: [e.id]);
      for (final path in e.images) {
        await txn.insert('entry_images', {'entry_id': e.id, 'path': path});
      }
    });
  }

  Future<void> deleteEntry(int id) {
    return _db.transaction((txn) async {
      await txn.delete('entry_images', where: 'entry_id = ?', whereArgs: [id]);
      await txn.delete('entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> clearEntries() {
    return _db.transaction((txn) async {
      await txn.delete('entry_images');
      await txn.delete('entries');
    });
  }

  // ---------- 圖片檔 ----------

  /// 把使用者選的圖片複製進 App 資料夾，回傳新路徑。
  Future<String> storeImage(File src) async {
    final now = DateTime.now();
    final dir = Directory(p.join(attachDir.path, '${now.year}', now.month.toString().padLeft(2, '0')));
    await dir.create(recursive: true);
    var ext = p.extension(src.path);
    if (ext.isEmpty) ext = '.jpg';
    final dest = p.join(dir.path, '${now.microsecondsSinceEpoch}$ext');
    await src.copy(dest);
    return dest;
  }

  Future<void> deleteImageFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 檔案刪不掉時忽略，不影響記帳資料
    }
  }

  // ---------- 類別 / 帳戶 / 專案 ----------

  Future<void> addCategory(String name, String type, int color, String icon) async {
    final rows = await _db.rawQuery('SELECT COALESCE(MAX(sort), 0) AS m FROM categories');
    final next = ((rows.first['m'] as num?) ?? 0).toInt() + 1;
    await _db.insert('categories', {'name': name, 'type': type, 'color': color, 'icon': icon, 'sort': next});
  }

  Future<void> deleteCategory(int id) => _db.delete('categories', where: 'id = ?', whereArgs: [id]);

  Future<void> addAccount(String name, String group, double initial) async {
    final rows = await _db.rawQuery('SELECT COALESCE(MAX(sort), 0) AS m FROM accounts');
    final next = ((rows.first['m'] as num?) ?? 0).toInt() + 1;
    await _db.insert('accounts', {'name': name, 'grp': group, 'initial': initial, 'sort': next});
  }

  Future<void> deleteAccount(int id) => _db.delete('accounts', where: 'id = ?', whereArgs: [id]);

  Future<void> addProject(String name) async {
    final rows = await _db.rawQuery('SELECT COALESCE(MAX(sort), 0) AS m FROM projects');
    final next = ((rows.first['m'] as num?) ?? 0).toInt() + 1;
    await _db.insert('projects', {'name': name, 'sort': next});
  }

  Future<void> deleteProject(int id) async {
    await _db.update('entries', {'project_id': null}, where: 'project_id = ?', whereArgs: [id]);
    await _db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
}
