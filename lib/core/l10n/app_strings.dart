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

  // ── Projects ───────────────────────────────────────────────────────────────────
  String get projects => _s('projects', 'proje');
  String get newProject => _s('New Project', 'Yeni Proje');
  String get noProjectsYet => _s('No projects yet', 'Henüz proje yok');
  String get createYourFirstProject => _s('Create your first project to get started', 'Başlamak için ilk projenizi oluşturun');
  String get active => _s('Active', 'Aktif');
  String get onHold => _s('On Hold', 'Beklemede');
  String get completed => _s('Completed', 'Tamamlandı');
  String get tasksDone => _s('done', 'tamamlandı');
  String get noTasksYet => _s('No tasks yet', 'Henüz görev yok');
  String get edit => _s('Edit', 'Düzenle');
  String get markComplete => _s('Mark as complete', 'Tamamlandı olarak işaretle');
  String get markActive => _s('Mark as active', 'Aktif olarak işaretle');
  String get putOnHold => _s('Put on hold', 'Beklemede bırak');
  String get resumeProject => _s('Resume', 'Devam ettir');
  String get readOnly => _s('Read only', 'Salt okunur');

  // ── Tasks ─────────────────────────────────────────────────────────────────────
  String get addTask => _s('Add task', 'Görev ekle');
  String get todo => _s('To Do', 'Yapılacak');
  String get inProgress => _s('In Progress', 'Devam Ediyor');
  String get done => _s('Done', 'Tamamlandı');
  String get noProjectsForTasks =>
      _s('No projects yet.\nCreate a project first to add tasks.', 'Henüz proje yok.\nGörev eklemek için önce bir proje oluşturun.');
  String get goToProjects => _s('Go to My Projects', 'Projelerime Git');

  // ── Notes link ────────────────────────────────────────────────────────────────
  String get linked => _s('linked', 'bağlı');
  String get linkNote => _s('Link note', 'Not bağla');
  String get noLinkedNotes => _s('No notes linked yet', 'Henüz bağlı not yok');

  // ── Notes ──────────────────────────────────────────────────────────────────
  String get newNote => _s('New Note', 'Yeni Not');
  String get emptyNote => _s('Empty note', 'Boş not');
  String get noNotesYet => _s('No notes yet', 'Henüz not yok');
  String get syncedCloud => _s('Synced', 'Senkronize edildi');
  String get offlineOnly => _s('Offline · local only', 'Çevrimdışı · yalnızca yerel');
  String get searchNotes => _s('Search notes or #tag...', 'Not veya #etiket ara...');
  String get addTag => _s('Add tag and press Enter...', 'Etiket ekle ve Enter\'a bas...');
  String get save => _s('Save', 'Kaydet');
  String get noteArchived => _s('Note archived', 'Not arşivlendi');
  String get searchNote => _s('Search note or #tag...', 'Not veya #etiket ara...');
  String get noMatchingNotes => _s('No matching notes', 'Eşleşen not yok');
  String get tryDifferentSearchOrTag => _s('Try a different search or tag', 'Farklı bir arama veya etiket deneyin');
  String get tapNewNoteToGetStarted => _s('Tap "New Note" to get started', '"Yeni Not" a dokunarak başlayın');
  String get archiveThisNote => _s('Archive this note', 'Bu notu arşivle');
  String get pin => _s('Pin', 'Sabitle');
  String get unpin => _s('Unpin', 'Sabitlemeyi kaldır');
  String get title => _s('Title', 'Başlık');
  String get writeYourNote => _s('Write your note...', 'Notunuzu yazın...');
  String get justNow => _s('Just now', 'Az önce');
  String get minutesAgo => _s('m ago', 'dk önce');
  String get hoursAgo => _s('h ago', 'sa önce');
  String get daysAgo => _s('d ago', 'g önce');

  // ── Archive ────────────────────────────────────────────────────────────────
  String get archiveEmpty => _s('Archive is empty', 'Arşiv boş');
  String get moveToNotes => _s('Move to Notes', 'Notlara Taşı');
  String get deleteForever => _s('Delete forever', 'Kalıcı olarak sil');
  String get searchArchive => _s('Search archive...', 'Arşivde ara...');
  String get movedBackToNotes => _s('moved back to Notes', 'Notlara geri taşındı');
  String get deletePermanently => _s('Delete permanently', 'Kalıcı olarak sil');
  String get thisItemWillBeDeletedForever => _s('This item will be deleted forever.', 'Bu öğe kalıcı olarak silinecek.');
  String get all => _s('All', 'Tümü');
  String get notes => _s('Notes', 'Notlar');
  String get noMatchingItems => _s('No matching items', 'Eşleşen öğe yok');
  String get tryDifferentSearch => _s('Try a different search term or clear filters.', 'Farklı bir arama terimi deneyin veya filtreleri temizleyin.');
  String get archivedNotesAppearHere => _s('Archived notes will appear here.', 'Arşivlenen notlar burada görünecektir.');
  String get items => _s('items', 'öğe');
  String get movetonotes => _s('Moves to Notes', 'Notlara Taşı');
  String get archived => _s('Archieved', 'Arşivlendi');
  String get january => _s('Jan', 'Oca');
  String get february => _s('Feb', 'Şub');
  String get march => _s('Mar', 'Mar');
  String get april => _s('Apr', 'Nis');
  String get may => _s('May', 'May');
  String get june => _s('Jun', 'Haz');
  String get july => _s('Jul', 'Tem');
  String get august => _s('Aug', 'Ağu');
  String get september => _s('Sep', 'Eyl');
  String get october => _s('Oct', 'Eki');
  String get november => _s('Nov', 'Kas');
  String get december => _s('Dec', 'Ara');

  // ── Settings ───────────────────────────────────────────────────────────────
  String get appearance => _s('Appearance', 'Görünüm');
  String get language => _s('Language', 'Dil');
  String get systemTheme => _s('System', 'Sistem');
  String get lightTheme => _s('Light', 'Açık');
  String get darkTheme => _s('Dark', 'Koyu');
  String get systemThemeSub => _s('Follows your device setting', 'Cihaz ayarını takip eder');
  String get lightThemeSub => _s('Always use light theme', 'Her zaman açık tema');
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
