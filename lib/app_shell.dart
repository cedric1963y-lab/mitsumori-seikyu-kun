import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'plan/limits.dart';
import 'screens/home_shell.dart';
import 'state/app_controller.dart';
import 'theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.controller,
    this.startTab = 0,
    this.startDocumentId = '',
    super.key,
  });

  final AppController controller;
  final int startTab;
  final String startDocumentId;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HomeShell(startTab: startTab, startDocumentId: startDocumentId),
      ),
    );
  }
}
