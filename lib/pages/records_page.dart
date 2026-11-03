import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/entry_detail.dart';

/// 全部記錄：依月份列出，可搜尋、依類型與是否有附圖篩選。
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.state});
  final AppState state;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _search = TextEditingController();
  String _type = 'all'; // all | expense | income | transfer
  bool _onlyImages = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _match(Entry e, AppState s, String q) {
    if (_type != 'all' && e.type != _type) return false;
    if (_onlyImages && e.images.isEmpty) return false;
    if (q.isEmpty) return true;
    final hay = [
      e.title,
      e.merchant ?? '',
      e.note ?? '',
      s.category(e.categoryId)?.name ?? '',
      s.account(e.accountId)?.name ?? '',
      s.project(e.projectId)?.name ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final q = _search.text.trim().toLowerCase();
    final list = [for (final e in s.entriesInMonth(s.month)) if (_match(e, s, q)) e];

    // 依日期分組
    final groups = <DateTime, List<Entry>>{};
    for (final e in list) {
      final d = DateTime(e.ts.year, e.ts.month, e.ts.day);
      (groups[d] ??= <Entry>[]).add(e);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(title: '記錄', trailing: MonthSwitcher(state: s)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '搜尋名稱、商家、備註、類別…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: C.panel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 16),
          for (final d in const [('all', '全部'), ('expense', '支出'), ('income', '收入'), ('transfer', '轉帳')])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(d.$2),
                selected: _type == d.$1,
                onSelected: (_) => setState(() => _type = d.$1),
              ),
            ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.image_outlined, size: 16),
            label: const Text('有附圖'),
            selected: _onlyImages,
            onSelected: (v) => setState(() => _onlyImages = v),
          ),
          const Spacer(),
          Text('${list.length} 筆', style: const TextStyle(color: C.muted)),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('沒有符合的記錄', style: TextStyle(color: C.muted)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 28),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final items = groups[d]!;
                    final exp = items.where((e) => e.isExpense).fold<double>(0, (a, e) => a + e.amount);
                    final inc = items.where((e) => e.isIncome).fold<double>(0, (a, e) => a + e.amount);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Panel(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Column(children: [
                          Row(children: [
                            Text('${DateFormat('MM/dd').format(d)} 週${weekdayOf(d)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (inc > 0)
                              Text('收入 ${money(inc)}   ', style: const TextStyle(fontSize: 12, color: C.income)),
                            if (exp > 0) Text('支出 ${money(exp)}', style: const TextStyle(fontSize: 12, color: C.expense)),
                          ]),
                          const SizedBox(height: 4),
                          for (final e in items)
                            EntryRow(
                              entry: e,
                              state: s,
                              showDate: false,
                              onTap: () => showEntryDetail(context, s, e),
                            ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
