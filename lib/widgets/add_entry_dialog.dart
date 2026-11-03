import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'category_dialog.dart';
import 'common.dart';

class _Img {
  final String? path; // 已存在 App 資料夾的圖片
  final File? file; // 剛挑選、尚未儲存的圖片
  _Img.stored(String p)
      : path = p,
        file = null;
  _Img.picked(File f)
      : path = null,
        file = f;
  String get shown => path ?? file!.path;
}

/// 新增 / 編輯記錄。左邊是表單，右邊是計算機與常用帳戶、專案。
class AddEntryDialog extends StatefulWidget {
  const AddEntryDialog({super.key, required this.state, this.editing, this.date});
  final AppState state;
  final Entry? editing;
  final DateTime? date;

  static Future<bool?> show(BuildContext context, AppState state, {Entry? editing, DateTime? date}) {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0xAA08090C),
      builder: (_) => AddEntryDialog(state: state, editing: editing, date: date),
    );
  }

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  static const _ops = ['+', '−', '×', '÷'];
  static const _keys = [
    '÷', '×', '−', '+',
    '1', '2', '3', '⌫',
    '4', '5', '6', 'C',
    '7', '8', '9', '=',
    '.', '0', '00', '✓',
  ];

  late String _type;
  String _expr = '';
  final _title = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();
  final _titleFocus = FocusNode();
  final _merchantFocus = FocusNode();
  int? _categoryId;
  int? _accountId;
  int? _toAccountId;
  int? _projectId;
  late DateTime _ts;
  final List<_Img> _imgs = [];
  String? _error;
  bool _saving = false;

  AppState get _s => widget.state;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.type;
      _expr = plainNum(e.amount);
      _title.text = e.title;
      _merchant.text = e.merchant ?? '';
      _note.text = e.note ?? '';
      _categoryId = e.categoryId;
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _projectId = e.projectId;
      _ts = e.ts;
      for (final p in e.images) {
        _imgs.add(_Img.stored(p));
      }
    } else {
      _type = 'expense';
      final d = widget.date ?? DateTime.now();
      final n = DateTime.now();
      _ts = DateTime(d.year, d.month, d.day, n.hour, n.minute);
      if (_s.accounts.isNotEmpty) _accountId = _s.accounts.first.id;
      if (_s.accounts.length > 1) _toAccountId = _s.accounts[1].id;
      _defaultCategory();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _merchant.dispose();
    _note.dispose();
    _titleFocus.dispose();
    _merchantFocus.dispose();
    super.dispose();
  }

  void _defaultCategory() {
    final cats = _s.categoriesOf(_type == 'income' ? 'income' : 'expense');
    _categoryId = cats.isNotEmpty ? cats.first.id : null;
  }

  void _setType(String t) {
    setState(() {
      _type = t;
      _error = null;
      if (t != 'transfer') {
        final cat = _s.category(_categoryId);
        if (cat == null || cat.type != t) _defaultCategory();
      }
    });
  }

  // ---------- 計算機 ----------

  void _press(String k) {
    if (k == '✓') {
      _save();
      return;
    }
    setState(() {
      _error = null;
      if (k == 'C') {
        _expr = '';
      } else if (k == '⌫') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      } else if (k == '=') {
        final v = evalExpr(_expr);
        if (v != null) _expr = plainNum(v);
      } else if (_ops.contains(k)) {
        if (_expr.isEmpty) {
          // 開頭不能放運算符號
        } else if (_ops.contains(_expr[_expr.length - 1])) {
          _expr = _expr.substring(0, _expr.length - 1) + k;
        } else {
          _expr += k;
        }
      } else if (k == '.') {
        final seg = _expr.split(RegExp(r'[+−×÷]')).last;
        if (!seg.contains('.')) _expr += seg.isEmpty ? '0.' : '.';
      } else {
        final seg = _expr.split(RegExp(r'[+−×÷]')).last;
        final add = (seg.isEmpty && k == '00') ? '0' : k;
        if (seg == '0') {
          _expr = _expr.substring(0, _expr.length - 1) + (add == '00' ? '0' : add);
        } else {
          _expr += add;
        }
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    // 在文字欄位輸入時，不要把按鍵當成計算機輸入
    final primary = FocusManager.instance.primaryFocus;
    if (primary?.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _press('⌫');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _press('=');
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.length == 1 && '0123456789.+-*/'.contains(ch)) {
      const map = {'-': '−', '*': '×', '/': '÷'};
      _press(map[ch] ?? ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------- 動作 ----------

  Future<void> _pickImages() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (r == null) return;
    setState(() {
      for (final f in r.files) {
        final p = f.path;
        if (p != null) _imgs.add(_Img.picked(File(p)));
      }
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ts,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '選擇日期',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (d == null) return;
    setState(() => _ts = DateTime(d.year, d.month, d.day, _ts.hour, _ts.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_ts),
      helpText: '選擇時間（24 小時制）',
      cancelText: '取消',
      confirmText: '確定',
      hourLabelText: '時',
      minuteLabelText: '分',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() => _ts = DateTime(_ts.year, _ts.month, _ts.day, t.hour, t.minute));
  }

  Future<void> _pickAccount({required bool target}) async {
    final r = await pickFrom<int>(
      context,
      target ? '轉入帳戶' : (_type == 'transfer' ? '轉出帳戶' : '帳戶'),
      [for (final a in _s.accounts) Opt(a.id, a.name)],
      current: target ? _toAccountId : _accountId,
    );
    if (r == null) return;
    setState(() {
      if (target) {
        _toAccountId = r;
      } else {
        _accountId = r;
      }
    });
  }

  Future<void> _pickProject() async {
    final r = await pickFrom<int>(
      context,
      '專案',
      [const Opt(-1, '無專案'), for (final p in _s.projects) Opt(p.id, p.name)],
      current: _projectId ?? -1,
    );
    if (r == null) return;
    setState(() => _projectId = r == -1 ? null : r);
  }

  Future<void> _addCategory() async {
    final type = _type == 'income' ? 'income' : 'expense';
    final ok = await CategoryDialog.show(context, _s, fixedType: type);
    if (ok == true) {
      setState(() {
        final cats = _s.categoriesOf(type);
        if (cats.isNotEmpty) _categoryId = cats.last.id;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final total = evalExpr(_expr) ?? 0;
    if (total <= 0) {
      setState(() => _error = '請輸入金額');
      return;
    }
    if (_type == 'transfer') {
      if (_accountId == null || _toAccountId == null || _accountId == _toAccountId) {
        setState(() => _error = '請選擇不同的轉出與轉入帳戶');
        return;
      }
    } else if (_accountId == null) {
      setState(() => _error = '請選擇帳戶');
      return;
    }
    setState(() => _saving = true);
    final merchant = _merchant.text.trim();
    final note = _note.text.trim();
    final isTransfer = _type == 'transfer';
    final e = Entry(
      id: widget.editing?.id,
      type: _type,
      amount: total,
      title: _title.text.trim(),
      categoryId: isTransfer ? null : _categoryId,
      accountId: _accountId,
      toAccountId: isTransfer ? _toAccountId : null,
      projectId: isTransfer ? null : _projectId,
      merchant: merchant.isEmpty ? null : merchant,
      note: note.isEmpty ? null : note,
      ts: _ts,
    );
    await _s.saveEntry(
      e,
      keepPaths: [for (final i in _imgs) if (i.path != null) i.path!],
      newFiles: [for (final i in _imgs) if (i.file != null) i.file!],
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  // ---------- 畫面 ----------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = math.min(size.height - 48, 840.0);
    final w = math.min(size.width - 48, 1060.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      elevation: 0,
      child: SizedBox(
        width: w,
        height: h,
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Row(children: [
            Expanded(child: _form()),
            SizedBox(width: 360, child: _sidePanel()),
          ]),
        ),
      ),
    );
  }

  Widget _form() {
    return Container(
      decoration: const BoxDecoration(
        color: C.modal,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(22)),
      ),
      child: Column(children: [
        SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              IconButton(
                tooltip: '關閉',
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Center(
                  child: Text(widget.editing == null ? '新增記錄' : '編輯記錄',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              Material(
                color: C.accent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _save,
                  child: const SizedBox(width: 44, height: 40, child: Icon(Icons.check, color: C.onAccent)),
                ),
              ),
            ]),
          ),
        ),
        _tabs(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_type != 'transfer') ...[_categoryGrid(), const SizedBox(height: 16)],
              _amountField(),
              const SizedBox(height: 8),
              _nameField(),
              const SizedBox(height: 16),
              _imageSection(),
              const SizedBox(height: 16),
              _selectors(),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: _dec('備註'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3F4C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: C.accent),
        ),
      );

  Widget _tabs() {
    const defs = [('expense', '支出'), ('income', '收入'), ('transfer', '轉帳')];
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        for (final d in defs)
          Expanded(
            child: InkWell(
              onTap: () => _setType(d.$1),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _type == d.$1 ? C.accent : Colors.transparent, width: 2)),
                ),
                child: Text(d.$2,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _type == d.$1 ? FontWeight.w600 : FontWeight.w400,
                      color: _type == d.$1 ? C.text : C.muted,
                    )),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _categoryGrid() {
    final cats = _s.categoriesOf(_type == 'income' ? 'income' : 'expense');
    return Wrap(spacing: 8, runSpacing: 10, children: [
      for (final c in cats)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _categoryId = c.id),
          child: SizedBox(
            width: 76,
            child: Column(children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _categoryId == c.id ? C.accent : Colors.transparent, width: 3),
                ),
                child: CatAvatar(cat: c, size: 44),
              ),
              const SizedBox(height: 4),
              Text(c.name,
                  style: TextStyle(fontSize: 13, color: _categoryId == c.id ? C.text : C.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _addCategory,
        child: SizedBox(
          width: 76,
          child: Column(children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: C.line),
                child: const Icon(Icons.add, size: 22),
              ),
            ),
            const SizedBox(height: 4),
            const Text('新增', style: TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ),
      ),
    ]);
  }

  Widget _amountField() {
    final total = evalExpr(_expr);
    final hasOp = _expr.split('').any((c) => _ops.contains(c));
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: C.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.accent),
      ),
      child: Row(children: [
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF3C4150), borderRadius: BorderRadius.circular(8)),
          child: const Text('TWD', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              _expr.isEmpty ? '金額' : (hasOp && total != null ? '$_expr = ${plainNum(total)}' : _expr),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _expr.isEmpty ? 18 : 26,
                fontWeight: _expr.isEmpty ? FontWeight.w400 : FontWeight.w600,
                color: _expr.isEmpty ? C.muted : C.text,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ---------- 常用項目 / 商家：自動完成與帶入 ----------

  Widget _suggestField({
    required TextEditingController controller,
    required FocusNode focus,
    required List<String> Function(String) options,
    required ValueChanged<String> onPicked,
    required InputDecoration decoration,
    TextAlign align = TextAlign.start,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focus,
      optionsBuilder: (v) => options(v.text),
      onSelected: onPicked,
      fieldViewBuilder: (context, ctrl, node, onSubmit) => TextField(
        controller: ctrl,
        focusNode: node,
        textAlign: align,
        style: const TextStyle(fontSize: 16),
        decoration: decoration,
      ),
      optionsViewBuilder: (context, onSelected, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: C.modal,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 280),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              children: [
                for (final o in opts)
                  InkWell(
                    onTap: () => onSelected(o),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(o, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 選了舊名稱：把上次的類別、金額、帳戶、專案、商家一起帶進來（只補還沒填的）
  void _applyTitle(String title) {
    if (widget.editing != null) return;
    final last = _s.lastByTitle(_type, title);
    if (last == null) return;
    _fillFrom(last);
  }

  void _applyMerchant(String merchant) {
    if (widget.editing != null) return;
    final last = _s.lastByMerchant(merchant);
    if (last == null || last.type != _type) return;
    _fillFrom(last);
  }

  void _fillFrom(Entry last) {
    setState(() {
      if (last.categoryId != null && _s.category(last.categoryId)?.type == _type) {
        _categoryId = last.categoryId;
      }
      if (_expr.isEmpty) _expr = plainNum(last.amount);
      if (last.accountId != null) _accountId = last.accountId;
      if (_type == 'transfer') {
        if (last.toAccountId != null) _toAccountId = last.toAccountId;
      } else {
        _projectId = last.projectId;
        if (_merchant.text.trim().isEmpty && (last.merchant ?? '').isNotEmpty) {
          _merchant.text = last.merchant!;
        }
      }
      if (_title.text.trim().isEmpty && last.title.isNotEmpty) _title.text = last.title;
      _error = null;
    });
  }

  Widget _nameField() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Text('名稱', style: TextStyle(fontSize: 15, color: C.muted)),
        const SizedBox(width: 16),
        Expanded(
          child: _suggestField(
            controller: _title,
            focus: _titleFocus,
            options: (q) => _s.suggestTitles(_type, q),
            onPicked: _applyTitle,
            align: TextAlign.right,
            decoration: const InputDecoration.collapsed(hintText: '輸入或從常用項目選擇'),
          ),
        ),
      ]),
    );
  }

  Widget _imageSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('附圖', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('收據、發票、照片都能附上，之後點開就是明細',
              style: TextStyle(fontSize: 12, color: C.muted), overflow: TextOverflow.ellipsis),
        ),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 10, children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickImages,
          child: CustomPaint(
            painter: DashedBorderPainter(),
            child: const SizedBox(
              width: 76,
              height: 76,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFAEB5C4)),
                SizedBox(height: 4),
                Text('新增', style: TextStyle(fontSize: 12, color: Color(0xFFAEB5C4))),
              ]),
            ),
          ),
        ),
        for (final img in _imgs)
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: ImageThumb(path: img.shown, size: 76, radius: 12)),
              Positioned(
                right: -6,
                top: -6,
                child: InkWell(
                  onTap: () => setState(() => _imgs.remove(img)),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4A5062)),
                    child: const Icon(Icons.close, size: 14),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    ]);
  }

  Widget _pill(String label, VoidCallback onTap, {bool muted = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3F4C)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: muted ? C.muted : C.text)),
      ),
    );
  }

  Widget _selectors() {
    final acc = _s.account(_accountId);
    final to = _s.account(_toAccountId);
    final proj = _s.project(_projectId);
    final isTransfer = _type == 'transfer';
    final left = <Widget>[
      _pill(isTransfer ? '轉出：${acc?.name ?? '請選擇'}' : (acc?.name ?? '選擇帳戶'), () => _pickAccount(target: false)),
      _pill(DateFormat('yyyy/MM/dd (E)', 'en_US').format(_ts).replaceAll(RegExp(r' \(.*\)'), ' (週${weekdayOf(_ts)})'),
          _pickDate),
    ];
    final right = <Widget>[
      isTransfer
          ? _pill('轉入：${to?.name ?? '請選擇'}', () => _pickAccount(target: true))
          : _pill(proj?.name ?? '無專案', _pickProject, muted: proj == null),
      _pill(DateFormat('HH:mm').format(_ts), _pickTime),
    ];
    return Column(children: [
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: left[i]),
            const SizedBox(width: 8),
            Expanded(child: right[i]),
          ]),
        ),
      if (!isTransfer)
        _suggestField(
          controller: _merchant,
          focus: _merchantFocus,
          options: _s.suggestMerchants,
          onPicked: _applyMerchant,
          decoration: _dec('商家（選填）'),
        ),
    ]);
  }

  Widget _sidePanel() {
    final total = evalExpr(_expr) ?? 0;
    final isExpense = _type == 'expense';
    final isTransfer = _type == 'transfer';
    final totalColor = isTransfer ? C.text : (isExpense ? C.expense : C.income);
    final totalText = isTransfer ? money(total) : '${isExpense ? '-' : '+'}${money(total)}';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F222A),
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
        border: Border(left: BorderSide(color: Color(0xFF2B2F3A))),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('金額', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: C.muted),
            onPressed: () => _press('C'),
            child: const Text('重置'),
          ),
        ]),
        const SizedBox(height: 6),
        Panel(
          color: C.modal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(children: [
            Row(children: [
              const Text('金額', style: TextStyle(fontSize: 15)),
              const Spacer(),
              Text(_expr.isEmpty ? '0' : _expr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
            const Divider(height: 18, color: C.line),
            Row(children: [
              const Text('總額', style: TextStyle(fontSize: 15)),
              const Spacer(),
              Text(totalText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: totalColor)),
            ]),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: C.expense, fontSize: 13)),
          ),
        const SizedBox(height: 12),
        Panel(
          color: C.modal,
          padding: const EdgeInsets.all(10),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.45,
            children: [for (final k in _keys) _key(k)],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isTransfer ? '常用帳戶（轉出）' : '常用帳戶',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Panel(
                color: C.modal,
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  for (final a in _s.accounts)
                    _listItem(a.name, _accountId == a.id, () => setState(() => _accountId = a.id)),
                ]),
              ),
              if (!isTransfer) ...[
                const SizedBox(height: 16),
                const Text('常用專案', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Panel(
                  color: C.modal,
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    _listItem('無專案', _projectId == null, () => setState(() => _projectId = null)),
                    for (final p in _s.projects)
                      _listItem(p.name, _projectId == p.id, () => setState(() => _projectId = p.id)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _listItem(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E3A4E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: selected ? C.accent : Colors.transparent, width: 3)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  Widget _key(String k) {
    final isCheck = k == '✓';
    final isOp = _ops.contains(k) || k == '⌫' || k == 'C' || k == '=';
    return Material(
      color: isCheck ? C.accent : (isOp ? C.line : C.raised),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _press(k),
        child: Center(
          child: Text(k,
              style: TextStyle(
                fontSize: isOp || isCheck ? 22 : 24,
                color: isCheck ? C.onAccent : C.text,
              )),
        ),
      ),
    );
  }
}
