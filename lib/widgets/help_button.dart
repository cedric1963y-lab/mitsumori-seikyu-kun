import 'package:flutter/material.dart';

import '../theme.dart';

/// 「？」: a short one-point explanation for the screen it sits on.
class HelpButton extends StatelessWidget {
  const HelpButton({required this.text, super.key});

  final HelpText text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'この画面の使い方',
      icon: const Icon(Icons.help_outline),
      onPressed: () => showHelp(context, title: text.title, body: text.body),
    );
  }
}

Future<void> showHelp(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lightbulb_outline, color: AppColors.orange),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Text(body, style: const TextStyle(height: 1.5, fontSize: 15)),
      actions: [
        TextButton(
          key: const Key('help-close'),
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

/// One-point texts, kept in one place so wording stays consistent.
class HelpText {
  const HelpText(this.title, this.body);
  final String title;
  final String body;
}

abstract final class HelpTexts {
  static const documents = HelpText(
    '書類の画面',
    '見積書と請求書の一覧です。「新規作成」で見積書を作り、書類をタップするとPDFを確認して送れます。',
  );
  static const unpaid = HelpText(
    '未入金の画面',
    '入金待ちの請求書だけが並びます。入金されたら「入金済」にすると、ここから消えます。',
  );
  static const master = HelpText(
    '取引先・品目の画面',
    'よく使う取引先と、作業・材料の単価を登録しておくと、見積書を「選ぶだけ」で作れます。',
  );
  static const settings = HelpText(
    '設定の画面',
    '屋号・住所・振込先・登録番号を入れておくと、見積書や請求書のPDFに印字されます。',
  );
  static const profile = HelpText(
    '自社情報',
    'ここで入れた内容が、すべての書類に印字されます。登録番号は任意で、入れる場合は「T」と13桁です。',
  );
  static const document = HelpText(
    '書類の詳細',
    'PDFのプレビューです。「PDFを送る」でLINEやメールへ。見積書は「請求書を作る」で1タップで請求書にできます。',
  );
  static const editor = HelpText(
    '書類の編集',
    '取引先を選び、「品目から追加」で数量を入れると見積書が完成します。明細の行をタップすると、日付や現場も入れられます。',
  );
}
