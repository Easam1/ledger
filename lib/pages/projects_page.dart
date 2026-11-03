import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key, required this.state});
  final AppState state;

  Future<void> _add(BuildContext context) async {
    final name = await askText(context, '新增專案', hint: '專案名稱，例如：日本旅行');
    if (name != null && name.isNotEmpty) await state.addProject(name);
  }

  Future<void> _delete(BuildContext context, int id, String name) async {
    final ok = await confirmDialog(
      context,
      '刪除專案「$name」？',
      body: '這個專案底下的記錄會保留，只是變成「無專案」。',
      okLabel: '刪除',
    );
    if (ok) await state.deleteProject(id);
  }

  @override
  Widget build(BuildContext context) {
    final m = state.month;
    final monthSpend = <int?, double>{};
    final allSpend = <int?, double>{};
    for (final e in state.entries) {
      if (!e.isExpense) continue;
      allSpend[e.projectId] = (allSpend[e.projectId] ?? 0) + e.amount;
      if (e.ts.year == m.year && e.ts.month == m.month) {
        monthSpend[e.projectId] = (monthSpend[e.projectId] ?? 0) + e.amount;
      }
    }
    final maxAll = allSpend.values.fold<double>(0, (a, b) => b > a ? b : a);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageHeader(
          title: '專案',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            MonthSwitcher(state: state),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增專案'),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Panel(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 8),
              child: Row(children: [
                Expanded(child: Text('專案', style: TextStyle(fontSize: 13, color: C.muted))),
                SizedBox(width: 110, child: Text('本月支出', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: C.muted))),
                SizedBox(width: 120, child: Text('累計支出', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: C.muted))),
                SizedBox(width: 48),
              ]),
            ),
            _row(context, null, '無專案', monthSpend, allSpend, maxAll),
            for (final p in state.projects) _row(context, p.id, p.name, monthSpend, allSpend, maxAll),
          ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, int? id, String name, Map<int?, double> month, Map<int?, double> all, double maxAll) {
    final total = all[id] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.lineSoft))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(children: [
                  Container(height: 6, color: C.raised),
                  FractionallySizedBox(
                    widthFactor: maxAll <= 0 ? 0 : (total / maxAll).clamp(0.0, 1.0),
                    child: Container(height: 6, color: C.accent),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        SizedBox(
          width: 110,
          child: Text(money(month[id] ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 15)),
        ),
        SizedBox(
          width: 120,
          child: Text(money(total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 15)),
        ),
        SizedBox(
          width: 48,
          child: id == null
              ? null
              : IconButton(
                  tooltip: '刪除專案',
                  onPressed: () => _delete(context, id, name),
                  icon: const Icon(Icons.delete_outline, size: 20, color: C.muted),
                ),
        ),
      ]),
    );
  }
}
