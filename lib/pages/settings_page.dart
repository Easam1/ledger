import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets/category_dialog.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});
  final AppState state;

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _deleteCategory(BuildContext context, int id, String name) async {
    if (state.categoryInUse(id)) {
      _toast(context, '「$name」已經有記錄使用，不能刪除');
      return;
    }
    if (await confirmDialog(context, '刪除類別「$name」？', okLabel: '刪除')) {
      await state.deleteCategory(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PageHeader(title: '設定'),
        const SizedBox(height: 20),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PanelTitle(
              '類別',
              trailing: TextButton.icon(
                onPressed: () => CategoryDialog.show(context, state),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增類別'),
              ),
            ),
            const SizedBox(height: 10),
            const Text('支出', style: TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 8),
            _chips(context, 'expense'),
            const SizedBox(height: 16),
            const Text('收入', style: TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 8),
            _chips(context, 'income'),
          ]),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PanelTitle('資料'),
            const SizedBox(height: 12),
            const Text('資料與附圖都存在這個資料夾，備份時整個複製即可：',
                style: TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 6),
            SelectableText(state.dataPath, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final path = await state.exportCsv();
                  if (context.mounted) _toast(context, '已匯出：$path');
                },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('匯出 CSV（Excel 可開）'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final n = await state.loadSample();
                  if (context.mounted) _toast(context, '已加入 $n 筆範例記錄');
                },
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('載入範例資料'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: C.expense,
                  side: const BorderSide(color: Color(0xFF5A3A3A)),
                ),
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    '清除所有記錄？',
                    body: '全部記錄與附圖都會刪除，帳戶、類別、專案會保留。這個動作無法復原。',
                    okLabel: '全部清除',
                  );
                  if (ok) await state.clearEntries();
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清除所有記錄'),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _chips(BuildContext context, String type) {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final c in state.categoriesOf(type))
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
          decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(22)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CatAvatar(cat: c, size: 28),
            const SizedBox(width: 8),
            Text(c.name, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 2),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _deleteCategory(context, c.id, c.name),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.close, size: 15, color: C.muted),
              ),
            ),
          ]),
        ),
    ]);
  }
}
