import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/entry_detail.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.state});
  final AppState state;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  String _tab = 'bal'; // inc | exp | bal

  String _pct(double cur, double prev) {
    if (prev == 0) return '—';
    final p = (cur - prev) / prev * 100;
    return '${p >= 0 ? '+' : '-'}${p.abs().toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final m = s.month;
    final prev = DateTime(m.year, m.month - 1);
    final inc = s.total('income', m);
    final exp = s.total('expense', m);
    final pInc = s.total('income', prev);
    final pExp = s.total('expense', prev);
    final bal = inc - exp;
    final pBal = pInc - pExp;
    final recent = s.entriesInMonth(m).take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(title: '總覽', trailing: MonthSwitcher(state: s)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _netWorth(s)),
          const SizedBox(width: 16),
          Expanded(child: _stat('餘額', bal, C.balance, signedMoney(bal - pBal))),
          const SizedBox(width: 16),
          Expanded(child: _stat('支出', exp, C.expense, _pct(exp, pExp))),
          const SizedBox(width: 16),
          Expanded(child: _stat('收入', inc, C.income, _pct(inc, pInc))),
        ]),
        const SizedBox(height: 20),
        _trend(s),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: _recent(s, recent)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _upcoming()),
        ]),
      ]),
    );
  }

  Widget _netWorth(AppState s) {
    var assets = 0.0;
    var debts = 0.0;
    for (final a in s.accounts) {
      final v = s.accountBalance(a);
      if (v >= 0) {
        assets += v;
      } else {
        debts += -v;
      }
    }
    final net = assets - debts;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('淨資產', style: TextStyle(fontSize: 14, color: C.muted)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            net < 0 ? '-${money(net.abs())}' : money(net),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: C.text, height: 1.1),
          ),
        ),
        const SizedBox(height: 8),
        Text('資產 ${money(assets)} · 負債 ${money(debts)}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
  }

  Widget _stat(String label, double value, Color color, String delta) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: C.muted)),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value < 0 ? '-${money(value.abs())}' : money(value),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: color, height: 1.1),
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(TextSpan(children: [
          const TextSpan(text: '較上月 ', style: TextStyle(fontSize: 13, color: C.muted)),
          TextSpan(text: delta, style: const TextStyle(fontSize: 13, color: C.text)),
        ])),
      ]),
    );
  }

  Widget _trend(AppState s) {
    final m = s.month;
    final months = [for (var i = 5; i >= 0; i--) DateTime(m.year, m.month - i)];
    double val(DateTime d) {
      final i = s.total('income', d);
      final e = s.total('expense', d);
      return _tab == 'inc' ? i : (_tab == 'exp' ? e : i - e);
    }

    final values = [for (final d in months) val(d)];
    final cur = values.last;
    final diff = cur - values[values.length - 2];
    final color = _tab == 'inc' ? C.income : (_tab == 'exp' ? C.expense : C.balance);
    final label = '${m.year}/${m.month.toString().padLeft(2, '0')} 總計';

    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 2),
            Text(cur < 0 ? '-${money(cur.abs())}' : money(cur),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: color, height: 1.1)),
          ]),
          const SizedBox(width: 20),
          Container(width: 1, height: 40, color: C.line),
          const SizedBox(width: 20),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('比前一月', style: TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 2),
            Text('${diff >= 0 ? '增加' : '減少'} ${money(diff.abs())}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
          const Spacer(),
          _segmented(),
        ]),
        const SizedBox(height: 8),
        TrendChart(values: values, months: months, color: color),
      ]),
    );
  }

  Widget _segmented() {
    const defs = [('inc', '收入'), ('exp', '支出'), ('bal', '結餘')];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: C.panelDeep, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final d in defs)
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => _tab = d.$1),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tab == d.$1 ? const Color(0xFF3A3F4C) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(d.$2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _tab == d.$1 ? FontWeight.w600 : FontWeight.w400,
                    color: _tab == d.$1 ? C.text : C.muted,
                  )),
            ),
          ),
      ]),
    );
  }

  Widget _recent(AppState s, List<Entry> recent) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PanelTitle('近期記錄'),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: Text('這個月還沒有記錄，按左下角的 ＋ 新增第一筆', style: TextStyle(color: C.muted))),
          )
        else
          for (final e in recent) EntryRow(entry: e, state: s, onTap: () => showEntryDetail(context, s, e)),
      ]),
    );
  }

  Widget _upcoming() {
    return const Panel(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PanelTitle('即將到來'),
        SizedBox(height: 40),
        Center(child: Text('未來 30 天沒有任何交易', style: TextStyle(color: C.muted))),
        SizedBox(height: 6),
        Center(child: Text('週期與分期事件之後會放在這裡', style: TextStyle(fontSize: 12, color: Color(0xFF6E7587)))),
        SizedBox(height: 40),
      ]),
    );
  }
}
