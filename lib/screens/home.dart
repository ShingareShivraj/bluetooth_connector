import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/device_service.dart';
import '../services/theme_service.dart';

class _C {
  static bool isDark = false;
  static Color page = Color(0xFFF5F8FF);
  static Color card = Colors.white;
  static final Color blue = Color(0xFF2563EB);
  static final Color blueDark = Color(0xFF1D4ED8);
  static Color blueSoft = Color(0xFFEFF6FF);
  static Color text = Color(0xFF0F172A);
  static Color muted = Color(0xFF64748B);
  static Color border = Color(0xFFE2E8F0);
  static final Color green = Color(0xFF16A34A);
  static final Color orange = Color(0xFFF97316);
  static final Color red = Color(0xFFEF4444);

  static void applyTheme(bool dark) {
    isDark = dark;
    page = dark ? Color(0xFF080D18) : Color(0xFFF5F8FF);
    card = dark ? Color(0xFF111827) : Colors.white;
    blueSoft = dark ? Color(0xFF172554) : Color(0xFFEFF6FF);
    text = dark ? Color(0xFFF8FAFC) : Color(0xFF0F172A);
    muted = dark ? Color(0xFF94A3B8) : Color(0xFF64748B);
    border = dark ? Color(0xFF263348) : Color(0xFFE2E8F0);
  }
}

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
    _C.applyTheme(context.watch<ThemeService>().isDarkMode);
    final service = context.watch<DeviceService>();
    final device = service.selectedDevice;

    return Scaffold(
      backgroundColor: _C.page,
      appBar: AppBar(
        backgroundColor: _C.card,
        foregroundColor: _C.text,
        systemOverlayStyle:
        _C.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        elevation: 0,
        titleSpacing: 4,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Garam Mug',
              style: TextStyle(
                color: _C.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              service.isDeviceConnected ? 'Connected and ready' : 'Disconnected',
              style: TextStyle(
                color: service.isDeviceConnected ? _C.green : _C.red,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (device != null)
            IconButton(
              tooltip: 'Disconnect',
              onPressed: () => _disconnect(service),
              icon: Icon(Icons.link_off_rounded, color: _C.muted),
            ),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _C.border),
        ),
      ),
      body: device == null
          ? _DisconnectedView(onBack: () => Navigator.maybePop(context))
          : SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _MugOverview(service: service),
            SizedBox(height: 14),
            _TemperatureModes(
              selected: service.selectedTemperatureMode,
              busy: _modeBusy,
              onSelected: (mode) => _selectMode(service, mode),
            ),
            SizedBox(height: 14),
            _PowerCard(
              isOn: service.isOn,
              isBusy: _powerBusy,
              onChanged: (enabled) => _changePower(service, enabled),
            ),
            SizedBox(height: 14),
            _SafetyNote(),
          ],
        ),
      ),
    );
  }
}

class _MugOverview extends StatelessWidget {
  _MugOverview({required this.service});

  final DeviceService service;

  String get _status {
    if (!service.isOn) return 'Heating is paused';
    final difference = service.targetTemperature - service.temperature;
    if (difference <= 1.5) return 'Ready for the perfect sip';
    if (difference <= 4) return 'Almost at your selected warmth';
    return 'Gently warming your coffee';
  }

  @override
  Widget build(BuildContext context) {
    final liveTemperature = service.temperature;
    final hasLiveTemperature = liveTemperature > 0;
    final liveMode = TemperatureMode.fromTemperature(liveTemperature);
    final battery = service.battery.clamp(0, 100);
    final batteryColor =
    battery >= 30 ? _C.green : battery >= 15 ? _C.orange : _C.red;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.blue, _C.blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.coffee_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.selectedDevice?.name ?? 'Garam Mug',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      _status,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      battery >= 85
                          ? Icons.battery_full_rounded
                          : Icons.battery_5_bar_rounded,
                      color: batteryColor,
                      size: 17,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$battery%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          Text(
            'CURRENT COFFEE TEMPERATURE',
            style: TextStyle(
              color: Colors.white.withOpacity(.65),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          SizedBox(height: 7),
          Row(
            children: [
              Icon(
                hasLiveTemperature
                    ? _modeIcon(liveMode)
                    : Icons.sync_rounded,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 9),
              Text(
                hasLiveTemperature
                    ? '${liveTemperature.toStringAsFixed(1)}°C  •  ${liveMode.label}'
                    : 'Waiting for mug status…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemperatureModes extends StatelessWidget {
  _TemperatureModes({
    required this.selected,
    required this.busy,
    required this.onSelected,
  });

  final TemperatureMode selected;
  final TemperatureMode? busy;
  final ValueChanged<TemperatureMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your warmth',
            style: TextStyle(
              color: _C.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Select how you want your coffee to feel.',
            style: TextStyle(color: _C.muted, fontSize: 12),
          ),
          SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
            ),
            itemCount: TemperatureMode.values.length,
            itemBuilder: (context, index) {
              final mode = TemperatureMode.values[index];
              final isSelected = mode == selected;
              final isBusy = mode == busy;
              final color = _modeColor(mode);
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: busy == null ? () => onSelected(mode) : null,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 220),
                  padding: EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(.11) : _C.page,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : _C.border,
                      width: isSelected ? 1.7 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withOpacity(.13),
                          shape: BoxShape.circle,
                        ),
                        child: isBusy
                            ? Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                            : Icon(_modeIcon(mode), color: color, size: 20),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          mode.label,
                          style: TextStyle(
                            color: isSelected ? color : _C.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (isSelected && !isBusy)
                        Icon(Icons.check_circle_rounded, color: color, size: 17),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PowerCard extends StatelessWidget {
  _PowerCard({
    required this.isOn,
    required this.isBusy,
    required this.onChanged,
  });

  final bool isOn;
  final bool isBusy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isOn ? _C.green : _C.muted).withOpacity(.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOn ? Icons.local_fire_department_rounded : Icons.power_settings_new,
              color: isOn ? _C.green : _C.muted,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOn ? 'Keep warm is on' : 'Keep warm is off',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  isOn
                      ? 'Your mug is maintaining the selected mode.'
                      : 'Turn it on when you are ready.',
                  style: TextStyle(color: _C.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          isBusy
              ? SizedBox(
            width: 36,
            height: 36,
            child: Padding(
              padding: EdgeInsets.all(7),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
              : Switch.adaptive(
            value: isOn,
            activeColor: _C.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.blueSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: _C.blue, size: 19),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'For best performance, keep the mug charged and within Bluetooth range.',
              style: TextStyle(
                color: Color(0xFF1E40AF),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DisconnectedView extends StatelessWidget {
  _DisconnectedView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled_rounded, size: 54, color: _C.muted),
            SizedBox(height: 16),
            Text(
              'Mug disconnected',
              style: TextStyle(
                color: _C.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Return to the device screen to reconnect your Garam Mug.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.muted, fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onBack,
              icon: Icon(Icons.bluetooth_searching_rounded),
              label: Text('Find my mug'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _modeColor(TemperatureMode mode) {
  switch (mode) {
    case TemperatureMode.coolAndCozy:
      return Color(0xFF3B82F6);
    case TemperatureMode.perfectSip:
      return Color(0xFF0D9488);
    case TemperatureMode.warmAndRich:
      return Color(0xFFF97316);
    case TemperatureMode.extraHot:
      return Color(0xFFEF4444);
  }
}

IconData _modeIcon(TemperatureMode mode) {
  switch (mode) {
    case TemperatureMode.coolAndCozy:
      return Icons.ac_unit_rounded;
    case TemperatureMode.perfectSip:
      return Icons.coffee_rounded;
    case TemperatureMode.warmAndRich:
      return Icons.local_fire_department_rounded;
    case TemperatureMode.extraHot:
      return Icons.whatshot_rounded;
  }
}
