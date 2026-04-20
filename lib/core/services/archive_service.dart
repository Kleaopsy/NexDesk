import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notes_service.dart';

// Archive item wraps any archivable content type
enum ArchivedItemType { note }

class ArchivedItem {
  final String id;
  final ArchivedItemType type;
  final String title;
  final String preview;
  final Map<String, dynamic> data; // Original item data
  final DateTime archivedAt;

  const ArchivedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.preview,
    required this.data,
    required this.archivedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'preview': preview,
    'data': data,
    'archivedAt': archivedAt.toIso8601String(),
  };

  factory ArchivedItem.fromMap(Map<String, dynamic> m) => ArchivedItem(
    id: m['id'] as String,
    type: ArchivedItemType.values.firstWhere(
      (t) => t.name == m['type'],
      orElse: () => ArchivedItemType.note,
    ),
    title: m['title'] as String? ?? '',
    preview: m['preview'] as String? ?? '',
    data: Map<String, dynamic>.from(m['data'] as Map? ?? {}),
    archivedAt: DateTime.parse(m['archivedAt'] as String),
  );

  // Convenience: reconstruct a Note from archived data
  Note? toNote() {
    if (type != ArchivedItemType.note) return null;
    try {
      return Note.fromMap({...data, 'id': id});
    } catch (_) {
      return null;
    }
  }

  static ArchivedItem fromNote(Note note) => ArchivedItem(
    id: note.id,
    type: ArchivedItemType.note,
    title: note.title.isNotEmpty ? note.title : 'Untitled',
    preview: note.content.length > 120
        ? '${note.content.substring(0, 120)}...'
        : note.content,
    data: note.toMap(),
    archivedAt: DateTime.now(),
  );
}

class ArchiveService {
  static const _localKey = 'archive_v1';

  // ── Connectivity ───────────────────────────────────────────────────────────

  Future<bool> isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r.first != ConnectivityResult.none;
  }

  // ── Local ──────────────────────────────────────────────────────────────────

  Future<List<ArchivedItem>> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ArchivedItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveLocal(List<ArchivedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      jsonEncode(items.map((i) => i.toMap()).toList()),
    );
  }

  // ── Firebase ───────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('archive');
  }

  Future<List<ArchivedItem>> _fetchRemote() async {
    final col = _col();
    if (col == null) return [];
    final snap = await col.orderBy('archivedAt', descending: true).get();
    return snap.docs
        .map((d) => ArchivedItem.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  Future<void> _pushBatch(List<ArchivedItem> items) async {
    final col = _col();
    if (col == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in items) {
      final map = item.toMap()..remove('id');
      batch.set(col.doc(item.id), map);
    }
    await batch.commit();
  }

  Future<void> _deleteRemote(String id) async {
    await _col()?.doc(id).delete();
  }

  // ── Merge ──────────────────────────────────────────────────────────────────

  List<ArchivedItem> _merge(
    List<ArchivedItem> local,
    List<ArchivedItem> remote,
  ) {
    final map = <String, ArchivedItem>{};
    for (final item in [...local, ...remote]) {
      map[item.id] = item; // Last write wins — archive items don't mutate
    }
    return map.values.toList()
      ..sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<List<ArchivedItem>> syncAndLoad() async {
    final local = await loadLocal();
    if (!await isOnline()) return local;
    try {
      final remote = await _fetchRemote();
      final merged = _merge(local, remote);
      await _saveLocal(merged);
      await _pushBatch(merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<List<ArchivedItem>> archiveNote(
    Note note,
    List<ArchivedItem> current,
  ) async {
    final item = ArchivedItem.fromNote(note);
    final updated = [item, ...current.where((i) => i.id != item.id)];
    await _saveLocal(updated);
    if (await isOnline()) {
      try {
        await _pushBatch([item]);
      } catch (_) {}
    }
    return updated;
  }

  Future<List<ArchivedItem>> deleteItem(
    String id,
    List<ArchivedItem> current,
  ) async {
    final updated = current.where((i) => i.id != id).toList();
    await _saveLocal(updated);
    if (await isOnline()) {
      try {
        await _deleteRemote(id);
      } catch (_) {}
    }
    return updated;
  }

  Future<List<ArchivedItem>> clearAll(List<ArchivedItem> current) async {
    await _saveLocal([]);
    if (await isOnline()) {
      try {
        final col = _col();
        if (col != null) {
          final batch = FirebaseFirestore.instance.batch();
          for (final item in current) {
            batch.delete(col.doc(item.id));
          }
          await batch.commit();
        }
      } catch (_) {}
    }
    return [];
  }
}
