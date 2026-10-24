import 'package:flutter/material.dart';
import 'package:peripage_app/config/routes.dart';
import 'package:peripage_app/config/theme.dart';

final class PeriPageApp extends StatelessWidget {
  const PeriPageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeriPage',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: Routes.home,
      routes: Routes.routes,
    );
  }
}
