import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 色彩（與介面設計稿一致）
class C {
  static const bg = Color(0xFF181A20);
  static const side = Color(0xFF13151A);
  static const panel = Color(0xFF21242C);
  static const panelDeep = Color(0xFF1B1D24);
  static const raised = Color(0xFF2E323D);
  static const line = Color(0xFF343947);
  static const lineSoft = Color(0xFF2A2E38);
  static const text = Color(0xFFECEEF2);
  static const muted = Color(0xFF9AA1B0);
  static const accent = Color(0xFF58C4A8);
  static const accentDim = Color(0xFF1F3B35);
  static const onAccent = Color(0xFF0E1A17);
  static const expense = Color(0xFFFF7A6B);
  static const income = Color(0xFF8BD36B);
  static const balance = Color(0xFFB79CFF);
  static const modal = Color(0xFF262932);
  static const rightPanel = Color(0xFF1D1F26);
  static const dark = Color(0xFF12141A);
}

final NumberFormat _numFmt = NumberFormat('#,##0.##');

String fmt(double v) => _numFmt.format(v);
String money(double v) => '\$${fmt(v)}';
String signedMoney(double v) => '${v >= 0 ? '+' : '-'}\$${fmt(v.abs())}';
String plainNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

const List<String> weekdayZh = ['日', '一', '二', '三', '四', '五', '六'];
String weekdayOf(DateTime d) => weekdayZh[d.weekday % 7];

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      onPrimary: C.onAccent,
      surface: C.panel,
      onSurface: C.text,
      error: C.expense,
    ),
    fontFamilyFallback: const ['Microsoft JhengHei', 'PingFang TC', 'Noto Sans TC', 'sans-serif'],
    dividerColor: C.line,
  );
}
