import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/landing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to portrait for better accessibility
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const VaviApp());
}

class VaviApp extends StatelessWidget {
  const VaviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAVI - Voice Assistant for Visually Impaired',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // High contrast theme for visually impaired users
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0066CC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066CC),
          brightness: Brightness.light,
          // High contrast colors
          primary: const Color(0xFF0066CC),
          secondary: const Color(0xFF0066CC),
          surface: Colors.white,
          error: const Color(0xFFCC0000),
        ),
        // Support large font sizes
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF000000),
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            color: Color(0xFF000000),
          ),
        ),
        // Large touch targets
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 48), // Material Design minimum
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // High contrast dropdowns
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            elevation: WidgetStateProperty.all(4),
          ),
        ),
      ),
      home: const LandingScreen(),
    );
  }
}

