import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import 'common.dart';

/// 新增類別：名稱、圖示、顏色
class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, required this.state, this.fixedType});
  final AppState state;
  final String? fixedType; // 指定後不能改類型

  static Future<bool?> show(BuildContext context, AppState state, {String? fixedType}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CategoryDialog(state: state, fixedType: fixedType),
    );
  }

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _name = TextEditingController();
  late String _type;
  String _icon = 'coffee';
  int _color = kPalette.first;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.fixedType ?? 'expense';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _ok() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '請輸入類別名稱');
      return;
    }
    final dup = widget.state.categoriesOf(_type).any((c) => c.name == name);
    if (dup) {
      setState(() => _error = '已經有同名的類別');
      return;
    }
    await widget.state.addCategory(name, _type, _color, _icon);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: C.modal,
      title: const Text('新增類別'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(hintText: '類別名稱'),
              onSubmitted: (_) => _ok(),
            ),
            if (widget.fixedType == null) ...[
              const SizedBox(height: 14),
              Row(children: [
                ChoiceChip(
                  label: const Text('支出'),
                  selected: _type == 'expense',
                  onSelected: (_) => setState(() => _type = 'expense'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('收入'),
                  selected: _type == 'income',
                  onSelected: (_) => setState(() => _type = 'income'),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            const Text('圖示', style: TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in kIcons.entries)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _icon = e.key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _icon == e.key ? C.accentDim : C.raised,
                      border: Border.all(color: _icon == e.key ? C.accent : Colors.transparent),
                    ),
                    child: Icon(e.value, size: 20),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            const Text('顏色', style: TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in kPalette)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(c),
                      border: Border.all(color: _color == c ? C.text : Colors.transparent, width: 2),
                    ),
                  ),
                ),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: C.expense, fontSize: 13)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
        FilledButton(onPressed: _ok, child: const Text('新增')),
      ],
    );
  }
}
