import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import 'package:pro/screens/settings_screen.dart';

import '../services/ble_bluetooth_service.dart';
import '../services/device_service.dart';
import '../services/theme_service.dart';
// import '../utils/permission_manager.dart';
import 'home.dart';

/// BLE device connection screen.
///
/// IMPORTANT:
/// - Scans ALL BLE devices. There is no Garam Mug name filter.
/// - There is no Classic Bluetooth / bonded-device logic.
/// - Any BLE device can be selected and connected.
/// - GATT services and writable characteristics are discovered by BleService.
/// - The BLE service can then send raw commands to the selected device.
/// - Leaving this screen does not deliberately disconnect the device.
///
/// This screen intentionally remains generic while BLE connectivity and
/// raw command transport are being tested with different ESP32 firmware.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {

  String? _connectingDeviceId;
  bool _loadingInitialState = true;
  bool _checkingPermissions = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialState();
    });
  }

  Future<void> _loadInitialState() async {
    if (!mounted) return;

    setState(() {
      _loadingInitialState = true;
      _checkingPermissions = true;
    });

    try {
      final bluetooth = context.read<BleService>();
      // Load the saved BLE remoteId, but do not start a normal scan.
      await bluetooth.loadLastConnectedDevice();

      if (!mounted) return;

      // Preserve the previous app behaviour: if a saved BLE device is
      // available and can be reconnected, open Home automatically.
      final reconnected =
      await bluetooth.reconnectLastConnectedDevice();

      if (!mounted || !reconnected) return;

      final deviceId = bluetooth.lastConnectedDeviceId;

      if (deviceId == null || deviceId.isEmpty) return;

      final model = bluetooth.connectedDeviceById(deviceId);

      if (model == null) return;

      final deviceService = context.read<DeviceService>();
      deviceService.selectDevice(model);

      await bluetooth.stopDiscovery();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingInitialState = false;
          _checkingPermissions = false;
        });
      }
    }
  }

  Future<void> _scanForNewMugs() async {
    if (_connectingDeviceId != null) return;

    final bluetooth = context.read<BleService>();

    if (bluetooth.isScanning) return;

    HapticFeedback.lightImpact();

    setState(() => _checkingPermissions = true);

    try {


      final success = await bluetooth.startDiscovery();

      if (!mounted) return;

      if (!success && bluetooth.lastError != null) {
        _showError(bluetooth.lastError!);
      }
    } finally {
      if (mounted) {
        setState(() => _checkingPermissions = false);
      }
    }
  }

  String _deviceName(BleDeviceModel model) {
    final name = model.name.trim();

    if (name.isNotEmpty) {
      return name;
    }

    return 'Unknown BLE Device';
  }

  BleDeviceModel? _connectedModel(
      BleService service,
      String deviceId,
      ) {
    return service.connectedDeviceById(deviceId);
  }

  List<BleDeviceModel> _visibleDevices(BleService service) {
    final byId = <String, BleDeviceModel>{};

    // Connected devices remain visible after scanning stops.
    for (final model in service.connectedDevices) {
      if (model.isConnected) {
        byId[model.deviceId] = model;
      }
    }

    // Scan results are converted into the same model used by DeviceService.
    for (final result in service.scanResults) {
      final id = result.device.remoteId.str;

      final existing = byId[id];

      if (existing != null) {
        continue;
      }

      byId[id] = BleDeviceModel(
        device: result.device,
        name: service.deviceNameFromScanResult(result),
        deviceId: id,
      );
    }

    final devices = byId.values.toList();

    devices.sort((a, b) {
      if (a.isConnected != b.isConnected) {
        return a.isConnected ? -1 : 1;
      }

      return _deviceName(a).toLowerCase().compareTo(
        _deviceName(b).toLowerCase(),
      );
    });

    return devices;
  }

  Future<void> _connectOrOpen(
      BleDeviceModel model,
      BleService bluetooth,
      ) async {
    if (_connectingDeviceId != null) return;

    HapticFeedback.mediumImpact();

    final deviceId = model.deviceId;

    setState(() => _connectingDeviceId = deviceId);

    try {
      // Already connected: reuse the existing GATT connection.
      final existing = _connectedModel(bluetooth, deviceId);

      if (existing != null) {
        await _openHome(existing);
        return;
      }

      // BleService.connectBluetoothDevice() accepts BluetoothDevice directly.
      // This works for devices obtained from the scan screen.
      final success = await bluetooth.connectBluetoothDevice(
        model.device,
        name: model.name,
      );

      if (!mounted) return;

      final connectedModel = _connectedModel(bluetooth, deviceId);

      if (!success || connectedModel == null) {
        _showConnectionError(
          bluetooth.lastError ??
              'Unable to connect to ${_deviceName(model)}.',
          model,
        );
        return;
      }

      await _openHome(connectedModel);
    } finally {
      if (mounted) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  Future<void> _openHome(BleDeviceModel model) async {
    if (!mounted) return;

    final deviceService = context.read<DeviceService>();
    deviceService.selectDevice(model);

    final bluetooth = context.read<BleService>();

    await bluetooth.stopDiscovery();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(),
      ),
    );

    // Do NOT scan or disconnect when returning from Home.
    // The shared BLE service continues to own the connection.
  }

  void _showConnectionError(
      String message,
      BleDeviceModel device,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Text(message),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              _connectOrOpen(
                device,
                context.read<BleService>(),
              );
            },
          ),
        ),
      );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final bluetooth = context.watch<BleService>();

    final dark = theme.isDarkMode;
    final colors = _Colors(dark);

    final devices = _visibleDevices(bluetooth);

    final scanning =
        bluetooth.isScanning || _checkingPermissions;

    final connected = devices.where(
          (device) => device.isConnected,
    );

    final nearby = devices.where(
          (device) => !device.isConnected,
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 18,
        title: _AppTitle(colors: colors),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: colors.border,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.primary,
          onRefresh: _scanForNewMugs,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  colors: colors,
                  scanning: scanning,
                  hasConnected: connected.isNotEmpty,
                ),
              ),

              if (bluetooth.lastError != null)
                SliverToBoxAdapter(
                  child: _ErrorBanner(
                    colors: colors,
                    message: bluetooth.lastError!,
                    onRetry: scanning ? null : _scanForNewMugs,
                    onClose: bluetooth.clearError,
                  ),
                ),

              if (_loadingInitialState)
                SliverToBoxAdapter(
                  child: _LoadingCard(colors: colors),
                ),

              if (!_loadingInitialState && devices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    colors: colors,
                    scanning: scanning,
                  ),
                )
              else ...[
                if (connected.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      colors: colors,
                      title: 'Connected mugs',
                      subtitle: 'Ready to use',
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  _DeviceSliver(
                    devices: connected,
                    service: bluetooth,
                    colors: colors,
                    connectingDeviceId: _connectingDeviceId,
                    status: _DeviceStatus.connected,
                    connectedModel: _connectedModel,
                    deviceName: _deviceName,
                    onTap: _connectOrOpen,
                  ),
                ],

                if (nearby.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      colors: colors,
                      title: 'Nearby devices',
                      subtitle: 'Select a device to connect',
                      icon: Icons.bluetooth_searching_rounded,
                    ),
                  ),
                  _DeviceSliver(
                    devices: nearby,
                    service: bluetooth,
                    colors: colors,
                    connectingDeviceId: _connectingDeviceId,
                    status: _DeviceStatus.nearby,
                    connectedModel: _connectedModel,
                    deviceName: _deviceName,
                    onTap: _connectOrOpen,
                  ),
                ],

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ],
          ),
        ),
      ),

      // Exactly one primary scan button.
      bottomNavigationBar: _ScanAction(
        colors: colors,
        scanning: scanning,
        onPressed: scanning ? null : _scanForNewMugs,
      ),
    );
  }
}

class _DeviceSliver extends StatelessWidget {
  const _DeviceSliver({
    required this.devices,
    required this.service,
    required this.colors,
    required this.connectingDeviceId,
    required this.status,
    required this.connectedModel,
    required this.deviceName,
    required this.onTap,
  });

  final Iterable<BleDeviceModel> devices;
  final BleService service;
  final _Colors colors;
  final String? connectingDeviceId;
  final _DeviceStatus status;
  final BleDeviceModel? Function(BleService, String) connectedModel;
  final String Function(BleDeviceModel) deviceName;
  final Future<void> Function(BleDeviceModel, BleService) onTap;

  @override
  Widget build(BuildContext context) {
    final list = devices.toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      sliver: SliverList.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final device = list[index];
          final model = connectedModel(service, device.deviceId);

          return _DeviceCard(
            colors: colors,
            status: status,
            statusText: _statusText(status),
            battery: model?.battery,
            busy: connectingDeviceId == device.deviceId,
            disabled: connectingDeviceId != null &&
                connectingDeviceId != device.deviceId,
            name: deviceName(device),
            onTap: () => onTap(device, service),
          );
        },
      ),
    );
  }

  String _statusText(_DeviceStatus status) {
    switch (status) {
      case _DeviceStatus.connected:
        return 'Connected';
      case _DeviceStatus.nearby:
        return 'Ready to connect';
    }
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle({required this.colors});
  final _Colors colors;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Image.asset('assets/images/ic_mug_amber.png',
          width: 32, height: 32, excludeFromSemantics: true),
      const SizedBox(width: 9),
      Flexible(
        child: Text('Garam Mug',
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w800)),
      ),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.colors, required this.scanning,
    required this.hasConnected});

  final _Colors colors;
  final bool scanning;
  final bool hasConnected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 26, 18, 20),
    child: Column(
      children: [
        Text(hasConnected ? 'Your mug is connected' : 'Connect your mug',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.text, fontSize: 26,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          hasConnected ? 'Tap your mug to open its controls.'
              : 'Turn on your mug and keep it nearby.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        _ScanRadar(scanning: scanning, colors: colors),
      ],
    ),
  );
}

class _ScanRadar extends StatelessWidget {
  const _ScanRadar({required this.scanning, required this.colors});
  final bool scanning;
  final _Colors colors;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 200,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (final size in [200.0, 152.0, 106.0])
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _Colors.amber.withOpacity(colors.dark ? .12 : .09),
            ),
          ),
        Container(
          width: 62, height: 62,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _Colors.amber, shape: BoxShape.circle,
          ),
          child: Image.asset('assets/images/ic_bluetooth.png',
              width: 34, height: 34, color: _Colors.navy,
              excludeFromSemantics: true),
        ),
        if (scanning)
          SizedBox.square(
            dimension: 73,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.warmInk,
              semanticsLabel: 'Scanning for nearby devices',
            ),
          ),
      ],
    ),
  );
}

enum _DeviceStatus { connected, nearby }

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.colors, required this.status, required this.statusText,
    required this.battery, required this.busy, required this.disabled,
    required this.name, required this.onTap,
  });

  final _Colors colors;
  final _DeviceStatus status;
  final String statusText;
  final int? battery;
  final bool busy;
  final bool disabled;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connected = status == _DeviceStatus.connected;
    final action = FilledButton(
      onPressed: busy || disabled ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? SizedBox.square(
        dimension: 17,
        child: CircularProgressIndicator(
          color: colors.text, strokeWidth: 2, semanticsLabel: 'Connecting',
        ),
      )
          : Text(connected ? 'Open' : 'Connect'),
    );
    final info = Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: colors.neutralSoft, borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Image.asset('assets/images/ic_bluetooth.png',
                width: 24, height: 24, color: colors.text,
                excludeFromSemantics: true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.text, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                connected && battery != null ? '$statusText · $battery%' : statusText,
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(17),
        boxShadow: colors.dark ? null : const [
          BoxShadow(color: Color(0x0D14243B), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 250 || MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 8), action],
            );
          }
          return Row(children: [Expanded(child: info), const SizedBox(width: 8), action]);
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final _Colors colors;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 9),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: colors.primary,
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.05,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colors.muted,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.colors});

  final _Colors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Preparing BLE…',
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colors,
    required this.scanning,
  });

  final _Colors colors;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 25, 30, 95),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              scanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.coffee_outlined,
              color: colors.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            scanning
                ? 'Finding nearby BLE devices'
                : 'No BLE device found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            scanning
                ? 'Turn on the BLE device and keep it nearby.'
                : 'Use the Scan button below to find nearby BLE devices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.colors,
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final _Colors colors;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(13, 10, 6, 10),
      decoration: BoxDecoration(
        color: colors.redSoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: colors.red.withOpacity(.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colors.red,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.text,
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanAction extends StatelessWidget {
  const _ScanAction({
    required this.colors,
    required this.scanning,
    required this.onPressed,
  });

  final _Colors colors;
  final bool scanning;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border(
            top: BorderSide(color: colors.border),
          ),
        ),
        child: SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: scanning
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.text,
              ),
            )
                : const Icon(
              Icons.bluetooth_searching_rounded,
            ),
            label: Text(
              scanning ? 'Scanning nearby devices…' : 'Scan again',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.text,
              side: BorderSide(color: colors.text),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Colors {
  _Colors(this.dark);

  final bool dark;
  static const navy = Color(0xFF14243B);
  static const amber = Color(0xFFF59E0B);
  Color get onPrimary => dark ? navy : Colors.white;
  Color get warmInk => dark ? amber : const Color(0xFF9A4C06);

  Color get background =>
      dark ? const Color(0xFF0B1422) : const Color(0xFFFFF8EE);

  Color get surface =>
      dark ? const Color(0xFF14243B) : Colors.white;

  Color get primary => dark ? amber : navy;

  Color get primarySoft =>
      dark ? const Color(0xFF3A2A19) : const Color(0xFFF9EDDD);

  Color get neutralSoft =>
      dark ? const Color(0xFF20344C) : const Color(0xFFF6EFE6);

  Color get text =>
      dark ? const Color(0xFFFFF8EE) : const Color(0xFF14243B);

  Color get muted =>
      dark ? const Color(0xFFB3BFCC) : const Color(0xFF515F70);

  Color get border =>
      dark ? const Color(0xFF2B4058) : const Color(0xFFE8DED1);

  Color get red => dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

  Color get redSoft =>
      dark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
}
