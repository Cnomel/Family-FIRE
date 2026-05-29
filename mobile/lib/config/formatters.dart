String formatAmount(double amount) {
  if (amount >= 100000000) {
    return '¥${(amount / 100000000).toStringAsFixed(2)}亿';
  } else if (amount >= 10000) {
    return '¥${(amount / 10000).toStringAsFixed(2)}万';
  }
  return '¥${amount.toStringAsFixed(2)}';
}

String formatDate(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final date = DateTime.parse(isoDate);
    return '${date.month}月${date.day}日';
  } catch (e) {
    return isoDate;
  }
}

String formatRelativeTime(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final date = DateTime.parse(isoDate);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return formatDate(isoDate);
  } catch (e) {
    return isoDate;
  }
}
