import 'package:flutter/material.dart';

import '../format.dart';
import '../models/models.dart';
import '../state/app_controller.dart';
import '../theme.dart';

/// Result of [askAddToExisting]: add to [invoice], or make a new one.
class AddChoice {
  const AddChoice.existing(Doc this.invoice);
  const AddChoice.newInvoice() : invoice = null;

  final Doc? invoice;
}

String _docLine(AppController c, Doc d) =>
    '${d.number}　${formatShortDate(d.issued)}　${formatYen(c.totalsFor(d).total)}'
    '（明細${d.lines.length}行）';

/// Asks whether to add to an 未送付 請求書 of the same 取引先 this month.
/// Returns null when cancelled.
Future<AddChoice?> askAddToExisting(
  BuildContext context,
  AppController controller,
  List<Doc> open, {
  required String customerName,
}) {
  return showDialog<AddChoice>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('add-to-existing-dialog'),
      title: const Text('同じ月の請求書があります'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$customerName あての未送付の請求書があります。今回の明細を、その請求書に追加できます（1枚の請求書にまとまり、日付・現場ごとの行はそのまま残ります）。',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 12),
            for (final d in open) ...[
              FilledButton(
                key: Key('add-to-${d.id}'),
                onPressed: () => Navigator.pop(context, AddChoice.existing(d)),
                child: Text('${d.number} に追加する'),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(
                  _docLine(controller, d),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ),
            ],
            OutlinedButton(
              key: const Key('add-as-new'),
              onPressed: () =>
                  Navigator.pop(context, const AddChoice.newInvoice()),
              child: const Text('別の請求書として新しく作る'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    ),
  );
}

/// Lets the user pick which 請求書 to fold into [keep]. All are checked at
/// first. Returns null when cancelled.
Future<List<String>?> pickInvoicesToMerge(
  BuildContext context,
  AppController controller,
  Doc keep,
  List<Doc> candidates,
) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MergeSheet(
      controller: controller,
      keep: keep,
      candidates: candidates,
    ),
  );
}

class _MergeSheet extends StatefulWidget {
  const _MergeSheet({
    required this.controller,
    required this.keep,
    required this.candidates,
  });

  final AppController controller;
  final Doc keep;
  final List<Doc> candidates;

  @override
  State<_MergeSheet> createState() => _MergeSheetState();
}

class _MergeSheetState extends State<_MergeSheet> {
  late final Set<String> _picked = {for (final d in widget.candidates) d.id};

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '請求書を1枚にまとめる',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '選んだ請求書の明細を ${widget.keep.number} に移して、1枚にします。移したあとの請求書は一覧から消えます。明細の行は日付・現場・住所ごとにそのまま残ります（金額は変わりません）。',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 8),
            for (final d in widget.candidates)
              CheckboxListTile(
                key: Key('merge-${d.id}'),
                contentPadding: EdgeInsets.zero,
                value: _picked.contains(d.id),
                onChanged: (v) => setState(
                  () => v == true ? _picked.add(d.id) : _picked.remove(d.id),
                ),
                title: Text(d.number),
                subtitle: Text(_docLine(c, d)),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('merge-confirm'),
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, _picked.toList()),
              child: Text('${widget.keep.number} にまとめる'),
            ),
          ],
        ),
      ),
    );
  }
}
