import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../errors.dart';
import '../models/models.dart';
import '../services/seal_picker.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 自社情報: printed on every document, plus the 印影 / ロゴ (premium).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({this.picker = const SealPicker(), super.key});

  final SealPicker picker;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final BusinessProfile _initial = AppScope.of(context).profile;
  late final _name = TextEditingController(text: _initial.name);
  late final _postal = TextEditingController(text: _initial.postalCode);
  late final _address = TextEditingController(text: _initial.address);
  late final _phone = TextEditingController(text: _initial.phone);
  late final _email = TextEditingController(text: _initial.email);
  late final _bank = TextEditingController(text: _initial.bank);
  late final _number = TextEditingController(text: _initial.registrationNumber);

  @override
  void dispose() {
    for (final c in [
      _name,
      _postal,
      _address,
      _phone,
      _email,
      _bank,
      _number,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final controller = AppScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await guard(
      context,
      () => controller.saveProfile(
        BusinessProfile(
          name: _name.text,
          postalCode: _postal.text,
          address: _address.text,
          phone: _phone.text,
          email: _email.text,
          bank: _bank.text,
          registrationNumber: _number.text,
        ),
      ),
    );
    if (ok && mounted) {
      showSnack(context, '自社情報を保存しました。');
      navigator.pop();
    }
  }

  Future<void> _pickSeal() async {
    final controller = AppScope.of(context);
    await guard(context, () async {
      if (!controller.premium) throw const LimitReached(LimitKind.seal);
      final png = await widget.picker.pick();
      if (png == null) return;
      await controller.setSeal(png);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final seal = controller.seal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('自社情報'),
        actions: [
          TextButton(
            key: const Key('save-profile'),
            onPressed: _save,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: [
          const Text(
            '見積書・請求書の右上に印字されます。',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('profile-name'),
            controller: _name,
            decoration: const InputDecoration(
              labelText: '屋号または氏名（必須）',
              hintText: '例: 鈴木内装 / 鈴木 隼人',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _postal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '郵便番号',
              hintText: '例: 222-0033',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _address,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '住所'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '電話番号'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'メールアドレス（任意）'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('profile-bank'),
            controller: _bank,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '振込先（請求書に印字）',
              hintText: '例: ○○銀行 港北支店 普通 1234567 スズキ ハヤト',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('profile-number'),
            controller: _number,
            decoration: const InputDecoration(
              labelText: '適格請求書発行事業者 登録番号（任意）',
              hintText: 'T1234567890123',
              helperText: '登録している方だけ。Tと13桁の数字です。',
            ),
          ),
          const SectionTitle('印影・ロゴ（プレミアム）'),
          Panel(
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: seal == null
                      ? const Icon(
                          Icons.approval_outlined,
                          color: AppColors.muted,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.memory(seal, fit: BoxFit.contain),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '写真から選んだ画像を、社名の横に印字します。背景が透明なPNGがきれいです。',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('pick-seal'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(64, 44),
                              ),
                              onPressed: _pickSeal,
                              icon: Icon(
                                controller.premium
                                    ? Icons.photo_library_outlined
                                    : Icons.lock_outline,
                                size: 20,
                              ),
                              label: Text(seal == null ? '画像を選ぶ' : '変更'),
                            ),
                          ),
                          if (seal != null)
                            IconButton(
                              tooltip: '外す',
                              onPressed: () =>
                                  guard(context, controller.removeSeal),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
