import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to portrait for better accessibility
  // Do this asynchronously to avoid blocking
  await SystemChrome.setPreferredOrientations([
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
        // Custom color palette for visually impaired users
        brightness: Brightness.light,
        primaryColor: const Color(0xFF234C6A), // Medium muted blue
        colorScheme: ColorScheme.light(
          // Primary colors from palette
          primary: const Color(0xFF234C6A), // #234C6A - slightly lighter muted blue
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF456882), // #456882 - medium desaturated blue-grey
          onPrimaryContainer: Colors.white,
          
          // Secondary/Accent colors
          secondary: const Color(0xFF1B3C53), // #1B3C53 - dark muted blue
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFF456882), // #456882 - medium desaturated blue-grey
          onSecondaryContainer: Colors.white,
          
          // Surface colors
          surface: const Color(0xFFE3E3E3), // #E3E3E3 - very light grey
          onSurface: const Color(0xFF1B3C53), // Dark blue for text on light surface
          surfaceContainerHighest: const Color(0xFF456882).withOpacity(0.2),
          
          // Background
          background: const Color(0xFFE3E3E3), // #E3E3E3 - very light grey
          onBackground: const Color(0xFF1B3C53), // Dark blue for text on light background
          
          // Error
          error: const Color(0xFFCC0000),
          onError: Colors.white,
        ),
        // Support large font sizes
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B3C53), // Dark muted blue from palette
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B3C53), // Dark muted blue from palette
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            color: Color(0xFF1B3C53), // Dark muted blue from palette
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
            backgroundColor: WidgetStateProperty.all(const Color(0xFFE3E3E3)), // Light grey from palette
            elevation: WidgetStateProperty.all(4),
          ),
        ),
      ),
      home: const LandingScreen(),
    );
  }
}

