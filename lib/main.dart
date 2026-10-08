import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_shell.dart';
import 'data/repository.dart';
import 'plan/limits.dart';
import 'services/screenshot_purchase_gateway.dart';
import 'services/store_purchase_gateway.dart';
import 'state/app_controller.dart';
import 'theme.dart';

/// Debug builds only, for App Store screenshots of the live UI:
/// `flutter run --dart-define=SCREENSHOT=true --dart-define=SCREENSHOT_PREMIUM=true
/// --dart-define=SCREENSHOT_TAB=12 --dart-define=SCREENSHOT_DOC=DOCUMENT_ID`.
/// Release builds ignore all of them.
const _screenshot = bool.fromEnvironment('SCREENSHOT');
const _screenshotPremium = bool.fromEnvironment('SCREENSHOT_PREMIUM');
const _screenshotTab = int.fromEnvironment('SCREENSHOT_TAB');
const _screenshotDoc = String.fromEnvironment('SCREENSHOT_DOC');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}

class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  AppController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (_error != null && mounted) {
      setState(() => _error = null);
    }
    try {
      final documents = await getApplicationDocumentsDirectory();
      final repository = Repository(
        Directory(p.join(documents.path, 'mitsumori_seikyu')),
      );
      final controller = AppController(
        repository: repository,
        purchases: kDebugMode && _screenshot
            ? ScreenshotPurchaseGateway()
            : StorePurchaseGateway(),
        demoPremium: kDebugMode && _screenshot && _screenshotPremium,
      );
      await controller.load();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return AppShell(
        controller: controller,
        startTab: kDebugMode && _screenshot ? _screenshotTab : 0,
        startDocumentId: kDebugMode && _screenshot ? _screenshotDoc : '',
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: _error == null
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppInfo.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 16),
                      CircularProgressIndicator(color: AppColors.orange),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'データを開けませんでした',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'このiPhoneの保存領域を確認して、もう一度開いてください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.45),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _boot, child: const Text('再試行')),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
