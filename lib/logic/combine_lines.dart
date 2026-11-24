import '../format.dart';
import '../models/models.dart';

/// Optional tidy-up (never automatic): joins lines with the same 現場・住所
/// and the same work — same 品目, 施工内容, 単位, 単価 and 税率 — into one line.
/// Their 施工日 are merged (no duplicates) and the 数量 added up. Lines that
/// differ in any of those stay separate, in their first position. Amounts
/// never change: 数量×単価 of the joined line equals the sum of the parts.
List<DocLine> combineLines(List<DocLine> lines) {
  String key(DocLine l) => [
    collapseWhitespace(l.name),
    collapseWhitespace(l.detail),
    collapseWhitespace(l.site),
    collapseWhitespace(l.unit),
    l.unitPrice,
    l.taxRate.key,
  ].join('\u0001');

  final order = <String>[];
  final groups = <String, List<DocLine>>{};
  for (final l in lines) {
    final k = key(l);
    groups.putIfAbsent(k, () {
      order.add(k);
      return [];
    }).add(l);
  }
  final out = <DocLine>[];
  for (final k in order) {
    final group = groups[k]!;
    if (group.length == 1) {
      out.add(group.first);
      continue;
    }
    final days = <DateTime>{for (final l in group) ...l.workedDays};
    if (days.length > 62) {
      out.addAll(group); // too many 施工日 for one line; keep as they were
      continue;
    }
    final qty = group.fold<double>(0, (s, l) => s + l.quantity);
    final (first, all) = DocLine.datesFrom(days);
    out.add(
      DocLine(
        name: group.first.name,
        quantity: (qty * 1000).round() / 1000,
        unit: group.first.unit,
        unitPrice: group.first.unitPrice,
        taxRate: group.first.taxRate,
        workDate: first,
        workDates: all,
        detail: group.first.detail,
        site: group.first.site,
      ),
    );
  }
  return out;
}
