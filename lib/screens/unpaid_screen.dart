import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../format.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/doc_tile.dart';

/// 未入金 tab: unpaid invoices, earliest due date first.
class UnpaidScreen extends StatelessWidget {
  const UnpaidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final unpaid = controller.unpaidInvoices;
    return Scaffold(
      appBar: AppBar(title: const Text('未入金')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          Panel(
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.orange,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '未入金 ${unpaid.length}件',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      Text(
                        formatYen(controller.unpaidTotal),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.overdueCount > 0)
                  Pill(
                    label: '期限超過 ${controller.overdueCount}件',
                    color: AppColors.danger,
                    background: AppColors.dangerSoft,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (unpaid.isEmpty)
            const Panel(
              child: Text(
                '未入金の請求書はありません。入金を確認したら、請求書の状態を「入金済」にするとここから消えます。',
                style: TextStyle(height: 1.45),
              ),
            )
          else
            for (final doc in unpaid)
              DocTile(
                doc: doc,
                trailing: TextButton(
                  key: Key('paid-${doc.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () async {
                    final ok = await guard(
                      context,
                      () => controller.setStatus(doc.id, DocStatus.paid),
                    );
                    if (ok && context.mounted) {
                      showSnack(
                        context,
                        '${doc.number} を入金済にしました。',
                        action: SnackBarAction(
                          label: '取り消す',
                          onPressed: () =>
                              controller.setStatus(doc.id, doc.status),
                        ),
                      );
                    }
                  },
                  child: const Text('入金済にする'),
                ),
              ),
        ],
      ),
    );
  }
}
