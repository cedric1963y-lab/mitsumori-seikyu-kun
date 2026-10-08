import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../errors.dart';
import '../format.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';
import 'document_screen.dart';

/// Creates or edits a 見積書 / 請求書. [initial] with an empty id is a new
/// draft from [AppController.newDraft].
class EditorScreen extends StatefulWidget {
  const EditorScreen({required this.initial, super.key});

  final Doc initial;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Doc _doc = widget.initial;
  late final _title = TextEditingController(text: widget.initial.title);
  late final _note = TextEditingController(text: widget.initial.note);
  var _dirty = false;
  var _saving = false;

  bool get _isNew => widget.initial.id.isEmpty;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _update(Doc next) {
    setState(() {
      _doc = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final controller = AppScope.of(context);
    setState(() => _saving = true);
    final draft = _doc.copyWith(title: _title.text, note: _note.text);
    Doc? saved;
    final ok = await guard(context, () async {
      saved = await controller.saveDocument(draft);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok || saved == null) return;
    _dirty = false;
    final navigator = Navigator.of(context);
    if (_isNew) {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DocumentScreen(documentId: saved!.id),
        ),
      );
    } else {
      navigator.pop();
    }
  }

  Future<void> _pickCustomer() async {
    final controller = AppScope.of(context);
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _CustomerPicker(
        customers: controller.customers,
        onAdd: () async {
          Customer? created;
          await guard(sheetContext, () async {
            if (!controller.canAddCustomer) {
              throw const LimitReached(LimitKind.customers);
            }
            final draft = await showCustomerDialog(sheetContext);
            if (draft == null) return;
            created = await controller.addCustomer(
              name: draft.name,
              honorific: draft.honorific,
              address: draft.address,
            );
          });
          if (created != null && sheetContext.mounted) {
            Navigator.pop(sheetContext, created);
          }
        },
      ),
    );
    if (picked == null) return;
    _update(
      _doc.copyWith(
        customerId: picked.id,
        customerName: picked.name,
        honorific: picked.honorific,
        customerAddress: picked.address,
      ),
    );
  }

  Future<void> _addFromItems() async {
    final controller = AppScope.of(context);
    final item = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ItemPicker(
        items: controller.items,
        onAdd: () async {
          Item? created;
          await guard(sheetContext, () async {
            if (!controller.canAddItem) {
              throw const LimitReached(LimitKind.items);
            }
            final draft = await showItemDialog(sheetContext);
            if (draft == null) return;
            created = await controller.addItem(
              name: draft.name,
              unit: draft.unit,
              unitPrice: draft.unitPrice,
              taxRate: draft.taxRate,
            );
          });
          if (created != null && sheetContext.mounted) {
            Navigator.pop(sheetContext, created);
          }
        },
      ),
    );
    if (item == null || !mounted) return;
    final quantity = await showQuantityDialog(context, item);
    if (quantity == null) return;
    _update(
      _doc.copyWith(lines: [..._doc.lines, DocLine.fromItem(item, quantity)]),
    );
  }

  Future<void> _addFree() async {
    final result = await showLineSheet(context);
    final line = result?.line;
    if (line == null) return;
    _update(_doc.copyWith(lines: [..._doc.lines, line]));
  }

  Future<void> _editLine(int index) async {
    final result = await showLineSheet(context, initial: _doc.lines[index]);
    if (result == null) return;
    final lines = [..._doc.lines];
    if (result.delete) {
      lines.removeAt(index);
    } else {
      lines[index] = result.line!;
    }
    _update(_doc.copyWith(lines: lines));
  }

  Future<void> _pickDate({required bool due}) async {
    final current = due ? (_doc.due ?? _doc.issued) : _doc.issued;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _update(
      due
          ? _doc.copyWith(dueDate: dayKey(picked))
          : _doc.copyWith(issueDate: dayKey(picked)),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirmAction(
      context,
      title: '保存せずに戻りますか？',
      body: '入力した内容は保存されません。',
      confirmLabel: '戻る',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final totals = controller.totalsFor(_doc);
    final kind = _doc.kind;
    final due = _doc.due;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) {
          _dirty = false;
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '${kind.label}を作成' : '${kind.label}を編集'),
          actions: [
            TextButton(
              key: const Key('save-document'),
              onPressed: _saving ? null : _save,
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
            Row(
              children: [
                KindBadge(kind),
                const SizedBox(width: 10),
                Text(
                  kind.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  _isNew ? '番号は保存時に付きます' : 'No. ${_doc.number}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Panel(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const Key('pick-customer'),
                onTap: _pickCustomer,
                leading: const Icon(Icons.apartment, color: AppColors.slate),
                title: Text(
                  _doc.customerName.isEmpty
                      ? '取引先を選ぶ'
                      : '${_doc.customerName} ${_doc.honorific}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _doc.customerName.isEmpty
                        ? AppColors.orange
                        : AppColors.ink,
                  ),
                ),
                subtitle: _doc.customerAddress.isEmpty
                    ? null
                    : Text(_doc.customerAddress, maxLines: 1),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('doc-title'),
              controller: _title,
              onChanged: (_) => _dirty = true,
              decoration: const InputDecoration(
                labelText: '件名',
                hintText: '例: 港北倉庫 事務所内装工事',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DateBox(
                    label: '発行日',
                    value: formatJapaneseDate(_doc.issued),
                    onTap: () => _pickDate(due: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateBox(
                    label: kind.dueLabel,
                    value: due == null ? '未設定' : formatJapaneseDate(due),
                    onTap: () => _pickDate(due: true),
                    onClear: due == null
                        ? null
                        : () => _update(_doc.copyWith(clearDueDate: true)),
                  ),
                ),
              ],
            ),
            SectionTitle(
              '明細',
              trailing: Text(
                '${_doc.lines.length}行',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            if (_doc.lines.isNotEmpty)
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _doc.lines.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 14, endIndent: 14),
                      _LineRow(
                        key: Key('line-$i'),
                        line: _doc.lines[i],
                        onTap: () => _editLine(i),
                      ),
                    ],
                  ],
                ),
              )
            else
              const Panel(
                child: Text(
                  '「品目から追加」で、登録した品目を数量だけ入れて追加できます。',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('add-from-items'),
                    onPressed: _addFromItems,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                    ),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('品目から追加'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('add-free-line'),
                    onPressed: _addFree,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('自由入力'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TotalsCard(totals: totals),
            const SizedBox(height: 14),
            TextField(
              key: const Key('doc-note'),
              controller: _note,
              onChanged: (_) => _dirty = true,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '備考（任意）',
                hintText: '例: 振込手数料はご負担ください。',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isNew ? '保存してPDFを確認' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: '期限なし',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.onTap, super.key});

  final DocLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tag = taxTag(line.taxRate);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          line.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 6),
                        Pill(
                          label: tag,
                          color: AppColors.muted,
                          background: AppColors.greySoft,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lineDetail(line),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatYen(line.amount),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({required this.customers, required this.onAdd});

  final List<Customer> customers;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              '取引先を選ぶ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final c in customers)
              ListTile(
                key: Key('customer-${c.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.apartment),
                title: Text('${c.name} ${c.honorific}'),
                subtitle: c.address.isEmpty
                    ? null
                    : Text(c.address, maxLines: 1),
                onTap: () => Navigator.pop(context, c),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('picker-add-customer'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('新しい取引先を登録'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemPicker extends StatelessWidget {
  const _ItemPicker({required this.items, required this.onAdd});

  final List<Item> items;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              '品目から追加',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'タップして数量を入れるだけで明細に入ります。',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                key: Key('item-${item.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${formatYen(item.unitPrice)} / ${item.unit}${taxTag(item.taxRate) == null ? '' : '・${taxTag(item.taxRate)}'}',
                ),
                trailing: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.orange,
                ),
                onTap: () => Navigator.pop(context, item),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'まだ品目がありません。よく使う作業や材料を登録しておくと、次から数量だけで入力できます。',
                  style: TextStyle(height: 1.45),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('picker-add-item'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('品目を登録'),
            ),
          ],
        ),
      ),
    );
  }
}
