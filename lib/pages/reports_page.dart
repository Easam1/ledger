import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/entry_detail.dart';

/// 每月報表：統計、類別、排行、專案、帳戶、商家
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final m = s.month;
    final entries = s.entriesInMonth(m);
    final exps = [for (final e in entries) if (e.isExpense) e];
    final inc = s.total('income', m);
    final exp = s.total('expense', m);

    // 日均：本月（還沒過完）以今天為止，其他月份用整月天數
    final now = DateTime.now();
    final dim = DateTime(m.year, m.month + 1, 0).day;
    final days = (m.year == now.year && m.month == now.month) ? now.day : dim;
    final biggest = exps.isEmpty ? 0.0 : exps.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    // 類別
    final byCat = <int?, double>{};
    for (final e in exps) {
      byCat[e.categoryId] = (byCat[e.categoryId] ?? 0) + e.amount;
    }
    final catList = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // 專案、帳戶、商家
    final byProj = <int?, double>{};
    final byAcc = <int?, double>{};
    final byMerchant = <String, double>{};
    final merchantCount = <String, int>{};
    for (final e in exps) {
      byProj[e.projectId] = (byProj[e.projectId] ?? 0) + e.amount;
      byAcc[e.accountId] = (byAcc[e.accountId] ?? 0) + e.amount;
      final mn = e.merchant;
      if (mn != null && mn.isNotEmpty) {
        byMerchant[mn] = (byMerchant[mn] ?? 0) + e.amount;
        merchantCount[mn] = (merchantCount[mn] ?? 0) + 1;
      }
    }
    final projList = byProj.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final accList = byAcc.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final merList = byMerchant.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final rank = [...exps]..sort((a, b) => b.amount.compareTo(a.amount));

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(
          title: '報表',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFF242832), borderRadius: BorderRadius.circular(10)),
              child: const Text('每月報表', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 16),
            MonthSwitcher(state: s),
          ]),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(children: [
              _row([
                _statsPanel(inc, exp, exp == 0 ? 0 : exp / days, entries.length, biggest),
                _categoryPanel(s, catList, exp),
                _rankPanel(context, s, rank.take(5).toList(), biggest),
              ]),
              const SizedBox(height: 16),
              _row([
                _barPanel('專案', [
                  for (final x in projList)
                    _BarItem(s.project(x.key)?.name ?? '無專案', x.value, C.accent),
                ]),
                _barPanel('帳戶', [
                  for (final x in accList) _BarItem(s.account(x.key)?.name ?? '—', x.value, const Color(0xFF5BA8F5)),
                ]),
                _merchantPanel(merList, merchantCount),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(List<Widget> children) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: children[i]),
        ],
      ]),
    );
  }

  Widget _statsPanel(double inc, double exp, double perDay, int count, double biggest) {
    Widget line(String label, String value, Color color) => Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2E323D)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(label, style: const TextStyle(fontSize: 14, color: C.muted)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: color)),
          ]),
        );
    final bal = inc - exp;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelTitle('統計'),
        const SizedBox(height: 4),
        line('收入', money(inc), C.income),
        line('支出', money(exp), C.expense),
        line('餘額', bal < 0 ? '-${money(bal.abs())}' : money(bal), C.balance),
        line('日均支出', money(perDay.roundToDouble()), C.text),
        line('記錄筆數', '$count 筆', C.text),
        line('單筆最高支出', money(biggest), C.text),
      ]),
    );
  }

  Widget _categoryPanel(AppState s, List<MapEntry<int?, double>> list, double total) {
    final slices = [
      for (final x in list) DonutSlice(x.value, Color(s.category(x.key)?.color ?? 0xFF666666)),
    ];
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelTitle('類別', trailing: Text('支出', style: TextStyle(fontSize: 13, color: C.muted))),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('尚無報表資料', style: TextStyle(color: C.muted))),
          )
        else
          Row(children: [
            Stack(alignment: Alignment.center, children: [
              DonutChart(slices: slices, size: 150, thickness: 26),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('支出', style: TextStyle(fontSize: 12, color: C.muted)),
                Text(money(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                for (final x in list.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(s.category(x.key)?.color ?? 0xFF666666),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.category(x.key)?.name ?? '未分類',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ),
                      Text('${(x.value / total * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12, color: C.muted)),
                      SizedBox(
                        width: 66,
                        child: Text(money(x.value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]),
      ]),
    );
  }

  Widget _rankPanel(BuildContext context, AppState s, List<Entry> top, double biggest) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelTitle('排行'),
        const SizedBox(height: 14),
        if (top.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('尚無報表資料', style: TextStyle(color: C.muted))),
          )
        else
          for (final e in top)
            InkWell(
              onTap: () => showEntryDetail(context, s, e),
              child: BarRow(
                label: e.title.isNotEmpty ? e.title : (s.category(e.categoryId)?.name ?? ''),
                sub: '${e.ts.month}/${e.ts.day} · ${s.category(e.categoryId)?.name ?? ''}',
                amount: money(e.amount),
                fraction: biggest <= 0 ? 0 : e.amount / biggest,
                color: Color(s.category(e.categoryId)?.color ?? 0xFF666666),
              ),
            ),
      ]),
    );
  }

  Widget _barPanel(String title, List<_BarItem> items) {
    final maxV = items.isEmpty ? 0.0 : items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PanelTitle(title),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: Text('尚無報表資料', style: TextStyle(color: C.muted))),
          )
        else
          for (final it in items)
            BarRow(label: it.label, amount: money(it.value), fraction: maxV <= 0 ? 0 : it.value / maxV, color: it.color),
      ]),
    );
  }

  Widget _merchantPanel(List<MapEntry<String, double>> list, Map<String, int> count) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelTitle('商家', trailing: Text('依金額排序', style: TextStyle(fontSize: 13, color: C.muted))),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: Text('尚無報表資料', style: TextStyle(color: C.muted))),
          )
        else
          for (final x in list.take(6))
            Container(
              height: 46,
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.lineSoft))),
              child: Row(children: [
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(x.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                    Text('${count[x.key] ?? 0} 筆', style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
                Text('-${money(x.value)}', style: const TextStyle(fontSize: 15, color: C.expense)),
              ]),
            ),
      ]),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  final Color color;
  _BarItem(this.label, this.value, this.color);
}
