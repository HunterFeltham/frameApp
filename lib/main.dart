import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/frame_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait — one-handed use in a jam setting.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => FrameService(),
      child: const AltoJamApp(),
    ),
  );
}

class AltoJamApp extends StatelessWidget {
  const AltoJamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alto Jam Key Helper',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF12122A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0D20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF9500),    // amber – concert key accent
        secondary: Color(0xFF00D4FF),  // cyan   – alto key accent
        surface: Color(0xFF1C1C3A),
        onSurface: Colors.white,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF2A2A4A),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
