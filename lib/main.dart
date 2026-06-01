import 'package:flutter/material.dart';
import 'package:pro/services/classic_bluetooth_service.dart';
import 'screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'services/bluetooth_service.dart';
import 'services/device_service.dart';
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClassicBluetoothService()),

        ChangeNotifierProxyProvider<ClassicBluetoothService, DeviceService>(
          create: (context) =>
              DeviceService(context.read<ClassicBluetoothService>()),

          update: (context, bluetoothService, previous) {
            return previous ??
                DeviceService(bluetoothService);
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sanpra Connect',
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}


