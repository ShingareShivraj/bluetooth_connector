import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClassicDeviceModel {
  ClassicDeviceModel({
    required this.device,
    required this.name,
    required this.address,
  });

  final BluetoothDevice device;
  final String name;
  final String address;
  BluetoothConnection? connection;
  StreamSubscription<Uint8List>? inputSubscription;
  String buffer = '';
  double setTemperature = 0;
  double temperature = 0;
  int battery = 0;
  int power = 0;
  bool isConnected = false;
}

class ClassicBluetoothService extends ChangeNotifier {
  final List<BluetoothDevice> bondedDevices = [];
  final List<ClassicDeviceModel> connectedDevices = [];
  final List<BluetoothDiscoveryResult> discoveredDevices = [];

  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  Timer? _discoveryTimer;
  final Set<String> _connectingAddresses = <String>{};

  bool isDiscovering = false;
  String? lastError;

  // Persistent address of the last Garam Mug successfully connected by the
  // user. This survives Flutter screen/service recreation and app restarts.
  static const String _lastConnectedDeviceKey =
      'garam_mug_last_connected_device_address';

  String? _lastConnectedDeviceAddress;

  String? get lastConnectedDeviceAddress => _lastConnectedDeviceAddress;

  Future<void> loadLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastConnectedDeviceAddress =
          prefs.getString(_lastConnectedDeviceKey);

      debugPrint(
        'ClassicBluetoothService: saved last device = '
            '$_lastConnectedDeviceAddress',
      );
      notifyListeners();
    } catch (error) {
      debugPrint(
        'ClassicBluetoothService: unable to load last device: $error',
      );
    }
  }

  Future<void> _saveLastConnectedDevice(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastConnectedDeviceKey, address);
      _lastConnectedDeviceAddress = address;

      debugPrint(
        'ClassicBluetoothService: LAST CONNECTED DEVICE SAVED: $address',
      );
    } catch (error) {
      debugPrint(
        'ClassicBluetoothService: unable to save last device: $error',
      );
    }
  }

  Future<void> clearLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastConnectedDeviceKey);
      _lastConnectedDeviceAddress = null;
      notifyListeners();
    } catch (error) {
      debugPrint(
        'ClassicBluetoothService: unable to clear last device: $error',
      );
    }
  }

  Future<BluetoothDevice?> _discoverSavedDevice(String address) async {
    debugPrint('');
    debugPrint('========== FIND SAVED DEVICE ==========');
    debugPrint('ADDRESS: $address');
    debugPrint('MODE: TARGETED DISCOVERY');
    debugPrint('=======================================');

    await stopDiscovery(notify: false);

    discoveredDevices.clear();
    isDiscovering = true;
    notifyListeners();

    final completer = Completer<BluetoothDevice?>();
    StreamSubscription<BluetoothDiscoveryResult>? subscription;
    Timer? timer;

    void finish(BluetoothDevice? device) {
      if (completer.isCompleted) return;

      timer?.cancel();
      subscription?.cancel();

      isDiscovering = false;
      notifyListeners();

      completer.complete(device);
    }

    try {
      subscription =
          FlutterBluetoothSerial.instance.startDiscovery().listen(
                (result) {
              final discoveredAddress = result.device.address;

              debugPrint(
                'DISCOVERY DEVICE: '
                    '${result.device.name ?? 'Unknown'} '
                    '[$discoveredAddress]',
              );

              final index = discoveredDevices.indexWhere(
                    (item) => item.device.address == discoveredAddress,
              );

              if (index >= 0) {
                discoveredDevices[index] = result;
              } else {
                discoveredDevices.add(result);
              }

              notifyListeners();

              if (discoveredAddress.toUpperCase() == address.toUpperCase()) {
                debugPrint(
                  'SAVED DEVICE FOUND: $discoveredAddress',
                );

                finish(result.device);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'TARGETED DISCOVERY ERROR: $error',
              );

              finish(null);
            },
            onDone: () {
              finish(null);
            },
            cancelOnError: true,
          );

      timer = Timer(
        const Duration(seconds: 15),
            () {
          debugPrint(
            'TARGETED DISCOVERY TIMEOUT: $address',
          );

          finish(null);
        },
      );

      final device = await completer.future;

      return device;
    } catch (error) {
      debugPrint(
        'TARGETED DISCOVERY FAILED: $error',
      );

      await subscription?.cancel();
      timer?.cancel();

      isDiscovering = false;
      notifyListeners();

      return null;
    }
  }

  /// Reconnects the last successfully connected mug without starting a scan.
  /// The device must still be paired in Android.
  Future<bool> reconnectLastConnectedDevice() async {
    final address = _lastConnectedDeviceAddress;

    if (address == null || address.isEmpty) {
      debugPrint(
        'ClassicBluetoothService: no saved last connected device.',
      );
      return false;
    }

    debugPrint('');
    debugPrint('========== RESTORE LAST DEVICE ==========');
    debugPrint('SAVED ADDRESS: $address');
    debugPrint('=========================================');

    // ------------------------------------------------------------
    // STEP 1: If already connected, nothing else is required.
    // ------------------------------------------------------------

    final existing = connectedDeviceByAddress(address);

    if (existing != null &&
        existing.connection != null &&
        existing.connection!.isConnected) {
      debugPrint(
        'ClassicBluetoothService: saved device is already connected.',
      );

      return true;
    }

    // ------------------------------------------------------------
    // STEP 2: Refresh Android paired-device list.
    // ------------------------------------------------------------

    final loaded = await getBondedDevices();

    if (!loaded) {
      debugPrint(
        'ClassicBluetoothService: unable to refresh paired devices.',
      );
    }

    // ------------------------------------------------------------
    // STEP 3: Try to obtain the actual BluetoothDevice from
    // Android's paired list.
    // ------------------------------------------------------------

    BluetoothDevice? device = bondedDeviceByAddress(address);

    if (device != null) {
      debugPrint(
        'ClassicBluetoothService: saved device found in paired list.',
      );
    } else {
      // ----------------------------------------------------------
      // STEP 4: Device is not in the paired list.
      //
      // Do NOT create BluetoothDevice(address) and directly connect.
      // That was the approach that failed on your phone.
      //
      // Instead, discover the device and use the actual object
      // returned by Android discovery.
      // ----------------------------------------------------------

      debugPrint(
        'ClassicBluetoothService: saved device not in paired list.',
      );

      debugPrint(
        'ClassicBluetoothService: starting targeted discovery.',
      );

      device = await _discoverSavedDevice(address);

      if (device == null) {
        debugPrint(
          'ClassicBluetoothService: saved device was not found.',
        );

        return false;
      }
    }

    // ------------------------------------------------------------
    // STEP 5: Stop discovery before opening the RFCOMM connection.
    // ------------------------------------------------------------

    await stopDiscovery();

    debugPrint('');
    debugPrint('========== AUTO RECONNECT ==========');
    debugPrint('DEVICE: ${device.name ?? 'Garam Mug'}');
    debugPrint('ADDRESS: ${device.address}');
    debugPrint('MODE: DISCOVERED DEVICE');
    debugPrint('DISCOVERY: FINISHED');
    debugPrint('====================================');

    // ------------------------------------------------------------
    // STEP 6: First connection attempt.
    // ------------------------------------------------------------

    var success = await connectDevice(
      device,
      saveAsLastDevice: false,
    );

    if (success) {
      debugPrint(
        'ClassicBluetoothService: AUTO RECONNECT SUCCESS.',
      );

      return true;
    }

    // ------------------------------------------------------------
    // STEP 7: One controlled retry.
    // ------------------------------------------------------------

    debugPrint('');
    debugPrint('========== AUTO RECONNECT RETRY ==========');
    debugPrint('ADDRESS: ${device.address}');
    debugPrint('RETRY: 1');
    debugPrint('==========================================');

    await Future<void>.delayed(
      const Duration(milliseconds: 800),
    );

    success = await connectDevice(
      device,
      saveAsLastDevice: false,
    );

    if (success) {
      debugPrint(
        'ClassicBluetoothService: AUTO RECONNECT RETRY SUCCESS.',
      );

      return true;
    }

    debugPrint(
      'ClassicBluetoothService: AUTO RECONNECT FAILED.',
    );

    return false;
  }

  bool isConnecting(String address) => _connectingAddresses.contains(address);

  ClassicDeviceModel? connectedDeviceByAddress(String address) {
    for (final model in connectedDevices) {
      if (model.address == address && model.isConnected) {
        return model;
      }
    }
    return null;
  }

  BluetoothDevice? bondedDeviceByAddress(String address) {
    for (final device in bondedDevices) {
      if (device.address == address) return device;
    }
    return null;
  }

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    notifyListeners();
  }

  void _setError(Object error, String message) {
    lastError = message;
    print('ClassicBluetoothService: $error');
    notifyListeners();
  }

  Future<bool> getBondedDevices() async {
    try {
      final devices =
      await FlutterBluetoothSerial.instance.getBondedDevices();

      bondedDevices
        ..clear()
        ..addAll(devices);

      lastError = null;

      notifyListeners();
      return true;
    } catch (error) {
      _setError(
        error,
        'Unable to load paired Bluetooth devices.',
      );
      return false;
    }
  }

  Future<bool> connectDevice(
      BluetoothDevice device, {
        bool saveAsLastDevice = true,
      }) async {
    final existing = connectedDeviceByAddress(device.address);

    if (existing != null &&
        existing.connection != null &&
        existing.connection!.isConnected) {
      return true;
    }
    if (_connectingAddresses.contains(device.address)) return false;

    _connectingAddresses.add(device.address);
    lastError = null;
    notifyListeners();

    try {
      final connection =
      await BluetoothConnection.toAddress(device.address);

      final model = ClassicDeviceModel(
        device: device,
        name: device.name?.trim().isNotEmpty == true
            ? device.name!.trim()
            : 'Garam Mug',
        address: device.address,
      )
        ..connection = connection
        ..isConnected = connection.isConnected;

      connectedDevices.removeWhere(
            (item) => item.address == device.address,
      );
      connectedDevices.add(model);

      final input = connection.input;

      if (input != null) {
        model.inputSubscription = input.listen(
              (data) => _handleIncomingData(model, data),
          onError: (Object error, StackTrace stackTrace) {
            _setError(error, 'Bluetooth connection was interrupted.');
            _removeConnectedDevice(model);
          },
          onDone: () => _removeConnectedDevice(model),
          cancelOnError: true,
        );
      }

      if (!connection.isConnected) {
        _removeConnectedDevice(model);
        _setError(
          StateError('Bluetooth connection is not active.'),
          'The Bluetooth connection was not established.',
        );
        return false;
      }

      if (saveAsLastDevice) {
        await _saveLastConnectedDevice(device.address);
      }

      notifyListeners();
      return true;
    } catch (error) {
      _setError(error, 'Unable to connect to ${device.name ?? 'the mug'}.');
      return false;
    } finally {
      _connectingAddresses.remove(device.address);
      notifyListeners();
    }
  }

  void _handleIncomingData(
      ClassicDeviceModel model,
      Uint8List data,
      ) {
    if (!model.isConnected) {
      print('========== DEVICE → APP ==========');
      print('RECEIVED DATA BUT DEVICE IS NOT CONNECTED');
      print('==================================');
      return;
    }

    final incoming = utf8.decode(
      data,
      allowMalformed: true,
    );

    print('');
    print('========== DEVICE → APP ==========');
    print('RAW DATA RECEIVED: $incoming');
    print('==================================');

    model.buffer += incoming;

    while (model.buffer.contains('\n')) {
      final newlineIndex = model.buffer.indexOf('\n');

      final line = model.buffer
          .substring(0, newlineIndex)
          .trim();

      model.buffer = model.buffer.substring(newlineIndex + 1);

      if (line.isEmpty) continue;

      print('DEVICE MESSAGE: $line');

      if (line.startsWith('TEM:')) {
        print('MESSAGE TYPE: TEXT STATUS');
        _parseTextStatus(model, line);
      } else if (line.startsWith('{')) {
        print('MESSAGE TYPE: JSON');
        parseData(model, line);
      } else {
        print('MESSAGE TYPE: UNKNOWN');
      }
    }
  }
  void _parseTextStatus(ClassicDeviceModel model, String data) {
    try {
      final parts = data.split(',');

      for (final part in parts) {
        final separatorIndex = part.indexOf(':');
        if (separatorIndex == -1) continue;

        final key = part.substring(0, separatorIndex).trim();
        final value = part.substring(separatorIndex + 1).trim();

        switch (key) {
          case 'TEM':
            final temperature = double.tryParse(value);
            if (temperature != null) {
              model.temperature = temperature;
            }
            break;

          case 'B':
            final battery = int.tryParse(value);
            if (battery != null) {
              model.battery = battery.clamp(0, 100).toInt();
            }
            break;

          case 'H':
            final heater = int.tryParse(value);

            print('');
            print('========== HEATER STATUS ==========');
            print('H VALUE FROM DEVICE: $heater');

            if (heater == 1) {
              model.power = 1;
              print('HEATER STATUS: ON');
            } else if (heater == 0) {
              model.power = 0;
              print('HEATER STATUS: OFF');
            } else {
              print('INVALID H VALUE: $value');
            }

            print('MODEL POWER: ${model.power}');
            print('===================================');
            break;

          case 'TAR':
            final target = double.tryParse(value);
            if (target != null) {
              model.setTemperature = target;
            }
            break;
        }
      }

      print(
        'STATUS → TEMP:${model.temperature}, '
            'BAT:${model.battery}, '
            'POWER:${model.power}, '
            'TARGET:${model.setTemperature}',
      );

      lastError = null;
      notifyListeners();
    } catch (error) {
      print('Invalid ESP32 status: $data ($error)');
    }
  }

  void _parseCompleteJsonObjects(ClassicDeviceModel model) {
    while (true) {
      final start = model.buffer.indexOf('{');
      if (start < 0) {
        model.buffer = '';
        return;
      }
      if (start > 0) model.buffer = model.buffer.substring(start);

      var depth = 0;
      var inString = false;
      var escaped = false;
      var end = -1;

      for (var index = 0; index < model.buffer.length; index++) {
        final character = model.buffer[index];
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (character == '\\') {
            escaped = true;
          } else if (character == '"') {
            inString = false;
          }
          continue;
        }

        if (character == '"') {
          inString = true;
        } else if (character == '{') {
          depth++;
        } else if (character == '}') {
          depth--;
          if (depth == 0) {
            end = index;
            break;
          }
        }
      }

      if (end < 0) return;
      final jsonText = model.buffer.substring(0, end + 1);
      model.buffer = model.buffer.substring(end + 1);
      parseData(model, jsonText);
    }
  }

  void parseData(ClassicDeviceModel model, String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;

      final temp = decoded['temp'];
      final percentage = decoded['percentage'];
      final set = decoded['set'];
      final power = decoded['power'];

      if (temp is num) model.temperature = temp.toDouble();
      if (percentage is num) {
        model.battery = percentage.round().clamp(0, 100).toInt();
      }
      if (set is num) model.setTemperature = set.toDouble();
      if (power is num) model.power = power == 1 ? 1 : 0;

      lastError = null;
      notifyListeners();
    } catch (error) {
      print('Invalid ESP32 JSON: $data ($error)');
    }
  }
  Future<bool> sendCommand(
      ClassicDeviceModel model,
      String command,
      ) async {

    final cleanCommand = command.trim();

    print('');
    print('========== APP → DEVICE ==========');
    print('DEVICE: ${model.name}');
    print('CONNECTED: ${model.isConnected}');
    print('COMMAND: $cleanCommand');
    print('==================================');

    final connection = model.connection;

    if (!model.isConnected ||
        connection == null ||
        !connection.isConnected) {

      print('');
      print('========== COMMAND NOT SENT ==========');
      print('REASON: Device is not connected');
      print('======================================');

      _setError(
        StateError('Device is not connected.'),
        'The mug is disconnected.',
      );

      return false;
    }

    try {
      // The ESP32 firmware uses readStringUntil('\n'), so every command must
      // finish with exactly one newline. Send an explicit Uint8List because
      // flutter_bluetooth_serial writes raw bytes.
      final fullCommand = '$cleanCommand\n';
      final bytes = Uint8List.fromList(utf8.encode(fullCommand));

      print('');
      print('========== BLUETOOTH WRITE ==========');
      print('TEXT: ${fullCommand.replaceAll('\n', r'\n')}');
      print('BYTES: ${bytes.join(',')}');
      print(
        'HEX: ${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      print('=====================================');

      connection.output.add(bytes);

      await connection.output.allSent;

      print('');
      print('========== SEND SUCCESS =============');
      print('COMMAND SENT: $cleanCommand');
      print('BYTE COUNT: ${bytes.length}');
      print('=====================================');

      lastError = null;
      return true;

    } catch (error) {

      print('');
      print('========== SEND FAILED ==============');
      print('COMMAND: $cleanCommand');
      print('ERROR: $error');
      print('=====================================');

      _setError(
        error,
        'Unable to send the command to the mug.',
      );

      return false;
    }
  }

  Future<bool> setPower(
      ClassicDeviceModel model,
      bool enabled,
      ) async {

    final powerValue = enabled ? 1 : 0;

    // ESP32 expects:
    // H:1 = Heater ON
    // H:0 = Heater OFF
    final command = 'H:$powerValue';

    print('');
    print('========== POWER COMMAND ===========');
    print('ENABLED: $enabled');
    print('POWER VALUE: $powerValue');
    print('COMMAND CREATED: $command');
    print('====================================');

    final success = await sendCommand(
      model,
      command,
    );

    print('');
    print('========== POWER RESULT ============');
    print('SUCCESS: $success');
    print('====================================');

    // Do not update model.power here. The ESP32 response is the source of
    // truth and _parseTextStatus() will update it from H:1 or H:0.

    return success;
  }


  Future<bool> setTargetTemperature(
      ClassicDeviceModel model,
      double value,
      ) async {

    final temperature = value.round();

    // ESP32 expects TAR:<temperature>
    // Example: TAR:47
    final command = 'TAR:$temperature';

    print('');
    print('========== TEMPERATURE COMMAND =====');
    print('TARGET TEMPERATURE: $temperature');
    print('COMMAND CREATED: $command');
    print('====================================');

    final success = await sendCommand(
      model,
      command,
    );

    print('');
    print('========== TEMPERATURE RESULT ======');
    print('SUCCESS: $success');
    print('====================================');

    // Do not update model.setTemperature here. Wait for the ESP32 TAR value
    // so the selected preference always represents confirmed device state.

    return success;
  }

  Future<bool> disconnectDevice(ClassicDeviceModel model) async {
    try {
      await model.inputSubscription?.cancel();
      model.inputSubscription = null;

      await model.connection?.close();
      model.connection = null;
      model.isConnected = false;

      connectedDevices.removeWhere(
            (item) => item.address == model.address,
      );

      if (model.address == _lastConnectedDeviceAddress) {
        await clearLastConnectedDevice();
      }

      notifyListeners();
      return true;
    } catch (error) {
      _removeConnectedDevice(
        model,
        errorMessage: 'Unable to disconnect the mug cleanly.',
        error: error,
      );
      return false;
    }
  }

  void _removeConnectedDevice(
      ClassicDeviceModel model, {
        String? errorMessage,
        Object? error,
      }) {
    model.isConnected = false;

    final subscription = model.inputSubscription;
    model.inputSubscription = null;
    unawaited(subscription?.cancel());

    model.connection = null;

    connectedDevices.removeWhere(
          (item) => item.address == model.address,
    );

    if (errorMessage != null) {
      lastError = errorMessage;
      if (error != null) {
        debugPrint('ClassicBluetoothService: $error');
      }
    }

    notifyListeners();
  }

  /// Starts discovery only when the UI explicitly asks for it.
  /// The service never starts discovery from its constructor or automatically.
  Future<bool> startDiscovery() async {
    try {
      var enabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!enabled) {
        await FlutterBluetoothSerial.instance.requestEnable();
        enabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      }
      if (!enabled) {
        _setError(StateError('Bluetooth is disabled.'), 'Please turn on Bluetooth.');
        return false;
      }

      await stopDiscovery(notify: false);
      if (!await getBondedDevices()) return false;

      discoveredDevices.clear();
      isDiscovering = true;
      lastError = null;
      notifyListeners();

      _discoverySubscription =
          FlutterBluetoothSerial.instance.startDiscovery().listen(
                (result) {
              final index = discoveredDevices.indexWhere(
                    (item) => item.device.address == result.device.address,
              );
              if (index >= 0) {
                discoveredDevices[index] = result;
              } else {
                discoveredDevices.add(result);
              }
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              _setError(error, 'Bluetooth device discovery failed.');
              unawaited(stopDiscovery());
            },
            onDone: _finishDiscovery,
            cancelOnError: true,
          );

      _discoveryTimer = Timer(
        const Duration(seconds: 15),
            () => unawaited(stopDiscovery()),
      );
      return true;
    } catch (error) {
      await stopDiscovery(notify: false);
      _setError(error, 'Unable to scan for nearby Bluetooth devices.');
      return false;
    }
  }

  void _finishDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _discoverySubscription = null;
    if (!isDiscovering) return;
    isDiscovering = false;
    notifyListeners();
  }

  Future<void> stopDiscovery({bool notify = true}) async {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    final changed = isDiscovering;
    isDiscovering = false;
    if (notify && changed) notifyListeners();
  }

  Future<bool> refreshDevices() => startDiscovery();

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _discoverySubscription?.cancel();

    // Do NOT dispose live Bluetooth connections here.
    //
    // This service is intended to be app-level/shared. Leaving a screen must
    // not disconnect the Garam Mug. Explicit user disconnect is handled by
    // disconnectDevice().
    //
    // If Android actually kills the process/native Bluetooth engine, the live
    // socket can still be lost. The saved address lets the app reconnect when
    // it starts again.
    super.dispose();
  }
}
