import 'package:flutter/material.dart';
import '../../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Appearance'),
          const SizedBox(height: 12),
          // Rebuilds only this subtree on theme change
          ListenableBuilder(
            listenable: themeProvider,
            builder: (context, _) {
              final cs = Theme.of(context).colorScheme;
              return _ThemeSelector(
                current: themeProvider.mode,
                onSelect: themeProvider.setMode,
                cs: cs,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;
  final ColorScheme cs;

  const _ThemeSelector({
    required this.current,
    required this.onSelect,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          _ThemeOption(
            icon: Icons.brightness_auto_rounded,
            label: 'System',
            subtitle: 'Follows your device setting',
            isActive: current == ThemeMode.system,
            onTap: () => onSelect(ThemeMode.system),
            cs: cs,
            isFirst: true,
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          _ThemeOption(
            icon: Icons.light_mode_rounded,
            label: 'Light',
            subtitle: 'Always use light theme',
            isActive: current == ThemeMode.light,
            onTap: () => onSelect(ThemeMode.light),
            cs: cs,
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          _ThemeOption(
            icon: Icons.dark_mode_rounded,
            label: 'Dark',
            subtitle: 'Always use dark theme',
            isActive: current == ThemeMode.dark,
            onTap: () => onSelect(ThemeMode.dark),
            cs: cs,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// Stateless + InkWell — no local hover state, no stale _hovered bug
class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isFirst;
  final bool isLast;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
    required this.cs,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(12) : Radius.zero,
      bottom: isLast ? const Radius.circular(12) : Radius.zero,
    );

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: isActive ? null : onTap,
        borderRadius: radius,
        // InkWell handles hover highlight natively — no manual state needed
        hoverColor: cs.surfaceContainerLow,
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? cs.primaryContainer
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isActive ? cs.primary : cs.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Radio indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? cs.primary : cs.outlineVariant,
                    width: isActive ? 5.5 : 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
