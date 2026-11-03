import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'db.dart';
import 'models.dart';

/// 範例資料的樣板（日, 時, 分, 類型, 名稱, 金額, 類別, 帳戶, 專案, 商家, 固定金額）
class _Tpl {
  final int day, hour, minute;
  final String type, title;
  final double amount;
  final String cat, account, project, merchant;
  final bool fixed;
  const _Tpl(this.day, this.hour, this.minute, this.type, this.title, this.amount, this.cat, this.account,
      this.project, this.merchant, this.fixed);
}

const List<_Tpl> _sampleTemplate = [
  _Tpl(3, 14, 20, 'expense', '博客來 書籍', 680, '學習', '信用卡', '工作', '博客來', false),
  _Tpl(5, 9, 0, 'income', '薪水', 52000, '薪水', '銀行存款', '', '', true),
  _Tpl(8, 12, 10, 'expense', '午餐', 150, '飲食', '錢包', '生活開銷', '', false),
  _Tpl(10, 8, 0, 'expense', '房租', 12000, '家居', '銀行存款', '家用', '', true),
  _Tpl(12, 15, 30, 'expense', '咖啡', 120, '飲食', '錢包', '生活開銷', '', false),
  _Tpl(15, 8, 0, 'expense', '電費', 2140, '家居', '銀行存款', '家用', '台灣電力公司', false),
  _Tpl(18, 17, 0, 'income', '接案收入', 6800, '獎金', '銀行存款', '工作', '', false),
  _Tpl(20, 10, 0, 'expense', '電信費', 999, '生活', '信用卡', '生活開銷', '', true),
  _Tpl(24, 11, 20, 'expense', '診所掛號', 350, '醫療', '錢包', '生活開銷', '', false),
  _Tpl(25, 19, 0, 'expense', '家人聚餐', 1860, '飲食', '信用卡', '生活開銷', '', false),
  _Tpl(26, 17, 30, 'expense', '加油', 760, '交通', '信用卡', '生活開銷', '台灣中油', false),
  _Tpl(28, 0, 0, 'expense', 'Netflix', 390, '娛樂', '信用卡', '生活開銷', 'Netflix', true),
  _Tpl(29, 19, 10, 'expense', '全聯 週補貨', 1286, '購物', '信用卡', '生活開銷', '全聯福利中心', false),
  _Tpl(30, 18, 45, 'expense', '悠遊卡加值', 500, '交通', '錢包', '生活開銷', '', true),
  _Tpl(31, 12, 8, 'expense', '牛肉麵', 180, '飲食', '錢包', '生活開銷', '阿財牛肉麵', false),
];

class AppState extends ChangeNotifier {
  AppState(this.db);

  final AppDb db;

  List<Category> categories = [];
  List<Account> accounts = [];
  List<Project> projects = [];
  List<Entry> entries = []; // 依時間由新到舊

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDay = _today();

  Map<int, Category> _catById = {};
  Map<int, Account> _accById = {};
  Map<int, Project> _projById = {};

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String get dataPath => db.root.path;

  // ---------- 載入 ----------

  Future<void> load() async {
    categories = await db.categories();
    accounts = await db.accounts();
    projects = await db.projects();
    entries = await db.entries();
    _catById = {for (final c in categories) c.id: c};
    _accById = {for (final a in accounts) a.id: a};
    _projById = {for (final x in projects) x.id: x};
    notifyListeners();
  }

  // ---------- 查詢 ----------

  Category? category(int? id) => id == null ? null : _catById[id];
  Account? account(int? id) => id == null ? null : _accById[id];
  Project? project(int? id) => id == null ? null : _projById[id];

  List<Category> categoriesOf(String type) => [for (final c in categories) if (c.type == type) c];

  List<Entry> entriesInMonth(DateTime m) =>
      [for (final e in entries) if (e.ts.year == m.year && e.ts.month == m.month) e];

  List<Entry> entriesOn(DateTime d) => [for (final e in entries) if (sameDate(e.ts, d)) e];

  static bool sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  double total(String type, DateTime m) {
    var sum = 0.0;
    for (final e in entries) {
      if (e.type == type && e.ts.year == m.year && e.ts.month == m.month) sum += e.amount;
    }
    return sum;
  }

  // ---------- 輸入建議（常用項目 / 商家）----------

  /// 依使用次數排序的歷史名稱；[q] 為空時回傳最常用的。
  List<String> suggestTitles(String type, String q) {
    final count = <String, int>{};
    for (final e in entries) {
      if (e.type != type || e.title.isEmpty) continue;
      count[e.title] = (count[e.title] ?? 0) + 1;
    }
    return _rank(count, q);
  }

  List<String> suggestMerchants(String q) {
    final count = <String, int>{};
    for (final e in entries) {
      final m = e.merchant;
      if (m == null || m.isEmpty) continue;
      count[m] = (count[m] ?? 0) + 1;
    }
    return _rank(count, q);
  }

  List<String> _rank(Map<String, int> count, String q) {
    final key = q.trim().toLowerCase();
    final list = [for (final k in count.keys) if (key.isEmpty || k.toLowerCase().contains(key)) k];
    list.sort((a, b) => count[b]!.compareTo(count[a]!));
    return list.take(8).toList();
  }

  /// 同名稱最近一筆（entries 已依時間新到舊排序）
  Entry? lastByTitle(String type, String title) {
    for (final e in entries) {
      if (e.type == type && e.title == title) return e;
    }
    return null;
  }

  /// 同商家最近一筆
  Entry? lastByMerchant(String merchant) {
    for (final e in entries) {
      if (e.merchant == merchant) return e;
    }
    return null;
  }

  double get netWorth => accounts.fold<double>(0, (sum, a) => sum + accountBalance(a));

  double accountBalance(Account a) {
    var v = a.initial;
    for (final e in entries) {
      if (e.isIncome && e.accountId == a.id) {
        v += e.amount;
      } else if (e.isExpense && e.accountId == a.id) {
        v -= e.amount;
      } else if (e.isTransfer) {
        if (e.accountId == a.id) v -= e.amount;
        if (e.toAccountId == a.id) v += e.amount;
      }
    }
    return v;
  }

  bool categoryInUse(int id) => entries.any((e) => e.categoryId == id);
  bool accountInUse(int id) => entries.any((e) => e.accountId == id || e.toAccountId == id);

  // ---------- 月份與日期 ----------

  void shiftMonth(int delta) {
    month = DateTime(month.year, month.month + delta);
    final dim = DateTime(month.year, month.month + 1, 0).day;
    final day = selectedDay.day > dim ? dim : selectedDay.day;
    selectedDay = DateTime(month.year, month.month, day);
    notifyListeners();
  }

  void goToday() {
    selectedDay = _today();
    month = DateTime(selectedDay.year, selectedDay.month);
    notifyListeners();
  }

  void selectDay(DateTime d) {
    selectedDay = DateTime(d.year, d.month, d.day);
    month = DateTime(d.year, d.month);
    notifyListeners();
  }

  // ---------- 記錄 ----------

  /// 新增或更新一筆記錄。keepPaths 是要保留的既有圖片，newFiles 是新挑的圖片。
  Future<void> saveEntry(Entry e, {List<String> keepPaths = const [], List<File> newFiles = const []}) async {
    final paths = <String>[...keepPaths];
    for (final f in newFiles) {
      paths.add(await db.storeImage(f));
    }
    final full = e.withImages(paths);
    if (e.id == null) {
      await db.insertEntry(full);
    } else {
      Entry? old;
      for (final x in entries) {
        if (x.id == e.id) old = x;
      }
      await db.updateEntry(full);
      if (old != null) {
        for (final path in old.images) {
          if (!paths.contains(path)) await db.deleteImageFile(path);
        }
      }
    }
    entries = await db.entries();
    notifyListeners();
  }

  Future<void> deleteEntry(Entry e) async {
    if (e.id == null) return;
    await db.deleteEntry(e.id!);
    for (final path in e.images) {
      await db.deleteImageFile(path);
    }
    entries = await db.entries();
    notifyListeners();
  }

  Future<void> clearEntries() async {
    for (final e in entries) {
      for (final path in e.images) {
        await db.deleteImageFile(path);
      }
    }
    await db.clearEntries();
    entries = await db.entries();
    notifyListeners();
  }

  // ---------- 類別 / 帳戶 / 專案 ----------

  Future<void> addCategory(String name, String type, int color, String icon) async {
    await db.addCategory(name, type, color, icon);
    await load();
  }

  Future<void> deleteCategory(int id) async {
    await db.deleteCategory(id);
    await load();
  }

  Future<void> addAccount(String name, String group, double initial) async {
    await db.addAccount(name, group, initial);
    await load();
  }

  Future<void> deleteAccount(int id) async {
    await db.deleteAccount(id);
    await load();
  }

  Future<void> addProject(String name) async {
    await db.addProject(name);
    await load();
  }

  Future<void> deleteProject(int id) async {
    await db.deleteProject(id);
    await load();
  }

  // ---------- 範例資料與匯出 ----------

  int? _idByName<T>(List<T> list, String name, String Function(T) nameOf, int Function(T) idOf) {
    for (final x in list) {
      if (nameOf(x) == name) return idOf(x);
    }
    return null;
  }

  /// 產生最近六個月的範例記錄（不含圖片）。
  Future<int> loadSample() async {
    final now = DateTime.now();
    final cur = DateTime(now.year, now.month);
    const factors = [1.15, 0.9, 1.3, 0.95, 1.05];
    var count = 0;
    for (var back = 5; back >= 0; back--) {
      final m = DateTime(cur.year, cur.month - back);
      final dim = DateTime(m.year, m.month + 1, 0).day;
      final f = back == 0 ? 1.0 : factors[(back - 1) % factors.length];
      for (final t in _sampleTemplate) {
        final day = t.day > dim ? dim : t.day;
        final when = DateTime(m.year, m.month, day, t.hour, t.minute);
        if (back == 0 && when.isAfter(now)) continue;
        final amt = t.fixed ? t.amount : ((t.amount * f) / 10).round() * 10.0;
        final isIncome = t.type == 'income';
        await db.insertEntry(Entry(
          type: t.type,
          amount: amt,
          title: t.title,
          categoryId: _idByName<Category>(categories, t.cat, (c) => c.name, (c) => c.id),
          accountId: _idByName<Account>(accounts, t.account, (a) => a.name, (a) => a.id),
          projectId: t.project.isEmpty
              ? null
              : _idByName<Project>(projects, t.project, (x) => x.name, (x) => x.id),
          merchant: t.merchant.isEmpty ? null : t.merchant,
          ts: when,
        ));
        if (isIncome) {
          // 範例收入不必再做額外處理
        }
        count++;
      }
    }
    entries = await db.entries();
    notifyListeners();
    return count;
  }

  String _csvCell(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// 匯出全部記錄成 CSV（UTF-8 含 BOM，Excel 可直接開啟），回傳檔案路徑。
  Future<String> exportCsv() async {
    final d = DateFormat('yyyy/MM/dd');
    final t = DateFormat('HH:mm');
    const typeName = {'expense': '支出', 'income': '收入', 'transfer': '轉帳'};
    final buf = StringBuffer('日期,時間,類型,類別,名稱,金額,帳戶,轉入帳戶,專案,商家,備註,附圖數\n');
    for (final e in entries.reversed) {
      final cells = [
        d.format(e.ts),
        t.format(e.ts),
        typeName[e.type] ?? e.type,
        category(e.categoryId)?.name ?? '',
        e.title,
        plain(e.amount),
        account(e.accountId)?.name ?? '',
        account(e.toAccountId)?.name ?? '',
        project(e.projectId)?.name ?? '',
        e.merchant ?? '',
        e.note ?? '',
        '${e.images.length}',
      ];
      buf.writeln(cells.map(_csvCell).join(','));
    }
    final name = 'ledger_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    final path = p.join(db.root.path, name);
    await File(path).writeAsString('﻿${buf.toString()}');
    return path;
  }

  static String plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
