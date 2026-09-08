import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/classic_bluetooth_service.dart';
import 'services/device_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the user's saved theme preference
  // before the application starts.
  final themeService = ThemeService();
  await themeService.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
        ),

        ChangeNotifierProvider<ClassicBluetoothService>(
          create: (_) => ClassicBluetoothService(),
        ),

        ChangeNotifierProxyProvider<
            ClassicBluetoothService,
            DeviceService>(
          create: (context) => DeviceService(
            context.read<ClassicBluetoothService>(),
          ),
          update: (context, bluetooth, previous) =>
          previous ?? DeviceService(bluetooth),
        ),
      ],

      child: const GaramMugApp(),
    ),
  );
}

class GaramMugApp extends StatelessWidget {
  const GaramMugApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      title: 'Garam Mug',

      debugShowCheckedModeBanner: false,

      // Use the theme selected by the user.
      themeMode: themeService.themeMode,

      // --------------------------------------------------
      // LIGHT THEME
      // --------------------------------------------------
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor:
        const Color(0xFFF5F8FF),

        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,

          systemOverlayStyle:
          SystemUiOverlayStyle.dark,
        ),
      ),

      // --------------------------------------------------
      // DARK THEME
      // --------------------------------------------------
      darkTheme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),

        scaffoldBackgroundColor:
        const Color(0xFF0F172A),

        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,

          systemOverlayStyle:
          SystemUiOverlayStyle.light,
        ),
      ),

      home: const SplashScreen(),
    );
  }
}