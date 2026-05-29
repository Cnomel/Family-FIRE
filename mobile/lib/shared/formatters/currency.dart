class CurrencyFormatter {
  static String format(double amount, {String symbol = '¥', bool showSign = false}) {
    final sign = showSign && amount > 0 ? '+' : '';
    if (amount.abs() >= 100000000) {
      return '$sign$symbol${(amount / 100000000).toStringAsFixed(2)}亿';
    } else if (amount.abs() >= 10000) {
      return '$sign$symbol${(amount / 10000).toStringAsFixed(2)}万';
    }
    return '$sign$symbol${amount.toStringAsFixed(2)}';
  }

  static String formatPercent(double value, {bool showSign = true}) {
    final sign = showSign && value > 0 ? '+' : '';
    return '$sign${(value * 100).toStringAsFixed(2)}%';
  }

  static String formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return formatDate(date);
  }
}
