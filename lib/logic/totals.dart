import '../models/models.dart';

/// 税率ごとの対象額と消費税額.
class TaxBucket {
  const TaxBucket({required this.rate, required this.base, required this.tax});

  final TaxRate rate;

  /// Sum of line amounts at this rate, without tax.
  final int base;

  /// One rounding (切り捨て) per rate per document, as the インボイス制度
  /// requires.
  final int tax;
}

class DocTotals {
  const DocTotals({required this.buckets});

  /// Present rates only, in the order 10%, 8%, 非課税.
  final List<TaxBucket> buckets;

  int get subtotal => buckets.fold(0, (sum, b) => sum + b.base);

  int get tax => buckets.fold(0, (sum, b) => sum + b.tax);

  int get total => subtotal + tax;

  bool get hasReducedRate => buckets.any((b) => b.rate == TaxRate.eight);

  TaxBucket? bucketFor(TaxRate rate) {
    for (final b in buckets) {
      if (b.rate == rate) return b;
    }
    return null;
  }
}

/// Floors toward zero so a negative (値引き) base never rounds up the tax.
int taxFor(int base, TaxRate rate) {
  if (rate.percent == 0) return 0;
  final magnitude = base.abs() * rate.percent ~/ 100;
  return base < 0 ? -magnitude : magnitude;
}

DocTotals computeTotals(Iterable<DocLine> lines) {
  final bases = <TaxRate, int>{};
  for (final line in lines) {
    bases[line.taxRate] = (bases[line.taxRate] ?? 0) + line.amount;
  }
  return DocTotals(
    buckets: [
      for (final rate in TaxRate.values)
        if (bases.containsKey(rate))
          TaxBucket(
            rate: rate,
            base: bases[rate]!,
            tax: taxFor(bases[rate]!, rate),
          ),
    ],
  );
}
