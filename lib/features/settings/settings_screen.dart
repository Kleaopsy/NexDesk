import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/locale_service.dart';
import '../../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.settings,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Appearance ─────────────────────────────────────────────
                _SectionLabel(s.appearance),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: themeProvider,
                  builder: (context, _) {
                    final cs = Theme.of(context).colorScheme;
                    return _ThemeSelector(
                      current: themeProvider.mode,
                      onSelect: themeProvider.setMode,
                      cs: cs,
                      s: s,
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Language ───────────────────────────────────────────────
                _SectionLabel(s.language),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: localeProvider,
                  builder: (context, _) {
                    final cs = Theme.of(context).colorScheme;
                    return _LocaleSelector(
                      current: localeProvider.locale,
                      onSelect: localeProvider.setLocale,
                      cs: cs,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
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

// ── Theme selector ─────────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;
  final ColorScheme cs;
  final AppStrings s;

  const _ThemeSelector({
    required this.current,
    required this.onSelect,
    required this.cs,
    required this.s,
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
            label: s.systemTheme,
            subtitle: s.systemThemeSub,
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
            label: s.lightTheme,
            subtitle: s.lightThemeSub,
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
            label: s.darkTheme,
            subtitle: s.darkThemeSub,
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

// ── Locale selector ────────────────────────────────────────────────────────

class _LocaleSelector extends StatelessWidget {
  final Locale current;
  final ValueChanged<Locale> onSelect;
  final ColorScheme cs;

  const _LocaleSelector({
    required this.current,
    required this.onSelect,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    const locales = LocaleService.supported;

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
          for (int i = 0; i < locales.length; i++) ...[
            if (i > 0)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            _LocaleOption(
              locale: locales[i],
              isActive: current.languageCode == locales[i].languageCode,
              onTap: () => onSelect(locales[i]),
              cs: cs,
              isFirst: i == 0,
              isLast: i == locales.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _LocaleOption extends StatelessWidget {
  final Locale locale;
  final bool isActive;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isFirst;
  final bool isLast;

  const _LocaleOption({
    required this.locale,
    required this.isActive,
    required this.onTap,
    required this.cs,
    this.isFirst = false,
    this.isLast = false,
  });

  // Flag emoji per language code
  String get _flag => switch (locale.languageCode) {
    'tr' => '🇹🇷',
    _ => '🇬🇧',
  };

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
        hoverColor: cs.surfaceContainerLow,
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Flag in a rounded container
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
                child: Center(
                  child: Text(_flag, style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleService.labelOf(locale),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isActive ? cs.primary : cs.onSurface,
                      ),
                    ),
                    Text(
                      LocaleService.subtitleOf(locale),
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
