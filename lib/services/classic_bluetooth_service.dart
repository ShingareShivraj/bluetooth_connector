import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:convert';

class ClassicDeviceModel {
  BluetoothDevice device;
  BluetoothConnection? connection;
  String buffer = "";
  String name;
  String address;
  double setTemperature = 0;
  bool isConnected = false;

  double temperature = 0;
  int battery = 0;

  ClassicDeviceModel({
    required this.device,
    required this.name,
    required this.address,
  });
}

class ClassicBluetoothService extends ChangeNotifier {
  List<BluetoothDevice> bondedDevices = [];
  List<ClassicDeviceModel> connectedDevices = [];
  String _buffer = "";
  /// 🔍 GET PAIRED DEVICES
  Future<void> getBondedDevices() async {
    bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    notifyListeners();
  }

  /// 🔗 CONNECT
  Future<void> connectDevice(BluetoothDevice device) async {
    // Prevent duplicate connection
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

      // 🔥 ADD FIRST
      connectedDevices.add(model);
      notifyListeners();

      // 🔥 SINGLE LISTENER ONLY (IMPORTANT)
      connection.input?.listen(
            (data) {
          try {
            String chunk = utf8.decode(data);

            // 🔥 Append safely
            model.buffer += chunk;



// 🔥 Try to decode ONLY if full JSON exists
            int start = model.buffer.indexOf("{");
            int end = model.buffer.lastIndexOf("}");

            if (start != -1 && end != -1 && end > start) {
              String jsonString = model.buffer.substring(start, end + 1);

              try {
                print("📥 JSON: $jsonString");
                parseData(model, jsonString);
              } catch (e) {
                print("❌ JSON Parse Error: $e");
              }

              // clear buffer after processing
              model.buffer = "";
            }
            notifyListeners();
          } catch (e) {
            print("❌ Stream error: $e");
          }
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

      if (jsonData["temp"] != null) {
        model.temperature = (jsonData["temp"] as num).toDouble();
      }

      if (jsonData["battery"] != null) {
        model.battery = jsonData["battery"];
      }

      if (jsonData["set"] != null) {
        model.setTemperature = (jsonData["set"] as num).toDouble();
      }

    } catch (e) {
      print("❌ JSON Parse Error: $e");
    }
  }

  /// 🔘 SEND COMMAND
  Future<void> sendCommand(
      ClassicDeviceModel model,
      String command,
      ) async {
    model.connection?.output.add(utf8.encode(command));
    await model.connection?.output.allSent;

    print("📤 Sent: $command");
  }
  /// ❌ DISCONNECT
  Future<void> disconnectDevice(ClassicDeviceModel model) async {
    await model.connection?.close();
    connectedDevices.remove(model);
    notifyListeners();
  }


  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStream;

  List<BluetoothDiscoveryResult> discoveredDevices = [];

  bool isDiscovering = false;

  /// 🔍 START DISCOVERY (NEW DEVICES)
  void startDiscovery() {
    discoveredDevices.clear();
    isDiscovering = true;
    notifyListeners();

    _discoveryStream =
        FlutterBluetoothSerial.instance.startDiscovery().listen((result) {

          final existingIndex = discoveredDevices.indexWhere(
                  (d) => d.device.address == result.device.address);

          if (existingIndex >= 0) {
            discoveredDevices[existingIndex] = result;
          } else {
            discoveredDevices.add(result);
          }

          notifyListeners();
        });

    _discoveryStream?.onDone(() {
      isDiscovering = false;
      notifyListeners();
    });
  }
}