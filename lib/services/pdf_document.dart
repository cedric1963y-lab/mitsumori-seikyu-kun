import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../format.dart';
import '../logic/totals.dart';
import '../models/models.dart';

const _ink = PdfColor.fromInt(0xFF1B1F24);
const _muted = PdfColor.fromInt(0xFF5B6470);
const _line = PdfColor.fromInt(0xFFBFC5CC);
const _head = PdfColor.fromInt(0xFFEDEFF2);
const _accent = PdfColor.fromInt(0xFF2B3A42);

/// 見積書 / 請求書 on A4 portrait, laid out the way Japanese businesses
/// expect: title, addressee on the left, issuer and 登録番号 on the right,
/// the total in a box, a line table, totals per tax rate (インボイス制度),
/// then 振込先 and 備考. The font is subset to the glyphs used.
Future<Uint8List> buildDocumentPdf({
  required ByteData fontData,
  required ByteData boldFontData,
  required Doc doc,
  required DocTotals totals,
  required BusinessProfile profile,
  Uint8List? seal,
  String? footer,
}) async {
  final font = pw.Font.ttf(fontData);
  final bold = pw.Font.ttf(boldFontData);
  final theme =
      pw.ThemeData.withFont(
        base: font,
        bold: bold,
        italic: font,
        boldItalic: bold,
      ).copyWith(
        defaultTextStyle: pw.TextStyle(font: font, fontSize: 9.5, color: _ink),
      );
  final document = pw.Document(
    title: '${doc.kind.label} ${doc.number}',
    author: profile.name,
    creator: 'かんたん見積・請求くん',
    theme: theme,
  );
  final sealImage = seal == null ? null : pw.MemoryImage(seal);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 34),
      theme: theme,
      footer: (context) => _footer(context, footer),
      build: (context) => [
        _title(doc),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(flex: 11, child: _addressee(doc, totals)),
            pw.SizedBox(width: 18),
            pw.Expanded(flex: 9, child: _issuer(doc, profile, sealImage)),
          ],
        ),
        pw.SizedBox(height: 18),
        _table(doc),
        pw.SizedBox(height: 10),
        _totals(totals),
        if (doc.isInvoice && profile.bank.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _box('お振込先', profile.bank),
        ],
        if (doc.note.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _box('備考', doc.note),
        ],
      ],
    ),
  );
  return document.save();
}

String _spaced(String text) => text.split('').join(' ');

pw.Widget _title(Doc doc) {
  final title = doc.kind == DocKind.estimate ? '御見積書' : '請求書';
  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Text(
            _spaced(title),
            style: pw.TextStyle(
              fontSize: 24,
              letterSpacing: 2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'No. ${doc.number}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '発行日 ${formatDate(doc.issued)}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 1.6, color: _accent),
      pw.SizedBox(height: 1.4),
      pw.Container(height: 0.6, color: _accent),
    ],
  );
}

pw.Widget _addressee(Doc doc, DocTotals totals) {
  final estimate = doc.kind == DocKind.estimate;
  final due = doc.due;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.9)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Text(
                doc.customerName,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(doc.honorific, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      ),
      if (doc.customerAddress.isNotEmpty) ...[
        pw.SizedBox(height: 3),
        pw.Text(
          doc.customerAddress,
          style: const pw.TextStyle(fontSize: 8.5, color: _muted),
        ),
      ],
      pw.SizedBox(height: 10),
      if (doc.title.isNotEmpty) ...[
        pw.Text('件名：${doc.title}', style: const pw.TextStyle(fontSize: 10.5)),
        pw.SizedBox(height: 6),
      ],
      pw.Text(
        estimate ? '下記のとおりお見積り申し上げます。' : '下記のとおりご請求申し上げます。',
        style: const pw.TextStyle(fontSize: 9.5),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _accent, width: 1.2),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              estimate ? 'お見積金額\n（税込）' : 'ご請求金額\n（税込）',
              style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Text(
                '${formatYen(totals.total)} -',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      if (due != null) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          '${estimate ? '有効期限' : 'お支払期限'}：${formatDate(due)}',
          style: const pw.TextStyle(fontSize: 9.5),
        ),
      ],
    ],
  );
}

pw.Widget _issuer(Doc doc, BusinessProfile profile, pw.ImageProvider? seal) {
  final rows = <pw.Widget>[
    pw.Text(
      profile.name.isEmpty ? '（自社情報を設定してください）' : profile.name,
      style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    if (profile.postalCode.isNotEmpty)
      pw.Text(
        '〒${profile.postalCode}',
        style: const pw.TextStyle(fontSize: 8.5),
      ),
    if (profile.address.isNotEmpty)
      pw.Text(profile.address, style: const pw.TextStyle(fontSize: 8.5)),
    if (profile.phone.isNotEmpty)
      pw.Text('TEL ${profile.phone}', style: const pw.TextStyle(fontSize: 8.5)),
    if (profile.email.isNotEmpty)
      pw.Text(profile.email, style: const pw.TextStyle(fontSize: 8.5)),
    if (profile.registrationNumber.isNotEmpty) ...[
      pw.SizedBox(height: 3),
      pw.Text(
        '登録番号 ${profile.registrationNumber}',
        style: const pw.TextStyle(fontSize: 9),
      ),
    ],
  ];
  return pw.Stack(
    overflow: pw.Overflow.visible,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 28),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rows,
        ),
      ),
      if (seal != null)
        pw.Positioned(
          right: 0,
          top: 18,
          child: pw.SizedBox(
            width: 58,
            height: 58,
            child: pw.Image(seal, fit: pw.BoxFit.contain),
          ),
        ),
    ],
  );
}

pw.Widget _cell(
  String text, {
  pw.TextAlign align = pw.TextAlign.left,
  bool header = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: header ? 8.5 : 9.2,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _table(Doc doc) {
  const minRows = 8;
  String name(DocLine l) => switch (l.taxRate) {
    TaxRate.eight => '${l.name} ※',
    TaxRate.exempt => '${l.name}（非課税）',
    TaxRate.ten => l.name,
  };
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _head),
      children: [
        _cell('品目・内容', header: true),
        _cell('数量', header: true, align: pw.TextAlign.right),
        _cell('単位', header: true, align: pw.TextAlign.center),
        _cell('単価', header: true, align: pw.TextAlign.right),
        _cell('金額', header: true, align: pw.TextAlign.right),
      ],
    ),
    for (final l in doc.lines)
      pw.TableRow(
        children: [
          _cell(name(l)),
          _cell(formatQuantity(l.quantity), align: pw.TextAlign.right),
          _cell(l.unit, align: pw.TextAlign.center),
          _cell(formatNumber(l.unitPrice), align: pw.TextAlign.right),
          _cell(formatNumber(l.amount), align: pw.TextAlign.right),
        ],
      ),
    for (var i = doc.lines.length; i < minRows; i++)
      pw.TableRow(children: [for (var c = 0; c < 5; c++) _cell(' ')]),
  ];
  return pw.Table(
    border: const pw.TableBorder(
      top: pw.BorderSide(color: _ink, width: 0.9),
      bottom: pw.BorderSide(color: _ink, width: 0.9),
      left: pw.BorderSide(color: _line, width: 0.5),
      right: pw.BorderSide(color: _line, width: 0.5),
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
      verticalInside: pw.BorderSide(color: _line, width: 0.5),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(5.2),
      1: pw.FlexColumnWidth(1.1),
      2: pw.FlexColumnWidth(0.9),
      3: pw.FlexColumnWidth(1.6),
      4: pw.FlexColumnWidth(1.8),
    },
    children: rows,
  );
}

pw.Widget _totals(DocTotals totals) {
  pw.Widget row(String label, int yen, {bool strong = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      decoration: strong
          ? const pw.BoxDecoration(
              color: _head,
              border: pw.Border(top: pw.BorderSide(color: _ink, width: 0.9)),
            )
          : const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _line, width: 0.5),
              ),
            ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: strong ? 10.5 : 9,
                fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            formatYen(yen),
            style: pw.TextStyle(
              fontSize: strong ? 12 : 9.5,
              fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  final lines = <pw.Widget>[
    row('小計（税抜）', totals.subtotal),
    for (final b in totals.buckets)
      if (b.rate == TaxRate.exempt)
        row('非課税 対象', b.base)
      else ...[
        row(
          '${b.rate.percent}%${b.rate == TaxRate.eight ? '（軽減税率）' : ''} 対象',
          b.base,
        ),
        row('　消費税（${b.rate.percent}%）', b.tax),
      ],
    row('合計（税込）', totals.total, strong: true),
  ];
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: totals.hasReducedRate
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4, right: 12),
                child: pw.Text(
                  '※ は軽減税率（8%）対象です。',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
              )
            : pw.SizedBox(),
      ),
      pw.SizedBox(width: 230, child: pw.Column(children: lines)),
    ],
  );
}

pw.Widget _box(String label, String body) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line, width: 0.7),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
        pw.SizedBox(height: 3),
        pw.Text(body, style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2)),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context context, String? footer) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            footer ?? '',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ),
        if (context.pagesCount > 1)
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
      ],
    ),
  );
}
