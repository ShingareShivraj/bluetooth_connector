import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/classic_bluetooth_service.dart';
import '../services/device_service.dart';

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
  late Animation<double> _pulseAnimation;

  // ── Palette ────────────────────────────────────────────────────
  static const Color _teal1 = Color(0xFF07B5AF);
  static const Color _teal2 = Color(0xFF13C4BC);
  static const Color _teal3 = Color(0xFF7DD8D6);
  static const Color _bg1   = Color(0xFF051E1D);
  static const Color _bg2   = Color(0xFF073330);
  static const Color _surface = Color(0xFF0C2E2C);

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

  // ── Battery colour ─────────────────────────────────────────────
  Color _batteryColor(dynamic battery) {
    final pct = (battery is num) ? battery.toDouble() : 0.0;
    if (pct >= 60) return const Color(0xFF4CAF82);
    if (pct >= 30) return const Color(0xFFFFB946);
    return const Color(0xFFFF5757);
  }

  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bluetooth    = context.watch<ClassicBluetoothService>();
    final deviceService = context.watch<DeviceService>();

    // ── Sync device state (original logic) ──────────────────────
    if (bluetooth.connectedDevices.isNotEmpty) {
      final device = bluetooth.connectedDevices.first;
      deviceService.selectedDevice   = device;
      deviceService.temperature      = device.temperature;
      deviceService.battery          = device.battery;
      deviceService.setTemperature   = device.setTemperature;
      deviceService.isDeviceConnected = true;
    }

    return Scaffold(
      backgroundColor: _bg1,
      extendBodyBehindAppBar: true,
      appBar: _PremiumAppBar(isConnected: deviceService.isDeviceConnected),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF051E1D), Color(0xFF073330), Color(0xFF082E2C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: deviceService.selectedDevice == null
              ? const _NoDeviceView()
              : _DashboardLayout(
            deviceService:   deviceService,
            pulseAnimation:  _pulseAnimation,
            batteryColor:    _batteryColor(deviceService.battery),
          ),
        ),
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
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF13C4BC), Color(0xFF07B5AF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Smart Pot",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                "Control Dashboard",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _StatusChip(isConnected: isConnected),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NO DEVICE
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white12, width: 1.5),
            ),
            child: const Icon(Icons.bluetooth_disabled_rounded,
                size: 40, color: Colors.white30),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Device Selected",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Connect a device to get started",
            style: TextStyle(color: Colors.white30, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN DASHBOARD LAYOUT  (no scroll — Column fills SafeArea)
// ═══════════════════════════════════════════════════════════════════════════

class _DashboardLayout extends StatelessWidget {
  final DeviceService deviceService;
  final Animation<double> pulseAnimation;
  final Color batteryColor;

  const _DashboardLayout({
    required this.deviceService,
    required this.pulseAnimation,
    required this.batteryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Section 1: Device selector ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _DeviceDropdown(deviceService: deviceService),
        ),

        const SizedBox(height: 14),

        // ── Section 2: Stat chips row ──────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: "Live Temp",
                  value: "${deviceService.temperature}°",
                  icon: Icons.thermostat_rounded,
                  accent: const Color(0xFFFF7043),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: "Battery",
                  value: "${deviceService.battery}%",
                  icon: Icons.battery_charging_full_rounded,
                  accent: batteryColor,
                  trailing: _MiniProgressBar(
                    value: ((deviceService.battery is num)
                        ? (deviceService.battery as num).toDouble()
                        : 0.0)
                        .clamp(0.0, 100.0) /
                        100,
                    color: batteryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Section 3: Circular temperature dial (Expanded) ────
        Expanded(
          child: Center(
            child: _ArcTemperatureDial(
              currentTemp: (deviceService.temperature is num)
                  ? (deviceService.temperature as num).toDouble()
                  : 0.0,
              setTemp: deviceService.setTemperature,
              onChanged: (val) => deviceService.sendSetTemperature(val),
            ),
          ),
        ),

        // ── Section 4: Power panel (fixed bottom) ──────────────
        _BottomPowerPanel(
          isOn: deviceService.isOn,
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
// STAT CHIP
// ═══════════════════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2E2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 5),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MINI PROGRESS BAR
// ═══════════════════════════════════════════════════════════════════════════

class _MiniProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _MiniProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        backgroundColor: Colors.white10,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ARC TEMPERATURE DIAL  (CustomPainter + GestureDetector)
// ═══════════════════════════════════════════════════════════════════════════

class _ArcTemperatureDial extends StatefulWidget {
  final double currentTemp;
  final double setTemp;
  final ValueChanged<double> onChanged;

  const _ArcTemperatureDial({
    required this.currentTemp,
    required this.setTemp,
    required this.onChanged,
  });

  @override
  State<_ArcTemperatureDial> createState() => _ArcTemperatureDialState();
}

class _ArcTemperatureDialState extends State<_ArcTemperatureDial> {
  static const double _minTemp = 0;
  static const double _maxTemp = 1000;
  // Arc spans 240° starting from 150° (bottom-left) going clockwise
  static const double _startAngle = 150 * pi / 180;
  static const double _sweepAngle = 240 * pi / 180;

  double get _fraction =>
      (widget.setTemp - _minTemp) / (_maxTemp - _minTemp);

  void _handlePan(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle  = atan2(localPos.dy - center.dy, localPos.dx - center.dx);

    // Normalise angle to [0, 2π)
    double a = angle < 0 ? angle + 2 * pi : angle;

    // Distance from start of arc
    double s = _startAngle;
    double diff = a - s;
    if (diff < 0) diff += 2 * pi;

    if (diff > _sweepAngle + 0.3) return; // outside arc, ignore

    final frac  = (diff / _sweepAngle).clamp(0.0, 1.0);
    final value = _minTemp + frac * (_maxTemp - _minTemp);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(
        constraints.maxWidth.clamp(0.0, 280),
        constraints.maxWidth.clamp(0.0, 280),
      );

      return GestureDetector(
        onPanUpdate: (d) => _handlePan(d.localPosition, size),
        onTapDown:   (d) => _handlePan(d.localPosition, size),
        child: SizedBox(
          width:  size.width,
          height: size.height,
          child: CustomPaint(
            painter: _DialPainter(
              fraction:    _fraction,
              currentTemp: widget.currentTemp,
              setTemp:     widget.setTemp,
            ),
            child: Center(
              child: _DialCenter(
                currentTemp: widget.currentTemp,
                setTemp:     widget.setTemp,
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ── Custom painter ─────────────────────────────────────────────────────────

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
    final trackW = 14.0;
    final trackR = outerR - trackW / 2;
    final rect   = Rect.fromCircle(center: center, radius: trackR);

    // ── Track background ───────────────────────────────────────
    final trackPaint = Paint()
      ..color   = Colors.white.withOpacity(0.06)
      ..style   = PaintingStyle.stroke
      ..strokeWidth = trackW
      ..strokeCap   = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);

    // ── Filled arc ─────────────────────────────────────────────
    if (fraction > 0) {
      final gradient = SweepGradient(
        startAngle: _startAngle,
        endAngle:   _startAngle + _sweepAngle * fraction,
        colors: const [Color(0xFF07B5AF), Color(0xFF13C4BC), Color(0xFF7DD8D6)],
        stops: const [0.0, 0.6, 1.0],
      );
      final fillPaint = Paint()
        ..shader    = gradient.createShader(rect)
        ..style     = PaintingStyle.stroke
        ..strokeWidth = trackW
        ..strokeCap   = StrokeCap.round;
      canvas.drawArc(
          rect, _startAngle, _sweepAngle * fraction, false, fillPaint);
    }

    // ── Thumb knob ─────────────────────────────────────────────
    final thumbAngle = _startAngle + _sweepAngle * fraction;
    final thumbPos   = Offset(
      center.dx + trackR * cos(thumbAngle),
      center.dy + trackR * sin(thumbAngle),
    );

    // Outer glow
    canvas.drawCircle(
      thumbPos,
      12,
      Paint()
        ..color     = const Color(0xFF13C4BC).withOpacity(0.25)
        ..style     = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // White knob
    canvas.drawCircle(thumbPos, 8,
        Paint()..color = Colors.white..style = PaintingStyle.fill);
    // Inner accent
    canvas.drawCircle(thumbPos, 4,
        Paint()..color = const Color(0xFF07B5AF)..style = PaintingStyle.fill);

    // ── Tick marks ─────────────────────────────────────────────
    final tickR  = outerR + 4;
    final labelR = outerR + 16;
    for (int i = 0; i <= 10; i++) {
      final a   = _startAngle + _sweepAngle * (i / 10);
      final isMajor = i % 5 == 0;
      final tl  = isMajor ? 10.0 : 5.0;
      final p1  = Offset(center.dx + (tickR - tl) * cos(a),
          center.dy + (tickR - tl) * sin(a));
      final p2  = Offset(center.dx + tickR * cos(a),
          center.dy + tickR * sin(a));
      canvas.drawLine(
        p1, p2,
        Paint()
          ..color = isMajor
              ? Colors.white.withOpacity(0.35)
              : Colors.white.withOpacity(0.15)
          ..strokeWidth = isMajor ? 2 : 1,
      );
    }

    // ── Min / Max labels ───────────────────────────────────────
    _drawLabel(canvas, center, labelR + 6, _startAngle, "0°");
    _drawLabel(canvas, center, labelR + 6,
        _startAngle + _sweepAngle, "1000°");
  }

  void _drawLabel(
      Canvas canvas, Offset center, double r, double angle, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF4A7A78),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pos = Offset(
      center.dx + r * cos(angle) - tp.width / 2,
      center.dy + r * sin(angle) - tp.height / 2,
    );
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
          old.currentTemp != currentTemp ||
          old.setTemp != setTemp;
}

// ── Dial centre content ────────────────────────────────────────────────────

class _DialCenter extends StatelessWidget {
  final double currentTemp;
  final double setTemp;
  const _DialCenter({required this.currentTemp, required this.setTemp});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "SET TEMP",
          style: TextStyle(
            color: Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "${setTemp.toInt()}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const TextSpan(
                text: "°C",
                style: TextStyle(
                  color: Color(0xFF13C4BC),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0C2E2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.thermostat_rounded,
                  size: 12, color: Color(0xFFFF7043)),
              const SizedBox(width: 4),
              Text(
                "Now: $currentTemp°C",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Drag the ring to adjust",
          style: TextStyle(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w400,
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
  final bool isOn;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _BottomPowerPanel({
    required this.isOn,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2E2C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOn
              ? const Color(0xFF13C4BC).withOpacity(0.3)
              : Colors.white.withOpacity(0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn
                ? const Color(0xFF07B5AF).withOpacity(0.18)
                : Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Left: status info ──────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOn ? "DEVICE ACTIVE" : "DEVICE STANDBY",
                  style: TextStyle(
                    color: isOn
                        ? const Color(0xFF13C4BC)
                        : Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOn
                      ? "Tap power to turn off"
                      : "Tap power to turn on",
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 11.5,
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
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow halo
                    if (isOn)
                      Opacity(
                        opacity: pulseAnimation.value * 0.5,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF13C4BC).withOpacity(0.25),
                          ),
                        ),
                      ),

                    // Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isOn
                            ? const LinearGradient(
                          colors: [
                            Color(0xFF13C4BC),
                            Color(0xFF07B5AF)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : const LinearGradient(
                          colors: [
                            Color(0xFF142E2D),
                            Color(0xFF0F2524)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isOn
                                ? const Color(0xFF07B5AF).withOpacity(0.5)
                                : Colors.black.withOpacity(0.4),
                            blurRadius: isOn ? 20 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          color: isOn ? Colors.white : Colors.white30,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUS CHIP
// ═══════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final bool isConnected;
  const _StatusChip({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? const Color(0xFF4CAF82) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.7), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isConnected ? "Connected" : "Disconnected",
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DEVICE DROPDOWN
// ═══════════════════════════════════════════════════════════════════════════

class _DeviceDropdown extends StatelessWidget {
  final DeviceService deviceService;
  const _DeviceDropdown({required this.deviceService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2E2C),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF13C4BC), Color(0xFF07B5AF)],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.bluetooth_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
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
                  style: TextStyle(color: Colors.white38, fontSize: 13.5),
                ),
                dropdownColor: const Color(0xFF0A2A28),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38, size: 20),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
                items: deviceService.bluetoothService.connectedDevices
                    .map((device) => DropdownMenuItem(
                  value: device,
                  child: Text(device.name),
                ))
                    .toList(),
                onChanged: (device) {
                  if (device != null) deviceService.selectDevice(device);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}