import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/device_service.dart';
import '../services/theme_service.dart';

import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _powerBusy = false;
  TemperatureMode? _modeBusy;

  Future<void> _changePower(DeviceService service, bool enabled) async {
    if (_powerBusy) return;
    HapticFeedback.mediumImpact();
    debugPrint('POWER SWITCH PRESSED: $enabled');
    setState(() => _powerBusy = true);
    final success = enabled
        ? await service.turnOn()
        : await service.turnOff();
    debugPrint('POWER COMMAND RESULT: $success');
    if (!mounted) return;
    setState(() => _powerBusy = false);
    if (!success) _showError(service.lastError);
  }

  Future<void> _selectMode(
      DeviceService service,
      TemperatureMode mode,
      ) async {
    if (_modeBusy != null) return;
    HapticFeedback.selectionClick();
    debugPrint(
      'WARMTH MODE PRESSED: ${mode.label} -> TAR:${mode.espValue}',
    );
    setState(() => _modeBusy = mode);
    final success = await service.sendTemperatureMode(mode);
    if (!mounted) return;
    setState(() => _modeBusy = null);
    if (!success) _showError(service.lastError);
  }

  Future<void> _disconnect(DeviceService service) async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect Garam Mug?'),
        content: Text(
          'Heating controls will be unavailable until you reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await service.disconnectSelected();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      _showError(service.lastError);
    }
  }

  void _showError(String? message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message ?? 'Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _MugPalette(context.watch<ThemeService>().isDarkMode);
    final service = context.watch<DeviceService>();
    final connected = service.isDeviceConnected;
    final on = service.isOn;
    final battery = service.battery.clamp(0, 100);
    final batteryColor = battery < 15 ? palette.error
        : battery < 30 ? palette.warmInk : palette.green;
    final text = TextStyle(color: palette.text, fontWeight: FontWeight.w800);
    final secondary = TextStyle(color: palette.muted, fontSize: 13);

    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: palette.dark
            ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleSpacing: 0,
        title: Row(
          children: [
            _mugAsset('ic_mug_amber', 30),
            const SizedBox(width: 8),
            Flexible(child: Text('Garam Mug', style: text)),
          ],
        ),
        actions: [
          if (service.selectedDevice != null)
            IconButton(
              tooltip: 'Disconnect',
              onPressed: () => _disconnect(service),
              icon: const Icon(Icons.link_off_rounded),
            ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !connected
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bluetooth_disabled, color: palette.muted, size: 48),
              const SizedBox(height: 14),
              Text('Mug disconnected', style: text.copyWith(fontSize: 22)),
              const SizedBox(height: 8),
              Text('Return to the device screen to reconnect.',
                  textAlign: TextAlign.center, style: secondary),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: palette.text),
                onPressed: () => Navigator.maybePop(context),
                child: const Text('Find my mug'),
              ),
            ],
          ),
        ),
      )
          : SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.green.withOpacity(.14),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 9, color: palette.green),
                    const SizedBox(width: 7),
                    Text('Connected', style: text.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MugPanel(
              palette: palette,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _mugAsset('garam_mug_hero', 144),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                service.temperature > 0
                                    ? '${service.temperature.toStringAsFixed(1)}°C'
                                    : '—',
                                style: text.copyWith(fontSize: 46, height: 1.05),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Current temperature', style: secondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: palette.border),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      _MugMetric(
                        label: '$battery%',
                        semantics: 'Battery $battery percent',
                        icon: _mugAsset('ic_battery', 23, tint: batteryColor),
                        style: text,
                      ),
                      _MugMetric(
                        label: on ? 'Heating' : 'Heating off',
                        icon: _mugAsset('ic_heating', 22,
                            tint: on ? null : palette.muted),
                        style: text,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Set temperature', style: text.copyWith(fontSize: 21)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(15) > 21
                    ? 2 : 4;
                final width = (constraints.maxWidth - (count - 1) * 8) / count;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in TemperatureMode.values)
                      SizedBox(
                        width: width,
                        child: _TemperatureButton(
                          palette: palette,
                          mode: mode,
                          selected: mode == service.selectedTemperatureMode,
                          busy: mode == _modeBusy,
                          onPressed: _modeBusy == null
                              ? () => _selectMode(service, mode) : null,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _MugPanel(
              palette: palette,
              child: Row(
                children: [
                  Expanded(child: Text('Keep warm', style: text.copyWith(fontSize: 17))),
                  if (_powerBusy)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          color: palette.warmInk,
                          strokeWidth: 2,
                          semanticsLabel: 'Sending heating command',
                        ),
                      ),
                    )
                  else
                    Semantics(
                      label: 'Keep warm',
                      child: Switch(
                        value: on,
                        activeColor: Colors.white,
                        activeTrackColor: _MugPalette.amber,
                        onChanged: (enabled) => _changePower(service, enabled),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Keep the mug charged and within Bluetooth range.',
              textAlign: TextAlign.center,
              style: secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TemperatureButton extends StatelessWidget {
  const _TemperatureButton({
    required this.palette, required this.mode, required this.selected,
    required this.busy, required this.onPressed,
  });

  final _MugPalette palette;
  final TemperatureMode mode;
  final bool selected;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? _MugPalette.navy : palette.text;
    final label = '${mode.espValue}°C';
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          backgroundColor: selected ? _MugPalette.amber : palette.card,
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          disabledBackgroundColor: selected ? _MugPalette.amber : palette.card,
          side: BorderSide(color: selected ? _MugPalette.amber : palette.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: busy
            ? SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: foreground,
            semanticsLabel: 'Setting temperature to $label',
          ),
        )
            : FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _MugPanel extends StatelessWidget {
  const _MugPanel({required this.palette, required this.child});
  final _MugPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    decoration: BoxDecoration(
      color: palette.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: palette.border),
      boxShadow: palette.dark ? null : const [
        BoxShadow(color: Color(0x0D14243B), blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    child: child,
  );
}

class _MugMetric extends StatelessWidget {
  const _MugMetric({required this.label, required this.icon, required this.style,
    this.semantics});
  final String label;
  final Widget icon;
  final TextStyle style;
  final String? semantics;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 6),
      Text(label, style: style, semanticsLabel: semantics),
    ],
  );
}

Widget _mugAsset(String name, double size, {Color? tint}) => Image.asset(
  'assets/images/$name.png',
  width: size,
  height: size,
  fit: BoxFit.contain,
  color: tint,
  excludeFromSemantics: true,
);

class _MugPalette {
  const _MugPalette(this.dark);
  final bool dark;
  static const navy = Color(0xFF14243B);
  static const amber = Color(0xFFF59E0B);
  Color get page => dark ? const Color(0xFF0B1422) : const Color(0xFFFFF8EE);
  Color get card => dark ? navy : Colors.white;
  Color get text => dark ? const Color(0xFFFFF8EE) : navy;
  Color get muted => dark ? const Color(0xFFB3BFCC) : const Color(0xFF515F70);
  Color get border => dark ? const Color(0xFF2B4058) : const Color(0xFFE8DED1);
  Color get green => dark ? const Color(0xFF86EFAC) : const Color(0xFF16803C);
  Color get warmInk => dark ? amber : const Color(0xFF9A4C06);
  Color get error => dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
}
