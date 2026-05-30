/// ¥1,234.56 / ¥1.23万 / ¥1.23亿
String formatCurrency(num amount, {bool showSign = false, String currency = '¥'}) {
  final doubleAmount = amount.toDouble();
  final prefix = showSign && doubleAmount > 0 ? '+' : '';

  if (doubleAmount.abs() >= 100000000) {
    return '$prefix$currency${(doubleAmount / 100000000).toStringAsFixed(2)}亿';
  } else if (doubleAmount.abs() >= 10000) {
    return '$prefix$currency${(doubleAmount / 10000).toStringAsFixed(2)}万';
  } else {
    return '$prefix$currency${doubleAmount.toStringAsFixed(2)}';
  }
}

/// ¥1,234 (无小数)
String formatCurrencyInt(num amount, {String currency = '¥'}) {
  final doubleAmount = amount.toDouble();
  if (doubleAmount.abs() >= 100000000) {
    return '$currency${(doubleAmount / 100000000).toStringAsFixed(2)}亿';
  } else if (doubleAmount.abs() >= 10000) {
    return '$currency${(doubleAmount / 10000).toStringAsFixed(2)}万';
  } else {
    final formatted = doubleAmount.toStringAsFixed(0);
    final buffer = StringBuffer();
    final chars = formatted.split('').reversed.toList();
    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(',');
      buffer.write(chars[i]);
    }
    return '$currency${buffer.toString().split('').reversed.join()}';
  }
}

/// 百分比格式化: 12.34%
String formatPercent(num value, {int decimals = 2}) {
  return '${value.toDouble().toStringAsFixed(decimals)}%';
}
