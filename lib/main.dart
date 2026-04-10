import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:macos_window_utils/macos/ns_window_button_type.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:macos_window_utils/window_manipulator.dart';
import 'dart:io';
import 'app/shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (Platform.isMacOS) {
    await WindowManipulator.initialize();

    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();

    // Hide the title bar (we'll make our own in the app)
    await WindowManipulator.hideTitle();

    // Close button (Red)
    await WindowManipulator.overrideStandardWindowButtonPosition(
      buttonType: NSWindowButtonType.closeButton,
      offset: const Offset(15, 15),
    );

    // Minimize button (Yellow)
    await WindowManipulator.overrideStandardWindowButtonPosition(
      buttonType: NSWindowButtonType.miniaturizeButton,
      offset: const Offset(40, 15),
    );

    // Fullscreen button (Green)
    await WindowManipulator.overrideStandardWindowButtonPosition(
      buttonType: NSWindowButtonType.zoomButton,
      offset: const Offset(65, 15),
    );
  }
  runApp(const NexDeskApp());
}

class NexDeskApp extends StatelessWidget {
  const NexDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        const Color brandColor = Color(0xFF7C3AED);

        return MaterialApp(
          title: 'NexDesk',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
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
          home: const AppShell(),
        );
      },
    );
  }
}
