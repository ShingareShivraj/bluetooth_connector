import 'package:flutter/foundation.dart';

import 'classic_bluetooth_service.dart';

enum TemperatureMode {
  coolAndCozy(47, 'Cool & Cozy'),
  perfectSip(52, 'Perfect Sip'),
  warmAndRich(57, 'Warm & Rich'),
  extraHot(62, 'Extra Hot');

  const TemperatureMode(this.espValue, this.label);

  final int espValue;
  final String label;

  static TemperatureMode fromTemperature(num value) {
    if (value < 50) return TemperatureMode.coolAndCozy;
    if (value < 55) return TemperatureMode.perfectSip;
    if (value < 60) return TemperatureMode.warmAndRich;
    return TemperatureMode.extraHot;
  }
}

class DeviceService extends ChangeNotifier {
  DeviceService(this.bluetoothService) {
    bluetoothService.addListener(_handleBluetoothUpdate);
  }

  final ClassicBluetoothService bluetoothService;
  ClassicDeviceModel? _selectedDevice;

  ClassicDeviceModel? get selectedDevice => _selectedDevice;

  // Compatibility setter for the current Home screen. The updated screen
  // should use selectDevice() and must not assign state inside build().
  set selectedDevice(ClassicDeviceModel? value) {
    if (identical(_selectedDevice, value)) return;
    _selectedDevice = value;
  }

  // These values come directly from the selected Bluetooth model. They are
  // not duplicated inside DeviceService.
  double get temperature => _selectedDevice?.temperature ?? 0;
  int get battery => _selectedDevice?.battery ?? 0;
  double get targetTemperature => _selectedDevice?.setTemperature ?? 0;
  double get espSetTemperature => _selectedDevice?.setTemperature ?? 0;
  bool get isOn => _selectedDevice?.power == 1;
  bool get isDeviceConnected => _selectedDevice?.isConnected == true;
  bool get hasLiveTemperature => temperature > 0;
  String? get lastError => bluetoothService.lastError;

  TemperatureMode? get currentTemperatureMode =>
      hasLiveTemperature ? TemperatureMode.fromTemperature(temperature) : null;

  TemperatureMode get selectedTemperatureMode {
    if (targetTemperature <= 0) return TemperatureMode.perfectSip;
    return TemperatureMode.fromTemperature(targetTemperature);
  }

  // Temporary compatibility setters for the existing Home screen. Each one
  // forwards to the model, so there is still only one source of truth.
  set temperature(double value) {
    if (_selectedDevice != null) _selectedDevice!.temperature = value;
  }

  set battery(int value) {
    if (_selectedDevice != null) {
      _selectedDevice!.battery = value.clamp(0, 100).toInt();
    }
  }

  set targetTemperature(double value) {
    if (_selectedDevice != null) _selectedDevice!.setTemperature = value;
  }

  set espSetTemperature(double value) {
    if (_selectedDevice != null) _selectedDevice!.setTemperature = value;
  }

  set isOn(bool value) {
    if (_selectedDevice != null) _selectedDevice!.power = value ? 1 : 0;
  }

  set isDeviceConnected(bool value) {
    // Connection truth belongs to ClassicBluetoothService. This no-op setter
    // only keeps the old Home screen compiling until it is replaced.
  }

  void selectDevice(ClassicDeviceModel? device) {
    if (device != null &&
        !bluetoothService.connectedDevices.any(
              (item) => item.address == device.address && item.isConnected,
        )) {
      return;
    }
    if (identical(_selectedDevice, device)) return;
    _selectedDevice = device;
    notifyListeners();
  }

  void _handleBluetoothUpdate() {
    final selected = _selectedDevice;
    if (selected != null) {
      final matches = bluetoothService.connectedDevices.where(
            (item) => item.address == selected.address && item.isConnected,
      );
      _selectedDevice = matches.isEmpty ? null : matches.first;
    }
    notifyListeners();
  }

  /// Sends H:1 exactly. It does not depend on the currently displayed state.
  Future<bool> turnOn() => setPower(true);

  /// Sends H:0 exactly. It does not depend on the currently displayed state.
  Future<bool> turnOff() => setPower(false);

  /// Use this from Switch.onChanged so the value selected by the user is sent
  /// directly rather than calculating the opposite of a possibly stale state.
  Future<bool> setPower(bool enabled) async {
    debugPrint('DEVICE SERVICE: explicit power request = $enabled');
    return _setPower(enabled);
  }

  Future<bool> togglePower() async {
    print('');
    print('========== POWER BUTTON ===========');
    print('BUTTON PRESSED');
    print('CURRENT isOn: $isOn');
    print('CURRENT device.power: ${_selectedDevice?.power}');
    print('REQUESTED isOn: ${!isOn}');
    print('===================================');

    final result = await _setPower(!isOn);

    print('');
    print('========== POWER BUTTON RESULT =====');
    print('RESULT: $result');
    print('====================================');

    return result;
  }

  Future<bool> _setPower(bool enabled) async {
    final device = _selectedDevice;

    print('');
    print('========== DEVICE SERVICE POWER =====');
    print('REQUESTED ENABLED: $enabled');
    print('SELECTED DEVICE: ${device?.name}');
    print('DEVICE POWER: ${device?.power}');
    print('DEVICE CONNECTED: ${device?.isConnected}');
    print('=====================================');

    if (device == null) {
      print('POWER NOT SENT: No selected device');
      return false;
    }

    if (!device.isConnected) {
      print('POWER NOT SENT: Device is disconnected');
      return false;
    }

    final result = await bluetoothService.setPower(
      device,
      enabled,
    );

    print('POWER SET RESULT: $result');

    return result;
  }

  Future<bool> sendTemperatureMode(TemperatureMode mode) async {
    final device = _selectedDevice;
    debugPrint(
      'DEVICE SERVICE: ${mode.label} selected -> TAR:${mode.espValue}',
    );

    if (device == null || !device.isConnected) {
      debugPrint('TEMPERATURE NOT SENT: No connected selected device');
      return false;
    }

    // Send the enum's exact firmware value without deriving it from any
    // current target or live-temperature state.
    return bluetoothService.setTargetTemperature(
      device,
      mode.espValue.toDouble(),
    );
  }

  Future<bool> sendSetTemperature(double value) async {
    final device = _selectedDevice;
    if (device == null || !device.isConnected) return false;

    // Until the old continuous dial is replaced, normalize any dial value to
    // one of the four valid ESP values. The customer UI will use
    // sendTemperatureMode() directly.
    final mode = TemperatureMode.fromTemperature(value);
    return bluetoothService.setTargetTemperature(
      device,
      mode.espValue.toDouble(),
    );
  }

  Future<bool> disconnectSelected() async {
    final device = _selectedDevice;
    if (device == null) return true;

    final success = await bluetoothService.disconnectDevice(device);
    if (_selectedDevice?.address == device.address) {
      _selectedDevice = null;
      notifyListeners();
    }
    return success;
  }

  void clearError() => bluetoothService.clearError();

  @override
  void dispose() {
    bluetoothService.removeListener(_handleBluetoothUpdate);
    super.dispose();
  }
}
