import 'package:flutter/material.dart';

/// Simple string lookup — no codegen needed.
/// Usage: AppStrings.of(context).dashboard
class AppStrings {
  final String languageCode;
  const AppStrings._(this.languageCode);

  factory AppStrings.of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return AppStrings._(code);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  String get dashboard => _s('Dashboard', 'Dashboard');
  String get myProjects => _s('My Projects', 'Projelerim');
  String get tasks => _s('Tasks', 'Görevler');
  String get quickNotes => _s('Quick Notes', 'Hızlı Notlar');
  String get archive => _s('Archive', 'Arşiv');
  String get settings => _s('Settings', 'Ayarlar');

  // ── Auth ───────────────────────────────────────────────────────────────────
  String get signIn => _s('Sign In', 'Giriş Yap');
  String get signUp => _s('Sign Up', 'Kayıt Ol');
  String get signOut => _s('Log out', 'Çıkış Yap');

  // ── Notes ──────────────────────────────────────────────────────────────────
  String get newNote => _s('New Note', 'Yeni Not');
  String get emptyNote => _s('Empty note', 'Boş not');
  String get noNotesYet => _s('No notes yet', 'Henüz not yok');
  String get syncedCloud => _s('Synced', 'Senkronize edildi');
  String get offlineOnly =>
      _s('Offline · local only', 'Çevrimdışı · yalnızca yerel');
  String get searchNotes =>
      _s('Search notes or #tag...', 'Not veya #etiket ara...');
  String get addTag =>
      _s('Add tag and press Enter...', 'Etiket ekle ve Enter\'a bas...');
  String get save => _s('Save', 'Kaydet');
  String get noteArchived => _s('Note archived', 'Not arşivlendi');

  // ── Archive ────────────────────────────────────────────────────────────────
  String get archiveEmpty => _s('Archive is empty', 'Arşiv boş');
  String get moveToNotes => _s('Move to Notes', 'Notlara Taşı');
  String get deleteForever => _s('Delete forever', 'Kalıcı olarak sil');
  String get searchArchive => _s('Search archive...', 'Arşivde ara...');
  String get movedBackToNotes =>
      _s('moved back to Notes', 'Notlara geri taşındı');

  // ── Settings ───────────────────────────────────────────────────────────────
  String get appearance => _s('Appearance', 'Görünüm');
  String get language => _s('Language', 'Dil');
  String get systemTheme => _s('System', 'Sistem');
  String get lightTheme => _s('Light', 'Açık');
  String get darkTheme => _s('Dark', 'Koyu');
  String get systemThemeSub =>
      _s('Follows your device setting', 'Cihaz ayarını takip eder');
  String get lightThemeSub =>
      _s('Always use light theme', 'Her zaman açık tema');
  String get darkThemeSub => _s('Always use dark theme', 'Her zaman koyu tema');

  // ── Generic ────────────────────────────────────────────────────────────────
  String get cancel => _s('Cancel', 'İptal');
  String get delete => _s('Delete', 'Sil');
  String get restore => _s('Restore', 'Geri Yükle');
  String get today => _s('Today', 'Bugün');
  String get yesterday => _s('Yesterday', 'Dün');
  String get thisWeek => _s('This week', 'Bu hafta');
  String get thisMonth => _s('This month', 'Bu ay');

  // ── Internal helper ────────────────────────────────────────────────────────
  String _s(String en, String tr) => languageCode == 'tr' ? tr : en;
}
