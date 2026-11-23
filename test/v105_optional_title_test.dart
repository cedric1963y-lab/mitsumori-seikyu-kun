import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/models/models.dart';

import 'support/harness.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mitsumori_title_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('件名 is optional: an estimate and an invoice save and print without one', () async {
    final c = await openController(directory, premium: true);
    final estimate = await seedEstimate(c);
    final blank = await c.saveDocument(estimate.copyWith(title: '   '));
    expect(blank.title, '');
    expect((await c.pdfBytesFor(blank)).length, greaterThan(1000));

    final invoice = await c.saveDocument(
      c.newDraft(DocKind.invoice).copyWith(
        customerId: estimate.customerId,
        lines: estimate.lines,
      ),
    );
    expect(invoice.title, '');
    expect((await c.pdfBytesFor(invoice)).length, greaterThan(1000));
    c.dispose();
  });

  test('a saved 件名 is kept as is', () async {
    final c = await openController(directory);
    final doc = await seedEstimate(c);
    expect(doc.title, '事務所 内装改修');
    final again = await c.saveDocument(doc);
    expect(again.title, '事務所 内装改修');
    c.dispose();
  });
}
