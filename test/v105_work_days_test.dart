import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitsumori_seikyu/format.dart';
import 'package:mitsumori_seikyu/models/models.dart';
import 'package:mitsumori_seikyu/widgets/forms.dart';

void main() {
  test('1.0.4 single-day lines read and write the same', () {
    final old = {
      'name': '現場A',
      'quantity': 5.0,
      'unit': '人工',
      'unitPrice': 25000,
      'taxRate': 'ten',
      'workDate': '2026-11-19',
    };
    final line = DocLine.fromJson(old);
    expect(line.workedDays, [DateTime(2026, 11, 19)]);
    expect(line.toJson(), old);
  });

  test('several days round-trip and keep workDate as the first day', () {
    final (first, all) = DocLine.datesFrom([
      DateTime(2026, 11, 22),
      DateTime(2026, 11, 19),
      DateTime(2026, 11, 20),
      DateTime(2026, 11, 20),
    ]);
    final line = DocLine(
      name: '現場A',
      quantity: 3,
      unit: '人工',
      unitPrice: 20000,
      taxRate: TaxRate.ten,
      workDate: first,
      workDates: all,
    );
    expect(line.workDate, '2026-11-19');
    final back = DocLine.fromJson(line.toJson());
    expect(back.workedDays.length, 3);
    expect(back.worked, DateTime(2026, 11, 19));
    expect(back.copyWith(clearWorkDate: true).workedDays, isEmpty);
    expect(back.copyWith(name: 'x').workedDays.length, 3);
  });

  test('formatWorkDays joins consecutive days', () {
    final d = [for (final x in [19, 20, 21, 22, 25]) DateTime(2026, 11, x)];
    expect(formatWorkDays(d), '11月19日〜22日、25日');
    expect(formatWorkDays(d, short: true), '11/19〜22・25');
    expect(formatWorkDays([DateTime(2026, 11, 30), DateTime(2026, 12, 1), DateTime(2026, 12, 3)]),
        '11月30日〜12月1日、3日');
    expect(formatWorkDays([DateTime(2026, 11, 19)]), '11月19日');
  });

  testWidgets('line sheet saves several 施工日', (tester) async {
    LineResult? result;
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showLineSheet(
                  context,
                  initial: const DocLine(
                    name: '現場A',
                    quantity: 3,
                    unit: '人工',
                    unitPrice: 20000,
                    taxRate: TaxRate.ten,
                    workDate: '2026-11-19',
                    workDates: ['2026-11-19', '2026-11-20', '2026-11-22'],
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('line-work-days-summary')), findsOneWidget);
    expect(find.textContaining('3日分'), findsOneWidget);
    expect(find.byKey(const Key('line-work-range')), findsOneWidget);
    await tester.ensureVisible(find.text('保存').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    expect(result?.line?.workedDays.length, 3);
  });
}
