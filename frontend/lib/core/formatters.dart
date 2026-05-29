/// 格式化金额 - 参考支付宝/招商银行
String formatAmount(double amount) {
  if (amount.abs() >= 100000000) {
    return '¥${(amount / 100000000).toStringAsFixed(2)}亿';
  } else if (amount.abs() >= 10000) {
    return '¥${(amount / 10000).toStringAsFixed(2)}万';
  }
  return '¥${amount.toStringAsFixed(2)}';
}

/// 格式化百分比
String formatPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${(value * 100).toStringAsFixed(2)}%';
}

/// 格式化日期
String formatDate(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final date = DateTime.parse(isoDate);
    return '${date.month}月${date.day}日';
  } catch (e) {
    return isoDate;
  }
}

/// 格式化完整日期
String formatFullDate(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final date = DateTime.parse(isoDate);
    return '${date.year}年${date.month}月${date.day}日';
  } catch (e) {
    return isoDate;
  }
}

/// 相对时间
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

/// 资产用途中文名
String utilityLabel(String utility) {
  switch (utility) {
    case 'productive': return '投资';
    case 'consumable': return '消耗品';
    case 'protective': return '保护';
    case 'speculative': return '投机';
    case 'lifestyle': return '生活';
    case 'essential': return '必需';
    default: return utility;
  }
}

/// 负债类型中文名
String liabilityTypeLabel(String type) {
  switch (type) {
    case 'mortgage': return '房贷';
    case 'auto_loan': return '车贷';
    case 'credit_card': return '信用卡';
    case 'consumer_loan': return '消费贷';
    case 'personal_loan': return '个人借款';
    default: return type;
  }
}
