import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// 🔥 CHANGE THESE UUIDs BASED ON YOUR ESP32
const String SERVICE_UUID = "1234";
const String CHARACTERISTIC_UUID = "ABCD";

/// 📦 DEVICE MODEL
class BleDeviceModel {
  BluetoothDevice device;
  BluetoothCharacteristic? characteristic;
  String name;
  String id;

  double temperature = 0;
  int battery = 0;
  bool isConnected = false;

  BleDeviceModel({
    required this.device,
    required this.name,
    required this.id,
  });
}

/// 🔵 BLUETOOTH SERVICE WITH PROVIDER
class BleService extends ChangeNotifier {


  List<ScanResult> scanResults = [];
  List<BleDeviceModel> connectedDevices = [];

  StreamSubscription? scanSubscription;

  bool isScanning = false;

  // 🔍 START SCAN
  Future<void> startScan() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    scanResults.clear();
    isScanning = true;
    notifyListeners();

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10), // 🔥 increase time
    );

    scanSubscription?.cancel(); // prevent duplicate listeners

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results.toSet().toList();
      notifyListeners();
    });
  }
  // 🛑 STOP SCAN
  void stopScan() {
    FlutterBluePlus.stopScan();
    scanSubscription?.cancel();
    isScanning = false;
    notifyListeners();
  }

  // 🔗 CONNECT DEVICE
  Future<void> connectDevice(ScanResult result) async {
    BluetoothDevice device = result.device;

    // ❗ Prevent duplicate connections
    if (connectedDevices.any((d) => d.id == device.remoteId.str)) return;
    await FlutterBluePlus.stopScan();
    try {
      await device.connect();
    } catch (e) {
      // already connected or failed
    }

    BleDeviceModel model = BleDeviceModel(
      device: device,
      name: device.platformName.isNotEmpty ? device.platformName : "Unknown Device",
      id: device.remoteId.str,
    );

    model.isConnected = true;

    connectedDevices.add(model);
    notifyListeners();

    await discoverServices(model);
  }

  // 🔍 DISCOVER SERVICES WITH UUID MATCHING
  Future<void> discoverServices(BleDeviceModel model) async {
    List<BluetoothService> services =
    await model.device.discoverServices();

    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() ==
              CHARACTERISTIC_UUID.toLowerCase()) {
            model.characteristic = char;

            await char.setNotifyValue(true);

            listenToDevice(model);

            notifyListeners();
            return;
          }
        }
      }
    }
  }

  // 📥 LISTEN TO DEVICE DATA
  void listenToDevice(BleDeviceModel model) {
    model.characteristic?.onValueReceived.listen((value) {
      String data = String.fromCharCodes(value);

      parseData(model, data);
      notifyListeners();
    });
  }

  // 🧠 PARSE DATA (TEMP + BATTERY)
  void parseData(BleDeviceModel model, String data) {
    // Example format: TEMP:45,BAT:78

    List<String> parts = data.split(",");

    for (var part in parts) {
      if (part.contains("TEMP")) {
        model.temperature =
            double.tryParse(part.split(":")[1]) ?? 0;
      }

      if (part.contains("BAT")) {
        model.battery =
            int.tryParse(part.split(":")[1]) ?? 0;
      }
    }
  }

  // 🔘 SEND COMMAND (ON / OFF)
  Future<void> sendCommand(BleDeviceModel model, String command) async {
    if (model.characteristic == null) return;

    await model.characteristic!.write(command.codeUnits);
  }

  // ❌ DISCONNECT DEVICE
  Future<void> disconnectDevice(BleDeviceModel model) async {
    await model.device.disconnect();
    model.isConnected = false;
    connectedDevices.remove(model);
    notifyListeners();
  }
}