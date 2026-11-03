import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state.dart';
import '../theme.dart';
import 'add_entry_dialog.dart';
import 'common.dart';
import 'entry_detail.dart';

/// 總覽右側：月曆 + 選取日期的記錄
class CalendarPanel extends StatelessWidget {
  const CalendarPanel({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final m = s.month;
    final first = DateTime(m.year, m.month, 1);
    final lead = first.weekday % 7;
    final cells = [for (var i = 0; i < 42; i++) DateTime(m.year, m.month, 1 - lead + i)];

    final flags = <int, int>{};
    for (final e in s.entries) {
      final key = e.ts.year * 10000 + e.ts.month * 100 + e.ts.day;
      flags[key] = (flags[key] ?? 0) | (e.isIncome ? 2 : (e.isExpense ? 1 : 0));
    }

    final day = s.selectedDay;
    final dayEntries = s.entriesOn(day);
    final dayExpense = dayEntries.where((e) => e.isExpense).fold<double>(0, (a, e) => a + e.amount);

    return Container(
      width: 372,
      decoration: const BoxDecoration(
        color: C.rightPanel,
        border: Border(left: BorderSide(color: Color(0xFF262A33))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(DateFormat('yyyy/MM/dd').format(day), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF242832),
              foregroundColor: C.text,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: s.goToday,
            child: const Text('今天'),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (final w in weekdayZh)
            Expanded(
              child: Center(child: Text(w, style: const TextStyle(fontSize: 13, color: C.muted))),
            ),
        ]),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: [
            for (var i = 0; i < cells.length; i++)
              _cell(cells[i], i % 7 == 0, m, flags),
          ],
        ),
        const Divider(height: 24, color: Color(0xFF2B2F3A)),
        Row(children: [
          Text('${DateFormat('MM/dd').format(day)} 週${weekdayOf(day)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text.rich(TextSpan(children: [
            const TextSpan(text: '支出 ', style: TextStyle(fontSize: 13, color: C.muted)),
            TextSpan(text: money(dayExpense), style: const TextStyle(fontSize: 13, color: C.expense)),
          ])),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: dayEntries.isEmpty
              ? const Center(child: Text('這天沒有記錄', style: TextStyle(color: C.muted)))
              : ListView(children: [
                  for (final e in dayEntries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF242832), borderRadius: BorderRadius.circular(12)),
                      child: EntryRow(
                        entry: e,
                        state: s,
                        showDate: false,
                        onTap: () => showEntryDetail(context, s, e),
                      ),
                    ),
                ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: C.text,
              side: const BorderSide(color: C.line),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => AddEntryDialog.show(context, s, date: day),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('在這天新增記錄'),
          ),
        ),
      ]),
    );
  }

  Widget _cell(DateTime d, bool sunday, DateTime m, Map<int, int> flags) {
    final inMonth = d.month == m.month;
    final isSel = sameDay(d, state.selectedDay);
    final f = flags[d.year * 10000 + d.month * 100 + d.day] ?? 0;
    final dot = (f & 2) != 0 ? C.income : ((f & 1) != 0 ? C.expense : Colors.transparent);
    final Color textColor = !inMonth ? const Color(0xFF5C6373) : (sunday ? const Color(0xFFE58B86) : C.text);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => state.selectDay(d),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isSel ? C.accent : Colors.transparent, width: 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${d.day}', style: TextStyle(fontSize: 15, height: 1.1, color: textColor)),
            const SizedBox(height: 2),
            Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
          ]),
        ),
      ),
    );
  }
}
