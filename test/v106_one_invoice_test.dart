import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/models/models.dart';
import 'package:mitsumori_seikyu/state/app_controller.dart';
import 'package:mitsumori_seikyu/widgets/forms.dart';

import 'support/harness.dart';

DocLine day(String key, int qty, {String site = '港北区○○1-2 A邸'}) => DocLine(
  name: site,
  quantity: qty.toDouble(),
  unit: '人工',
  unitPrice: 22000,
  taxRate: TaxRate.ten,
  workDate: key,
);

Future<Doc> invoice(AppController c, Customer cust, List<DocLine> lines, {String note = ''}) =>
    c.saveDocument(
      c.newDraft(DocKind.invoice).copyWith(customerId: cust.id, lines: lines, note: note),
    );

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mitsumori_v106_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('two invoices of one 取引先 merge into one, nothing lost', () async {
    final c = await openController(directory, premium: true);
    final a = await c.addCustomer(name: '山田工務店', address: '');
    final b = await c.addCustomer(name: '佐藤設備', address: '');
    final first = await invoice(c, a, [day('2026-10-05', 2), day('2026-10-06', 2)], note: '常用分');
    final second = await invoice(c, a, [day('2026-10-07', 1)], note: '常用分');
    final other = await invoice(c, b, [day('2026-10-07', 3)]);
    final paid = await invoice(c, a, [day('2026-09-30', 1)]);
    await c.setStatus(paid.id, DocStatus.paid);

    final candidates = c.mergeCandidates(first.id);
    expect(candidates.map((d) => d.id), [second.id]);
    final before = c.totalsFor(first).total + c.totalsFor(second).total;

    final merged = await c.mergeInvoices(first.id, [second.id]);
    expect(merged.number, first.number);
    // Same 現場・same 単価: one line with all its days and the 数量 added up.
    expect(merged.lines.length, 1);
    expect(merged.lines.single.workDates, ['2026-10-05', '2026-10-06', '2026-10-07']);
    expect(merged.lines.single.quantity, 5);
    expect(merged.note, '常用分');
    expect(c.totalsFor(merged).total, before);
    expect(c.documentById(second.id), isNull);
    expect(c.documentById(other.id), isNotNull);
    expect(c.documentById(paid.id)!.status, DocStatus.paid);
    expect(c.mergeCandidates(first.id), isEmpty);
    expect((await c.pdfBytesFor(merged)).length, greaterThan(1000));
    c.dispose();

    final again = await openController(directory, premium: true);
    expect(again.documentById(first.id)!.lines.single.workedDays.length, 3);
    expect(again.documentById(second.id), isNull);
    again.dispose();
  });

  test('merge refuses ids that are not unpaid invoices of the same 取引先', () async {
    final c = await openController(directory, premium: true);
    final a = await c.addCustomer(name: '山田工務店', address: '');
    final b = await c.addCustomer(name: '佐藤設備', address: '');
    final first = await invoice(c, a, [day('2026-10-05', 1)]);
    final other = await invoice(c, b, [day('2026-10-06', 1)]);
    expect(() => c.mergeInvoices(first.id, [other.id]), throwsA(anything));
    expect(c.documents.length, 2);
    c.dispose();
  });

  test('a new invoice can be added to the open one of the same month', () async {
    final c = await openController(directory, premium: true);
    final a = await c.addCustomer(name: '山田工務店', address: '');
    final first = await invoice(c, a, [day('2026-10-05', 2)]);
    final draft = c.newDraft(DocKind.invoice).copyWith(customerId: a.id, customerName: a.name, lines: [day('2026-10-08', 1)]);
    expect(c.openInvoicesLike(draft).map((d) => d.id), [first.id]);
    final updated = await c.addLinesToInvoice(first.id, draft.lines);
    expect(updated.lines.length, 1);
    expect(updated.lines.single.workDates, ['2026-10-05', '2026-10-08']);
    expect(updated.lines.single.quantity, 3);
    expect(c.documents.where((d) => d.isInvoice).length, 1);

    await c.setStatus(first.id, DocStatus.sent);
    expect(c.openInvoicesLike(draft), isEmpty, reason: 'sent invoices are not changed silently');
    c.dispose();
  });

  test('見積書 can go into an existing 請求書 and links to it', () async {
    final c = await openController(directory, premium: true);
    final est = await seedEstimate(c);
    final cust = c.customerById(est.customerId)!;
    final inv = await invoice(c, cust, [day('2026-10-02', 1)]);
    final out = await c.addEstimateToInvoice(est.id, inv.id);
    expect(out.id, inv.id);
    expect(out.lines.length, 1 + est.lines.length);
    expect(c.documentById(est.id)!.convertedId, inv.id);
    expect(c.documents.where((d) => d.isInvoice).length, 1);
    c.dispose();
  });

  test('merging moves the 見積書 link to the kept invoice', () async {
    final c = await openController(directory, premium: true);
    final est = await seedEstimate(c);
    final converted = await c.convertToInvoice(est.id);
    final cust = c.customerById(est.customerId)!;
    final keep = await invoice(c, cust, [day('2026-10-01', 1)]);
    await c.mergeInvoices(keep.id, [converted.id]);
    expect(c.documentById(est.id)!.convertedId, keep.id);
    c.dispose();
  });

  test('merging keeps each line 現場 and every 件名', () async {
    final c = await openController(directory, premium: true);
    final a = await c.addCustomer(name: '山田工務店', address: '');
    final x = await c.saveDocument(c.newDraft(DocKind.invoice).copyWith(
        customerId: a.id, title: '○○市△△ A邸', lines: [day('2026-10-05', 2, site: '○○市△△1-2 A邸')]));
    final y = await c.saveDocument(c.newDraft(DocKind.invoice).copyWith(
        customerId: a.id, title: '○○市□□ B邸', lines: [day('2026-10-06', 1, site: '○○市□□3-4 B邸')]));
    final m = await c.mergeInvoices(x.id, [y.id]);
    expect(m.lines.map((l) => l.name), ['○○市△△1-2 A邸', '○○市□□3-4 B邸']);
    expect(m.title, '○○市△△ A邸・○○市□□ B邸');
    c.dispose();
  });

  test('long 件名 that do not fit go to 備考 instead of being dropped', () async {
    final c = await openController(directory, premium: true);
    final a = await c.addCustomer(name: '山田工務店', address: '');
    final t1 = '○○市△△一丁目 共同住宅新築工事 内装仕上げ（1期）';
    final t2 = '○○市□□二丁目 店舗改装工事 内装下地・ボード（2期）';
    final x = await c.saveDocument(c.newDraft(DocKind.invoice).copyWith(
        customerId: a.id, title: t1, lines: [day('2026-10-05', 1)]));
    final m = await c.addLinesToInvoice(x.id, [day('2026-10-06', 1)], title: t2);
    expect(m.title, t1);
    expect(m.note, contains('件名：$t2'));
    expect(m.lines.single.workedDays.length, 2);
    c.dispose();
  });

  test('different 現場, 単価 or 施工内容 stay separate lines; PDF renders', () async {
    final c = await openController(directory, premium: true);
    final a = await c.addCustomer(name: '山田工務店', address: '');
    final x = await invoice(c, a, [
      day('2026-10-05', 2, site: '○○市△△1-2'),
      day('2026-10-06', 1, site: '○○市□□3-4'),
    ]);
    final y = await invoice(c, a, [
      day('2026-10-07', 1, site: '○○市△△1-2'),
      day('2026-10-07', 1, site: '○○市□□3-4').copyWith(unitPrice: 25000),
      day('2026-10-08', 1, site: '○○市□□3-4').copyWith(detail: '残工事'),
      day('2026-10-09', 2, site: '○○市□□3-4'),
    ]);
    final total = c.totalsFor(x).total + c.totalsFor(y).total;
    final m = await c.mergeInvoices(x.id, [y.id]);
    expect(m.lines.length, 4);
    final a1 = m.lines[0];
    expect(a1.name, '○○市△△1-2');
    expect(a1.workDates, ['2026-10-05', '2026-10-07']);
    expect(a1.quantity, 3);
    final b1 = m.lines[1];
    expect(b1.name, '○○市□□3-4');
    expect(b1.workDates, ['2026-10-06', '2026-10-09']);
    expect(b1.quantity, 3);
    expect(m.lines[2].unitPrice, 25000);
    expect(m.lines[3].detail, '残工事');
    expect(c.totalsFor(m).total, total);
    expect((await c.pdfBytesFor(m)).length, greaterThan(1000));
    c.dispose();
  });

  testWidgets('multi-day calendar picks several days at once', (tester) async {
    List<DateTime>? result;
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showMultiDayPicker(context, initial: [DateTime(2026, 11, 3)]);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('multi-day-2026-11-04')));
    await tester.tap(find.byKey(const Key('multi-day-2026-11-05')));
    await tester.tap(find.byKey(const Key('multi-day-2026-11-10')));
    await tester.tap(find.byKey(const Key('multi-day-2026-11-03'))); // off again
    await tester.pump();
    expect(find.textContaining('3日 選択中'), findsOneWidget);
    await tester.tap(find.byKey(const Key('multi-day-done')));
    await tester.pumpAndSettle();
    expect(result, [DateTime(2026, 11, 4), DateTime(2026, 11, 5), DateTime(2026, 11, 10)]);
  });
}
