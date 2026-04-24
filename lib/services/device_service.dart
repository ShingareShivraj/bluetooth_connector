import 'package:flutter/material.dart';
import 'classic_bluetooth_service.dart';

class DeviceService extends ChangeNotifier {
  final ClassicBluetoothService bluetoothService;

  DeviceService(this.bluetoothService) {


  }

  ClassicDeviceModel? selectedDevice;

  bool isOn = false;
  double setTemperature = 0;
  double temperature = 0;
  int battery = 0;
  bool isDeviceConnected = false;
  /// 🔽 SELECT DEVICE
  void selectDevice(ClassicDeviceModel? device) {
    selectedDevice = device;

    if (device != null) {
      temperature = device.temperature;
      battery = device.battery;
      setTemperature = device.setTemperature;
    }

    notifyListeners();
  }

  /// 🔘 TURN ON
  Future<void> turnOn() async {
    if (selectedDevice == null) return;

    isOn = true;
    notifyListeners();

    await bluetoothService.sendCommand(selectedDevice!, '{"power":1}');
  }

  Future<void> turnOff() async {
    if (selectedDevice == null) return;

    isOn = false;
    notifyListeners();

    await bluetoothService.sendCommand(selectedDevice!, '{"power":0}');
  }

  Future<void> togglePower() async {
    if (selectedDevice == null) return;

    isOn = !isOn;
    notifyListeners();

    String command = isOn ? '{"power":1}' : '{"power":0}';

    await bluetoothService.sendCommand(selectedDevice!, command);
  }

  Future<void> sendSetTemperature(double value) async {
    if (selectedDevice == null) return;

    setTemperature = value;
    notifyListeners();

    await bluetoothService.sendCommand(
      selectedDevice!,
      '{"set":${value.toInt()}}',
    );
  }

  /// 📥 SYNC DATA FROM BLE DEVICE

  /// 🔄 AUTO SYNC (CALL PERIODICALLY OR AFTER DATA CHANGE)
  // void refresh() {
  //   syncFromDevice();
  // }

  /// ❌ DISCONNECT SELECTED DEVICE
  Future<void> disconnectSelected() async {
    if (selectedDevice == null) return;

    await bluetoothService.disconnectDevice(selectedDevice!);

    selectedDevice = null;
    isOn = false;
    temperature = 0;
    battery = 0;

    notifyListeners();
  }


  @override
  void dispose() {


    super.dispose();
  }
}