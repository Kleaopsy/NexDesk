import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:nexdesk/core/providers/locale_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:macos_window_utils/macos/ns_window_button_type.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:macos_window_utils/window_manipulator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'core/theme_provider.dart';
import 'app/shell.dart';
import 'dart:io';

// Single global instance — shared across entire app
final themeProvider = ThemeProvider();
final localeProvider = LocaleProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (Platform.isMacOS) {
    ProcessSignal.sigterm.watch().listen((_) => exit(0));

    await WindowManipulator.initialize();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.hideTitle();
    await WindowManipulator.overrideStandardWindowButtonPosition(
      buttonType: NSWindowButtonType.closeButton,
      offset: const Offset(15, 15),
    );
    await WindowManipulator.overrideStandardWindowButtonPosition(
      buttonType: NSWindowButtonType.miniaturizeButton,
      offset: const Offset(38, 15),
    );
    await WindowManipulator.overrideStandardWindowButtonPosition(
      buttonType: NSWindowButtonType.zoomButton,
      offset: const Offset(61, 15),
    );
  }

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(850, 580));
  }

  runApp(const NexDeskApp());
}

class NexDeskApp extends StatefulWidget {
  const NexDeskApp({super.key});

  @override
  State<NexDeskApp> createState() => _NexDeskAppState();
}

class _NexDeskAppState extends State<NexDeskApp> {
  @override
  void initState() {
    super.initState();
    themeProvider.addListener(_onThemeChange);
    localeProvider.addListener(_onThemeChange); // same rebuild trigger
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChange);
    localeProvider.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        const Color brandColor = Color(0xFF7C3AED);

        return MaterialApp(
          title: 'NexDesk',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.mode,
          locale: localeProvider.locale,
          // Missing translations will fallback to English, which is our base language
          supportedLocales: const [Locale('en'), Locale('tr')],
          localeResolutionCallback: (locale, supported) =>
              localeProvider.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) => const AppShell(),
          ),
        );
      },
    );
  }
}
