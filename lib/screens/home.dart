import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/classic_bluetooth_service.dart';
import '../services/device_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PALETTE  (Blue + White premium theme)
// ═══════════════════════════════════════════════════════════════════════════

class _P {
  // Blues
  static const Color blue1     = Color(0xFF2563EB); // deep blue
  static const Color blue2     = Color(0xFF3B82F6); // mid blue
  static const Color blue3     = Color(0xFF60A5FA); // light blue
  static const Color blueLight = Color(0xFFEFF6FF); // tinted bg card
  static const Color blueMid   = Color(0xFFDBEAFE); // progress bg

  // Backgrounds
  static const Color bgPage    = Color(0xFFF5F8FF); // overall page
  static const Color cardWhite = Color(0xFFFFFFFF); // card surface

  // Text
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint      = Color(0xFFCBD5E1);

  // Status
  static const Color green  = Color(0xFF22C55E);
  static const Color red    = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF97316);

  // Shadow
  static const Color shadow = Color(0x1A2563EB);
}

// ═══════════════════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _batteryColor(dynamic battery) {
    final pct = (battery is num) ? battery.toDouble() : 0.0;
    if (pct >= 60) return _P.green;
    if (pct >= 30) return _P.orange;
    return _P.red;
  }

  @override
  Widget build(BuildContext context) {
    final bluetooth     = context.watch<ClassicBluetoothService>();
    final deviceService = context.watch<DeviceService>();

    // ── Sync device state (original logic unchanged) ────────────
    if (bluetooth.connectedDevices.isNotEmpty) {
      final device = bluetooth.connectedDevices.first;
      deviceService.selectedDevice    = device;
      deviceService.temperature       = device.temperature;
      deviceService.battery           = device.battery;
      deviceService.espSetTemperature = device.setTemperature;
      deviceService.isDeviceConnected = true;
    }

    return Scaffold(
      backgroundColor: _P.bgPage,
      appBar: _PremiumAppBar(isConnected: deviceService.isDeviceConnected),
      body: deviceService.selectedDevice == null
          ? const _NoDeviceView()
          : _DashboardLayout(
        deviceService:  deviceService,
        pulseAnimation: _pulseAnimation,
        batteryColor:   _batteryColor(deviceService.battery),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP BAR
// ═══════════════════════════════════════════════════════════════════════════

class _PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isConnected;
  const _PremiumAppBar({required this.isConnected});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _P.cardWhite,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFE2E8F0),
        ),
      ),
      title: Row(
        children: [
          // App icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_P.blue2, _P.blue1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x403B82F6),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.wifi_tethering_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Smart Pot",
                style: TextStyle(
                  color: _P.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                "Control Dashboard",
                style: TextStyle(
                  color: _P.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _StatusBadge(isConnected: isConnected),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NO DEVICE VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _NoDeviceView extends StatelessWidget {
  const _NoDeviceView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _P.blueLight,
              shape: BoxShape.circle,
              border: Border.all(color: _P.blueMid, width: 1.5),
            ),
            child: const Icon(
              Icons.bluetooth_disabled_rounded,
              size: 40,
              color: _P.blue3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Device Selected",
            style: TextStyle(
              color: _P.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Connect a device to get started",
            style: TextStyle(color: _P.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD LAYOUT
// ═══════════════════════════════════════════════════════════════════════════

class _DashboardLayout extends StatelessWidget {
  final DeviceService      deviceService;
  final Animation<double>  pulseAnimation;
  final Color              batteryColor;

  const _DashboardLayout({
    required this.deviceService,
    required this.pulseAnimation,
    required this.batteryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Scrollable body ──────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Connected Device Card ──────────────────────
                _DeviceCard(deviceService: deviceService),

                const SizedBox(height: 16),

                // ── Stats Row ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label:  "Live Temp",
                        value:  "${deviceService.temperature}°C",
                        icon:   Icons.thermostat_rounded,
                        accent: _P.orange,
                        bgColor: const Color(0xFFFFF7ED),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BatteryCard(
                        battery:      deviceService.battery,
                        batteryColor: batteryColor,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Section Label ─────────────────────────────
                // const Text(
                //   "Temperature Control",
                //   style: TextStyle(
                //     color:      _P.textPrimary,
                //     fontSize:   15,
                //     fontWeight: FontWeight.w700,
                //     letterSpacing: -0.2,
                //   ),
                // ),
                // const SizedBox(height: 4),
                // const Text(
                //   "Drag the ring to set target temperature",
                //   style: TextStyle(color: _P.textSecondary, fontSize: 12),
                // ),
                //
                // const SizedBox(height: 16),

                // ── Temperature Dial Card ─────────────────────

              ],
            ),
          ),
        ),

        _DialCard(deviceService: deviceService),

        // ── Power Panel (pinned bottom) ──────────────────────────
        _BottomPowerPanel(
          isOn:           deviceService.isOn,
          pulseAnimation: pulseAnimation,
          onTap: () async {
            if (deviceService.selectedDevice == null) return;
            await deviceService.togglePower();
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DEVICE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _DeviceCard extends StatelessWidget {
  final DeviceService deviceService;
  const _DeviceCard({required this.deviceService});

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Row(
        children: [
          // Blue Bluetooth icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_P.blue2, _P.blue1],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x353B82F6),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          // Device info
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ClassicDeviceModel>(
                value: deviceService.bluetoothService.connectedDevices
                    .contains(deviceService.selectedDevice)
                    ? deviceService.selectedDevice
                    : null,
                isExpanded: true,
                hint: const Text(
                  "Select Device",
                  style: TextStyle(color: _P.textSecondary, fontSize: 14),
                ),
                dropdownColor: _P.cardWhite,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _P.textSecondary,
                  size: 22,
                ),
                style: const TextStyle(
                  color:      _P.textPrimary,
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                ),
                items: deviceService.bluetoothService.connectedDevices
                    .map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(d.name),
                ))
                    .toList(),
                onChanged: (d) {
                  if (d != null) deviceService.selectDevice(d);
                },
              ),
            ),
          ),

          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _P.blueLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Connected",
              style: TextStyle(
                color:      _P.blue1,
                fontSize:   11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STAT CARD  (Live Temp)
// ═══════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final Color   accent;
  final Color   bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 12),
          // Value
          Text(
            value,
            style: const TextStyle(
              color:      _P.textPrimary,
              fontSize:   26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color:    _P.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BATTERY CARD
// ═══════════════════════════════════════════════════════════════════════════

class _BatteryCard extends StatelessWidget {
  final dynamic battery;
  final Color   batteryColor;
  const _BatteryCard({required this.battery, required this.batteryColor});

  @override
  Widget build(BuildContext context) {
    final pct = (battery is num) ? (battery as num).toDouble() : 0.0;
    return _ShadowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: batteryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.battery_charging_full_rounded,
              color: batteryColor,
              size: 18,
            ),
          ),
          const SizedBox(height: 12),
          // Value
          Text(
            "${pct.toInt()}%",
            style: const TextStyle(
              color:      _P.textPrimary,
              fontSize:   26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Battery",
            style: TextStyle(
              color:    _P.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 100.0) / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIAL CARD  (wraps the arc temperature dial)
// ═══════════════════════════════════════════════════════════════════════════

class _DialCard extends StatelessWidget {
  final DeviceService deviceService;
  const _DialCard({required this.deviceService});

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: _ArcTemperatureDial(
        currentTemp: (deviceService.temperature is num)
            ? (deviceService.temperature as num).toDouble()
            : 0.0,
        setTemp: deviceService.targetTemperature,
        espSetTemp: deviceService.espSetTemperature,
        onChanged: (val) => deviceService.sendSetTemperature(val),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ARC TEMPERATURE DIAL  (custom painter — logic unchanged, colors updated)
// ═══════════════════════════════════════════════════════════════════════════

class _ArcTemperatureDial extends StatefulWidget {
  final double currentTemp;
  final double setTemp;
  final ValueChanged<double> onChanged;
  final double espSetTemp;

  const _ArcTemperatureDial({
    required this.currentTemp,
    required this.setTemp,
    required this.onChanged,
    required this.espSetTemp,
  });

  @override
  State<_ArcTemperatureDial> createState() => _ArcTemperatureDialState();
}

class _ArcTemperatureDialState extends State<_ArcTemperatureDial> {
  double localSetTemp = 0;
  static const double _minTemp    = 0;
  static const double _maxTemp    = 1000;
  static const double _startAngle = 150 * pi / 180;
  static const double _sweepAngle = 240 * pi / 180;
  @override
  void initState() {
    super.initState();

    localSetTemp = widget.setTemp;
  }
  double get _fraction =>
      (localSetTemp - _minTemp) / (_maxTemp - _minTemp);

  void _handlePan(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;

    double angle = atan2(dy, dx);

    // Normalize angle (0 → 2π)
    if (angle < 0) angle += 2 * pi;

    // Convert to dial range
    double start = _startAngle;
    double end = _startAngle + _sweepAngle;

    // Clamp angle inside arc
    if (angle < start) angle = start;
    if (angle > end) angle = end;

    final fraction = (angle - start) / _sweepAngle;

    final value = _minTemp + fraction * (_maxTemp - _minTemp);

    setState(() {
      localSetTemp = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final side = constraints.maxWidth.clamp(0.0, 280.0);
      final size = Size(side, side);

      return GestureDetector(
        onPanStart: (d) {
          _handlePan(d.localPosition, size);
        },

        onPanUpdate: (d) {
          _handlePan(d.localPosition, size);
        },

        onPanEnd: (_) {
          widget.onChanged(localSetTemp);
        },

        onTapDown: (d) {
          _handlePan(d.localPosition, size);

          widget.onChanged(localSetTemp);
        },
        child: SizedBox(
          width:  side,
          height: side,
          child: CustomPaint(
            painter: _DialPainter(
              fraction:    _fraction,
              currentTemp: widget.currentTemp,
              setTemp:     widget.setTemp,
            ),
            child: Center(
              child: _DialCenter(
                currentTemp: widget.currentTemp,
                setTemp: localSetTemp,
                espSetTemp: widget.espSetTemp,
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ── Dial Painter ───────────────────────────────────────────────────────────

class _DialPainter extends CustomPainter {
  final double fraction;
  final double currentTemp;
  final double setTemp;

  _DialPainter({
    required this.fraction,
    required this.currentTemp,
    required this.setTemp,
  });

  static const double _startAngle = 150 * pi / 180;
  static const double _sweepAngle = 240 * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 10;
    const trackW = 16.0;
    final trackR = outerR - trackW / 2;
    final rect   = Rect.fromCircle(center: center, radius: trackR);

    // ── Track background ───────────────────────────────────────
    canvas.drawArc(
      rect, _startAngle, _sweepAngle, false,
      Paint()
        ..color       = const Color(0xFFE2E8F0)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = trackW
        ..strokeCap   = StrokeCap.round,
    );

    // ── Filled arc (blue gradient) ─────────────────────────────
    if (fraction > 0) {
      final grad = SweepGradient(
        startAngle: _startAngle,
        endAngle:   _startAngle + _sweepAngle * fraction,
        colors: const [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF60A5FA)],
        stops: const [0.0, 0.6, 1.0],
      );
      canvas.drawArc(
        rect, _startAngle, _sweepAngle * fraction, false,
        Paint()
          ..shader      = grad.createShader(rect)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = trackW
          ..strokeCap   = StrokeCap.round,
      );
    }

    // ── Thumb knob ─────────────────────────────────────────────
    final thumbAngle = _startAngle + _sweepAngle * fraction;
    final thumbPos   = Offset(
      center.dx + trackR * cos(thumbAngle),
      center.dy + trackR * sin(thumbAngle),
    );

    // Glow
    canvas.drawCircle(
      thumbPos, 14,
      Paint()
        ..color      = const Color(0x503B82F6)
        ..style      = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // White ring
    canvas.drawCircle(thumbPos, 10,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    // Blue fill
    canvas.drawCircle(thumbPos, 7,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          ).createShader(Rect.fromCircle(center: thumbPos, radius: 7))
          ..style = PaintingStyle.fill);

    // ── Tick marks ─────────────────────────────────────────────
    final tickR  = outerR + 4;
    for (int i = 0; i <= 10; i++) {
      final a       = _startAngle + _sweepAngle * (i / 10);
      final isMajor = i % 5 == 0;
      final tl      = isMajor ? 10.0 : 5.0;
      final p1      = Offset(center.dx + (tickR - tl) * cos(a),
          center.dy + (tickR - tl) * sin(a));
      final p2      = Offset(center.dx + tickR * cos(a),
          center.dy + tickR * sin(a));
      canvas.drawLine(
        p1, p2,
        Paint()
          ..color       = isMajor ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1)
          ..strokeWidth = isMajor ? 2.0 : 1.0,
      );
    }

    // ── Min / Max labels ───────────────────────────────────────
    _drawLabel(canvas, center, tickR + 16, _startAngle, "0°");
    _drawLabel(canvas, center, tickR + 16, _startAngle + _sweepAngle, "1000°");
  }

  void _drawLabel(Canvas canvas, Offset center, double r, double angle, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color:      Color(0xFF94A3B8),
          fontSize:   9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        center.dx + r * cos(angle) - tp.width  / 2,
        center.dy + r * sin(angle) - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
          old.currentTemp != currentTemp ||
          old.setTemp != setTemp;
}

// ── Dial Centre ────────────────────────────────────────────────────────────

class _DialCenter extends StatelessWidget {
  final double currentTemp;
  final double setTemp;
  final double espSetTemp;
  const _DialCenter({required this.currentTemp, required this.setTemp, required this.espSetTemp,});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _P.blueLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            "SET TEMPERATURE",
            style: TextStyle(
              color:        _P.blue1,
              fontSize:     9.5,
              fontWeight:   FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Big value
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "${setTemp.toInt()}",
                style: const TextStyle(
                  color:      _P.textPrimary,
                  fontSize:   54,
                  fontWeight: FontWeight.w900,
                  height:     1.0,
                  letterSpacing: -2,
                ),
              ),
              const TextSpan(
                text: "°C",
                style: TextStyle(
                  color:      _P.blue2,
                  fontSize:   22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Current temp pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFED7AA), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.thermostat_rounded,
                  size: 12, color: _P.orange),
              const SizedBox(width: 4),
              Text(
                "Now: ${currentTemp.toStringAsFixed(1)}°C",
                style: const TextStyle(
                  color:      _P.orange,
                  fontSize:   11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        const Text(
          "Drag the ring to adjust",
          style: TextStyle(color: _P.textHint, fontSize: 10.5),
        ),
        const SizedBox(height: 6),

        Text(
          "ESP Set Temperature: ${espSetTemp.toInt()}°C",
          style: const TextStyle(
            color: _P.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM POWER PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _BottomPowerPanel extends StatelessWidget {
  final bool             isOn;
  final Animation<double> pulseAnimation;
  final VoidCallback     onTap;

  const _BottomPowerPanel({
    required this.isOn,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _P.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOn
              ? _P.blue2.withOpacity(0.25)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn ? _P.shadow : const Color(0x0D000000),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Left: Status info ──────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn ? _P.green : const Color(0xFFCBD5E1),
                        boxShadow: isOn
                            ? [BoxShadow(color: _P.green.withOpacity(0.5), blurRadius: 6)]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isOn ? "DEVICE ACTIVE" : "DEVICE STANDBY",
                      style: TextStyle(
                        color:      isOn ? _P.blue1 : _P.textSecondary,
                        fontSize:   11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isOn ? "Tap power to turn off" : "Tap power to turn on",
                  style: const TextStyle(
                    color:    _P.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ── Right: Power button ────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: AnimatedBuilder(
              animation: pulseAnimation,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  // Glow ring (only when ON)
                  if (isOn)
                    Opacity(
                      opacity: pulseAnimation.value * 0.45,
                      child: Container(
                        width: 76, height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _P.blue2.withOpacity(0.2),
                        ),
                      ),
                    ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve:    Curves.easeInOut,
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isOn
                          ? const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      )
                          : const LinearGradient(
                        colors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isOn
                              ? _P.blue2.withOpacity(0.45)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: isOn ? 20 : 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        color: isOn ? Colors.white : const Color(0xFF94A3B8),
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ═══════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final bool isConnected;
  const _StatusBadge({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? _P.green : _P.red;
    final bg    = isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.6), blurRadius: 5),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? "Connected" : "Disconnected",
            style: TextStyle(
              color:      color,
              fontSize:   11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REUSABLE SHADOW CARD
// ═══════════════════════════════════════════════════════════════════════════

class _ShadowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _ShadowCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _P.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color:       Color(0x0D2563EB),
            blurRadius:  20,
            offset:      Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color:       Color(0x08000000),
            blurRadius:  6,
            offset:      Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}