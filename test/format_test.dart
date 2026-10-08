import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/format.dart';

void main() {
  test('yen and quantity parsing accept full-width input', () {
    expect(parseYen('１２，０００円'), 12000);
    expect(parseYen('¥22,000'), 22000);
    expect(parseYen('-5000'), -5000);
    expect(parseYen(''), isNull);
    expect(parseYen('1.5'), isNull);
    expect(parseQuantity('２．５'), 2.5);
    expect(parseQuantity('1,200'), 1200);
    expect(parseQuantity(''), isNull);
  });

  test('formatting', () {
    expect(formatYen(1234567), '¥1,234,567');
    expect(formatYen(-500), '-¥500');
    expect(formatQuantity(3), '3');
    expect(formatQuantity(42.5), '42.5');
    expect(formatQuantity(1.25), '1.25');
    expect(formatQuantity(1200), '1,200');
    expect(formatDate(DateTime(2026, 10, 8)), '2026年10月8日');
    expect(formatShortDate(DateTime(2026, 10, 8)), '10/8（木）');
    expect(formatSlashDate(DateTime(2026, 1, 5)), '2026/01/05');
  });

  test('registration number is T plus 13 digits', () {
    expect(normalizeRegistrationNumber(''), '');
    expect(normalizeRegistrationNumber('T1234567890123'), 'T1234567890123');
    expect(normalizeRegistrationNumber('ｔ１２３４-５６７８-９０１２３'), 'T1234567890123');
    expect(normalizeRegistrationNumber('t 1234 5678 90123'), 'T1234567890123');
    expect(normalizeRegistrationNumber('1234567890123'), isNull);
    expect(normalizeRegistrationNumber('T123456789012'), isNull);
    expect(normalizeRegistrationNumber('T12345678901234'), isNull);
  });

  test('due date helpers', () {
    expect(endOfNextMonth(DateTime(2026, 10, 8)), DateTime(2026, 11, 30));
    expect(endOfNextMonth(DateTime(2026, 12, 31)), DateTime(2027, 1, 31));
    expect(endOfNextMonth(DateTime(2027, 1, 15)), DateTime(2027, 2, 28));
  });

  test('file names drop characters the share sheet rejects', () {
    expect(
      documentFileName(
        kindLabel: '請求書',
        number: 'INV-2026-012',
        customer: '山田 工務店/本社',
        extension: 'pdf',
      ),
      '請求書_INV-2026-012_山田工務店_本社.pdf',
    );
  });
}
