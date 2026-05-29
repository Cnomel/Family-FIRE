import 'package:flutter_test/flutter_test.dart';
import 'package:family_fire_app/utils/formatters.dart';

void main() {
  test('Currency format', () {
    expect(formatAmount(1234.56), '¥1,234.56');
    expect(formatAmount(12345678), '¥1234.57万');
    expect(formatAmount(1234567890), '¥12.35亿');
  });

  test('Date format', () {
    expect(formatDate('2026-05-29T00:00:00'), '2026年5月29日');
  });
}
