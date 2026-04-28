import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class ClassicDeviceModel {
  BluetoothDevice device;
  BluetoothConnection? connection;
  String buffer = "";
  String name;
  String address;

  double setTemperature = 0;
  double temperature = 0;
  int battery = 0;

  bool isConnected = false;

  ClassicDeviceModel({
    required this.device,
    required this.name,
    required this.address,
  });
}

class ClassicBluetoothService extends ChangeNotifier {
  List<BluetoothDevice> bondedDevices = [];
  List<ClassicDeviceModel> connectedDevices = [];

  /// 🔍 GET PAIRED DEVICES (INSTANT)
  Future<void> getBondedDevices() async {
    try {
      bondedDevices =
      await FlutterBluetoothSerial.instance.getBondedDevices();
      notifyListeners();
    } catch (e) {
      print("❌ Bonded devices error: $e");
    }
  }

  /// 🔗 CONNECT DEVICE
  Future<void> connectDevice(BluetoothDevice device) async {
    if (connectedDevices.any((d) => d.address == device.address)) return;

    try {
      BluetoothConnection connection =
      await BluetoothConnection.toAddress(device.address);

      ClassicDeviceModel model = ClassicDeviceModel(
        device: device,
        name: device.name ?? "Unknown",
        address: device.address,
      );

      model.connection = connection;
      model.isConnected = true;

      connectedDevices.add(model);
      notifyListeners();

      // 🔥 SINGLE STREAM LISTENER
      connection.input?.listen(
            (data) {
          try {
            String chunk = utf8.decode(data);
            model.buffer += chunk;

            int start = model.buffer.indexOf("{");
            int end = model.buffer.lastIndexOf("}");

            if (start != -1 && end != -1 && end > start) {
              String jsonString =
              model.buffer.substring(start, end + 1);

              try {
                print("📥 JSON: $jsonString");
                parseData(model, jsonString);
              } catch (e) {
                print("❌ JSON Parse Error: $e");
              }

              model.buffer = "";
              notifyListeners();
            }
          } catch (e) {
            print("❌ Stream error: $e");
          }
        },
        onDone: () {
          model.isConnected = false;
          connectedDevices.removeWhere(
                  (d) => d.address == model.address);
          notifyListeners();
        },
      );
    } catch (e) {
      print("❌ Connection failed: $e");
    }
  }

  /// 🧠 PARSE DATA
  void parseData(ClassicDeviceModel model, String data) {
    try {
      if (data.trim().isEmpty) return;

      final jsonData = jsonDecode(data);

      model.temperature =
          (jsonData["temp"] ?? 0).toDouble();
      model.battery = jsonData["battery"] ?? 0;
      model.setTemperature =
          (jsonData["set"] ?? 0).toDouble();
    } catch (e) {
      print("❌ JSON Parse Error: $e");
    }
  }

  /// 🔘 SEND COMMAND
  Future<void> sendCommand(
      ClassicDeviceModel model, String command) async {
    try {
      model.connection?.output.add(utf8.encode(command));
      await model.connection?.output.allSent;
      print("📤 Sent: $command");
    } catch (e) {
      print("❌ Send failed: $e");
    }
  }

  /// ❌ DISCONNECT
  Future<void> disconnectDevice(ClassicDeviceModel model) async {
    try {
      await model.connection?.close();
    } catch (_) {}

    connectedDevices.removeWhere(
            (d) => d.address == model.address);

    notifyListeners();
  }

  /// 🔍 DISCOVERY SYSTEM
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStream;

  List<BluetoothDiscoveryResult> discoveredDevices = [];
  bool isDiscovering = false;

  /// 🔍 START DISCOVERY (FIXED)
  Future<void> startDiscovery() async {
    try {
      bool isEnabled =
          await FlutterBluetoothSerial.instance.isEnabled ?? false;

      if (!isEnabled) {
        await FlutterBluetoothSerial.instance.requestEnable();
        return;
      }

      // 👉 ADD THIS SAFETY CHECK
      try {
        await FlutterBluetoothSerial.instance.getBondedDevices();
      } catch (e) {
        print("❌ Permission not granted");
        return; // 🚫 STOP instead of crash
      }

      await _discoveryStream?.cancel();

      await getBondedDevices();

      discoveredDevices.clear();
      isDiscovering = true;
      notifyListeners();

      _discoveryStream =
          FlutterBluetoothSerial.instance.startDiscovery().listen(
                (result) {
              final index = discoveredDevices.indexWhere(
                      (d) => d.device.address == result.device.address);

              if (index >= 0) {
                discoveredDevices[index] = result;
              } else {
                discoveredDevices.add(result);
              }

              notifyListeners();
            },
          );

      Future.delayed(const Duration(seconds: 15), () async {
        await _discoveryStream?.cancel();
        isDiscovering = false;
        notifyListeners();
      });

    } catch (e) {
      print("❌ Discovery error: $e");
    }
  }

  /// 🔁 MANUAL REFRESH (CALL FROM UI)
  Future<void> refreshDevices() async {
    await startDiscovery();
  }

  @override
  void dispose() {
    _discoveryStream?.cancel();
    super.dispose();
  }
}