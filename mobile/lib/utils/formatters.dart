/// 格式化金额 - 参考支付宝/招商银行
/// ¥1,234.56 / ¥1.23万 / ¥1.23亿
String formatAmount(double amount) {
  if (amount.abs() >= 100000000) {
    return '¥${(amount / 100000000).toStringAsFixed(2)}亿';
  } else if (amount.abs() >= 10000) {
    return '¥${(amount / 10000).toStringAsFixed(2)}万';
  }
  return '¥${amount.toStringAsFixed(2)}';
}

/// 格式化百分比
/// +2.34% / -1.56%
String formatPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${(value * 100).toStringAsFixed(2)}%';
}

/// 格式化日期
/// 2024年1月15日
String formatDate(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final date = DateTime.parse(isoDate);
    return '${date.year}年${date.month}月${date.day}日';
  } catch (e) {
    return isoDate;
  }
}

/// 格式化短日期
/// 1月15日
String formatShortDate(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final date = DateTime.parse(isoDate);
    return '${date.month}月${date.day}日';
  } catch (e) {
    return isoDate;
  }
}

/// 格式化相对时间
/// 刚刚 / 5分钟前 / 3天前
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
    return formatShortDate(isoDate);
  } catch (e) {
    return isoDate;
  }
}

/// 资产性质中文名
String natureLabel(String nature) {
  switch (nature) {
    case 'tangible': return '实物资产';
    case 'financial': return '金融资产';
    case 'digital': return '数字资产';
    case 'service': return '服务订阅';
    case 'intangible': return '保险';
    default: return nature;
  }
}

/// 资产性质图标
String natureEmoji(String nature) {
  switch (nature) {
    case 'tangible': return '📦';
    case 'financial': return '📈';
    case 'digital': return '💻';
    case 'service': return '🎬';
    case 'intangible': return '🛡️';
    default: return '📋';
  }
}
