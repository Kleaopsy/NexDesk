import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _localKey = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  ThemeProvider() {
    _init();
  }

  // these are stored separately to avoid unnecessary Firebase listeners when not logged in
  StreamSubscription<User?>? _authSub;

  Future<void> _init() async {
    await _loadLocal();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _fetchFromFirebase(user.uid);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ── Local ──────────────────────────────────────────────────────────────────

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_localKey);
    _mode = _parse(value);
    notifyListeners();
  }

  Future<void> _saveLocal(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, _serialize(mode));
  }

  // ── Firebase ───────────────────────────────────────────────────────────────

  Future<void> _fetchFromFirebase(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final value = doc.data()?['themeMode'] as String?;
      if (value == null) return;
      final remote = _parse(value);
      // Only update if different — avoids unnecessary rebuild
      if (remote != _mode) {
        _mode = remote;
        notifyListeners();
        await _saveLocal(_mode);
      }
    } catch (_) {
      // Firebase unreachable — keep local value
    }
  }

  Future<void> _pushToFirebase(ThemeMode mode) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'themeMode': _serialize(mode),
      }, SetOptions(merge: true));
    } catch (_) {
      // Will sync next login
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _saveLocal(mode);
    await _pushToFirebase(mode);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  ThemeMode _parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  String _serialize(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
