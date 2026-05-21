import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/quotation/presentation/pages/home_navigation_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EstimaTekApp());
}

class EstimaTekApp extends StatelessWidget {
  const EstimaTekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EstimaTek V2',
      theme: AppTheme.lightTheme,
      home: const HomeNavigationPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

