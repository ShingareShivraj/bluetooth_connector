import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/classic_bluetooth_service.dart';
import 'home.dart';
import '../services/device_service.dart';
import 'dart:async';
import '../utils/permission_manager.dart';
// ═══════════════════════════════════════════════════════════════════════════
// PALETTE  (matches HomeScreen blue + white theme)
// ═══════════════════════════════════════════════════════════════════════════

class _P {
  static const Color blue1      = Color(0xFF2563EB);
  static const Color blue2      = Color(0xFF3B82F6);
  static const Color blue3      = Color(0xFF60A5FA);
  static const Color blueLight  = Color(0xFFEFF6FF);
  static const Color blueMid    = Color(0xFFDBEAFE);
  static const Color bgPage     = Color(0xFFF5F8FF);
  static const Color cardWhite  = Color(0xFFFFFFFF);
  static const Color textPrim   = Color(0xFF0F172A);
  static const Color textSec    = Color(0xFF64748B);
  static const Color textHint   = Color(0xFFCBD5E1);
  static const Color divider    = Color(0xFFE2E8F0);
  static const Color green      = Color(0xFF22C55E);
  static const Color greenLight = Color(0xFFF0FDF4);
  static const Color red        = Color(0xFFEF4444);
  static const Color redLight   = Color(0xFFFEF2F2);
  static const Color orange     = Color(0xFFF97316);
  static const Color shadow     = Color(0x142563EB);
}

// ═══════════════════════════════════════════════════════════════════════════
// SCAN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.microtask(() async {
      bool granted = await PermissionManager.requestAll(context);

      if (granted) {
        Provider.of<ClassicBluetoothService>(context, listen: false)
            .startDiscovery();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bluetooth = Provider.of<ClassicBluetoothService>(context);
    final devices   = bluetooth.discoveredDevices;

    return Scaffold(
      backgroundColor: _P.bgPage,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // ── Scan header ──────────────────────────────────────
          _ScanHeader(
            pulseAnim:      _pulseAnim,
            rotateCtrl:     _rotateController,
            deviceCount:    devices.length,
            onRefresh:      () => bluetooth.startDiscovery(),
          ),

          // ── Device list ──────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: _P.blue2,
              backgroundColor: _P.cardWhite,
              onRefresh: () async {
                bool granted = await PermissionManager.requestAll(context);
                if (granted) {
                  bluetooth.startDiscovery();
                }
              },
              child: devices.isEmpty
                  ? _EmptyState(onScan: () => bluetooth.startDiscovery())
                  : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final result = devices[index];
                  final device = result.device;
                  final name = (device.name != null &&
                      device.name!.isNotEmpty)
                      ? device.name!
                      : "Unknown Device";
                  final isConnected = bluetooth.connectedDevices
                      .any((d) => d.address == device.address);
                  return _DeviceCard(
                    name:        name,
                    deviceId:    device.address,
                    isConnected: isConnected,
                    onConnect:   () async =>
                    await bluetooth.connectDevice(device),
                  );
                },
              ),
            ),
          ),

          // ── Connected panel ──────────────────────────────────
          if (bluetooth.connectedDevices.isNotEmpty)
            _ConnectedPanel(
              context:   context,
              bluetooth: bluetooth,
            ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _P.cardWhite,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 4,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _P.divider),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            color: _P.blueLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.bluetooth_rounded,
              color: _P.blue1, size: 20),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Scan Devices",
            style: TextStyle(
              color:       _P.textPrim,
              fontSize:    17,
              fontWeight:  FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            "Find and connect your smart pot",
            style: TextStyle(
              color:    _P.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCAN HEADER  (pulse animation + live count badge)
// ═══════════════════════════════════════════════════════════════════════════

class _ScanHeader extends StatelessWidget {
  final Animation<double>  pulseAnim;
  final AnimationController rotateCtrl;
  final int                deviceCount;
  final VoidCallback       onRefresh;

  const _ScanHeader({
    required this.pulseAnim,
    required this.rotateCtrl,
    required this.deviceCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _P.cardWhite,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        children: [
          // ── Animated radar orb ──────────────────────────────
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: pulseAnim.value,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _P.blue2.withOpacity(0.18),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // Middle ring
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: pulseAnim.value * 0.8,
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _P.blue2.withOpacity(0.12),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                // Icon core
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_P.blue2, _P.blue1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x453B82F6),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: RotationTransition(
                    turns: rotateCtrl,
                    child: const Icon(Icons.radar_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ── Text info ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Scanning nearby...",
                  style: TextStyle(
                    color:      _P.textPrim,
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  "Make sure Bluetooth is enabled on your device",
                  style: TextStyle(
                    color:    _P.textSec,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Live count badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: deviceCount > 0 ? _P.blueLight : _P.bgPage,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: deviceCount > 0
                              ? _P.blue2.withOpacity(0.3)
                              : _P.divider,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        deviceCount > 0
                            ? "$deviceCount device${deviceCount > 1 ? 's' : ''} found"
                            : "No devices yet",
                        style: TextStyle(
                          color:      deviceCount > 0 ? _P.blue1 : _P.textSec,
                          fontSize:   11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Refresh chip
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onRefresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _P.bgPage,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _P.divider, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 12, color: _P.textSec),
                            SizedBox(width: 4),
                            Text(
                              "Refresh",
                              style: TextStyle(
                                color:    _P.textSec,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _P.blueLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: _P.blueMid, width: 1.5),
                ),
                child: const Icon(Icons.devices_other_rounded,
                    size: 40, color: _P.blue3),
              ),
              const SizedBox(height: 20),
              const Text(
                "No devices found",
                style: TextStyle(
                  color:      _P.textPrim,
                  fontSize:   17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Make sure your Smart Pot is nearby, powered on, and in pairing mode.",
                  style: TextStyle(color: _P.textSec, fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onScan();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_P.blue2, _P.blue1]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x453B82F6),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Scan Again",
                        style: TextStyle(
                          color:      Colors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DEVICE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _DeviceCard extends StatefulWidget {
  final String   name;
  final String   deviceId;
  final bool     isConnected;
  final Future<void> Function() onConnect;

  const _DeviceCard({
    required this.name,
    required this.deviceId,
    required this.isConnected,
    required this.onConnect,
  });

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  bool isConnecting = false;
  bool isFailed     = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Connection handler (original logic intact) ─────────────────

  Future<void> _handleConnect() async {
    if (isConnecting) return;
    HapticFeedback.lightImpact();

    setState(() {
      isConnecting = true;
      isFailed     = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Pairing with ${widget.name}...",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: _P.blue1,
        behavior:         SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );

    try {
      bool granted = await PermissionManager.requestAll(context);
      if (!granted) return;
      await widget.onConnect();
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      if (!widget.isConnected) {
        setState(() => isFailed = true);
      }
    } catch (_) {
      if (mounted) setState(() => isFailed = true);
    } finally {
      if (mounted) setState(() => isConnecting = false);
    }
  }

  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool connected = widget.isConnected;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _P.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: connected
                ? _P.green.withOpacity(0.35)
                : _P.divider,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: connected
                  ? _P.green.withOpacity(0.08)
                  : _P.shadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Bluetooth icon ─────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: connected
                      ? _P.greenLight
                      : _P.blueLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: connected
                        ? _P.green.withOpacity(0.3)
                        : _P.blueMid,
                    width: 1,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    connected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_rounded,
                    key: ValueKey(connected),
                    color: connected ? _P.green : _P.blue2,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ── Name + ID ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color:      _P.textPrim,
                        fontSize:   14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: connected ? _P.green : _P.textHint,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.deviceId,
                            style: const TextStyle(
                              color:    _P.textSec,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── Right action ───────────────────────────────
              connected
                  ? _ConnectedBadge()
                  : _ConnectButton(
                isConnecting: isConnecting,
                isFailed:     isFailed,
                onTap:        _handleConnect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Connected badge ───────────────────────────────────────────────────────

class _ConnectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _P.greenLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.green.withOpacity(0.35), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: _P.green, size: 13),
          SizedBox(width: 5),
          Text(
            "Connected",
            style: TextStyle(
              color:      _P.green,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Connect / Connecting / Failed button ──────────────────────────────────

class _ConnectButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool         isConnecting;
  final bool         isFailed;

  const _ConnectButton({
    required this.onTap,
    this.isConnecting = false,
    this.isFailed     = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine state appearance
    final List<Color> grad = isFailed
        ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
        : [_P.blue2, _P.blue1];

    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: isConnecting
              ? null
              : LinearGradient(colors: grad),
          color: isConnecting ? _P.bgPage : null,
          borderRadius: BorderRadius.circular(22),
          border: isConnecting
              ? Border.all(color: _P.divider, width: 1)
              : null,
          boxShadow: isConnecting || isFailed
              ? []
              : [
            BoxShadow(
              color: _P.blue2.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isConnecting
            ? const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 11, height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor:
                AlwaysStoppedAnimation(_P.blue2),
              ),
            ),
            SizedBox(width: 7),
            Text(
              "Pairing...",
              style: TextStyle(
                color:      _P.textSec,
                fontSize:   12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFailed
                  ? Icons.refresh_rounded
                  : Icons.bluetooth_searching_rounded,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              isFailed ? "Retry" : "Connect",
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONNECTED PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _ConnectedPanel extends StatelessWidget {
  final BuildContext             context;
  final ClassicBluetoothService  bluetooth;

  const _ConnectedPanel({
    required this.context,
    required this.bluetooth,
  });

  @override
  Widget build(BuildContext bContext) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: _P.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _P.green.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _P.green.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
          const BoxShadow(
            color: _P.shadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_P.blue2, _P.blue1]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x353B82F6),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.link_rounded,
                      color: Colors.white, size: 15),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Connected Devices",
                  style: TextStyle(
                    color:      _P.textPrim,
                    fontSize:   14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                // Active count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _P.greenLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _P.green.withOpacity(0.35), width: 1),
                  ),
                  child: Text(
                    "${bluetooth.connectedDevices.length} active",
                    style: const TextStyle(
                      color:      _P.green,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Device rows ──────────────────────────────────────
          ...bluetooth.connectedDevices.map((device) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _P.bgPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _P.divider, width: 1),
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _P.greenLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sensors_rounded,
                          color: _P.green, size: 18),
                    ),
                    const SizedBox(width: 12),

                    // Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: const TextStyle(
                              color:      _P.textPrim,
                              fontSize:   13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _MiniStat(
                                icon:  Icons.thermostat_rounded,
                                label: "${device.temperature}°C",
                                color: _P.orange,
                              ),
                              const SizedBox(width: 12),
                              _MiniStat(
                                icon:  Icons.battery_charging_full_rounded,
                                label: "${device.battery}%",
                                color: _P.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Disconnect — original logic
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        bluetooth.disconnectDevice(device);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _P.redLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _P.red.withOpacity(0.25), width: 1),
                        ),
                        child: const Icon(Icons.link_off_rounded,
                            color: _P.red, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 4),

          // ── Continue button — original navigation ────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                final deviceService =
                Provider.of<DeviceService>(context, listen: false);
                if (bluetooth.connectedDevices.isNotEmpty) {
                  deviceService.selectDevice(
                      bluetooth.connectedDevices.first);
                } else {
                  deviceService.selectDevice(null);
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HomeScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_P.blue2, _P.blue1],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color:      Color(0x453B82F6),
                      blurRadius: 16,
                      offset:     Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dashboard_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      "Continue to Dashboard",
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MINI STAT  (temp / battery label — original logic, new colors)
// ═══════════════════════════════════════════════════════════════════════════

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _MiniStat(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color:      color,
            fontSize:   11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}