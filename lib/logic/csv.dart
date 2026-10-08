import '../format.dart';
import '../models/models.dart';
import 'totals.dart';

String _cell(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(RegExp(r'[",\n\r]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// One row per document, with the tax split per rate. Starts with a BOM so
/// Excel opens the Japanese text correctly.
String documentsAsCsv(List<Doc> documents) {
  final buffer = StringBuffer('\uFEFF');
  const header = [
    '種類',
    '番号',
    '発行日',
    '取引先',
    '件名',
    '10%対象',
    '消費税(10%)',
    '8%対象',
    '消費税(8%)',
    '非課税',
    '合計（税込）',
    '状態',
    '期限',
    '入金日',
  ];
  buffer.write('${header.join(',')}\r\n');
  for (final d in documents) {
    final totals = computeTotals(d.lines);
    final ten = totals.bucketFor(TaxRate.ten);
    final eight = totals.bucketFor(TaxRate.eight);
    final exempt = totals.bucketFor(TaxRate.exempt);
    final row = [
      d.kind.label,
      d.number,
      formatSlashDate(d.issued),
      '${d.customerName} ${d.honorific}',
      d.title,
      ten?.base ?? 0,
      ten?.tax ?? 0,
      eight?.base ?? 0,
      eight?.tax ?? 0,
      exempt?.base ?? 0,
      totals.total,
      d.status.label,
      d.due == null ? '' : formatSlashDate(d.due!),
      d.paidDate == null ? '' : formatSlashDate(parseDayKey(d.paidDate!)),
    ];
    buffer.write('${row.map(_cell).join(',')}\r\n');
  }
  return buffer.toString();
}
