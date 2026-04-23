import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/locale_service.dart';

/// Holds the current Locale and syncs with Firebase on login.
class LocaleProvider extends ChangeNotifier {
  final _service = LocaleService();
  Locale _locale = const Locale('en');
  StreamSubscription<User?>? _authSub;

  Locale get locale => _locale;

  LocaleProvider() {
    _init();
  }

  Future<void> _init() async {
    // Apply local immediately — no flicker on startup
    _locale = await _service.loadLocal();
    notifyListeners();

    // Sync from Firebase when user logs in
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _syncFromFirebase(user.uid);
    });
  }

  Future<void> _syncFromFirebase(String uid) async {
    final remote = await _service.fetchRemote(uid);
    if (remote == null || remote == _locale) return;
    _locale = remote;
    notifyListeners();
    await _service.saveLocal(_locale);
  }

  /// Call this when the user picks a new language.
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    await _service.saveLocal(locale);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await _service.pushRemote(uid, locale);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
