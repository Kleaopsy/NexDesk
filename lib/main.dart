import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() {
  runApp(const NexDeskApp());
}

class NexDeskApp extends StatelessWidget {
  const NexDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    // DynamicColorBuilder captures the system's accent color
    // across Windows, macOS, and Android.
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // Default brand color if system accent color is not available
        Color brandColor = const Color(0xFF7C3AED);

        return MaterialApp(
          title: 'NexDesk',
          debugShowCheckedModeBanner: false,

          // Automatically switches theme based on system settings
          themeMode: ThemeMode.system,

          // Light Theme Configuration
          theme: ThemeData(
            colorScheme:
                lightDynamic ??
                ColorScheme.fromSeed(
                  seedColor: brandColor,
                  brightness: Brightness.light,
                ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            useMaterial3: true,
          ),

          // Dark Theme Configuration
          darkTheme: ThemeData(
            colorScheme:
                darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: brandColor,
                  brightness: Brightness.dark,
                ),
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            useMaterial3: true,
          ),

          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access current theme context for responsive UI
    final theme = Theme.of(context);

    return Scaffold(
      // Background color adapts to the system theme surface color
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NexDesk',
              style: GoogleFonts.inter(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                // Adapts automatically to light/dark surface
                color: theme.colorScheme.onSurface,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dashboard setup complete 🚀',
              style: GoogleFonts.inter(
                fontSize: 18,
                // Modern opacity handling with .withValues
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
