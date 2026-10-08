const _weekdays = ['月', '火', '水', '木', '金', '土', '日'];

/// Calendar day as `YYYY-MM-DD`. Dates are stored as this string so a time
/// zone change on the phone never moves an issue date or a due date.
String dayKey(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseDayKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) throw FormatException('日付の形式が不正です: $key');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime firstOfMonth(DateTime value) => DateTime(value.year, value.month);

DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// Last day of the month after [issued], the usual 翌月末 due date.
DateTime endOfNextMonth(DateTime issued) =>
    DateTime(issued.year, issued.month + 2, 0);

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

String weekdayLabel(DateTime value) => _weekdays[value.weekday - 1];

String formatMonth(DateTime month) => '${month.year}年${month.month}月';

/// `2026年10月8日`
String formatDate(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';

/// `2026年10月8日（木）`
String formatJapaneseDate(DateTime value) =>
    '${formatDate(value)}（${weekdayLabel(value)}）';

/// `10/8（木）`
String formatShortDate(DateTime value) =>
    '${value.month}/${value.day}（${weekdayLabel(value)}）';

/// `2026/10/08`, for CSV.
String formatSlashDate(DateTime value) {
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '${value.year}/$m/$d';
}

String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 18000 -> `¥18,000`.
String formatYen(int yen) {
  final negative = yen < 0;
  return '${negative ? '-' : ''}¥${_groupDigits(yen.abs().toString())}';
}

/// 18000 -> `18,000`.
String formatNumber(int value) {
  final negative = value < 0;
  return '${negative ? '-' : ''}${_groupDigits(value.abs().toString())}';
}

/// 1.0 -> `1`, 2.5 -> `2.5`, 12.25 -> `12.25`, 1200 -> `1,200`.
String formatQuantity(double value) {
  final rounded = (value * 100).round() / 100;
  final whole = rounded.truncate();
  final fraction = (rounded - whole).abs();
  final head = formatNumber(whole);
  if (fraction < 0.0001) return head;
  final tail = fraction
      .toStringAsFixed(2)
      .substring(1)
      .replaceAll(RegExp(r'0+$'), '');
  return '$head$tail';
}

String collapseWhitespace(String input) {
  return input.replaceAll(RegExp(r'[ \t\u3000]+'), ' ').trim();
}

String _halfWidthDigits(String input) {
  return input.replaceAllMapped(
    RegExp('[０-９．]'),
    (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0),
  );
}

/// Parses `18,000` / `１８０００` / `18000円` into yen. Null when empty or not
/// a whole number.
int? parseYen(String input) {
  final normalized = _halfWidthDigits(input)
      .replaceAll(RegExp(r'[,，円¥￥\s]'), '');
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized);
}

/// Parses `2` / `２．５` / `1,200` into a quantity. Null when empty.
double? parseQuantity(String input) {
  final normalized = _halfWidthDigits(input).replaceAll(RegExp(r'[,，\s]'), '');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Normalizes an 適格請求書発行事業者 登録番号 to `T` + 13 digits.
/// Accepts full-width characters, a lower-case t, hyphens and spaces.
/// Returns '' for empty input and null when it is not a valid number.
String? normalizeRegistrationNumber(String input) {
  final text = _halfWidthDigits(input)
      .replaceAll(RegExp(r'[\s\-－ー‐]'), '')
      .replaceAll('Ｔ', 'T')
      .replaceAll('t', 'T')
      .replaceAll('ｔ', 'T');
  if (text.isEmpty) return '';
  if (!RegExp(r'^T\d{13}$').hasMatch(text)) return null;
  return text;
}

/// File name for the share sheet, for example `請求書_INV-2026-012_山田工務店.pdf`.
String documentFileName({
  required String kindLabel,
  required String number,
  required String customer,
  required String extension,
}) {
  final safeCustomer = customer
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final tail = safeCustomer.isEmpty ? '' : '_$safeCustomer';
  return '${kindLabel}_$number$tail.$extension';
}
