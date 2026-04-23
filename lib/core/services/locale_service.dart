import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const _localKey = 'app_locale';

  // ── Supported locales ──────────────────────────────────────────────────────

  static const supported = [Locale('en'), Locale('tr')];

  static String labelOf(Locale locale) => switch (locale.languageCode) {
    'tr' => 'Türkçe',
    _ => 'English',
  };

  static String subtitleOf(Locale locale) => switch (locale.languageCode) {
    'tr' => 'Uygulamayı Türkçe kullan',
    _ => 'Use the app in English',
  };

  // ── Serialization ──────────────────────────────────────────────────────────

  static Locale parse(String? code) => supported.firstWhere(
    (l) => l.languageCode == code,
    orElse: () => const Locale('en'),
  );

  static String serialize(Locale locale) => locale.languageCode;

  // ── Local storage ──────────────────────────────────────────────────────────

  Future<Locale> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return parse(prefs.getString(_localKey));
  }

  Future<void> saveLocal(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, serialize(locale));
  }

  // ── Firebase ───────────────────────────────────────────────────────────────

  Future<Locale?> fetchRemote(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final value = doc.data()?['locale'] as String?;
      if (value == null) return null;
      return parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> pushRemote(String uid, Locale locale) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'locale': serialize(locale),
      }, SetOptions(merge: true));
    } catch (_) {
      // Will sync on next save
    }
  }
}
