import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_strings.dart';
import 'constants/app_theme.dart';
import 'providers/faculty_provider.dart';
import 'providers/navigation_provider.dart';
import 'screens/faculty_screen.dart';
import 'screens/github_settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FacultyProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const FacultyScreen(),
        routes: {
          '/github-settings': (_) => const GitHubSettingsScreen(),
        },
      ),
    );
  }
}
