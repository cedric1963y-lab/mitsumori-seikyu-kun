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
    expect(merged.lines.length, 3);
    expect(merged.lines.map((l) => l.workDate), ['2026-10-05', '2026-10-06', '2026-10-07']);
    expect(merged.note, '常用分');
    expect(c.totalsFor(merged).total, before);
    expect(c.documentById(second.id), isNull);
    expect(c.documentById(other.id), isNotNull);
    expect(c.documentById(paid.id)!.status, DocStatus.paid);
    expect(c.mergeCandidates(first.id), isEmpty);
    expect((await c.pdfBytesFor(merged)).length, greaterThan(1000));
    c.dispose();

    final again = await openController(directory, premium: true);
    expect(again.documentById(first.id)!.lines.length, 3);
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
    expect(updated.lines.length, 2);
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
