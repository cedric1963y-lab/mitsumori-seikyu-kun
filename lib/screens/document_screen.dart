import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../app_scope.dart';
import '../format.dart';
import '../models/models.dart';
import '../plan/limits.dart';
import '../services/share_service.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'editor_screen.dart';

/// One document: A4 PDF preview, share, status, edit, 見積→請求.
class DocumentScreen extends StatefulWidget {
  const DocumentScreen({required this.documentId, super.key});

  final String documentId;

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  String? _previewKey;
  Future<Uint8List?>? _preview;

  String _signature(AppController controller, Doc doc) {
    return jsonEncode([
      doc.toJson(),
      controller.profile.toJson(),
      controller.premium,
      controller.seal?.length ?? 0,
    ]);
  }

  Future<Uint8List?> _render(AppController controller, Doc doc) async {
    try {
      final pdf = await controller.pdfBytesFor(doc);
      await for (final page in Printing.raster(
        pdf,
        pages: const [0],
        dpi: 170,
      )) {
        return await page.toPng();
      }
    } catch (_) {
      // Sharing still works without the preview.
    }
    return null;
  }

  Future<void> _share(BuildContext buttonContext, Doc doc) async {
    final controller = AppScope.of(context);
    final origin = shareOriginOf(buttonContext);
    final ok = await guard(context, () async {
      final path = await controller.exportPdf(doc);
      await shareFile(
        path: path,
        fileName: controller.fileNameFor(doc, 'pdf'),
        mimeType: 'application/pdf',
        subject: '${doc.kind.label} ${doc.number}',
        origin: origin,
      );
    });
    if (!ok || !mounted) return;
    final current = controller.documentById(doc.id);
    if (current != null && current.status == DocStatus.unsent) {
      showSnack(
        context,
        '送ったら「送付済」にしておきましょう。',
        action: SnackBarAction(
          label: '送付済にする',
          onPressed: () => controller.setStatus(doc.id, DocStatus.sent),
        ),
      );
    }
  }

  Future<void> _convert(Doc doc) async {
    final controller = AppScope.of(context);
    Doc? invoice;
    await guard(context, () async {
      invoice = await controller.convertToInvoice(doc.id);
    });
    if (invoice == null || !mounted) return;
    showSnack(context, '請求書 ${invoice!.number} を作りました。');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DocumentScreen(documentId: invoice!.id),
      ),
    );
  }

  void _open(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DocumentScreen(documentId: id)),
    );
  }

  Future<void> _delete(Doc doc) async {
    final controller = AppScope.of(context);
    final ok = await confirmAction(
      context,
      title: '${doc.kind.label}を削除しますか？',
      body: '${doc.number}（${doc.customerName}）を削除します。元に戻せません。',
      confirmLabel: '削除',
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    final done = await guard(context, () => controller.deleteDocument(doc.id));
    if (done) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final doc = controller.documentById(widget.documentId);
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('この書類は削除されました。')),
      );
    }
    final key = _signature(controller, doc);
    if (key != _previewKey) {
      _previewKey = key;
      _preview = _render(controller, doc);
    }
    final totals = controller.totalsFor(doc);
    final estimate = doc.kind == DocKind.estimate;
    final converted = doc.convertedId == null
        ? null
        : controller.documentById(doc.convertedId!);
    final source = doc.sourceId == null
        ? null
        : controller.documentById(doc.sourceId!);

    return Scaffold(
      appBar: AppBar(
        title: Text('${doc.kind.label} ${doc.number}'),
        actions: [
          IconButton(
            key: const Key('edit-document'),
            tooltip: '編集',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditorScreen(initial: doc),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _delete(doc);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('削除')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          Panel(
            padding: const EdgeInsets.all(6),
            child: AspectRatio(
              aspectRatio: 210 / 297,
              child: FutureBuilder<Uint8List?>(
                future: _preview,
                builder: (context, snapshot) {
                  final png = snapshot.data;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (png == null) {
                    return const Center(
                      child: Text(
                        'プレビューを表示できませんでした',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }
                  return Image.memory(
                    png,
                    key: const Key('pdf-preview'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${doc.customerName} ${doc.honorific}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatYen(totals.total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              key: const Key('share-pdf'),
              onPressed: () => _share(buttonContext, doc),
              icon: const Icon(Icons.ios_share),
              label: const Text('PDFを送る（LINE・メールなど）'),
            ),
          ),
          if (estimate) ...[
            const SizedBox(height: 10),
            if (converted != null)
              OutlinedButton.icon(
                key: const Key('open-invoice'),
                onPressed: () => _open(converted.id),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text('請求書 ${converted.number} を開く'),
              )
            else
              FilledButton.icon(
                key: const Key('convert-invoice'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                ),
                onPressed: () => _convert(doc),
                icon: const Icon(Icons.receipt_long),
                label: const Text('この見積書から請求書を作る'),
              ),
          ],
          if (source != null)
            TextButton(
              onPressed: () => _open(source.id),
              child: Text('元の見積書 ${source.number} を開く'),
            ),
          const SectionTitle('状態'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<DocStatus>(
              key: const Key('status'),
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(
                  value: DocStatus.unsent,
                  label: Text('未送付'),
                ),
                const ButtonSegment(value: DocStatus.sent, label: Text('送付済')),
                if (doc.isInvoice)
                  const ButtonSegment(
                    value: DocStatus.paid,
                    label: Text('入金済'),
                  ),
              ],
              selected: {doc.status},
              onSelectionChanged: (value) => guard(
                context,
                () => controller.setStatus(doc.id, value.first),
              ),
            ),
          ),
          if (doc.status == DocStatus.paid && doc.paidDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                '入金日 ${formatDate(parseDayKey(doc.paidDate!))}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          if (!controller.premium) ...[
            const SizedBox(height: 14),
            Panel(
              color: AppColors.greySoft,
              child: InkWell(
                onTap: () => openPremium(context),
                child: const Text(
                  '無料プランのPDFには、下に小さく「${PlanLimits.freeFooter}」と入ります。プレミアムなら表示なし・印影/ロゴも入れられます。',
                  style: TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
