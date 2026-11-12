import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
/// ============================================================
/// GARAM MUG - BLE SERVICE
/// ============================================================
///
/// This service replaces the old flutter_bluetooth_serial /
/// Bluetooth Classic implementation.
///
/// IMPORTANT:
/// - Discovery intentionally does NOT filter by Garam Mug UUID.
/// - Any BLE device found during scanning can be displayed and connected.
/// - The device can have any name (Garam Mug, XYZ, unnamed, etc.).
/// - Commands are sent as raw UTF-8 text to a writable BLE characteristic.
/// - Incoming BLE notifications are logged as RAW DATA.
/// - We do not require temperature/status data for a BLE connection.
///
/// The actual Garam Mug firmware UUIDs are used when they are available,
/// but the service can also connect to another BLE firmware and expose its
/// writable/notifiable characteristics.
///
/// Garam Mug UUIDs:
/// Service:       7d9b0001-7c4a-4e10-9a1b-000000000001
/// Device Info:   7d9b0002-7c4a-4e10-9a1b-000000000001
/// Status:        7d9b0003-7c4a-4e10-9a1b-000000000001
/// Command:       7d9b0004-7c4a-4e10-9a1b-000000000001
///
/// ============================================================

const String garamMugServiceUuid =
    '7d9b0001-7c4a-4e10-9a1b-000000000001';

const String garamMugDeviceInfoUuid =
    '7d9b0002-7c4a-4e10-9a1b-000000000001';

const String garamMugStatusUuid =
    '7d9b0003-7c4a-4e10-9a1b-000000000001';

const String garamMugCommandUuid =
    '7d9b0004-7c4a-4e10-9a1b-000000000001';

/// Keeps the device model independent from Bluetooth Classic.
///
/// `deviceId` is the BLE remoteId:
/// - Android: normally the Bluetooth MAC address.
/// - iOS: normally Apple's UUID-style identifier.
///
/// Do not treat this as a Bluetooth Classic address.
class BleDeviceModel {
  BleDeviceModel({
    required this.device,
    required this.name,
    required this.deviceId,
  });

  final BluetoothDevice device;

  /// Name shown in the scan screen.
  final String name;

  /// BLE remoteId used to reconnect to this device.
  final String deviceId;

  bool isConnected = false;

  /// All discovered GATT services.
  List<BluetoothService> services = [];

  /// All writable characteristics discovered on the device.
  final List<BluetoothCharacteristic> writableCharacteristics = [];

  /// All notify/read characteristics discovered on the device.
  final List<BluetoothCharacteristic> notifyCharacteristics = [];

  /// Preferred command characteristic.
  ///
  /// For the real Garam Mug firmware this should be COMMAND_UUID.
  /// For another BLE firmware, the service automatically selects a
  /// writable characteristic when possible.
  BluetoothCharacteristic? commandCharacteristic;

  /// Garam Mug status characteristic, when present.
  BluetoothCharacteristic? statusCharacteristic;

  /// Garam Mug device-info characteristic, when present.
  BluetoothCharacteristic? deviceInfoCharacteristic;

  /// Generic subscriptions for notification characteristics.
  final List<StreamSubscription<List<int>>> notificationSubscriptions = [];

  /// Raw incoming bytes/text are kept here for diagnostics and for the
  /// next stage of the app integration.
  String rawIncomingData = '';
  final Map<BluetoothCharacteristic, String> _statusJsonBuffers = {};

  /// Compatibility/state fields used by DeviceService and the UI.
  ///
  /// For Garam Mug BLE firmware, these are updated from the ESP32 status
  /// notification/read packet. For other BLE firmware they remain unchanged
  /// unless that firmware happens to use the same status format.
  double setTemperature = 0;
  double temperature = 0;
  int battery = 0;
  int power = 0;

  String get remoteId => device.remoteId.str;

  bool get hasWritableCharacteristic => writableCharacteristics.isNotEmpty;

  bool get hasNotifyCharacteristic => notifyCharacteristics.isNotEmpty;

  @override
  String toString() {
    return 'BleDeviceModel(name: $name, deviceId: $deviceId, '
        'connected: $isConnected)';
  }
}

class BleService extends ChangeNotifier {
  /// Devices currently visible during the latest BLE scan.
  final List<ScanResult> scanResults = [];

  /// Devices currently connected through this service.
  final List<BleDeviceModel> connectedDevices = [];

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  Timer? _scanTimer;

  final Set<String> _connectingDeviceIds = <String>{};

  bool isScanning = false;
  bool isBluetoothSupported = true;
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;

  String? lastError;

  /// Persist only the BLE remoteId.
  static const String _lastConnectedDeviceKey =
      'garam_mug_last_connected_ble_device_id';

  String? _lastConnectedDeviceId;

  String? get lastConnectedDeviceId => _lastConnectedDeviceId;

  BleService() {
    _listenToAdapterState();
  }

  // ============================================================
  // ADAPTER STATE
  // ============================================================

  void _listenToAdapterState() {
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
          adapterState = state;

          debugPrint(
            'BLE ADAPTER STATE: ${state.name}',
          );

          notifyListeners();
        });
  }

  Future<bool> ensureBluetoothReady() async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    try {
      isBluetoothSupported = await FlutterBluePlus.isSupported;
      if (!isBluetoothSupported) {
        return _bluetoothNotReady('Bluetooth LE is not supported on this device.');
      }

      if (isAndroid && !await _requestAndroidBlePermissions()) {
        return false;
      }

      var state = await _readBluetoothState();

      if (isAndroid && state == BluetoothAdapterState.off) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (error) {
          debugPrint('Bluetooth enable request failed: $error');
        }
        state = await _readBluetoothState();
      }

      adapterState = state;

      if (state == BluetoothAdapterState.unauthorized) {
        return _bluetoothNotReady(
          'Allow Bluetooth for Garam Mug in your phone settings, then try again.',
        );
      }

      if (state != BluetoothAdapterState.on) {
        return _bluetoothNotReady('Turn on Bluetooth and try again.');
      }

      return true;
    } on TimeoutException {
      return _bluetoothNotReady('Bluetooth is still starting. Try again.');
    } catch (error) {
      _setError(error, 'Unable to initialize Bluetooth LE.');
      return false;
    }
  }

  Future<BluetoothAdapterState> _readBluetoothState() {
    return FlutterBluePlus.adapterState
        .firstWhere(
          (state) =>
      state != BluetoothAdapterState.unknown &&
          state != BluetoothAdapterState.turningOn &&
          state != BluetoothAdapterState.turningOff,
    )
        .timeout(const Duration(seconds: 15));
  }

  Future<bool> _requestAndroidBlePermissions() async {
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

    if (sdk >= 31) {
      final statuses = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      if (statuses[Permission.bluetoothScan]?.isGranted == true &&
          statuses[Permission.bluetoothConnect]?.isGranted == true) {
        return true;
      }

      return _bluetoothNotReady(
        'Allow Nearby devices for Garam Mug, then try again.',
      );
    }

    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) return true;

    return _bluetoothNotReady(
      'Allow location permission to scan for mugs on this Android version.',
    );
  }

  bool _bluetoothNotReady(String message) {
    _setError(StateError(message), message);
    return false;
  }

  // ============================================================
  // PERSISTENT LAST DEVICE
  // ============================================================

  Future<void> loadLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _lastConnectedDeviceId =
          prefs.getString(_lastConnectedDeviceKey);

      debugPrint(
        'BleService: saved last BLE device = $_lastConnectedDeviceId',
      );

      notifyListeners();
    } catch (error) {
      debugPrint(
        'BleService: unable to load last BLE device: $error',
      );
    }
  }

  Future<void> _saveLastConnectedDevice(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _lastConnectedDeviceKey,
        deviceId,
      );

      _lastConnectedDeviceId = deviceId;

      debugPrint(
        'BleService: LAST BLE DEVICE SAVED: $deviceId',
      );
    } catch (error) {
      debugPrint(
        'BleService: unable to save last BLE device: $error',
      );
    }
  }

  Future<void> clearLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_lastConnectedDeviceKey);

      _lastConnectedDeviceId = null;

      debugPrint(
        'BleService: saved last BLE device cleared.',
      );

      notifyListeners();
    } catch (error) {
      debugPrint(
        'BleService: unable to clear last BLE device: $error',
      );
    }
  }

  // ============================================================
  // SCANNING
  // ============================================================

  /// Starts a normal BLE scan.
  ///
  /// IMPORTANT:
  /// There is intentionally NO service UUID filter here.
  ///
  /// This means:
  ///   Garam Mug
  ///   XYZ
  ///   MyTestDevice
  ///   unnamed BLE device
  ///   another BLE firmware
  ///
  /// can all appear in the scan results.
  Future<bool> startDiscovery({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final ready = await ensureBluetoothReady();

      if (!ready) {
        return false;
      }

      await stopDiscovery(notify: false);

      scanResults.clear();
      isScanning = true;
      lastError = null;

      notifyListeners();

      debugPrint('');
      debugPrint('========================================');
      debugPrint('             BLE SCAN STARTED');
      debugPrint('========================================');
      debugPrint('FILTER: NONE');
      debugPrint('MODE: SHOW ALL BLE DEVICES');
      debugPrint('TIMEOUT: ${timeout.inSeconds} seconds');
      debugPrint('========================================');

      _scanSubscription = FlutterBluePlus.scanResults.listen(
            (results) {
          _updateScanResults(results);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('BLE SCAN ERROR: $error');

          _setError(
            error,
            'BLE device discovery failed.',
          );

          unawaited(
            stopDiscovery(),
          );
        },
      );

      await FlutterBluePlus.startScan(
        timeout: timeout,
        // Deliberately no withServices filter.
      );

      _scanTimer = Timer(
        timeout,
            () => unawaited(stopDiscovery()),
      );

      return true;
    } catch (error) {
      await stopDiscovery(notify: false);

      _setError(
        error,
        'Unable to scan for nearby BLE devices.',
      );

      return false;
    }
  }

  void _updateScanResults(List<ScanResult> results) {
    final Map<String, ScanResult> unique = <String, ScanResult>{};

    // Keep previous results too, because FlutterBluePlus may deliver
    // incremental scan-result lists depending on the platform.
    for (final result in scanResults) {
      unique[result.device.remoteId.str] = result;
    }

    for (final result in results) {
      unique[result.device.remoteId.str] = result;

      final name = _displayName(result);

      debugPrint(
        'BLE DEVICE FOUND: $name '
            '[${result.device.remoteId.str}] '
            'RSSI=${result.rssi}',
      );
    }

    scanResults
      ..clear()
      ..addAll(unique.values);

    notifyListeners();
  }

  /// Returns the best name available from the advertisement/device.
  ///
  /// We do NOT require the name to contain "Garam Mug".
  String deviceNameFromScanResult(ScanResult result) {
    return _displayName(result);
  }

  String _displayName(ScanResult result) {
    final platformName = result.device.platformName.trim();

    if (platformName.isNotEmpty) {
      return platformName;
    }

    final advertisementName = result.advertisementData.advName.trim();

    if (advertisementName.isNotEmpty) {
      return advertisementName;
    }

    return 'Unknown BLE Device';
  }

  void stopDiscoverySync() {
    unawaited(stopDiscovery());
  }

  Future<void> stopDiscovery({bool notify = true}) async {
    _scanTimer?.cancel();
    _scanTimer = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (error) {
      debugPrint(
        'BLE stop scan error: $error',
      );
    }

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    final changed = isScanning;

    isScanning = false;

    if (changed && notify) {
      notifyListeners();
    }

    debugPrint(
      'BLE SCAN STOPPED',
    );
  }

  Future<bool> refreshDevices() => startDiscovery();

  // ============================================================
  // DEVICE LOOKUP
  // ============================================================

  BleDeviceModel? connectedDeviceById(String deviceId) {
    for (final model in connectedDevices) {
      if (model.deviceId == deviceId && model.isConnected) {
        return model;
      }
    }

    return null;
  }

  ScanResult? scannedDeviceById(String deviceId) {
    for (final result in scanResults) {
      if (result.device.remoteId.str == deviceId) {
        return result;
      }
    }

    return null;
  }

  bool isConnecting(String deviceId) {
    return _connectingDeviceIds.contains(deviceId);
  }

  // ============================================================
  // CONNECT
  // ============================================================

  /// Connects to any BLE device returned by scanning.
  ///
  /// No device name or service UUID is required.
  Future<bool> connectDevice(
      ScanResult result, {
        bool saveAsLastDevice = true,
      }) async {
    return connectBluetoothDevice(
      result.device,
      name: _displayName(result),
      saveAsLastDevice: saveAsLastDevice,
    );
  }

  /// Low-level BLE connection method.
  ///
  /// This accepts a BluetoothDevice directly so the saved-device reconnect
  /// path can use BluetoothDevice.fromId().
  Future<bool> connectBluetoothDevice(
      BluetoothDevice device, {
        String? name,
        bool saveAsLastDevice = true,
      }) async {
    final deviceId = device.remoteId.str;

    final existing = connectedDeviceById(deviceId);

    if (existing != null && existing.isConnected) {
      debugPrint(
        'BleService: device is already connected: $deviceId',
      );

      return true;
    }

    if (_connectingDeviceIds.contains(deviceId)) {
      debugPrint(
        'BleService: connection already in progress: $deviceId',
      );

      return false;
    }

    _connectingDeviceIds.add(deviceId);
    lastError = null;
    notifyListeners();

    try {
      await stopDiscovery(notify: false);

      debugPrint('');
      debugPrint('========================================');
      debugPrint('              BLE CONNECT');
      debugPrint('========================================');
      debugPrint('NAME: ${name ?? _safeDeviceName(device)}');
      debugPrint('REMOTE ID: $deviceId');
      debugPrint('========================================');

      // A short retry is useful when Android/iOS has just stopped scanning.
      try {
        await device.connect(
          timeout: const Duration(seconds: 15),
          autoConnect: false,
        );
      } catch (error) {
        debugPrint(
          'BLE FIRST CONNECT ATTEMPT FAILED: $error',
        );

        // If the platform reports that the device is already connected,
        // continue to service discovery.
        final currentState = await _safeConnectionState(device);

        if (currentState != BluetoothConnectionState.connected) {
          await Future<void>.delayed(
            const Duration(milliseconds: 800),
          );

          await device.connect(
            timeout: const Duration(seconds: 15),
            autoConnect: false,
          );
        }
      }

      final currentState = await _safeConnectionState(device);

      if (currentState != BluetoothConnectionState.connected) {
        _setError(
          StateError('BLE connection is not active.'),
          'The BLE connection was not established.',
        );

        return false;
      }

      final model = BleDeviceModel(
        device: device,
        name: name?.trim().isNotEmpty == true
            ? name!.trim()
            : _safeDeviceName(device),
        deviceId: deviceId,
      );

      model.isConnected = true;

      connectedDevices.removeWhere(
            (item) => item.deviceId == deviceId,
      );

      connectedDevices.add(model);

      notifyListeners();

      // GATT discovery is mandatory before we can send commands.
      final discovered = await discoverServices(model);

      if (!discovered) {
        _removeConnectedDevice(
          model,
          errorMessage:
          'Connected to the BLE device, but GATT services could not be discovered.',
        );

        try {
          await device.disconnect();
        } catch (_) {}

        return false;
      }

      if (saveAsLastDevice) {
        await _saveLastConnectedDevice(deviceId);
      }

      debugPrint('');
      debugPrint('========================================');
      debugPrint('          BLE CONNECT SUCCESS');
      debugPrint('========================================');
      debugPrint('NAME: ${model.name}');
      debugPrint('REMOTE ID: ${model.deviceId}');
      debugPrint(
        'SERVICES: ${model.services.length}',
      );
      debugPrint(
        'WRITABLE CHARACTERISTICS: '
            '${model.writableCharacteristics.length}',
      );
      debugPrint(
        'NOTIFY CHARACTERISTICS: '
            '${model.notifyCharacteristics.length}',
      );
      debugPrint(
        'COMMAND CHARACTERISTIC: '
            '${model.commandCharacteristic?.uuid}',
      );
      debugPrint('========================================');

      return true;
    } catch (error) {
      _setError(
        error,
        'Unable to connect to ${name ?? 'the BLE device'}.',
      );

      return false;
    } finally {
      _connectingDeviceIds.remove(deviceId);
      notifyListeners();
    }
  }

  String _safeDeviceName(BluetoothDevice device) {
    final platformName = device.platformName.trim();

    if (platformName.isNotEmpty) {
      return platformName;
    }

    return 'Unknown BLE Device';
  }

  Future<BluetoothConnectionState> _safeConnectionState(
      BluetoothDevice device,
      ) async {
    try {
      return await device.connectionState.first;
    } catch (_) {
      return BluetoothConnectionState.disconnected;
    }
  }

  // ============================================================
  // SERVICE / CHARACTERISTIC DISCOVERY
  // ============================================================

  Future<bool> discoverServices(BleDeviceModel model) async {
    try {
      debugPrint('');
      debugPrint('========================================');
      debugPrint('         BLE GATT DISCOVERY');
      debugPrint('========================================');
      debugPrint('DEVICE: ${model.name}');
      debugPrint('REMOTE ID: ${model.deviceId}');
      debugPrint('========================================');

      final services = await model.device.discoverServices();

      model.services = services;

      model.writableCharacteristics.clear();
      model.notifyCharacteristics.clear();

      model.commandCharacteristic = null;
      model.statusCharacteristic = null;
      model.deviceInfoCharacteristic = null;

      for (final service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();

        debugPrint(
          'BLE SERVICE: $serviceUuid',
        );

        for (final characteristic in service.characteristics) {
          final characteristicUuid =
          characteristic.uuid.toString().toLowerCase();

          final properties = characteristic.properties;

          debugPrint(
            '  CHARACTERISTIC: $characteristicUuid '
                'read=${properties.read} '
                'write=${properties.write} '
                'writeWithoutResponse=${properties.writeWithoutResponse} '
                'notify=${properties.notify} '
                'indicate=${properties.indicate}',
          );

          if (properties.write ||
              properties.writeWithoutResponse) {
            model.writableCharacteristics.add(
              characteristic,
            );
          }

          if (properties.notify ||
              properties.indicate) {
            model.notifyCharacteristics.add(
              characteristic,
            );
          }

          // Prefer the exact Garam Mug characteristics when the connected
          // firmware happens to be the Garam Mug BLE firmware.
          if (characteristicUuid == garamMugCommandUuid) {
            model.commandCharacteristic = characteristic;
          }

          if (characteristicUuid == garamMugStatusUuid) {
            model.statusCharacteristic = characteristic;
          }

          if (characteristicUuid == garamMugDeviceInfoUuid) {
            model.deviceInfoCharacteristic = characteristic;
          }
        }
      }

      // If this is another BLE firmware, there may be no Garam Mug UUID.
      // In that case select the first writable characteristic so the app can
      // still connect and send raw commands to the tester firmware.
      if (model.commandCharacteristic == null &&
          model.writableCharacteristics.isNotEmpty) {
        model.commandCharacteristic =
            model.writableCharacteristics.first;

        debugPrint(
          'BLE GENERIC COMMAND CHARACTERISTIC SELECTED: '
              '${model.commandCharacteristic!.uuid}',
        );
      }

      // Subscribe to every notify/indicate characteristic.
      //
      // This is intentionally generic. We do not assume that another
      // firmware calls its status characteristic "STATUS".
      for (final characteristic in model.notifyCharacteristics) {
        await _enableNotifications(
          model,
          characteristic,
        );
      }

      notifyListeners();

      return true;
    } catch (error) {
      debugPrint(
        'BLE GATT DISCOVERY FAILED: $error',
      );

      _setError(
        error,
        'Unable to discover BLE services.',
      );

      return false;
    }
  }

  Future<void> _enableNotifications(
      BleDeviceModel model,
      BluetoothCharacteristic characteristic,
      ) async {
    StreamSubscription<List<int>>? subscription;
    try {
      subscription = characteristic.onValueReceived.listen(
            (value) {
          _handleIncomingData(
            model,
            characteristic,
            value,
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            'BLE NOTIFICATION ERROR '
                '${characteristic.uuid}: $error',
          );
        },
      );

      model.notificationSubscriptions.add(subscription);
      await characteristic.setNotifyValue(true);

      debugPrint(
        'BLE NOTIFICATIONS ENABLED: ${characteristic.uuid}',
      );
    } catch (error) {
      if (subscription != null) {
        model.notificationSubscriptions.remove(subscription);
        await subscription.cancel();
      }
      model._statusJsonBuffers.remove(characteristic);
      debugPrint(
        'BLE NOTIFICATION ENABLE FAILED '
            '${characteristic.uuid}: $error',
      );
    }
  }

  // ============================================================
  // INCOMING BLE DATA
  // ============================================================

  /// BLE receive handler.
  ///
  /// This remains generic for other BLE firmware, but when the incoming
  /// packet matches the Garam Mug status format:
  ///
  ///   TEM:56.9,B:64,H:0,TAR:47
  ///
  /// we also update the compatibility fields on [BleDeviceModel]:
  ///   temperature
  ///   battery
  ///   power
  ///   setTemperature
  ///
  /// The ESP32 status packet is the source of truth. We do NOT optimistically
  /// change power/temperature state just because a command was written.
  void _handleIncomingData(
      BleDeviceModel model,
      BluetoothCharacteristic characteristic,
      List<int> value,
      ) {
    final bytes = List<int>.from(value);

    final text = utf8.decode(
      bytes,
      allowMalformed: true,
    );

    model.rawIncomingData += text;

    debugPrint('');
    debugPrint('========== BLE DEVICE → APP ==========');
    debugPrint('DEVICE: ${model.name}');
    debugPrint('CHARACTERISTIC: ${characteristic.uuid}');
    debugPrint('BYTE COUNT: ${bytes.length}');
    debugPrint('BYTES: ${bytes.join(',')}');
    debugPrint(
      'HEX: ${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    debugPrint('TEXT: $text');
    debugPrint('======================================');

    // Match the payload format, regardless of the notification UUID.
    if (text.trimLeft().startsWith('TEM:')) {
      model._statusJsonBuffers.remove(characteristic);
      _parseGaramMugStatus(model, text);
    } else if (model._statusJsonBuffers.containsKey(characteristic) ||
        text.trimLeft().startsWith('{')) {
      _receiveJsonStatus(model, characteristic, text);
    }

    // This is important: DeviceService/UI listeners must be notified after
    // the model fields have been updated.
    notifyListeners();
  }

  /// Accepts a complete JSON notification or a newline-delimited JSON line
  /// split across notifications. The keys match the Classic service.
  void _receiveJsonStatus(
      BleDeviceModel model,
      BluetoothCharacteristic characteristic,
      String text,
      ) {
    const maxStatusLength = 1024;
    var pending = (model._statusJsonBuffers[characteristic] ?? '') + text;
    var newline = pending.indexOf('\n');
    while (newline >= 0) {
      final line = pending.substring(0, newline).trim();
      if (line.isNotEmpty && line.length <= maxStatusLength) {
        _applyJsonStatus(model, line);
      }
      pending = pending.substring(newline + 1);
      newline = pending.indexOf('\n');
    }

    pending = pending.trimLeft();
    if (pending.length > maxStatusLength ||
        !pending.startsWith('{') ||
        _applyJsonStatus(model, pending)) {
      model._statusJsonBuffers.remove(characteristic);
    } else {
      model._statusJsonBuffers[characteristic] = pending;
    }
  }

  // Returns false only when the JSON could not be decoded.
  bool _applyJsonStatus(BleDeviceModel model, String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return false;
    }
    if (decoded is! Map<String, dynamic>) return true;

    final temp = decoded['temp'];
    final percentage = decoded['percentage'];
    final set = decoded['set'];
    final power = decoded['power'];

    if (temp is num && temp.isFinite) model.temperature = temp.toDouble();
    if (percentage is num && percentage.isFinite) {
      model.battery = percentage.round().clamp(0, 100).toInt();
    }
    if (set is num && set.isFinite) model.setTemperature = set.toDouble();
    if (power == 0 || power == 1) model.power = power == 1 ? 1 : 0;

    return true;
  }

  /// Parses the Garam Mug status packet:
  ///
  ///   TEM:57.3,B:64,H:1,TAR:62
  ///
  /// The parser is deliberately strict enough to avoid treating arbitrary
  /// BLE data from a tester device as Garam Mug state, while still allowing
  /// the overall BLE service to remain fully generic.
  void _parseGaramMugStatus(
      BleDeviceModel model,
      String incomingText,
      ) {
    final text = incomingText.trim();

    if (text.isEmpty) {
      return;
    }

    // The firmware sends one complete status line per notification.
    // Also tolerate CR/LF and surrounding whitespace.
    final normalized = text
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .trim();

    if (!normalized.startsWith('TEM:') ||
        !normalized.contains(',B:') ||
        !normalized.contains(',H:') ||
        !normalized.contains(',TAR:')) {
      return;
    }

    try {
      final parts = normalized.split(',');

      if (parts.length < 4) {
        return;
      }

      double? temperature;
      int? battery;
      int? power;
      double? targetTemperature;

      for (final part in parts) {
        final separatorIndex = part.indexOf(':');

        if (separatorIndex <= 0 ||
            separatorIndex >= part.length - 1) {
          continue;
        }

        final key = part
            .substring(0, separatorIndex)
            .trim()
            .toUpperCase();

        final value = part
            .substring(separatorIndex + 1)
            .trim();

        switch (key) {
          case 'TEM':
            temperature = double.tryParse(value);
            break;

          case 'B':
            battery = int.tryParse(value);
            break;

          case 'H':
            power = int.tryParse(value);
            break;

          case 'TAR':
            targetTemperature = double.tryParse(value);
            break;
        }
      }

      // A valid status packet must contain all four values.
      if (temperature == null ||
          battery == null ||
          power == null ||
          targetTemperature == null) {
        debugPrint(
          'BLE STATUS PARSE IGNORED: incomplete Garam Mug status: $normalized',
        );
        return;
      }

      // Validate the values before putting them into app state.
      if (!temperature.isFinite ||
          !targetTemperature.isFinite ||
          battery < 0 ||
          battery > 100 ||
          (power != 0 && power != 1)) {
        debugPrint(
          'BLE STATUS PARSE IGNORED: invalid values: $normalized',
        );
        return;
      }

      model.temperature = temperature;
      model.battery = battery;
      model.power = power;
      model.setTemperature = targetTemperature;

      debugPrint('');
      debugPrint('========== GARAm MUG STATUS ===========');
      debugPrint('DEVICE: ${model.name}');
      debugPrint('TEMPERATURE: ${model.temperature}°C');
      debugPrint('BATTERY: ${model.battery}%');
      debugPrint(
        'POWER: ${model.power == 1 ? 'ON' : 'OFF'} (${model.power})',
      );
      debugPrint('TARGET: ${model.setTemperature}°C');
      debugPrint('=======================================');
    } catch (error) {
      debugPrint(
        'BLE STATUS PARSE ERROR: $error',
      );
    }
  }

  // ============================================================
  // RAW COMMAND SENDING
  // ============================================================

  /// Sends a JSON object as UTF-8, followed by one newline.
  ///
  /// If [characteristic] is omitted, uses the discovered command characteristic.
  Future<bool> sendCommand(
      BleDeviceModel model,
      String command, {
        BluetoothCharacteristic? characteristic,
        bool? withoutResponse,
      }) async {
    final cleanCommand = command.trim();

    debugPrint('');
    debugPrint('========== APP → BLE DEVICE ==========');
    debugPrint('DEVICE: ${model.name}');
    debugPrint('REMOTE ID: ${model.deviceId}');
    debugPrint('CONNECTED: ${model.isConnected}');
    debugPrint('COMMAND: $cleanCommand');
    debugPrint('======================================');

    if (!model.isConnected) {
      _setError(
        StateError('BLE device is not connected.'),
        'The BLE device is disconnected.',
      );

      return false;
    }

    late final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(cleanCommand);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        throw const FormatException('Expected a non-empty JSON object.');
      }
      payload = decoded;
    } on FormatException catch (error) {
      _setError(error, 'The mug command must be a JSON object.');
      return false;
    }

    final target =
        characteristic ?? model.commandCharacteristic;

    if (target == null) {
      _setError(
        StateError('No writable BLE characteristic found.'),
        'No writable BLE characteristic was found on this device.',
      );

      debugPrint(
        'BLE COMMAND NOT SENT: No writable characteristic.',
      );

      return false;
    }

    final bytes = utf8.encode('${jsonEncode(payload)}\n');

    final canWriteWithResponse =
        target.properties.write;

    final canWriteWithoutResponse =
        target.properties.writeWithoutResponse;

    if (!canWriteWithResponse &&
        !canWriteWithoutResponse) {
      _setError(
        StateError(
          'Characteristic ${target.uuid} is not writable.',
        ),
        'The selected BLE characteristic cannot receive commands.',
      );

      return false;
    }

    final useWithoutResponse =
        withoutResponse ??
            (!canWriteWithResponse && canWriteWithoutResponse);

    try {
      debugPrint('');
      debugPrint('========== BLE WRITE =================');
      debugPrint('CHARACTERISTIC: ${target.uuid}');
      debugPrint('WITHOUT RESPONSE: $useWithoutResponse');
      debugPrint('TEXT: $cleanCommand');
      debugPrint('BYTES: ${bytes.join(',')}');
      debugPrint(
        'HEX: ${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      debugPrint('======================================');

      await target.write(
        bytes,
        withoutResponse: useWithoutResponse,
      );

      debugPrint('');
      debugPrint('========== BLE SEND SUCCESS ==========');
      debugPrint('COMMAND SENT: $cleanCommand');
      debugPrint('CHARACTERISTIC: ${target.uuid}');
      debugPrint('BYTE COUNT: ${bytes.length}');
      debugPrint('======================================');

      lastError = null;
      notifyListeners();

      return true;
    } catch (error) {
      debugPrint('');
      debugPrint('========== BLE SEND FAILED ===========');
      debugPrint('COMMAND: $cleanCommand');
      debugPrint('CHARACTERISTIC: ${target.uuid}');
      debugPrint('ERROR: $error');
      debugPrint('======================================');

      _setError(
        error,
        'Unable to send the command to the BLE device.',
      );

      return false;
    }
  }

  // ============================================================
  // GARAM MUG COMMAND HELPERS
  // ============================================================

  Future<bool> setPower(BleDeviceModel model, bool enabled) {
    return sendCommand(model, jsonEncode({'h': enabled ? 1 : 0}));
  }

  Future<bool> setTargetTemperature(BleDeviceModel model, double value) {
    return sendCommand(model, jsonEncode({'tar': value.round()}));
  }

  // ============================================================
  // RECONNECT LAST BLE DEVICE
  // ============================================================

  /// Reconnects to the last BLE device using its BLE remoteId.
  ///
  /// Unlike Bluetooth Classic, BLE does not use the old RFCOMM
  /// BluetoothConnection.toAddress() flow.
  ///
  /// We first try BluetoothDevice.fromId(). If the platform requires the
  /// device to be rediscovered, we scan and find the same remoteId.
  Future<bool> reconnectLastConnectedDevice() async {
    final savedId = _lastConnectedDeviceId;

    if (savedId == null || savedId.isEmpty) {
      debugPrint(
        'BleService: no saved last BLE device.',
      );

      return false;
    }

    debugPrint('');
    debugPrint('========================================');
    debugPrint('       RESTORE LAST BLE DEVICE');
    debugPrint('========================================');
    debugPrint('SAVED REMOTE ID: $savedId');
    debugPrint('========================================');

    final existing = connectedDeviceById(savedId);

    if (existing != null && existing.isConnected) {
      debugPrint(
        'BleService: saved BLE device is already connected.',
      );

      return true;
    }

    final ready = await ensureBluetoothReady();

    if (!ready) {
      return false;
    }

    // ------------------------------------------------------------
    // STEP 1: Try direct BLE remoteId reconnect.
    // ------------------------------------------------------------

    try {
      final device = BluetoothDevice.fromId(savedId);

      debugPrint(
        'BleService: attempting direct BLE reconnect.',
      );

      final success = await connectBluetoothDevice(
        device,
        saveAsLastDevice: false,
      );

      if (success) {
        debugPrint(
          'BleService: DIRECT BLE RECONNECT SUCCESS.',
        );

        return true;
      }
    } catch (error) {
      debugPrint(
        'BleService: direct BLE reconnect failed: $error',
      );
    }

    // ------------------------------------------------------------
    // STEP 2: If direct reconnect failed, discover the same BLE ID.
    // ------------------------------------------------------------

    debugPrint(
      'BleService: starting fallback BLE discovery for saved device.',
    );

    final result = await _discoverSavedDevice(savedId);

    if (result == null) {
      debugPrint(
        'BleService: saved BLE device was not found.',
      );

      return false;
    }

    final success = await connectDevice(
      result,
      saveAsLastDevice: false,
    );

    if (success) {
      debugPrint(
        'BleService: DISCOVERED BLE RECONNECT SUCCESS.',
      );

      return true;
    }

    // ------------------------------------------------------------
    // STEP 3: One controlled retry.
    // ------------------------------------------------------------

    debugPrint(
      'BleService: BLE reconnect retry.',
    );

    await Future<void>.delayed(
      const Duration(milliseconds: 800),
    );

    final retrySuccess = await connectDevice(
      result,
      saveAsLastDevice: false,
    );

    if (retrySuccess) {
      debugPrint(
        'BleService: BLE RECONNECT RETRY SUCCESS.',
      );
    } else {
      debugPrint(
        'BleService: BLE AUTO RECONNECT FAILED.',
      );
    }

    return retrySuccess;
  }

  Future<ScanResult?> _discoverSavedDevice(
      String savedId,
      ) async {
    debugPrint('');
    debugPrint('========================================');
    debugPrint('       FIND SAVED BLE DEVICE');
    debugPrint('========================================');
    debugPrint('REMOTE ID: $savedId');
    debugPrint('FILTER: REMOTE ID ONLY');
    debugPrint('========================================');

    await stopDiscovery(notify: false);

    scanResults.clear();
    isScanning = true;

    notifyListeners();

    final completer = Completer<ScanResult?>();
    StreamSubscription<List<ScanResult>>? subscription;
    Timer? timer;

    void finish(ScanResult? result) {
      if (completer.isCompleted) {
        return;
      }

      timer?.cancel();
      unawaited(subscription?.cancel());

      isScanning = false;

      notifyListeners();

      completer.complete(result);
    }

    try {
      subscription = FlutterBluePlus.scanResults.listen(
            (results) {
          _updateScanResults(results);

          for (final result in results) {
            if (result.device.remoteId.str == savedId) {
              debugPrint(
                'SAVED BLE DEVICE FOUND: '
                    '${_displayName(result)} [$savedId]',
              );

              finish(result);
              return;
            }
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            'SAVED BLE DEVICE DISCOVERY ERROR: $error',
          );

          finish(null);
        },
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      timer = Timer(
        const Duration(seconds: 15),
            () {
          debugPrint(
            'SAVED BLE DEVICE DISCOVERY TIMEOUT: $savedId',
          );

          finish(null);
        },
      );

      final result = await completer.future;

      return result;
    } catch (error) {
      debugPrint(
        'SAVED BLE DISCOVERY FAILED: $error',
      );

      await subscription?.cancel();
      timer?.cancel();

      isScanning = false;
      notifyListeners();

      return null;
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      await subscription?.cancel();
      timer?.cancel();

      if (isScanning) {
        isScanning = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<bool> disconnectDevice(BleDeviceModel model) async {
    try {
      debugPrint('');
      debugPrint('========================================');
      debugPrint('              BLE DISCONNECT');
      debugPrint('========================================');
      debugPrint('DEVICE: ${model.name}');
      debugPrint('REMOTE ID: ${model.deviceId}');
      debugPrint('========================================');

      await _cancelNotificationSubscriptions(model);

      try {
        await model.device.disconnect();
      } catch (error) {
        debugPrint(
          'BLE disconnect warning: $error',
        );
      }

      model.isConnected = false;

      connectedDevices.removeWhere(
            (item) => item.deviceId == model.deviceId,
      );

      if (model.deviceId == _lastConnectedDeviceId) {
        await clearLastConnectedDevice();
      }

      notifyListeners();

      return true;
    } catch (error) {
      _removeConnectedDevice(
        model,
        errorMessage: 'Unable to disconnect the BLE device cleanly.',
        error: error,
      );

      return false;
    }
  }

  Future<void> _cancelNotificationSubscriptions(
      BleDeviceModel model,
      ) async {
    for (final subscription in model.notificationSubscriptions) {
      try {
        await subscription.cancel();
      } catch (_) {}
    }

    model.notificationSubscriptions.clear();
    model._statusJsonBuffers.clear();

    for (final characteristic in model.notifyCharacteristics) {
      try {
        await characteristic.setNotifyValue(false);
      } catch (_) {}
    }
  }

  void _removeConnectedDevice(
      BleDeviceModel model, {
        String? errorMessage,
        Object? error,
      }) {
    model.isConnected = false;

    unawaited(
      _cancelNotificationSubscriptions(model),
    );

    connectedDevices.removeWhere(
          (item) => item.deviceId == model.deviceId,
    );

    if (errorMessage != null) {
      lastError = errorMessage;

      if (error != null) {
        debugPrint(
          'BleService: $error',
        );
      }
    }

    notifyListeners();
  }

  // ============================================================
  // ERRORS
  // ============================================================

  void clearError() {
    if (lastError == null) {
      return;
    }

    lastError = null;
    notifyListeners();
  }

  void _setError(
      Object error,
      String message,
      ) {
    lastError = message;

    debugPrint(
      'BleService ERROR: $error',
    );

    notifyListeners();
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();

    // IMPORTANT:
    // Do not automatically disconnect live BLE devices here.
    //
    // This service is intended to be app-level/shared. Leaving a screen
    // should not disconnect the BLE device. Explicit user disconnect is
    // handled by disconnectDevice().
    //
    // The Android MainActivity change we previously made also helps keep
    // the Flutter engine alive when the user presses Android BACK.
    super.dispose();
  }
}
