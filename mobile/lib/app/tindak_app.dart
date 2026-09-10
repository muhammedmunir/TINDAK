import 'package:flutter/material.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/app/theme.dart';
import 'package:tindak/features/home/home_screen.dart';

/// The application shell.
class TindakApp extends StatelessWidget {
  const TindakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TINDAK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: Routes.home,
      routes: <String, WidgetBuilder>{
        Routes.home: (_) => const HomeScreen(),
      },
    );
  }
}
