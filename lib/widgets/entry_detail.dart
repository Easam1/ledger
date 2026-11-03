import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'add_entry_dialog.dart';
import 'common.dart';

/// 點開一筆記錄：看明細與附圖，可編輯、刪除。
Future<void> showEntryDetail(BuildContext context, AppState state, Entry entry) async {
  final r = await showDialog<String>(
    context: context,
    builder: (_) => EntryDetailDialog(state: state, entry: entry),
  );
  if (r == 'edit' && context.mounted) {
    await AddEntryDialog.show(context, state, editing: entry);
  }
}

class EntryDetailDialog extends StatefulWidget {
  const EntryDetailDialog({super.key, required this.state, required this.entry});
  final AppState state;
  final Entry entry;

  @override
  State<EntryDetailDialog> createState() => _EntryDetailDialogState();
}

class _EntryDetailDialogState extends State<EntryDetailDialog> {
  bool _confirm = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final e = widget.entry;
    final cat = s.category(e.categoryId);
    final title = e.title.isNotEmpty ? e.title : (e.isTransfer ? '轉帳' : (cat?.name ?? ''));
    final amountText = e.isExpense ? '-${money(e.amount)}' : (e.isIncome ? '+${money(e.amount)}' : money(e.amount));
    final amountColor = e.isExpense ? C.expense : (e.isIncome ? C.income : C.text);

    final meta = <MapEntry<String, String>>[
      if (!e.isTransfer && cat != null) MapEntry('類別', cat.name),
      if (e.isTransfer) ...[
        MapEntry('轉出帳戶', s.account(e.accountId)?.name ?? '—'),
        MapEntry('轉入帳戶', s.account(e.toAccountId)?.name ?? '—'),
      ] else
        MapEntry('帳戶', s.account(e.accountId)?.name ?? '—'),
      if (!e.isTransfer) MapEntry('專案', s.project(e.projectId)?.name ?? '無專案'),
      if (e.merchant != null && e.merchant!.isNotEmpty) MapEntry('商家', e.merchant!),
      if (e.note != null && e.note!.isNotEmpty) MapEntry('備註', e.note!),
    ];

    return Dialog(
      backgroundColor: C.modal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CatAvatar(cat: cat, transfer: e.isTransfer, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${DateFormat('yyyy/MM/dd').format(e.ts)} 週${weekdayOf(e.ts)} ${DateFormat('HH:mm').format(e.ts)}',
                      style: const TextStyle(fontSize: 13, color: C.muted)),
                ]),
              ),
              Text(amountText, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: amountColor)),
            ]),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final m in meta)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.lineSoft))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 80, child: Text(m.key, style: const TextStyle(fontSize: 14, color: C.muted))),
                        Expanded(child: Text(m.value, style: const TextStyle(fontSize: 15))),
                      ]),
                    ),
                  if (e.images.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('附圖 ${e.images.length} 張',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final path in e.images)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _zoom(context, path),
                          child: ImageThumb(path: path, size: 140, radius: 12),
                        ),
                    ]),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              if (!_confirm) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('edit'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('編輯'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.expense,
                    side: const BorderSide(color: Color(0xFF5A3A3A)),
                  ),
                  onPressed: () => setState(() => _confirm = true),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('刪除'),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('關閉')),
              ] else ...[
                const Expanded(child: Text('確定要刪除這筆記錄與它的附圖嗎？', style: TextStyle(color: C.expense))),
                TextButton(onPressed: () => setState(() => _confirm = false), child: const Text('取消')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.expense, foregroundColor: C.dark),
                  onPressed: () async {
                    await s.deleteEntry(e);
                    if (context.mounted) Navigator.of(context).pop('deleted');
                  },
                  child: const Text('刪除'),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  void _zoom(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xDD000000),
      builder: (c) => GestureDetector(
        onTap: () => Navigator.of(c).pop(),
        child: Center(
          child: InteractiveViewer(
            maxScale: 6,
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
