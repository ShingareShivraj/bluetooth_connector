import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/ble_bluetooth_service.dart';
import '../services/device_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();
    final user = context.watch<AuthService>().session?.user;
    final colors = _SettingsColors(theme.isDarkMode);
    final titleStyle = TextStyle(
      color: colors.text,
      fontSize: 22,
      fontWeight: FontWeight.w800,
    );
    final captionStyle = TextStyle(color: colors.muted, fontSize: 14);

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.page,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: colors.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text('Settings', style: titleStyle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: _MugMark(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text('Appearance', style: titleStyle),
            const SizedBox(height: 4),
            Text('Choose how Garam Mug looks.', style: captionStyle),
            const SizedBox(height: 14),
            _SettingsCard(
              colors: colors,
              padding: const EdgeInsets.all(6),
              children: [
                _ThemeOption(
                  colors: colors,
                  mode: ThemeMode.light,
                  currentMode: theme.themeMode,
                  icon: Icons.light_mode_outlined,
                  title: 'Light Mode',
                  subtitle: 'Clean and bright',
                  onTap: () => theme.setTheme(ThemeMode.light),
                ),
                const SizedBox(height: 4),
                _ThemeOption(
                  colors: colors,
                  mode: ThemeMode.dark,
                  currentMode: theme.themeMode,
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  subtitle: 'Comfortable in low light',
                  onTap: () => theme.setTheme(ThemeMode.dark),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Account', style: titleStyle),
            const SizedBox(height: 12),
            _SettingsCard(
              colors: colors,
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline_rounded, color: colors.text),
                  title: Text(user == null ? 'Account' : 'Signed in',
                      style: titleStyle.copyWith(fontSize: 16)),
                  subtitle: Text(user ?? 'Garam Mug account', style: captionStyle),
                ),
                Divider(height: 1, indent: 14, endIndent: 14, color: colors.border),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: colors.error),
                  title: Text('Log Out',
                      style: titleStyle.copyWith(fontSize: 16, color: colors.error)),
                  onTap: () async {
                    final auth = context.read<AuthService>();
                    final bluetooth = context.read<BleService>();
                    final device = context.read<DeviceService>();

                    try {
                      await bluetooth.stopDiscovery();

                      if (!await device.disconnectSelected()) {
                        throw StateError('Could not disconnect the selected mug.');
                      }

                      for (final mug in List.of(bluetooth.connectedDevices)) {
                        if (!await bluetooth.disconnectDevice(mug)) {
                          throw StateError('Could not disconnect a connected mug.');
                        }
                      }

                      await bluetooth.clearLastConnectedDevice();
                      await auth.signOut();

                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false,
                      );
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not complete logout. Please try again.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const _MugMark(),
                  Text('Garam Mug', style: titleStyle.copyWith(fontSize: 19)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('Smart warmth for every sip',
                textAlign: TextAlign.center, style: captionStyle),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.colors,
    required this.mode,
    required this.currentMode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final _SettingsColors colors;
  final ThemeMode mode;
  final ThemeMode currentMode;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = mode == currentMode;
    const radius = BorderRadius.all(Radius.circular(14));
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? colors.selected : Colors.transparent,
        borderRadius: radius,
        child: ListTile(
          shape: const RoundedRectangleBorder(borderRadius: radius),
          leading: Icon(icon, color: colors.text, size: 27),
          title: Text(title, style: TextStyle(
            color: colors.text, fontWeight: FontWeight.w800,
          )),
          subtitle: Text(subtitle, style: TextStyle(color: colors.muted)),
          trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? colors.selectionInk : colors.muted,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.colors,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final _SettingsColors colors;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: colors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: Column(children: children)),
  );
}

class _MugMark extends StatelessWidget {
  const _MugMark();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/ic_mug_amber.png',
    width: 34,
    height: 34,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class _SettingsColors {
  const _SettingsColors(this.dark);

  final bool dark;
  static const navy = Color(0xFF14243B);
  static const cream = Color(0xFFFFF8EE);
  Color get page => dark ? const Color(0xFF0B1422) : cream;
  Color get card => dark ? navy : Colors.white;
  Color get text => dark ? cream : navy;
  Color get muted => dark ? const Color(0xFFB3BFCC) : const Color(0xFF515F70);
  Color get border => dark ? const Color(0xFF2B4058) : const Color(0xFFE8DED1);
  Color get selected => dark ? const Color(0xFF493722) : const Color(0xFFFFEFD5);
  Color get selectionInk => dark ? const Color(0xFFF59E0B) : const Color(0xFF9A4C06);
  Color get error => dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
}
