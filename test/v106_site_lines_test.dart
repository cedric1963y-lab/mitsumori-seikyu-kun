import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/format.dart';
import 'package:mitsumori_seikyu/models/models.dart';
import 'package:mitsumori_seikyu/widgets/forms.dart';

import 'support/harness.dart';

void main() {
  test('現場・住所 is kept per line and old data still loads', () {
    const line = DocLine(
      name: '常用',
      quantity: 1,
      unit: '人工',
      unitPrice: 22000,
      taxRate: TaxRate.ten,
      workDate: '2026-11-04',
      site: '○○市△△1-2',
    );
    final back = DocLine.fromJson(line.toJson());
    expect(back.site, '○○市△△1-2');
    expect(back.workDate, '2026-11-04');
    final old = DocLine.fromJson({
      'name': '常用', 'quantity': 1, 'unit': '人工', 'unitPrice': 22000, 'taxRate': 'ten',
    });
    expect(old.site, '');
    expect(old.toJson().containsKey('site'), isFalse);
  });

  test('saving rejects a 現場・住所 longer than 60 characters; PDF has the column', () async {
    final directory = await Directory.systemTemp.createTemp('mitsumori_site_');
    addTearDown(() => directory.delete(recursive: true));
    final c = await openController(directory, premium: true);
    final a = await c.addCustomer(name: 'サンプル建設', address: '');
    DocLine l(String site, String day) => DocLine(
      name: '常用', quantity: 1, unit: '人工', unitPrice: 22000, taxRate: TaxRate.ten,
      workDate: day, site: site);
    final ok = await c.saveDocument(c.newDraft(DocKind.invoice).copyWith(
      customerId: a.id, lines: [l('○○市△△1-2', '2026-11-04'), l('○○市□□3-4', '2026-11-05')]));
    expect(ok.lines.map((x) => x.site), ['○○市△△1-2', '○○市□□3-4']);
    expect((await c.pdfBytesFor(ok)).length, greaterThan(1000));
    expect(
      () => c.saveDocument(c.newDraft(DocKind.invoice).copyWith(
        customerId: a.id, lines: [l('あ' * 61, '2026-11-06')])),
      throwsA(anything),
    );
    c.dispose();
  });

  testWidgets('new line: 住所 starts empty; several days become one line per day', (tester) async {
    LineResult? result;
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showLineSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final site = tester.widget<TextField>(find.byKey(const Key('line-site')));
    expect(site.controller!.text, '');
    await tester.enterText(find.byKey(const Key('line-name')), '常用');
    await tester.enterText(find.byKey(const Key('line-site')), '○○市△△1-2');
    await tester.enterText(find.byKey(const Key('line-price')), '22000');
    await tester.tap(find.byKey(const Key('line-work-date')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final days = [for (final d in [3, 4, 6]) DateTime(now.year, now.month, d)];
    for (final d in days) {
      await tester.tap(find.byKey(Key('multi-day-${dayKey(d)}')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('multi-day-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('line-split-days')), findsOneWidget);
    expect(find.text('数量（1日あたり）'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('line-save')));
    await tester.tap(find.byKey(const Key('line-save')));
    await tester.pumpAndSettle();
    expect(result!.lines.length, 3);
    expect(result!.lines.map((l) => l.workDate), [for (final d in days) dayKey(d)]);
    expect(result!.lines.every((l) => l.site == '○○市△△1-2' && l.quantity == 1), isTrue);
  });

  testWidgets('switch off: several days stay on one line', (tester) async {
    LineResult? result;
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showLineSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('line-name')), '常用');
    await tester.enterText(find.byKey(const Key('line-price')), '22000');
    await tester.tap(find.byKey(const Key('line-work-date')));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    await tester.tap(find.byKey(Key('multi-day-${dayKey(DateTime(now.year, now.month, 3))}')));
    await tester.tap(find.byKey(Key('multi-day-${dayKey(DateTime(now.year, now.month, 4))}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('multi-day-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('line-split-days')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('line-save')));
    await tester.tap(find.byKey(const Key('line-save')));
    await tester.pumpAndSettle();
    expect(result!.lines.length, 1);
    expect(result!.line!.workedDays.length, 2);
    expect(result!.line!.site, '');
  });
}
