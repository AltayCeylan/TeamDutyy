import 'package:flutter/material.dart';
import 'app_router.dart';
import 'app_theme.dart';

class TeamDutyApp extends StatelessWidget {
  const TeamDutyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,

      // ✅ Tema değiştirme yok: tek tema
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
    );
  }
}
