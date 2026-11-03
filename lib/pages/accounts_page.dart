import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _groupOrder = ['現金', '銀行', '信用卡', '投資'];
const _groupColor = {
  '現金': Color(0xFFE3C15A),
  '銀行': Color(0xFF7FD18B),
  '信用卡': Color(0xFFF07A9A),
  '投資': Color(0xFF5BA8F5),
};

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.state});
  final AppState state;

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final initial = TextEditingController();
    var group = '現金';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          backgroundColor: C.modal,
          title: const Text('新增帳戶'),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(hintText: '帳戶名稱')),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                for (final g in _groupOrder)
                  ChoiceChip(label: Text(g), selected: group == g, onSelected: (_) => setSt(() => group = g)),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: initial,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(hintText: '初始餘額（可留空，信用卡欠款請填負數）'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('新增')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await state.addAccount(name.text.trim(), group, double.tryParse(initial.text.trim()) ?? 0);
    }
    name.dispose();
    initial.dispose();
  }

  Future<void> _delete(BuildContext context, Account a) async {
    if (state.accountInUse(a.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${a.name}」已經有記錄，不能刪除')),
      );
      return;
    }
    if (await confirmDialog(context, '刪除帳戶「${a.name}」？', okLabel: '刪除') && context.mounted) {
      await state.deleteAccount(a.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balances = {for (final a in state.accounts) a.id: state.accountBalance(a)};
    var assets = 0.0;
    var debts = 0.0;
    for (final v in balances.values) {
      if (v >= 0) {
        assets += v;
      } else {
        debts += -v;
      }
    }
    final net = assets - debts;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(
          title: '帳戶',
          trailing: FilledButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增帳戶'),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _summary('淨資產', net, C.text)),
          const SizedBox(width: 16),
          Expanded(child: _summary('資產', assets, C.income)),
          const SizedBox(width: 16),
          Expanded(child: _summary('負債', debts, C.expense)),
        ]),
        const SizedBox(height: 20),
        for (final g in _groupOrder)
          if (state.accounts.any((a) => a.group == g)) ...[
            _group(context, g, balances),
            const SizedBox(height: 16),
          ],
      ]),
    );
  }

  Widget _summary(String label, double v, Color color) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: C.muted)),
        const SizedBox(height: 8),
        Text(v < 0 ? '-${money(v.abs())}' : money(v),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: color, height: 1.1)),
      ]),
    );
  }

  Widget _group(BuildContext context, String g, Map<int, double> balances) {
    final list = [for (final a in state.accounts) if (a.group == g) a];
    final total = list.fold<double>(0, (sum, a) => sum + (balances[a.id] ?? 0));
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Text(g, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(total < 0 ? '-${money(total.abs())}' : money(total),
                style: const TextStyle(fontSize: 14, color: C.muted)),
          ]),
        ),
        const SizedBox(height: 6),
        for (final a in list)
          Container(
            height: 58,
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.lineSoft))),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _groupColor[g] ?? C.accent, borderRadius: BorderRadius.circular(10)),
                child: Text(a.name.characters.first,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.dark)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(a.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
              Text(
                (balances[a.id] ?? 0) < 0 ? '-${money((balances[a.id] ?? 0).abs())}' : money(balances[a.id] ?? 0),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: (balances[a.id] ?? 0) < 0 ? C.expense : C.text,
                ),
              ),
              IconButton(
                tooltip: '刪除帳戶',
                onPressed: () => _delete(context, a),
                icon: const Icon(Icons.delete_outline, size: 20, color: C.muted),
              ),
            ]),
          ),
      ]),
    );
  }
}
