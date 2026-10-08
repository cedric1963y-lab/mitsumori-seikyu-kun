import 'package:flutter/material.dart';

import '../errors.dart';
import '../format.dart';
import '../logic/totals.dart';
import '../models/models.dart';
import '../screens/premium_screen.dart';
import '../theme.dart';

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

Future<void> openPremium(BuildContext context, {LimitKind? reason}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PremiumScreen(reason: reason)),
  );
}

/// Runs [action] and turns known failures into a snack bar or the premium
/// screen. Returns false when the action failed.
Future<bool> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on LimitReached catch (error) {
    if (context.mounted) await openPremium(context, reason: error.kind);
  } on InvalidInput catch (error) {
    if (context.mounted) showSnack(context, error.message);
  } catch (_) {
    if (context.mounted) {
      showSnack(context, '保存できませんでした。iPhoneの空き容量を確認してください。');
    }
  }
  return false;
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.danger : AppColors.slate,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Small rounded panel used across screens.
class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.card,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Material (not a decorated box) so ListTile ink shows inside.
    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    required this.color,
    required this.background,
    super.key,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final DocStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      DocStatus.unsent => Pill(
        label: status.label,
        color: AppColors.muted,
        background: AppColors.greySoft,
      ),
      DocStatus.sent => Pill(
        label: status.label,
        color: AppColors.blue,
        background: AppColors.blueSoft,
      ),
      DocStatus.paid => Pill(
        label: status.label,
        color: AppColors.green,
        background: AppColors.greenSoft,
      ),
    };
  }
}

/// Square `見積` / `請求` badge.
class KindBadge extends StatelessWidget {
  const KindBadge(this.kind, {super.key});

  final DocKind kind;

  @override
  Widget build(BuildContext context) {
    final estimate = kind == DocKind.estimate;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: estimate ? AppColors.blueSoft : AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        kind.shortLabel,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: estimate ? AppColors.blue : const Color(0xFFB8500F),
        ),
      ),
    );
  }
}

/// 小計 / 税率ごとの対象額と消費税 / 合計.
class TotalsCard extends StatelessWidget {
  const TotalsCard({required this.totals, super.key});

  final DocTotals totals;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int yen, {bool muted = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: muted ? AppColors.muted : AppColors.ink,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              formatYen(yen),
              style: TextStyle(
                color: muted ? AppColors.muted : AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Panel(
      child: Column(
        children: [
          row('小計（税抜）', totals.subtotal),
          for (final b in totals.buckets)
            if (b.rate == TaxRate.exempt)
              row('非課税 対象', b.base, muted: true)
            else ...[
              row('${b.rate.percent}%対象', b.base, muted: true),
              row('消費税（${b.rate.percent}%）', b.tax, muted: true),
            ],
          const Divider(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '合計（税込）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                formatYen(totals.total),
                key: const Key('doc-total'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `2.5 人工 × ¥22,000`
String lineDetail(DocLine line) =>
    '${formatQuantity(line.quantity)} ${line.unit} × ${formatYen(line.unitPrice)}';

/// Tax tag shown next to a line: `8%` or `非課税`. Null for the usual 10%.
String? taxTag(TaxRate rate) => switch (rate) {
  TaxRate.ten => null,
  TaxRate.eight => '軽減8%',
  TaxRate.exempt => '非課税',
};
