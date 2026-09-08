import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

import 'package:pro/screens/settings_screen.dart';

import '../services/classic_bluetooth_service.dart';
import '../services/device_service.dart';
import '../services/theme_service.dart';
import '../utils/permission_manager.dart';
import 'home.dart';

/// Garam Mug Bluetooth connection screen.
///
/// Behaviour:
/// - Never starts discovery automatically when the screen opens.
/// - Loads Android's already-paired devices immediately.
/// - Shows an existing live connection first.
/// - A paired mug stays visible even when it is not discoverable.
/// - There is exactly ONE primary "Scan" action.
/// - Tapping a paired device connects directly through ClassicBluetoothService.
/// - Tapping an already-connected device opens Home without reconnecting.
/// - Navigation away from this screen never deliberately disconnects the mug.
///
/// IMPORTANT:
/// ClassicBluetoothService must be a single app-level/shared instance.
/// Do not create a new service every time this screen is opened.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanAnimation;

  String? _connectingAddress;
  bool _loadingPairedDevices = true;
  bool _checkingPermissions = false;

  @override
  void initState() {
    super.initState();

    _scanAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialState();
    });
  }

  @override
  void dispose() {
    _scanAnimation.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    if (!mounted) return;

    setState(() {
      _loadingPairedDevices = true;
      _checkingPermissions = true;
    });

    try {
      final granted = await PermissionManager.requestAll(context);

      if (!mounted) return;

      if (!granted) return;

      final bluetooth = context.read<ClassicBluetoothService>();

// Load Android's persistent paired-device list first.
// This does NOT start Bluetooth discovery.
      final loaded = await bluetooth.getBondedDevices();

      if (!mounted || !loaded) return;

// Load the address of the last Garam Mug that was connected.
      await bluetooth.loadLastConnectedDevice();

      if (!mounted) return;

// Automatically reconnect to the saved Garam Mug.
// This uses direct Bluetooth connection.
// It does NOT start discovery.
      final reconnected =
      await bluetooth.reconnectLastConnectedDevice();

      if (!mounted) return;

// If automatic reconnect succeeded, select the device and open Home.
      if (reconnected) {
        final address = bluetooth.lastConnectedDeviceAddress;

        if (address != null) {
          final model =
          bluetooth.connectedDeviceByAddress(address);

          if (model != null) {
            final deviceService = context.read<DeviceService>();
            deviceService.selectDevice(model);

            await bluetooth.stopDiscovery();

            if (!mounted) return;

            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => HomeScreen(),
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPairedDevices = false;
          _checkingPermissions = false;
        });
      }
    }
  }

  Future<void> _scanForNewMugs() async {
    if (_connectingAddress != null) return;

    final bluetooth = context.read<ClassicBluetoothService>();

    if (bluetooth.isDiscovering) return;

    HapticFeedback.lightImpact();

    setState(() => _checkingPermissions = true);

    try {
      final granted = await PermissionManager.requestAll(context);

      if (!mounted || !granted) return;

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

  bool _isGaramMug(BluetoothDevice device) {
    final name = device.name?.trim().toLowerCase() ?? '';

    if (name.isEmpty) return false;

    return name.startsWith('garam_mug') ||
        name.startsWith('garam mug') ||
        name.startsWith('device_1');
  }

  String _deviceName(BluetoothDevice device) {
    final name = device.name?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'Garam Mug';
  }

  ClassicDeviceModel? _connectedModel(
      ClassicBluetoothService service,
      String address,
      ) {
    for (final model in service.connectedDevices) {
      if (model.address == address &&
          model.isConnected &&
          model.connection?.isConnected == true) {
        return model;
      }
    }

    return null;
  }

  bool _isBonded(
      ClassicBluetoothService service,
      String address,
      ) {
    return service.bondedDevices.any(
          (device) => device.address == address,
    );
  }

  List<BluetoothDevice> _visibleDevices(
      ClassicBluetoothService service,
      ) {
    final byAddress = <String, BluetoothDevice>{};

    // Priority 1: live connections.
    for (final model in service.connectedDevices) {
      if (model.isConnected && _isGaramMug(model.device)) {
        byAddress[model.address] = model.device;
      }
    }

    // Priority 2: Android bonded devices.
    for (final device in service.bondedDevices) {
      if (_isGaramMug(device)) {
        byAddress[device.address] = device;
      }
    }

    // Priority 3: explicit discovery results.
    for (final result in service.discoveredDevices) {
      if (_isGaramMug(result.device)) {
        byAddress[result.device.address] = result.device;
      }
    }

    final devices = byAddress.values.toList();

    devices.sort((a, b) {
      final aConnected = _connectedModel(service, a.address) != null;
      final bConnected = _connectedModel(service, b.address) != null;

      if (aConnected != bConnected) {
        return aConnected ? -1 : 1;
      }

      final aBonded = _isBonded(service, a.address);
      final bBonded = _isBonded(service, b.address);

      if (aBonded != bBonded) {
        return aBonded ? -1 : 1;
      }

      return _deviceName(a).toLowerCase().compareTo(
        _deviceName(b).toLowerCase(),
      );
    });

    return devices;
  }

  Future<void> _connectOrOpen(
      BluetoothDevice device,
      ClassicBluetoothService bluetooth,
      ) async {
    if (_connectingAddress != null) return;

    HapticFeedback.mediumImpact();

    final address = device.address;

    setState(() => _connectingAddress = address);

    try {
      // Already connected: reuse the existing connection.
      var model = _connectedModel(bluetooth, address);

      if (model != null) {
        await _openHome(model);
        return;
      }

      // Paired devices use direct connection. No discovery is required.
      final success = await bluetooth.connectDevice(device);

      if (!mounted) return;

      model = _connectedModel(bluetooth, address);

      if (!success || model == null) {
        _showConnectionError(
          bluetooth.lastError ??
              'Unable to connect to ${_deviceName(device)}.',
          device,
        );
        return;
      }

      await _openHome(model);
    } finally {
      if (mounted) {
        setState(() => _connectingAddress = null);
      }
    }
  }

  Future<void> _openHome(ClassicDeviceModel model) async {
    if (!mounted) return;

    final deviceService = context.read<DeviceService>();
    deviceService.selectDevice(model);

    final bluetooth = context.read<ClassicBluetoothService>();

    // Stop discovery before controlling the mug.
    await bluetooth.stopDiscovery();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(),
      ),
    );

    // Do NOT scan or disconnect when returning from Home.
    // The shared Bluetooth service continues owning the connection.
  }

  void _showConnectionError(
      String message,
      BluetoothDevice device,
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
                context.read<ClassicBluetoothService>(),
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
    final bluetooth = context.watch<ClassicBluetoothService>();

    final dark = theme.isDarkMode;
    final colors = _Colors(dark);

    final devices = _visibleDevices(bluetooth);

    final scanning =
        bluetooth.isDiscovering || _checkingPermissions;

    final connected = devices.where(
          (device) => _connectedModel(
        bluetooth,
        device.address,
      ) != null,
    );

    final paired = devices.where(
          (device) =>
      _connectedModel(bluetooth, device.address) == null &&
          _isBonded(bluetooth, device.address),
    );

    final nearby = devices.where(
          (device) =>
      _connectedModel(bluetooth, device.address) == null &&
          !_isBonded(bluetooth, device.address),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
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
                  deviceCount: devices.length,
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

              if (_loadingPairedDevices)
                SliverToBoxAdapter(
                  child: _LoadingCard(colors: colors),
                ),

              if (!_loadingPairedDevices &&
                  devices.isEmpty)
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
                      title: 'CONNECTED',
                      subtitle: 'Ready to use',
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  _DeviceSliver(
                    devices: connected,
                    service: bluetooth,
                    colors: colors,
                    connectingAddress: _connectingAddress,
                    status: _DeviceStatus.connected,
                    isBonded: _isBonded,
                    connectedModel: _connectedModel,
                    deviceName: _deviceName,
                    onTap: _connectOrOpen,
                  ),
                ],

                if (paired.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      colors: colors,
                      title: 'MY GARAM MUGS',
                      subtitle: 'Paired with this phone',
                      icon: Icons.link_rounded,
                    ),
                  ),
                  _DeviceSliver(
                    devices: paired,
                    service: bluetooth,
                    colors: colors,
                    connectingAddress: _connectingAddress,
                    status: _DeviceStatus.paired,
                    isBonded: _isBonded,
                    connectedModel: _connectedModel,
                    deviceName: _deviceName,
                    onTap: _connectOrOpen,
                  ),
                ],

                if (nearby.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      colors: colors,
                      title: 'NEARBY',
                      subtitle: 'Found during this scan',
                      icon: Icons.bluetooth_searching_rounded,
                    ),
                  ),
                  _DeviceSliver(
                    devices: nearby,
                    service: bluetooth,
                    colors: colors,
                    connectingAddress: _connectingAddress,
                    status: _DeviceStatus.nearby,
                    isBonded: _isBonded,
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

      // EXACTLY ONE primary scan button on the entire screen.
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
    required this.connectingAddress,
    required this.status,
    required this.isBonded,
    required this.connectedModel,
    required this.deviceName,
    required this.onTap,
  });

  final Iterable<BluetoothDevice> devices;
  final ClassicBluetoothService service;
  final _Colors colors;
  final String? connectingAddress;
  final _DeviceStatus status;
  final bool Function(ClassicBluetoothService, String) isBonded;
  final ClassicDeviceModel? Function(
      ClassicBluetoothService,
      String,
      ) connectedModel;
  final String Function(BluetoothDevice) deviceName;
  final Future<void> Function(
      BluetoothDevice,
      ClassicBluetoothService,
      ) onTap;

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
          final model = connectedModel(service, device.address);

          return _DeviceCard(
            colors: colors,
            device: device,
            status: status,
            statusText: _statusText(status),
            battery: model?.battery,
            busy: connectingAddress == device.address,
            disabled: connectingAddress != null &&
                connectingAddress != device.address,
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
      case _DeviceStatus.paired:
        return 'Paired • Not connected';
      case _DeviceStatus.nearby:
        return 'Available nearby';
    }
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle({required this.colors});

  final _Colors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primaryDark, colors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.coffee_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Garam Mug',
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),
            Text(
              'Smart temperature control',
              style: TextStyle(
                color: colors.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.colors,
    required this.scanning,
    required this.hasConnected,
    required this.deviceCount,
  });

  final _Colors colors;
  final bool scanning;
  final bool hasConnected;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final title = scanning
        ? 'Looking for your mug…'
        : hasConnected
        ? 'Your mug is ready'
        : deviceCount > 0
        ? 'Your mug is here'
        : 'Connect your Garam Mug';

    final subtitle = scanning
        ? 'Searching nearby Bluetooth devices'
        : hasConnected
        ? 'Connected and ready to keep your drink warm'
        : deviceCount > 0
        ? 'Select a mug below to continue'
        : 'Paired mugs appear here automatically';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryDark, colors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              shape: BoxShape.circle,
            ),
            child: scanning
                ? const _ScanPulseIcon()
                : Icon(
              hasConnected
                  ? Icons.coffee_rounded
                  : Icons.bluetooth_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.78),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanPulseIcon extends StatefulWidget {
  const _ScanPulseIcon();

  @override
  State<_ScanPulseIcon> createState() => _ScanPulseIconState();
}

class _ScanPulseIconState extends State<_ScanPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: controller,
      child: const Icon(
        Icons.bluetooth_searching_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

enum _DeviceStatus {
  connected,
  paired,
  nearby,
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.colors,
    required this.device,
    required this.status,
    required this.statusText,
    required this.battery,
    required this.busy,
    required this.disabled,
    required this.name,
    required this.onTap,
  });

  final _Colors colors;
  final BluetoothDevice device;
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
    final paired = status == _DeviceStatus.paired;

    final accent = connected
        ? colors.green
        : paired
        ? colors.primary
        : colors.muted;

    final soft = connected
        ? colors.greenSoft
        : paired
        ? colors.primarySoft
        : colors.neutralSoft;

    return AnimatedOpacity(
      opacity: disabled ? .48 : 1,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled || busy ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: connected
                    ? colors.green.withOpacity(.38)
                    : colors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    colors.dark ? .12 : .045,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: soft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    connected
                        ? Icons.coffee_rounded
                        : Icons.bluetooth_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (connected) ...[
                            const SizedBox(width: 7),
                            _StatusPill(
                              label: 'CONNECTED',
                              color: colors.green,
                              background: colors.greenSoft,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              device.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                          if (battery != null) ...[
                            Text(
                              '  •  ',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 9,
                              ),
                            ),
                            Icon(
                              Icons.battery_std_rounded,
                              size: 12,
                              color: colors.muted,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$battery%',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 38,
                  child: FilledButton(
                    onPressed: disabled || busy ? null : onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                      connected ? colors.green : colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      connected ? 'Open' : 'Connect',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .55,
        ),
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
              'Checking paired Garam Mugs…',
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
                ? 'Finding your Garam Mug'
                : 'No Garam Mug connected',
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
                ? 'Keep your mug switched on and nearby.'
                : 'If this is your first connection, use the Scan button below.',
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
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.border),
          ),
        ),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: scanning
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(
              Icons.bluetooth_searching_rounded,
            ),
            label: Text(
              scanning ? 'Scanning nearby devices…' : 'Scan for a new mug',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
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

  Color get background =>
      dark ? const Color(0xFF080D18) : const Color(0xFFF5F8FF);

  Color get surface =>
      dark ? const Color(0xFF111827) : Colors.white;

  Color get primary => const Color(0xFF2563EB);

  Color get primaryDark => const Color(0xFF1D4ED8);

  Color get primarySoft =>
      dark ? const Color(0xFF172554) : const Color(0xFFEFF6FF);

  Color get neutralSoft =>
      dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  Color get text =>
      dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  Color get muted =>
      dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  Color get border =>
      dark ? const Color(0xFF263348) : const Color(0xFFE2E8F0);

  Color get green => const Color(0xFF16A34A);

  Color get greenSoft =>
      dark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4);

  Color get red => const Color(0xFFEF4444);

  Color get redSoft =>
      dark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2);
}
