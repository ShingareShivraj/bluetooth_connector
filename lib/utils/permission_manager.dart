import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class PermissionManager {
  static Future<bool> requestAll(BuildContext context) async {
    // Step 1: Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((s) => s.isGranted);

    if (!allGranted) {
      _showPermissionDialog(context);
      return false;
    }

    // Step 2: Check Bluetooth ON
    bool isOn = await FlutterBluetoothSerial.instance.isEnabled ?? false;

    if (!isOn) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }

    return true;
  }

  static void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permissions Required"),
        content: const Text(
          "Bluetooth, Location & Nearby Devices permissions are required to scan devices.",
        ),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}