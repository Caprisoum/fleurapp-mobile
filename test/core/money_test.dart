import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/core/money.dart';

void main() {
  test('convertit les montants sans virgule flottante', () {
    expect(moneyToCents('12.34'), 1234);
    expect(moneyToCents('12,3'), 1230);
    expect(centsToApiDecimal(1234), '12.34');
    expect(formatEuroCents(1234), '12,34\u00a0€');
  });

  test('refuse les fractions de centime et les valeurs négatives', () {
    expect(() => moneyToCents('1.005'), throwsFormatException);
    expect(() => moneyToCents('-1'), throwsFormatException);
    expect(() => moneyToCents('NaN'), throwsFormatException);
  });
}
