import 'package:flutter_test/flutter_test.dart';
import 'package:family_fire_app/shared/formatters/currency.dart';

void main() {
  test('Currency format', () {
    expect(CurrencyFormatter.format(1234.56), '¥1,234.56');
    expect(CurrencyFormatter.format(12345678), '¥1234.57万');
    expect(CurrencyFormatter.format(1234567890), '¥12.35亿');
  });

  test('Percent format', () {
    expect(CurrencyFormatter.formatPercent(0.0633), '+6.33%');
    expect(CurrencyFormatter.formatPercent(-0.02), '-2.00%');
  });
}
