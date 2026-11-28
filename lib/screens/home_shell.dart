import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../plan/trial_tip.dart';
import 'document_screen.dart';
import 'documents_screen.dart';
import 'editor_screen.dart';
import 'guide_screen.dart';
import 'master_screen.dart';
import 'premium_screen.dart';
import 'settings_screen.dart';
import '../widgets/help_button.dart';
import 'unpaid_screen.dart';

/// Bottom tabs: 書類 / 未入金 / 登録 / 設定.
class HomeShell extends StatefulWidget {
  const HomeShell({this.startTab = 0, this.startDocumentId = '', super.key});

  /// 0-3 picks a tab. Debug screenshot runs also use 10 (edit
  /// [startDocumentId]), 11 (プレミアム), 12 (preview [startDocumentId]) and
  /// 13 (edit [startDocumentId] with its first line open), 14-16 (guide page
  /// 1-3) and 17 (書類の「？」).
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
    if (widget.startTab < 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showGuideOrTip());
      return;
    }
    _index = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = AppScope.of(context);
      final doc = controller.documentById(widget.startDocumentId);
      final Widget? page = switch (widget.startTab) {
        10 when doc != null => EditorScreen(initial: doc),
        12 when doc != null => DocumentScreen(documentId: doc.id),
        13 when doc != null => EditorScreen(initial: doc, openLine: 0),
        11 => const PremiumScreen(),
        14 || 15 || 16 => GuideScreen(initialPage: widget.startTab - 14),
        _ => null,
      };
      if (widget.startTab == 17) {
        showHelp(
          context,
          title: HelpTexts.documents.title,
          body: HelpTexts.documents.body,
        );
        return;
      }
      if (page == null) return;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    });
  }

  /// First launch only: the 3-page guide, skippable.
  /// After that, trial users may see one short tip — never both at once.
  Future<void> _showGuideOrTip() async {
    if (!mounted) return;
    final controller = AppScope.of(context);
    if (!controller.guideSeen) {
      unawaited(controller.markGuideSeen());
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => const GuideScreen(),
        ),
      );
      return;
    }
    _maybeShowTrialTip();
  }

  /// Free-trial users get one short tip, once. A quiet snack bar, no push.
  void _maybeShowTrialTip() {
    if (!mounted) return;
    final controller = AppScope.of(context);
    if (!controller.shouldShowTrialTip) return;
    unawaited(controller.markTrialTipShown());
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text(TrialTip.message),
        duration: const Duration(seconds: 9),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '見てみる',
          onPressed: () {
            final estimates = controller.documents
                .where((d) => d.kind == DocKind.estimate)
                .toList();
            final doc = estimates.isNotEmpty
                ? estimates.first
                : (controller.documents.isNotEmpty
                      ? controller.documents.first
                      : null);
            if (doc == null) return;
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DocumentScreen(documentId: doc.id),
              ),
            );
          },
        ),
      ),
    );
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
