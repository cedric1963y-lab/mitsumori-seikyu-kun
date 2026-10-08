import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/logic/totals.dart';
import 'package:mitsumori_seikyu/models/models.dart';

DocLine line(double q, int price, [TaxRate rate = TaxRate.ten]) =>
    DocLine(name: 'x', quantity: q, unit: '式', unitPrice: price, taxRate: rate);

void main() {
  test('tax is computed once per rate and floored', () {
    // Rounding each line would give floor(26.64) x 3 = 78.
    // The インボイス rule rounds the rate total once: floor(79.92) = 79.
    final totals = computeTotals([
      line(1, 333, TaxRate.eight),
      line(1, 333, TaxRate.eight),
      line(1, 333, TaxRate.eight),
    ]);
    expect(totals.bucketFor(TaxRate.eight)!.base, 999);
    expect(totals.bucketFor(TaxRate.eight)!.tax, 79);
    expect(totals.total, 1078);
    expect(totals.hasReducedRate, isTrue);
  });

  test('mixed rates keep separate buckets in a fixed order', () {
    final totals = computeTotals([
      line(1, 5000, TaxRate.exempt),
      line(2.5, 22000),
      line(10, 300, TaxRate.eight),
    ]);
    expect(
      [for (final b in totals.buckets) b.rate],
      [TaxRate.ten, TaxRate.eight, TaxRate.exempt],
    );
    expect(totals.bucketFor(TaxRate.ten)!.base, 55000);
    expect(totals.bucketFor(TaxRate.ten)!.tax, 5500);
    expect(totals.bucketFor(TaxRate.eight)!.tax, 240);
    expect(totals.bucketFor(TaxRate.exempt)!.tax, 0);
    expect(totals.subtotal, 63000);
    expect(totals.tax, 5740);
    expect(totals.total, 68740);
  });

  test('line amounts round to the yen and discounts reduce the base', () {
    expect(line(42.5, 1200).amount, 51000);
    expect(line(0.333, 1000).amount, 333);
    final totals = computeTotals([line(1, 100000), line(1, -5555)]);
    expect(totals.subtotal, 94445);
    expect(totals.tax, 9444);
    expect(taxFor(-5555, TaxRate.ten), -555);
  });

  test('empty document totals to zero', () {
    final totals = computeTotals(const []);
    expect(totals.buckets, isEmpty);
    expect(totals.total, 0);
  });
}
