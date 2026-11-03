class Category {
  final int id;
  final String name;
  final String type; // expense | income
  final int color;
  final String icon;
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
  });
}

class Account {
  final int id;
  final String name;
  final String group; // 現金 | 銀行 | 信用卡 | 投資
  final double initial;
  const Account({required this.id, required this.name, required this.group, this.initial = 0});
}

class Project {
  final int id;
  final String name;
  const Project({required this.id, required this.name});
}

class Entry {
  final int? id;
  final String type; // expense | income | transfer
  final double amount;
  final String title;
  final int? categoryId;
  final int? accountId;
  final int? toAccountId;
  final int? projectId;
  final String? merchant;
  final String? note;
  final DateTime ts;
  final List<String> images;

  const Entry({
    this.id,
    required this.type,
    required this.amount,
    this.title = '',
    this.categoryId,
    this.accountId,
    this.toAccountId,
    this.projectId,
    this.merchant,
    this.note,
    required this.ts,
    this.images = const [],
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isTransfer => type == 'transfer';

  Entry withImages(List<String> paths) => Entry(
        id: id,
        type: type,
        amount: amount,
        title: title,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        projectId: projectId,
        merchant: merchant,
        note: note,
        ts: ts,
        images: paths,
      );
}
