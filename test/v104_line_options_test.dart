import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/models/models.dart';

import 'support/harness.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mitsumori_v104_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('old lines and profiles read the same and write the same', () {
    final old = {
      'name': 'クロス張替え',
      'quantity': 2.0,
      'unit': 'm²',
      'unitPrice': 1200,
      'taxRate': 'ten',
    };
    final line = DocLine.fromJson(old);
    expect(line.workDate, isNull);
    expect(line.detail, '');
    expect(line.toJson(), old);

    final profile = BusinessProfile.fromJson({'name': '山田内装'});
    expect(profile.representative, '');
    expect(profile.toJson().containsKey('representative'), isFalse);
  });

  test('施工日 and 施工内容 round-trip', () {
    const line = DocLine(
      name: '横浜市港北区○○1-2-3',
      quantity: 5,
      unit: '人工',
      unitPrice: 20000,
      taxRate: TaxRate.ten,
      workDate: '2026-11-19',
      detail: '内装下地',
    );
    final back = DocLine.fromJson(line.toJson());
    expect(back.workDate, '2026-11-19');
    expect(back.worked, DateTime(2026, 11, 19));
    expect(back.detail, '内装下地');
    expect(back.copyWith(clearWorkDate: true).workDate, isNull);
  });

  test('line label and representative persist; default is 項目', () async {
    var c = await openController(directory);
    expect(c.lineLabel, LineLabel.item);
    expect(c.lineLabel.heading, '品目・内容');
    await c.setLineLabel(LineLabel.site);
    await c.saveProfile(
      const BusinessProfile(name: '合同会社 山田内装', representative: '代表 山田 太郎'),
    );
    c.dispose();
    c = await openController(directory);
    expect(c.lineLabel, LineLabel.site);
    expect(c.profile.representative, '代表 山田 太郎');
    c.dispose();
  });

  test('PDF renders with 月日 / 施工内容 columns and 2-line issuer', () async {
    final c = await openController(directory, premium: true);
    await c.setLineLabel(LineLabel.site);
    await c.saveProfile(
      const BusinessProfile(
        name: '合同会社 山田内装',
        representative: '代表 山田 太郎',
        registrationNumber: 'T1234567890123',
        bank: '○○銀行 港北支店 普通 1234567 ヤマダナイソウ',
      ),
    );
    final doc = await seedEstimate(c);
    final dated = doc.copyWith(
      lines: [
        doc.lines.first.copyWith(workDate: '2026-11-19', detail: '内装下地'),
        doc.lines.last,
      ],
    );
    final bytes = await c.pdfBytesFor(dated);
    expect(bytes.length, greaterThan(1000));
    final out = Platform.environment['MITSU_PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
    c.dispose();
  });
}
