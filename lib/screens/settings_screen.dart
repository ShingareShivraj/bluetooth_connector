import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Header
            _SettingsHeader(
              isDark: isDark,
              colors: colors,
            ),

            const SizedBox(height: 24),

            // Appearance
            const _SectionTitle(
              title: 'Appearance',
              subtitle: 'Personalize how Garam Mug looks on your device.',
            ),
            const SizedBox(height: 10),

            _SettingsCard(
              child: Column(
                children: [
                  _ThemeOption(
                    icon: Icons.light_mode_rounded,
                    title: 'Light Mode',
                    subtitle: 'Clean and bright appearance',
                    value: ThemeMode.light,
                    groupValue: themeService.themeMode,
                    accent: colors.primary,
                    onChanged: (mode) {
                      if (mode != null) {
                        context.read<ThemeService>().setTheme(mode);
                      }
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 62,
                    color: theme.dividerColor,
                  ),
                  _ThemeOption(
                    icon: Icons.dark_mode_rounded,
                    title: 'Dark Mode',
                    subtitle: 'Comfortable in low light',
                    value: ThemeMode.dark,
                    groupValue: themeService.themeMode,
                    accent: colors.primary,
                    onChanged: (mode) {
                      if (mode != null) {
                        context.read<ThemeService>().setTheme(mode);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Current theme
            const _SectionTitle(
              title: 'Current Theme',
              subtitle: 'Your active appearance preference.',
            ),
            const SizedBox(height: 10),

            _SettingsCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: _IconBox(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: colors.primary,
                ),
                title: const Text(
                  'Active appearance',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    isDark
                        ? 'Dark mode is currently enabled'
                        : 'Light mode is currently enabled',
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDark ? 'Dark' : 'Light',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mug settings - future-ready section
            const _SectionTitle(
              title: 'Garam Mug',
              subtitle: 'Manage your mug and connected-device preferences.',
            ),
            const SizedBox(height: 10),

            _SettingsCard(
              child: Column(
                children: [
                  _FutureSettingTile(
                    icon: Icons.bluetooth_rounded,
                    title: 'Mug Connection',
                    subtitle: 'Manage your connected Garam Mug',
                    colors: colors,
                  ),
                  Divider(
                    height: 1,
                    indent: 72,
                    color: theme.dividerColor,
                  ),
                  _FutureSettingTile(
                    icon: Icons.tune_rounded,
                    title: 'Mug Preferences',
                    subtitle: 'Temperature and heating preferences',
                    colors: colors,
                  ),
                  Divider(
                    height: 1,
                    indent: 72,
                    color: theme.dividerColor,
                  ),
                  _FutureSettingTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Heating and mug status alerts',
                    colors: colors,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account - ready for future functionality
            const _SectionTitle(
              title: 'Account',
              subtitle: 'Account and app access will appear here.',
            ),
            const SizedBox(height: 10),

            _SettingsCard(
              child: Column(
                children: [
                  _FutureSettingTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Account',
                    subtitle: 'Profile and account details',
                    colors: colors,
                  ),
                  Divider(
                    height: 1,
                    indent: 72,
                    color: theme.dividerColor,
                  ),
                  _FutureSettingTile(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    subtitle: 'Sign out of your Garam Mug account',
                    colors: colors,
                    showChevron: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // App information
            Center(
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.coffee_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Garam Mug',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Smart warmth for every sip',
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.isDark,
    required this.colors,
  });

  final bool isDark;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.secondary, .35) ??
                colors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(.12),
              ),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Garam Mug Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Make your smart mug experience feel right for you.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.78),
                    fontSize: 12,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.textTheme.titleMedium?.color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: .1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.dividerColor.withOpacity(.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.accent,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeMode value;
  final ThemeMode groupValue;
  final Color accent;
  final ValueChanged<ThemeMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
        child: Row(
          children: [
            _IconBox(
              icon: icon,
              color: selected
                  ? accent
                  : theme.textTheme.bodySmall?.color ??
                  Colors.grey,
              selected: selected,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Radio<ThemeMode>(
              value: value,
              groupValue: groupValue,
              activeColor: accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    this.selected = false,
  });

  final IconData icon;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(selected ? .12 : .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: color,
        size: 21,
      ),
    );
  }
}

class _FutureSettingTile extends StatelessWidget {
  const _FutureSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colors;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      enabled: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      leading: _IconBox(
        icon: icon,
        color: theme.textTheme.bodySmall?.color ?? Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          style: TextStyle(
            color: theme.textTheme.bodySmall?.color,
            fontSize: 11.5,
          ),
        ),
      ),
      trailing: showChevron
          ? Icon(
        Icons.chevron_right_rounded,
        color: theme.disabledColor,
      )
          : Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: theme.disabledColor.withOpacity(.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Soon',
          style: TextStyle(
            color: theme.disabledColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
