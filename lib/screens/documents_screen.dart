import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../errors.dart';
import '../format.dart';
import '../models/models.dart';
import '../plan/limits.dart';
import '../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/doc_tile.dart';
import 'editor_screen.dart';
import 'profile_screen.dart';

/// 書類 tab: every 見積書 and 請求書, newest first.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _search = TextEditingController();
  var _filter = DocFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create(DocKind kind) async {
    final controller = AppScope.of(context);
    await guard(context, () async {
      final draft = controller.newDraft(kind);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditorScreen(initial: draft)),
      );
    });
  }

  Future<void> _chooseKind() async {
    final kind = await showModalBottomSheet<DocKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '新しく作る書類',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('new-estimate'),
                onPressed: () => Navigator.pop(context, DocKind.estimate),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('見積書を作る'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('new-invoice'),
                onPressed: () => Navigator.pop(context, DocKind.invoice),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('請求書を作る'),
              ),
              const SizedBox(height: 8),
              const Text(
                '見積書は、あとから1タップで請求書にできます。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind != null && mounted) await _create(kind);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final premium = controller.premium;
    final docs = controller.listDocuments(
      filter: _filter,
      query: premium ? _search.text : '',
    );
    final left = controller.freeDocumentsLeft;

    return Scaffold(
      appBar: AppBar(title: const Text('書類')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-document'),
        heroTag: null,
        onPressed: _chooseKind,
        icon: const Icon(Icons.add),
        label: const Text('新規作成'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        children: [
          _SummaryCard(controller: controller),
          if (controller.profile.isEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              color: AppColors.orangeSoft,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'はじめに、書類に印字する屋号・住所・振込先を登録しましょう。',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('setup-profile'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    ),
                    child: const Text('登録'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('search'),
            controller: _search,
            readOnly: !premium,
            onTap: premium
                ? null
                : () => openPremium(context, reason: LimitKind.history),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '番号・取引先・件名・品目で検索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: premium
                  ? (_search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close),
                          ))
                  : const Icon(Icons.lock_outline, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<DocFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: DocFilter.all, label: Text('すべて')),
                ButtonSegment(value: DocFilter.estimates, label: Text('見積書')),
                ButtonSegment(value: DocFilter.invoices, label: Text('請求書')),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          if (left != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                '無料プラン：今月あと$left件作成できます（月${PlanLimits.freeDocumentsPerMonth}件まで・見積書から請求書への変換は数えません）',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Panel(
              child: Column(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 40,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _search.text.isNotEmpty
                        ? '見つかりませんでした'
                        : 'まだ書類がありません。「新規作成」から見積書か請求書を作りましょう。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.45),
                  ),
                ],
              ),
            )
          else
            for (final doc in docs) DocTile(doc: doc),
          if (controller.hiddenDocumentCount > 0)
            Panel(
              child: InkWell(
                onTap: () => openPremium(context, reason: LimitKind.history),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '先々月以前の書類${controller.hiddenDocumentCount}件は、プレミアムで表示・検索できます。',
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final unpaid = controller.unpaidInvoices;
    final overdue = controller.overdueCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '未入金',
                  style: TextStyle(color: Color(0xFFC9D2D8), fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  formatYen(controller.unpaidTotal),
                  key: const Key('unpaid-total'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  overdue > 0
                      ? '${unpaid.length}件・うち期限超過 $overdue件'
                      : '${unpaid.length}件',
                  style: TextStyle(
                    color: overdue > 0
                        ? const Color(0xFFFFB27A)
                        : const Color(0xFFC9D2D8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 56, color: const Color(0xFF4A5A63)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${controller.now.month}月の請求',
                  style: const TextStyle(
                    color: Color(0xFFC9D2D8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatYen(controller.invoicedThisMonth),
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
