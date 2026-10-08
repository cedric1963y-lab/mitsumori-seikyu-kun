import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../format.dart';
import '../models/models.dart';
import '../screens/document_screen.dart';
import '../theme.dart';
import 'common.dart';

/// One document in a list: badge, customer, 件名, number, amount, status.
class DocTile extends StatelessWidget {
  const DocTile({required this.doc, this.trailing, super.key});

  final Doc doc;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final total = controller.totalsFor(doc).total;
    final overdue = doc.isOverdue(controller.now);
    final due = doc.due;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: EdgeInsets.zero,
        child: InkWell(
          key: Key('doc-${doc.id}'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DocumentScreen(documentId: doc.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KindBadge(doc.kind),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${doc.customerName} ${doc.honorific}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (doc.title.isNotEmpty)
                            Text(
                              doc.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '${doc.number}・${formatShortDate(doc.issued)}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatYen(total),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StatusPill(doc.status),
                      ],
                    ),
                  ],
                ),
                if (doc.isUnpaid) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: overdue
                          ? AppColors.dangerSoft
                          : AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          overdue ? Icons.error_outline : Icons.schedule,
                          size: 16,
                          color: overdue
                              ? AppColors.danger
                              : const Color(0xFFB8500F),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            overdue
                                ? '期限超過・未入金（期限 ${due == null ? '-' : formatShortDate(due)}）'
                                : '未入金・支払期限 ${due == null ? '未設定' : formatShortDate(due)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: overdue
                                  ? AppColors.danger
                                  : const Color(0xFFB8500F),
                            ),
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                  ),
                ],
                if (doc.kind == DocKind.estimate && doc.convertedId != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 15,
                          color: AppColors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '請求書を作成済み',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
