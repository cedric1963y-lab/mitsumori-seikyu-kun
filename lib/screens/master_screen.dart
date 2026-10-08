import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../errors.dart';
import '../format.dart';
import '../models/models.dart';
import '../plan/limits.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

/// 取引先・品目 tab.
class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  var _showItems = false;

  Future<void> _addCustomer() async {
    final controller = AppScope.of(context);
    await guard(context, () async {
      if (!controller.canAddCustomer) {
        throw const LimitReached(LimitKind.customers);
      }
      final draft = await showCustomerDialog(context);
      if (draft == null) return;
      await controller.addCustomer(
        name: draft.name,
        honorific: draft.honorific,
        address: draft.address,
      );
    });
  }

  Future<void> _editCustomer(Customer customer) async {
    final controller = AppScope.of(context);
    final draft = await showCustomerDialog(
      context,
      initial: customer,
      note: '作成済みの書類の宛名は変わりません。',
    );
    if (draft == null || !mounted) return;
    await guard(
      context,
      () => controller.updateCustomer(
        id: customer.id,
        name: draft.name,
        honorific: draft.honorific,
        address: draft.address,
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final controller = AppScope.of(context);
    final ok = await confirmAction(
      context,
      title: '取引先を削除しますか？',
      body: '「${customer.name}」を削除します。作成済みの書類は残ります。',
      confirmLabel: '削除',
    );
    if (!ok || !mounted) return;
    await guard(context, () => controller.deleteCustomer(customer.id));
  }

  Future<void> _addItem() async {
    final controller = AppScope.of(context);
    await guard(context, () async {
      if (!controller.canAddItem) throw const LimitReached(LimitKind.items);
      final draft = await showItemDialog(context);
      if (draft == null) return;
      await controller.addItem(
        name: draft.name,
        unit: draft.unit,
        unitPrice: draft.unitPrice,
        taxRate: draft.taxRate,
      );
    });
  }

  Future<void> _editItem(Item item) async {
    final controller = AppScope.of(context);
    final draft = await showItemDialog(
      context,
      initial: item,
      note: '作成済みの書類の金額は変わりません。',
    );
    if (draft == null || !mounted) return;
    await guard(
      context,
      () => controller.updateItem(
        id: item.id,
        name: draft.name,
        unit: draft.unit,
        unitPrice: draft.unitPrice,
        taxRate: draft.taxRate,
      ),
    );
  }

  Future<void> _deleteItem(Item item) async {
    final controller = AppScope.of(context);
    final ok = await confirmAction(
      context,
      title: '品目を削除しますか？',
      body: '「${item.name}」を削除します。作成済みの書類は残ります。',
      confirmLabel: '削除',
    );
    if (!ok || !mounted) return;
    await guard(context, () => controller.deleteItem(item.id));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final premium = controller.premium;
    final count = _showItems
        ? controller.items.length
        : controller.customers.length;
    final limit = _showItems
        ? PlanLimits.freeItemLimit
        : PlanLimits.freeCustomerLimit;

    return Scaffold(
      appBar: AppBar(title: const Text('取引先・品目')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-master'),
        heroTag: null,
        onPressed: _showItems ? _addItem : _addCustomer,
        icon: const Icon(Icons.add),
        label: Text(_showItems ? '品目を登録' : '取引先を登録'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('取引先')),
                ButtonSegment(value: true, label: Text('品目')),
              ],
              selected: {_showItems},
              onSelectionChanged: (v) => setState(() => _showItems = v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
            child: Text(
              premium ? '$count件（プレミアム：上限なし）' : '$count / $limit件（無料プラン）',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          if (count == 0)
            Panel(
              child: Text(
                _showItems
                    ? 'よく使う作業や材料（例: クロス張替え 1,200円/m²）を登録すると、見積書に数量だけで入れられます。'
                    : '見積書・請求書の宛先を登録します。会社は「御中」、個人は「様」で印字されます。',
                style: const TextStyle(height: 1.45),
              ),
            )
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (_showItems)
                    for (final item in controller.items)
                      ListTile(
                        key: Key('master-item-${item.id}'),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${formatYen(item.unitPrice)} / ${item.unit}・${item.taxRate.label}',
                        ),
                        onTap: () => _editItem(item),
                        trailing: IconButton(
                          tooltip: '削除',
                          onPressed: () => _deleteItem(item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      )
                  else
                    for (final customer in controller.customers)
                      ListTile(
                        key: Key('master-customer-${customer.id}'),
                        leading: const Icon(Icons.apartment),
                        title: Text(
                          '${customer.name} ${customer.honorific}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (customer.address.isNotEmpty) customer.address,
                            '書類 ${controller.documentCountForCustomer(customer.id)}件',
                          ].join('\n'),
                        ),
                        onTap: () => _editCustomer(customer),
                        trailing: IconButton(
                          tooltip: '削除',
                          onPressed: () => _deleteCustomer(customer),
                          icon: const Icon(Icons.delete_outline),
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
