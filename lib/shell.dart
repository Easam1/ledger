import 'package:flutter/material.dart';

import 'pages/accounts_page.dart';
import 'pages/overview_page.dart';
import 'pages/projects_page.dart';
import 'pages/records_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets/add_entry_dialog.dart';
import 'widgets/calendar_panel.dart';

class _Nav {
  final String label;
  final IconData icon;
  const _Nav(this.label, this.icon);
}

const _items = [
  _Nav('總覽', Icons.home_outlined),
  _Nav('記錄', Icons.receipt_long_outlined),
  _Nav('帳戶', Icons.account_balance_wallet_outlined),
  _Nav('專案', Icons.folder_outlined),
  _Nav('報表', Icons.show_chart),
  _Nav('設定', Icons.tune),
];

/// 左側導覽 + 內容；總覽頁右側多一欄月曆。
class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  Widget _page(AppState s) {
    switch (_index) {
      case 0:
        return OverviewPage(state: s);
      case 1:
        return RecordsPage(state: s);
      case 2:
        return AccountsPage(state: s);
      case 3:
        return ProjectsPage(state: s);
      case 4:
        return ReportsPage(state: s);
      default:
        return SettingsPage(state: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Row(children: [
          _nav(context, s),
          Expanded(child: _page(s)),
          if (_index == 0) CalendarPanel(state: s),
        ]),
      ),
    );
  }

  Widget _nav(BuildContext context, AppState s) {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: C.side,
        border: Border(right: BorderSide(color: Color(0xFF262A33))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        for (var i = 0; i < _items.length; i++) _item(i),
        const Spacer(),
        Tooltip(
          message: '新增記錄',
          child: Material(
            color: C.accent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => AddEntryDialog.show(context, s, date: s.selectedDay),
              child: const SizedBox(width: 52, height: 52, child: Icon(Icons.add, size: 28, color: C.onAccent)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _item(int i) {
    final sel = i == _index;
    final it = _items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _index = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: sel ? C.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(it.icon, size: 22, color: sel ? C.accent : const Color(0xFFAEB5C4)),
            ),
            const SizedBox(height: 4),
            Text(it.label, style: TextStyle(fontSize: 12, color: sel ? C.text : C.muted)),
          ]),
        ),
      ),
    );
  }
}
