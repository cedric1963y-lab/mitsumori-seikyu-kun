import 'package:flutter/material.dart';

import '../format.dart';
import '../models/models.dart';
import '../theme.dart';

const unitSuggestions = [
  '式',
  '人工',
  'm²',
  'm',
  '個',
  '台',
  '日',
  '時間',
  '本',
  '枚',
  '箇所',
];

class CustomerDraft {
  const CustomerDraft({
    required this.name,
    required this.honorific,
    required this.address,
  });

  final String name;
  final String honorific;
  final String address;
}

class ItemDraft {
  const ItemDraft({
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.taxRate,
  });

  final String name;
  final String unit;
  final int unitPrice;
  final TaxRate taxRate;
}

/// Result of the line sheet. [delete] is true when the user removed the line.
class LineResult {
  const LineResult.save(DocLine this.line) : delete = false;
  const LineResult.delete() : line = null, delete = true;

  final DocLine? line;
  final bool delete;
}

class FormDialog extends StatelessWidget {
  const FormDialog({
    required this.title,
    required this.saveLabel,
    required this.saveKey,
    required this.onSave,
    required this.error,
    required this.children,
    this.note,
    super.key,
  });

  final String title;
  final String saveLabel;
  final Key saveKey;
  final VoidCallback onSave;
  final String? error;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...children,
            if (note != null) ...[
              const SizedBox(height: 10),
              Text(
                note!,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: saveKey,
                  onPressed: onSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 46),
                  ),
                  child: Text(saveLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- customer

Future<CustomerDraft?> showCustomerDialog(
  BuildContext context, {
  Customer? initial,
  String? note,
}) {
  return showDialog<CustomerDraft>(
    context: context,
    builder: (_) => _CustomerDialog(initial: initial, note: note),
  );
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog({required this.initial, required this.note});

  final Customer? initial;
  final String? note;

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  late var _honorific = widget.initial?.honorific ?? '御中';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '取引先名を入力してください。');
      return;
    }
    Navigator.pop(
      context,
      CustomerDraft(
        name: _name.text,
        honorific: _honorific,
        address: _address.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: widget.initial == null ? '取引先を登録' : '取引先を編集',
      saveLabel: widget.initial == null ? '登録' : '保存',
      saveKey: const Key('customer-save'),
      onSave: _save,
      error: _error,
      note: widget.note,
      children: [
        TextField(
          key: const Key('customer-name'),
          controller: _name,
          autofocus: widget.initial == null,
          decoration: const InputDecoration(
            labelText: '取引先名',
            hintText: '例: 山田工務店 / 佐藤 一郎',
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: '御中', label: Text('御中（会社）')),
            ButtonSegment(value: '様', label: Text('様（個人）')),
          ],
          selected: {_honorific},
          onSelectionChanged: (value) =>
              setState(() => _honorific = value.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          minLines: 1,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '住所（任意）'),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- item

Future<ItemDraft?> showItemDialog(
  BuildContext context, {
  Item? initial,
  String? note,
}) {
  return showDialog<ItemDraft>(
    context: context,
    builder: (_) => _ItemDialog(initial: initial, note: note),
  );
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.initial, required this.note});

  final Item? initial;
  final String? note;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _unit = TextEditingController(text: widget.initial?.unit ?? '式');
  late final _price = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.unitPrice.toString(),
  );
  late var _rate = widget.initial?.taxRate ?? TaxRate.ten;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final price = parseYen(_price.text);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '品目名を入力してください。');
      return;
    }
    if (_unit.text.trim().isEmpty) {
      setState(() => _error = '単位を入力してください。');
      return;
    }
    if (price == null) {
      setState(() => _error = '単価を数字で入力してください。');
      return;
    }
    Navigator.pop(
      context,
      ItemDraft(
        name: _name.text,
        unit: _unit.text,
        unitPrice: price,
        taxRate: _rate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: widget.initial == null ? '品目を登録' : '品目を編集',
      saveLabel: widget.initial == null ? '登録' : '保存',
      saveKey: const Key('item-save'),
      onSave: _save,
      error: _error,
      note: widget.note,
      children: [
        TextField(
          key: const Key('item-name'),
          controller: _name,
          autofocus: widget.initial == null,
          decoration: const InputDecoration(
            labelText: '品目名',
            hintText: '例: クロス張替え',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                key: const Key('item-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: '単価（税抜）',
                  prefixText: '¥ ',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                key: const Key('item-unit'),
                controller: _unit,
                decoration: const InputDecoration(labelText: '単位'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        UnitChips(onPick: (u) => setState(() => _unit.text = u)),
        const SizedBox(height: 12),
        TaxRatePicker(
          value: _rate,
          onChanged: (r) => setState(() => _rate = r),
        ),
      ],
    );
  }
}

class UnitChips extends StatelessWidget {
  const UnitChips({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final unit in unitSuggestions)
          ActionChip(
            label: Text(unit),
            visualDensity: VisualDensity.compact,
            onPressed: () => onPick(unit),
          ),
      ],
    );
  }
}

class TaxRatePicker extends StatelessWidget {
  const TaxRatePicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final TaxRate value;
  final ValueChanged<TaxRate> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TaxRate>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: TaxRate.ten, label: Text('10%')),
          ButtonSegment(value: TaxRate.eight, label: Text('8%（軽減）')),
          ButtonSegment(value: TaxRate.exempt, label: Text('非課税')),
        ],
        selected: {value},
        onSelectionChanged: (v) => onChanged(v.first),
      ),
    );
  }
}

// -------------------------------------------------------------------- line

/// Edits one document line, or creates a free-form one when [initial] is
/// null.
Future<LineResult?> showLineSheet(BuildContext context, {DocLine? initial}) {
  return showModalBottomSheet<LineResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LineSheet(initial: initial),
  );
}

class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.initial});

  final DocLine? initial;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _quantity = TextEditingController(
    text: formatQuantity(widget.initial?.quantity ?? 1).replaceAll(',', ''),
  );
  late final _unit = TextEditingController(text: widget.initial?.unit ?? '式');
  late final _price = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.unitPrice.toString(),
  );
  late var _rate = widget.initial?.taxRate ?? TaxRate.ten;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _price.dispose();
    super.dispose();
  }

  void _step(double delta) {
    final current = parseQuantity(_quantity.text) ?? 0;
    final next = (current + delta).clamp(0, 100000).toDouble();
    setState(() => _quantity.text = formatQuantity(next).replaceAll(',', ''));
  }

  void _save() {
    final quantity = parseQuantity(_quantity.text);
    final price = parseYen(_price.text);
    String? error;
    if (_name.text.trim().isEmpty) {
      error = '品目名を入力してください。';
    } else if (quantity == null || quantity <= 0) {
      error = '数量を0より大きい数字で入力してください。';
    } else if (_unit.text.trim().isEmpty) {
      error = '単位を入力してください。';
    } else if (price == null) {
      error = '単価を数字で入力してください。';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      LineResult.save(
        DocLine(
          name: collapseWhitespace(_name.text),
          quantity: quantity!,
          unit: collapseWhitespace(_unit.text),
          unitPrice: price!,
          taxRate: _rate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quantity = parseQuantity(_quantity.text) ?? 0;
    final price = parseYen(_price.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null ? '明細を追加' : '明細を編集',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('line-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: '品目・内容'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  key: const Key('line-minus'),
                  onPressed: () => _step(-1),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    key: const Key('line-quantity'),
                    controller: _quantity,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: '数量'),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  key: const Key('line-plus'),
                  onPressed: () => _step(1),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: TextField(
                    key: const Key('line-unit'),
                    controller: _unit,
                    decoration: const InputDecoration(labelText: '単位'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            UnitChips(onPick: (u) => setState(() => _unit.text = u)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('line-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '単価（税抜）',
                prefixText: '¥ ',
                helperText: '値引きはマイナスで入力できます',
              ),
            ),
            const SizedBox(height: 12),
            TaxRatePicker(
              value: _rate,
              onChanged: (r) => setState(() => _rate = r),
            ),
            const SizedBox(height: 12),
            Text(
              '金額 ${formatYen((quantity * price).round())}（税抜）',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (widget.initial != null)
                  TextButton.icon(
                    key: const Key('line-delete'),
                    onPressed: () =>
                        Navigator.pop(context, const LineResult.delete()),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    label: const Text(
                      '削除',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  key: const Key('line-save'),
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 50),
                  ),
                  child: Text(widget.initial == null ? '追加' : '保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quantity prompt after picking an item from the master.
Future<double?> showQuantityDialog(BuildContext context, Item item) {
  return showDialog<double>(
    context: context,
    builder: (_) => _QuantityDialog(item: item),
  );
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.item});

  final Item item;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _quantity = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    final value = parseQuantity(_quantity.text);
    if (value == null || value <= 0) {
      setState(() => _error = '数量を0より大きい数字で入力してください。');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FormDialog(
      title: item.name,
      saveLabel: '追加',
      saveKey: const Key('quantity-save'),
      onSave: _save,
      error: _error,
      note:
          '${formatYen(item.unitPrice)} / ${item.unit}（税抜・${item.taxRate.label}）',
      children: [
        TextField(
          key: const Key('quantity'),
          controller: _quantity,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(labelText: '数量', suffixText: item.unit),
        ),
      ],
    );
  }
}
