import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NoteColor { none, red, orange, yellow, green, blue, purple }

class Note {
  final String id;
  final String title;
  final String content;
  final List contentJson;
  final List<String> tags;
  final NoteColor color;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.contentJson,
    required this.tags,
    required this.color,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  Note copyWith({String? title, String? content, List? contentJson, List<String>? tags, NoteColor? color, bool? isPinned, DateTime? updatedAt}) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    contentJson: contentJson ?? this.contentJson,
    tags: tags ?? this.tags,
    color: color ?? this.color,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'contentJson': contentJson,
    'tags': tags,
    'color': color.name,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Note.fromMap(Map<String, dynamic> m) {
    final rawJson = m['contentJson'];
    List contentJson;
    if (rawJson != null && rawJson is List && rawJson.isNotEmpty) {
      contentJson = rawJson;
    } else {
      final text = m['content'] as String? ?? '';
      contentJson = text.isEmpty
          ? [
              {'insert': '\n'},
            ]
          : [
              {'insert': '$text\n'},
            ];
    }
    return Note(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      content: m['content'] as String? ?? '',
      contentJson: contentJson,
      tags: List<String>.from(m['tags'] as List? ?? []),
      color: NoteColor.values.firstWhere((c) => c.name == m['color'], orElse: () => NoteColor.none),
      isPinned: m['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
    );
  }

  static String deltaToPlainText(List delta) {
    final buffer = StringBuffer();
    for (final op in delta) {
      if (op is Map && op['insert'] is String) {
        buffer.write(op['insert'] as String);
      }
    }
    return buffer.toString().trim();
  }
}

class NotesService {
  static const _localKey = 'notes_v1';

  Future<bool> isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r.first != ConnectivityResult.none;
  }

  Stream<bool> get connectivityStream => Connectivity().onConnectivityChanged.map((r) => r.first != ConnectivityResult.none);

  Future<List<Note>> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Note.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveLocal(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, jsonEncode(notes.map((n) => n.toMap()).toList()));
  }

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('notes');
  }

  Future<List<Note>> _fetchRemote() async {
    final col = _col();
    if (col == null) return [];
    final snap = await col.orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => Note.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<void> _pushBatch(List<Note> notes) async {
    final col = _col();
    if (col == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in notes) {
      batch.set(col.doc(n.id), n.toMap()..remove('id'));
    }
    await batch.commit();
  }

  Future<void> _deleteRemote(String id) async {
    await _col()?.doc(id).delete();
  }

  List<Note> _merge(List<Note> local, List<Note> remote) {
    final map = <String, Note>{};
    for (final n in [...local, ...remote]) {
      final ex = map[n.id];
      if (ex == null || n.updatedAt.isAfter(ex.updatedAt)) map[n.id] = n;
    }
    return map.values.toList()..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  Future<List<Note>> syncAndLoad() async {
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

  Future<List<Note>> saveNote(Note note, List<Note> current) async {
    final updated = _merge([note], current.where((n) => n.id != note.id).toList());
    await _saveLocal(updated);
    if (await isOnline()) {
      try {
        await _pushBatch([note]);
      } catch (_) {}
    }
    return updated;
  }

  Future<List<Note>> deleteNote(String id, List<Note> current) async {
    final updated = current.where((n) => n.id != id).toList();
    await _saveLocal(updated);
    if (await isOnline()) {
      try {
        await _deleteRemote(id);
      } catch (_) {}
    }
    return updated;
  }
}
