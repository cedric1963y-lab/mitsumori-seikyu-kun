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
Future<LineResult?> showLineSheet(
  BuildContext context, {
  DocLine? initial,
  LineLabel label = LineLabel.item,
}) {
  return showModalBottomSheet<LineResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LineSheet(initial: initial, label: label),
  );
}

class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.initial, required this.label});

  final DocLine? initial;
  final LineLabel label;

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
  /// 施工日. One day, several days, or a 期間 (all its days).
  late final List<DateTime> _days = [...?widget.initial?.workedDays];
  late final _detail = TextEditingController(
    text: widget.initial?.detail ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _detail.dispose();
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
      error = widget.label == LineLabel.item
          ? '品目名を入力してください。'
          : '${widget.label.heading}を入力してください。';
    } else if (collapseWhitespace(_detail.text).length > 40) {
      error = '施工内容は40文字以内で入力してください。';
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
    final dates = DocLine.datesFrom(_days);
    Navigator.pop(
      context,
      LineResult.save(
        DocLine(
          name: collapseWhitespace(_name.text),
          quantity: quantity!,
          unit: collapseWhitespace(_unit.text),
          unitPrice: price!,
          taxRate: _rate,
          workDate: dates.$1,
          workDates: dates.$2,
          detail: collapseWhitespace(_detail.text),
        ),
      ),
    );
  }

  static const maxWorkDays = 62;

  void _addDays(Iterable<DateTime> days) {
    setState(() {
      for (final d in days) {
        final day = dateOnly(d);
        if (!_days.contains(day)) _days.add(day);
      }
      _days.sort();
      if (_days.length > maxWorkDays) {
        _days.removeRange(maxWorkDays, _days.length);
        _error = '施工日は1つの明細に$maxWorkDays日までです。';
      }
    });
  }

  Future<void> _pickWorkDate() async {
    final picked = await showMultiDayPicker(context, initial: _days);
    if (picked == null) return;
    setState(() {
      _days
        ..clear()
        ..addAll(picked);
    });
    _addDays(const []);
  }

  Future<void> _pickWorkRange() async {
    final now = dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _days.length > 1
          ? DateTimeRange(start: _days.first, end: _days.last)
          : null,
      currentDate: now,
      helpText: '施工期間を選ぶ',
      saveText: '決定',
    );
    if (picked == null) return;
    final days = <DateTime>[];
    for (
      var d = dateOnly(picked.start);
      !d.isAfter(picked.end) && days.length <= maxWorkDays;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      days.add(d);
    }
    _addDays(days);
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
              decoration: InputDecoration(labelText: widget.label.heading),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('line-work-date'),
                    onPressed: _pickWorkDate,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    icon: const Icon(Icons.event_outlined, size: 20),
                    label: Text(_days.isEmpty ? '施工日を選ぶ（複数OK）' : '日付を選び直す'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('line-work-range'),
                    onPressed: _pickWorkRange,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    icon: const Icon(Icons.date_range_outlined, size: 20),
                    label: const Text('期間で選ぶ'),
                  ),
                ),
              ],
            ),
            if (_days.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _days.length == 1
                          ? '施工日 ${formatDate(_days.first)}'
                          : '施工日 ${_days.length}日分　${formatWorkDays(_days)}',
                      key: const Key('line-work-days-summary'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    key: const Key('line-work-date-clear'),
                    onPressed: () => setState(() => _days.clear()),
                    child: const Text('全部消す'),
                  ),
                ],
              ),
              if (_days.length > 1)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final d in _days)
                      InputChip(
                        label: Text(formatShortDate(d)),
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => setState(() => _days.remove(d)),
                        deleteButtonTooltipMessage: 'この日を外す',
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('line-detail'),
              controller: _detail,
              decoration: const InputDecoration(
                labelText: '施工内容（任意）',
                hintText: '例: クロス張替え',
              ),
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


/// Calendar where several days can be tapped on and off (施工日).
/// Returns the picked days sorted, or null when cancelled.
Future<List<DateTime>?> showMultiDayPicker(
  BuildContext context, {
  List<DateTime> initial = const [],
}) {
  return showDialog<List<DateTime>>(
    context: context,
    builder: (_) => _MultiDayDialog(initial: initial),
  );
}

class _MultiDayDialog extends StatefulWidget {
  const _MultiDayDialog({required this.initial});

  final List<DateTime> initial;

  @override
  State<_MultiDayDialog> createState() => _MultiDayDialogState();
}

class _MultiDayDialogState extends State<_MultiDayDialog> {
  late final Set<DateTime> _picked = {
    for (final d in widget.initial) dateOnly(d),
  };
  late DateTime _month = firstOfMonth(
    widget.initial.isEmpty ? DateTime.now() : widget.initial.last,
  );

  static const _heads = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final first = _month;
    final days = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday % 7; // 日曜はじまり
    final today = dateOnly(DateTime.now());
    final cells = <Widget>[
      for (final h in _heads)
        Center(
          child: Text(
            h,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: h == '日'
                  ? AppColors.danger
                  : (h == '土' ? Colors.blue : AppColors.muted),
            ),
          ),
        ),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _day(DateTime(first.year, first.month, d), today),
    ];
    return AlertDialog(
      key: const Key('multi-day-dialog'),
      titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      title: Row(
        children: [
          IconButton(
            key: const Key('multi-day-prev'),
            tooltip: '前の月',
            onPressed: () => setState(() => _month = addMonths(_month, -1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              formatMonth(_month),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            key: const Key('multi-day-next'),
            tooltip: '次の月',
            onPressed: () => setState(() => _month = addMonths(_month, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '働いた日をタップ（何日でも選べます）',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: cells,
            ),
            const SizedBox(height: 6),
            Text(
              _picked.isEmpty
                  ? 'まだ選んでいません'
                  : '${_picked.length}日 選択中　${formatWorkDays(_picked.toList(), short: true)}',
              key: const Key('multi-day-count'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('multi-day-done'),
          onPressed: () =>
              Navigator.pop(context, _picked.toList()..sort()),
          child: const Text('決定'),
        ),
      ],
    );
  }

  Widget _day(DateTime d, DateTime today) {
    final on = _picked.contains(d);
    return InkWell(
      key: Key('multi-day-${dayKey(d)}'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => on ? _picked.remove(d) : _picked.add(d)),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.orange : null,
          shape: BoxShape.circle,
          border: d == today && !on
              ? Border.all(color: AppColors.slate)
              : null,
        ),
        child: Text(
          '${d.day}',
          style: TextStyle(
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
            color: on ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
