import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'document_screen.dart';
import 'documents_screen.dart';
import 'editor_screen.dart';
import 'master_screen.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';
import 'unpaid_screen.dart';

/// Bottom tabs: 書類 / 未入金 / 登録 / 設定.
class HomeShell extends StatefulWidget {
  const HomeShell({this.startTab = 0, this.startDocumentId = '', super.key});

  /// 0-3 picks a tab. Debug screenshot runs also use 10 (edit
  /// [startDocumentId]), 11 (プレミアム) and 12 (preview [startDocumentId]).
  final int startTab;
  final String startDocumentId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.startTab.clamp(0, 3);

  @override
  void initState() {
    super.initState();
    if (widget.startTab < 10) return;
    _index = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = AppScope.of(context);
      final doc = controller.documentById(widget.startDocumentId);
      final Widget? page = switch (widget.startTab) {
        10 when doc != null => EditorScreen(initial: doc),
        12 when doc != null => DocumentScreen(documentId: doc.id),
        11 => const PremiumScreen(),
        _ => null,
      };
      if (page == null) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    });
  }

  @override
  Widget build(BuildContext context) {
    final unpaid = AppScope.of(context).unpaidInvoices.length;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DocumentsScreen(),
          UnpaidScreen(),
          MasterScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          const NavigationDestination(
            key: Key('tab-documents'),
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: '書類',
          ),
          NavigationDestination(
            key: const Key('tab-unpaid'),
            icon: Badge(
              isLabelVisible: unpaid > 0,
              label: Text('$unpaid'),
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unpaid > 0,
              label: Text('$unpaid'),
              child: const Icon(Icons.account_balance_wallet),
            ),
            label: '未入金',
          ),
          const NavigationDestination(
            key: Key('tab-master'),
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '取引先・品目',
          ),
          const NavigationDestination(
            key: Key('tab-settings'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
