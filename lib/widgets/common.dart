import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';

// ---------- 圖示與色票 ----------

const Map<String, IconData> kIcons = {
  'restaurant': Icons.ramen_dining_outlined,
  'bus': Icons.directions_bus_outlined,
  'movie': Icons.movie_outlined,
  'bag': Icons.shopping_bag_outlined,
  'person': Icons.person_outline,
  'medical': Icons.medical_services_outlined,
  'home': Icons.home_outlined,
  'family': Icons.groups_outlined,
  'bulb': Icons.lightbulb_outline,
  'book': Icons.menu_book_outlined,
  'salary': Icons.payments_outlined,
  'gift': Icons.card_giftcard_outlined,
  'invest': Icons.trending_up,
  'savings': Icons.savings_outlined,
  'coffee': Icons.local_cafe_outlined,
  'car': Icons.directions_car_outlined,
  'phone': Icons.smartphone,
  'flight': Icons.flight_outlined,
  'pet': Icons.pets_outlined,
  'game': Icons.sports_esports_outlined,
  'fitness': Icons.fitness_center,
};

IconData iconFor(String key) => kIcons[key] ?? Icons.category_outlined;

const List<int> kPalette = [
  0xFFF2B84B, 0xFF5BA8F5, 0xFFA98BFF, 0xFFF07A9A, 0xFFB9BA9E, 0xFFFF6B5E,
  0xFF6C8CD5, 0xFFE3B5DB, 0xFF7FD18B, 0xFFFF9A4D, 0xFFE3C15A, 0xFF58C4A8,
];

// ---------- 小工具 ----------

/// 把「12+3×4」這類運算式算出結果；不完整時盡量容錯，空字串回傳 null。
double? evalExpr(String s) {
  final nums = <double>[];
  final ops = <String>[];
  var buf = '';
  for (final ch in s.split('')) {
    if ('+−×÷'.contains(ch)) {
      if (buf.isEmpty) continue;
      nums.add(double.tryParse(buf) ?? 0);
      buf = '';
      ops.add(ch);
    } else {
      buf += ch;
    }
  }
  if (buf.isNotEmpty) nums.add(double.tryParse(buf) ?? 0);
  if (nums.isEmpty) return null;
  while (ops.length > nums.length - 1) {
    ops.removeLast();
  }
  final n2 = <double>[nums[0]];
  final o2 = <String>[];
  for (var i = 0; i < ops.length; i++) {
    final next = nums[i + 1];
    if (ops[i] == '×') {
      n2[n2.length - 1] = n2.last * next;
    } else if (ops[i] == '÷') {
      if (next == 0) return null;
      n2[n2.length - 1] = n2.last / next;
    } else {
      o2.add(ops[i]);
      n2.add(next);
    }
  }
  var r = n2[0];
  for (var i = 0; i < o2.length; i++) {
    r = o2[i] == '+' ? r + n2[i + 1] : r - n2[i + 1];
  }
  return (r * 100).round() / 100;
}

class Opt<T> {
  final T value;
  final String label;
  const Opt(this.value, this.label);
}

Future<T?> pickFrom<T>(BuildContext context, String title, List<Opt<T>> options, {T? current}) {
  return showDialog<T>(
    context: context,
    builder: (c) => SimpleDialog(
      backgroundColor: C.modal,
      title: Text(title),
      children: [
        for (final o in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, o.value),
            child: Row(children: [
              Expanded(child: Text(o.label, style: const TextStyle(fontSize: 15))),
              if (o.value == current) const Icon(Icons.check, color: C.accent, size: 18),
            ]),
          ),
      ],
    ),
  );
}

Future<String?> askText(BuildContext context, String title, {String hint = '', String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: C.modal,
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('確定')),
      ],
    ),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, {String? body, String okLabel = '確定'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: C.modal,
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.expense, foregroundColor: C.dark),
          onPressed: () => Navigator.pop(c, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

// ---------- 版面元件 ----------

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = C.panel,
    this.radius = 16,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
  }
}

class PanelTitle extends StatelessWidget {
  const PanelTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      if (trailing != null) trailing!,
    ]);
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class SquareButton extends StatelessWidget {
  const SquareButton({super.key, required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: const Color(0xFF242832),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: C.text)),
        ),
      ),
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final m = state.month;
    final last = DateTime(m.year, m.month + 1, 0);
    final f = DateFormat('yyyy/MM/dd');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SquareButton(icon: Icons.chevron_left, tooltip: '上個月', onTap: () => state.shiftMonth(-1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('${f.format(m)} — ${f.format(last)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ),
      SquareButton(icon: Icons.chevron_right, tooltip: '下個月', onTap: () => state.shiftMonth(1)),
    ]);
  }
}

class CatAvatar extends StatelessWidget {
  const CatAvatar({super.key, this.cat, this.size = 36, this.transfer = false});
  final Category? cat;
  final double size;
  final bool transfer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: transfer ? const Color(0xFF5B6275) : Color(cat?.color ?? 0xFF666666),
      ),
      child: Icon(
        transfer ? Icons.swap_horiz : iconFor(cat?.icon ?? ''),
        size: size * 0.55,
        color: transfer ? C.text : C.dark,
      ),
    );
  }
}

/// 附圖縮圖
class ImageThumb extends StatelessWidget {
  const ImageThumb({super.key, required this.path, this.size = 30, this.radius = 6});
  final String path;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: C.raised,
          child: Icon(Icons.broken_image_outlined, size: size * 0.5, color: C.muted),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({this.color = const Color(0xFF5B6275), this.radius = 12});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) => old.color != color || old.radius != radius;
}

/// 一列記錄（總覽、月曆當日、記錄頁共用）
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.entry,
    required this.state,
    required this.onTap,
    this.showDate = true,
  });
  final Entry entry;
  final AppState state;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final cat = state.category(e.categoryId);
    final acc = state.account(e.accountId);
    final title = e.title.isNotEmpty ? e.title : (e.isTransfer ? '轉帳' : (cat?.name ?? ''));
    final parts = <String>[DateFormat(showDate ? 'MM/dd HH:mm' : 'HH:mm').format(e.ts)];
    if (e.isTransfer) {
      parts.add('${acc?.name ?? ''} → ${state.account(e.toAccountId)?.name ?? ''}');
    } else {
      if (cat != null) parts.add(cat.name);
      if (acc != null) parts.add(acc.name);
    }
    final String amountText;
    final Color amountColor;
    if (e.isExpense) {
      amountText = '-${money(e.amount)}';
      amountColor = C.expense;
    } else if (e.isIncome) {
      amountText = '+${money(e.amount)}';
      amountColor = C.income;
    } else {
      amountText = money(e.amount);
      amountColor = C.text;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(children: [
          CatAvatar(cat: cat, transfer: e.isTransfer, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(parts.join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
          if (e.images.isNotEmpty) ...[
            ImageThumb(path: e.images.first),
            if (e.images.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('+${e.images.length - 1}', style: const TextStyle(fontSize: 12, color: C.muted)),
              ),
            const SizedBox(width: 10),
          ],
          Text(amountText, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: amountColor)),
        ]),
      ),
    );
  }
}

/// 一條橫向比例條（報表、專案、帳戶用）
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
    this.sub,
  });
  final String label;
  final String? sub;
  final String amount;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: label, style: const TextStyle(fontSize: 14)),
                if (sub != null) TextSpan(text: '  $sub', style: const TextStyle(fontSize: 12, color: C.muted)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(amount, style: const TextStyle(fontSize: 14)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 7, color: C.raised),
            FractionallySizedBox(widthFactor: f, child: Container(height: 7, color: color)),
          ]),
        ),
      ]),
    );
  }
}
