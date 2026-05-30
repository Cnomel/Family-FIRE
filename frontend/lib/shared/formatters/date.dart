/// 2024年1月15日 星期一
String formatDateChinese(DateTime date) {
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '${date.year}年${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
}

/// 2024-01-15
String formatDateShort(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 1月15日
String formatDateMonthDay(DateTime date) {
  return '${date.month}月${date.day}日';
}

/// 5分钟前、1小时前、昨天
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays == 1) return '昨天';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}周前';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
  return '${(diff.inDays / 365).floor()}年前';
}

/// 2024年1月
String formatYearMonth(DateTime date) {
  return '${date.year}年${date.month}月';
}
