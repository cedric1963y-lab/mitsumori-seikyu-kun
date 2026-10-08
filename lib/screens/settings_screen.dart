import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../errors.dart';
import '../format.dart';
import '../plan/limits.dart';
import '../services/links.dart';
import '../services/share_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final expires = controller.entitlement.expiresAt;
    final plan = controller.premium && expires != null
        ? 'プレミアム（${PlanLimits.planName(controller.entitlement.productId)}）・${formatJapaneseDate(expires)}まで'
        : controller.premium
        ? 'プレミアム'
        : '無料・取引先 ${controller.customers.length}/${PlanLimits.freeCustomerLimit}・品目 ${controller.items.length}/${PlanLimits.freeItemLimit}・今月の作成 ${controller.documentsCreatedThisMonth}/${PlanLimits.freeDocumentsPerMonth}';
    final profile = controller.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('plan-tile'),
              leading: const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.orange,
              ),
              title: const Text(
                'プラン',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(plan),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPremium(context),
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('profile-tile'),
              leading: const Icon(Icons.badge_outlined, color: AppColors.slate),
              title: const Text(
                '自社情報（屋号・住所・振込先・登録番号）',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                profile.isEmpty
                    ? '未設定'
                    : [
                        profile.name,
                        if (profile.registrationNumber.isNotEmpty)
                          '登録番号 ${profile.registrationNumber}',
                      ].join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            padding: EdgeInsets.zero,
            child: Builder(
              builder: (tileContext) => ListTile(
                key: const Key('export-csv'),
                leading: Icon(
                  controller.premium
                      ? Icons.table_view_outlined
                      : Icons.lock_outline,
                  color: AppColors.slate,
                ),
                title: const Text(
                  '書類の一覧をCSVで書き出す',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Excelや会計ソフトに取り込めます（プレミアム）'),
                onTap: () => guard(context, () async {
                  final origin = shareOriginOf(tileContext);
                  if (!controller.premium) {
                    throw const LimitReached(LimitKind.csv);
                  }
                  final path = await controller.exportCsv();
                  await shareFile(
                    path: path,
                    fileName: path.split('/').last,
                    mimeType: 'text/csv',
                    subject: '見積・請求一覧',
                    origin: origin,
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Panel(
            child: _Block(
              title: '使い方',
              body: '1.「設定」で自社情報（屋号・住所・振込先・登録番号）を登録\n2.「取引先・品目」で宛先と、よく使う作業・材料の単価を登録\n3.「書類」の「新規作成」で見積書を作り、「品目から追加」で数量を入れる\n4. PDFを確認して、LINEやメールで送る\n5. 受注したら「この見積書から請求書を作る」で1タップ、入金されたら「入金済」に',
            ),
          ),
          const SizedBox(height: 10),
          const Panel(
            child: _Block(
              title: '消費税の計算',
              body: '単価は税抜で入力します。消費税は書類ごと・税率ごとに合計してから1回だけ計算し、1円未満は切り捨てます（インボイス制度の端数処理）。登録番号を入れると、書類に印字されます。',
            ),
          ),
          const SizedBox(height: 10),
          const Panel(
            child: _Block(
              title: 'データの保存場所',
              body: '書類・取引先・品目・自社情報はこのiPhoneの中だけに保存されます。アカウントは不要で、運営のサーバーには送りません。\n\niPhoneのバックアップをオンにしている場合、Appleのバックアップに含まれることがあります。アプリを削除すると、データも消えます。',
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LinkTile(label: '利用規約（Apple標準EULA）', url: AppLinks.appleEula),
                const Divider(height: 1),
                _LinkTile(label: 'プライバシーポリシー', url: AppLinks.privacy),
                const Divider(height: 1),
                _LinkTile(label: 'サポート', url: AppLinks.support),
                const Divider(height: 1),
                _LinkTile(
                  label: 'サブスクリプションの管理',
                  url: AppLinks.manageSubscriptions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Panel(
            child: _Block(
              title: 'バージョン',
              body: '${AppInfo.name} ${AppInfo.version}',
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 20),
      onTap: () async {
        final ok = await openExternal(url);
        if (!ok && context.mounted) showSnack(context, 'ページを開けませんでした。');
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(height: 1.5)),
      ],
    );
  }
}
