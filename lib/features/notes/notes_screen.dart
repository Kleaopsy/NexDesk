import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:nexdesk/core/l10n/app_strings.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/archive_service.dart';
import '../../core/services/notes_service.dart';

// ── Color helpers ─────────────────────────────────────────────────────────────

extension NoteColorX on NoteColor {
  Color surface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      NoteColor.none => Theme.of(context).colorScheme.surface,
      NoteColor.red => isDark ? const Color(0xFF2D1515) : const Color(0xFFFFF0F0),
      NoteColor.orange => isDark ? const Color(0xFF2D1E0A) : const Color(0xFFFFF4E6),
      NoteColor.yellow => isDark ? const Color(0xFF2D2A0A) : const Color(0xFFFFFDE6),
      NoteColor.green => isDark ? const Color(0xFF0F2D1A) : const Color(0xFFF0FFF4),
      NoteColor.blue => isDark ? const Color(0xFF0D1E2D) : const Color(0xFFEFF6FF),
      NoteColor.purple => isDark ? const Color(0xFF1A0D2D) : const Color(0xFFF5F0FF),
    };
  }

  Color accent(BuildContext context) => switch (this) {
    NoteColor.none => Theme.of(context).colorScheme.primary,
    NoteColor.red => const Color(0xFFE53E3E),
    NoteColor.orange => const Color(0xFFDD6B20),
    NoteColor.yellow => const Color(0xFFD69E2E),
    NoteColor.green => const Color(0xFF38A169),
    NoteColor.blue => const Color(0xFF3182CE),
    NoteColor.purple => const Color(0xFF805AD5),
  };
}

// ── Result types ──────────────────────────────────────────────────────────────

sealed class _EditorResult {}

class _SaveResult extends _EditorResult {
  final Note note;
  _SaveResult(this.note);
}

class _ArchiveResult extends _EditorResult {
  final Note note;
  _ArchiveResult(this.note);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _service = NotesService();
  final _archiveService = ArchiveService();
  List<Note> _notes = [];
  List<Note> _filtered = [];
  bool _loading = true;
  bool _online = false;
  bool _isGrid = true;
  String _search = '';
  String? _activeTag;
  StreamSubscription<bool>? _connSub;

  @override
  void initState() {
    super.initState();
    _init();
    _connSub = _service.connectivityStream.listen((online) {
      if (mounted) setState(() => _online = online);
      if (online) _sync();
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final notes = await _service.syncAndLoad();
    final online = await _service.isOnline();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _online = online;
      _loading = false;
    });
    _applyFilter();
  }

  Future<void> _sync() async {
    final notes = await _service.syncAndLoad();
    if (!mounted) return;
    setState(() => _notes = notes);
    _applyFilter();
  }

  void _applyFilter() {
    var result = List<Note>.from(_notes);
    if (_activeTag != null) {
      result = result.where((n) => n.tags.contains(_activeTag)).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((n) {
        if (q.startsWith('#')) {
          final tag = q.substring(1);
          return n.tags.any((t) => t.toLowerCase().contains(tag));
        }
        return n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q) || n.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }
    setState(() => _filtered = result);
  }

  Set<String> get _allTags => _notes.expand((n) => n.tags).toSet();

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.of(context).push<_EditorResult?>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, __) => _NoteEditorPage(note: note, animation: animation),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
      ),
    );
    if (result == null || !mounted) return;
    if (result is _SaveResult) {
      final updated = await _service.saveNote(result.note, _notes);
      if (!mounted) return;
      setState(() => _notes = updated);
      _applyFilter();
    } else if (result is _ArchiveResult) {
      await _archiveNote(result.note);
    }
  }

  Future<void> _deleteNote(String id) async {
    final updated = await _service.deleteNote(id, _notes);
    if (!mounted) return;
    setState(() => _notes = updated);
    _applyFilter();
  }

  Future<void> _togglePin(Note note) async {
    final updated = note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now());
    final list = await _service.saveNote(updated, _notes);
    if (!mounted) return;
    setState(() => _notes = list);
    _applyFilter();
  }

  Future<void> _archiveNote(Note note) async {
    final s = AppStrings.of(context);
    final updatedNotes = await _service.deleteNote(note.id, _notes);
    final currentArchive = await _archiveService.loadLocal();
    await _archiveService.archiveNote(note, currentArchive);
    if (!mounted) return;
    setState(() => _notes = updatedNotes);
    _applyFilter();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.noteArchived), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          _buildTopBar(cs, s),
          _buildFilterBar(cs, s),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? _buildEmpty(cs, s)
                : _isGrid
                ? _buildGrid()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.quickNotes, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _online ? Colors.green : cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _online ? '${s.syncedCloud} · ${_notes.length} ${s.notes}' : s.offlineOnly,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => setState(() => _isGrid = !_isGrid),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(_isGrid ? Icons.list_rounded : Icons.grid_view_rounded, size: 18, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(s.newNote),
            style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme cs, AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: Column(
        children: [
          TextField(
            onChanged: (v) {
              _search = v;
              _applyFilter();
            },
            style: TextStyle(fontSize: 13, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: s.searchNote,
              hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          if (_allTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TagChip(
                    label: 'All',
                    active: _activeTag == null,
                    cs: cs,
                    onTap: () {
                      setState(() => _activeTag = null);
                      _applyFilter();
                    },
                  ),
                  const SizedBox(width: 6),
                  ..._allTags.map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TagChip(
                        label: '#$tag',
                        active: _activeTag == tag,
                        cs: cs,
                        onTap: () {
                          setState(() => _activeTag = _activeTag == tag ? null : tag);
                          _applyFilter();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final note = _filtered[i];
        return _NoteCard(
          key: ValueKey(note.id),
          note: note,
          onTap: () => _openEditor(note: note),
          onDelete: () => _deleteNote(note.id),
          onPin: () => _togglePin(note),
          onArchive: () => _archiveNote(note),
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final note = _filtered[i];
        return _NoteListTile(
          key: ValueKey(note.id),
          note: note,
          onTap: () => _openEditor(note: note),
          onDelete: () => _deleteNote(note.id),
          onPin: () => _togglePin(note),
          onArchive: () => _archiveNote(note),
        );
      },
    );
  }

  Widget _buildEmpty(ColorScheme cs, AppStrings s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Text(
            _search.isNotEmpty || _activeTag != null ? s.noMatchingNotes : s.noNotesYet,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            _search.isNotEmpty || _activeTag != null ? s.tryDifferentSearchOrTag : s.tapNewNoteToGetStarted,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Note Card ─────────────────────────────────────────────────────────────────

class _NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onArchive;

  const _NoteCard({super.key, required this.note, required this.onTap, required this.onDelete, required this.onPin, required this.onArchive});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  void _showContextMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    showMenu(
      context: context,
      color: cs.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(offset.dx + size.width / 2, offset.dy + size.height / 2, offset.dx + size.width, offset.dy + size.height),
      items: [
        PopupMenuItem(
          onTap: widget.onPin,
          child: _ContextMenuItem(
            icon: widget.note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            label: widget.note.isPinned ? s.unpin : s.pin,
            cs: cs,
          ),
        ),
        PopupMenuItem(
          onTap: widget.onArchive,
          child: _ContextMenuItem(icon: Icons.archive_outlined, label: s.archive, cs: cs),
        ),
        PopupMenuItem(
          onTap: widget.onDelete,
          child: _ContextMenuItem(icon: Icons.delete_outline_rounded, label: s.delete, cs: cs, danger: true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final note = widget.note;
    final bg = note.color.surface(context);
    final accent = note.color.accent(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTap: () => _showContextMenu(context),
        onLongPress: () => _showContextMenu(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? accent.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3), width: _hovered ? 1.5 : 0.5),
            boxShadow: _hovered ? [BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 4))] : [],
          ),
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note.isPinned)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Icon(Icons.push_pin_rounded, size: 13, color: accent),
                              ),
                            if (note.title.isNotEmpty)
                              Text(
                                note.title,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (_hovered) const SizedBox(width: 72) else const SizedBox.shrink(),
                    ],
                  ),
                  if (note.title.isNotEmpty) const SizedBox(height: 5),
                  Expanded(
                    child: Text(
                      note.content.isEmpty ? s.emptyNote : note.content,
                      style: TextStyle(fontSize: 12, color: note.content.isEmpty ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.75), height: 1.5),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (note.tags.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: note.tags.take(3).map((t) => _MiniTag(tag: t, accent: accent)).toList(),
                    ),
                  const SizedBox(height: 6),
                  Text(_relativeTime(note.updatedAt, s), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              ),
              if (_hovered)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionDot(icon: note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: accent, onTap: widget.onPin),
                      const SizedBox(width: 4),
                      _ActionDot(icon: Icons.archive_outlined, color: cs.onSurfaceVariant, onTap: widget.onArchive),
                      const SizedBox(width: 4),
                      _ActionDot(icon: Icons.close_rounded, color: cs.error, onTap: widget.onDelete),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Note List Tile ────────────────────────────────────────────────────────────

class _NoteListTile extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onArchive;

  const _NoteListTile({super.key, required this.note, required this.onTap, required this.onDelete, required this.onPin, required this.onArchive});

  @override
  State<_NoteListTile> createState() => _NoteListTileState();
}

class _NoteListTileState extends State<_NoteListTile> {
  bool _hovered = false;

  void _showContextMenu(BuildContext context, ColorScheme cs) {
    final s = AppStrings.of(context);
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    showMenu(
      context: context,
      color: cs.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(offset.dx + size.width / 2, offset.dy + size.height / 2, offset.dx + size.width, offset.dy + size.height),
      items: [
        PopupMenuItem(
          onTap: widget.onPin,
          child: _ContextMenuItem(
            icon: widget.note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            label: widget.note.isPinned ? s.unpin : s.pin,
            cs: cs,
          ),
        ),
        PopupMenuItem(
          onTap: widget.onArchive,
          child: _ContextMenuItem(icon: Icons.archive_outlined, label: s.archive, cs: cs),
        ),
        PopupMenuItem(
          onTap: widget.onDelete,
          child: _ContextMenuItem(icon: Icons.delete_outline_rounded, label: s.delete, cs: cs, danger: true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final note = widget.note;
    final bg = note.color.surface(context);
    final accent = note.color.accent(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTap: () => _showContextMenu(context, cs),
        onLongPress: () => _showContextMenu(context, cs),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? accent.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3), width: _hovered ? 1.5 : 0.5),
          ),
          child: Row(
            children: [
              if (note.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(Icons.push_pin_rounded, size: 14, color: accent),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.title.isNotEmpty)
                      Text(
                        note.title,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (note.content.isNotEmpty)
                      Text(
                        note.content,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        children: note.tags.take(4).map((t) => _MiniTag(tag: t, accent: accent)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(_relativeTime(note.updatedAt, s), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeInOutCubic,
                child: _hovered
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 8),
                          _ActionDot(icon: note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: accent, onTap: widget.onPin),
                          const SizedBox(width: 4),
                          _ActionDot(icon: Icons.archive_outlined, color: cs.onSurfaceVariant, onTap: widget.onArchive),
                          const SizedBox(width: 4),
                          _ActionDot(icon: Icons.close_rounded, color: cs.error, onTap: widget.onDelete),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Editor Page ───────────────────────────────────────────────────────────────

class _NoteEditorPage extends StatefulWidget {
  final Note? note;
  final Animation<double> animation;

  const _NoteEditorPage({this.note, required this.animation});

  @override
  State<_NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<_NoteEditorPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _tagCtrl;
  late final quill.QuillController _quillCtrl;
  late List<String> _tags;
  late NoteColor _color;
  late bool _isPinned;
  final _editorFocusNode = FocusNode();
  final _editorScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _tagCtrl = TextEditingController();
    _tags = List<String>.from(n?.tags ?? []);
    _color = n?.color ?? NoteColor.none;
    _isPinned = n?.isPinned ?? false;

    // Load existing Quill delta or start empty
    if (n != null && n.contentJson.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(List<Map>.from(n.contentJson));
        _quillCtrl = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      } catch (_) {
        _quillCtrl = quill.QuillController.basic();
      }
    } else {
      _quillCtrl = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    _quillCtrl.dispose();
    _editorFocusNode.dispose();
    _editorScrollCtrl.dispose();
    super.dispose();
  }

  Note _buildNote() {
    final delta = _quillCtrl.document.toDelta().toJson();
    final plainText = Note.deltaToPlainText(delta);
    return Note(
      id: widget.note?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      content: plainText,
      contentJson: delta,
      tags: _tags,
      color: _color,
      isPinned: _isPinned,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _save() => Navigator.pop(context, _SaveResult(_buildNote()));
  void _archive() => Navigator.pop(context, _ArchiveResult(_buildNote()));

  void _addTag(String raw) {
    final tag = raw.trim().replaceAll('#', '').toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagCtrl.clear();
      return;
    }
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _color.surface(context);
    final accent = _color.accent(context);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final curve = CurvedAnimation(parent: widget.animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve), child: child),
        );
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // ── Top toolbar ─────────────────────────────────────────────────
            _TopToolbar(
              isPinned: _isPinned,
              color: _color,
              accent: accent,
              isDark: isDark,
              cs: cs,
              s: s,
              onBack: () => Navigator.pop(context),
              onPin: () => setState(() => _isPinned = !_isPinned),
              onArchive: _archive,
              onColorChange: (c) => setState(() => _color = c),
              onSave: _save,
            ),
            // ── Formatting toolbar ──────────────────────────────────────────
            _FormattingToolbar(controller: _quillCtrl, accent: accent, isDark: isDark, cs: cs),
            const SizedBox(height: 8),
            // ── Title ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _titleCtrl,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5),
                decoration: InputDecoration(
                  hintText: s.title,
                  hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant.withValues(alpha: 0.4), letterSpacing: -0.5),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Quill editor ────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: quill.QuillEditor(
                  controller: _quillCtrl,
                  focusNode: _editorFocusNode,
                  scrollController: _editorScrollCtrl,
                  config: quill.QuillEditorConfig(
                    autoFocus: widget.note == null,
                    expands: true,
                    padding: const EdgeInsets.only(bottom: 40),
                    placeholder: s.writeYourNote,
                    customStyles: _quillStyles(cs, isDark),
                  ),
                ),
              ),
            ),
            // ── Tag bar ─────────────────────────────────────────────────────
            _TagBar(
              tags: _tags,
              accent: accent,
              isDark: isDark,
              cs: cs,
              s: s,
              tagCtrl: _tagCtrl,
              onAdd: _addTag,
              onRemove: (t) => setState(() => _tags.remove(t)),
            ),
          ],
        ),
      ),
    );
  }

  quill.DefaultStyles _quillStyles(ColorScheme cs, bool isDark) {
    final baseColor = cs.onSurface.withValues(alpha: 0.85);
    final base = TextStyle(fontSize: 15, color: baseColor, height: 1.65);
    return quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(
        base,
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(0, 0),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      bold: base.copyWith(fontWeight: FontWeight.bold),
      italic: base.copyWith(fontStyle: FontStyle.italic),
      underline: base.copyWith(decoration: TextDecoration.underline),
      strikeThrough: base.copyWith(decoration: TextDecoration.lineThrough),
      h1: quill.DefaultTextBlockStyle(
        base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(12, 4),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h2: quill.DefaultTextBlockStyle(
        base.copyWith(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(10, 4),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h3: quill.DefaultTextBlockStyle(
        base.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(8, 4),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      lists: quill.DefaultListBlockStyle(
        base,
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(4, 0),
        const quill.VerticalSpacing(0, 0),
        null,
        null,
      ),
      quote: quill.DefaultTextBlockStyle(
        base.copyWith(color: cs.onSurface.withValues(alpha: 0.55), fontStyle: FontStyle.italic),
        const quill.HorizontalSpacing(8, 8),
        const quill.VerticalSpacing(0, 0),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          border: Border(left: BorderSide(color: cs.primary.withValues(alpha: 0.5), width: 3)),
        ),
      ),
      code: quill.DefaultTextBlockStyle(
        base.copyWith(fontFamily: 'monospace', fontSize: 13, color: cs.primary, backgroundColor: cs.primary.withValues(alpha: 0.08)),
        const quill.HorizontalSpacing(8, 8),
        const quill.VerticalSpacing(0, 0),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(color: cs.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
// ── Top Toolbar ───────────────────────────────────────────────────────────────

class _TopToolbar extends StatelessWidget {
  final bool isPinned;
  final NoteColor color;
  final Color accent;
  final bool isDark;
  final ColorScheme cs;
  final AppStrings s;
  final VoidCallback onBack;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final ValueChanged<NoteColor> onColorChange;
  final VoidCallback onSave;

  const _TopToolbar({
    required this.isPinned,
    required this.color,
    required this.accent,
    required this.isDark,
    required this.cs,
    required this.s,
    required this.onBack,
    required this.onPin,
    required this.onArchive,
    required this.onColorChange,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, Platform.isMacOS ? 10 : 16, 16, 0),
      child: Row(
        children: [
          SizedBox(width: Platform.isMacOS ? 72 : 0),
          _Btn(icon: Icons.arrow_back_rounded, onTap: onBack, isDark: isDark, cs: cs),
          const SizedBox(width: 6),
          _Btn(icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, onTap: onPin, isDark: isDark, cs: cs, active: isPinned, accent: accent),
          const SizedBox(width: 6),
          _Btn(icon: Icons.archive_outlined, onTap: onArchive, isDark: isDark, cs: cs, tooltip: s.archiveThisNote),
          const Spacer(),
          // Color dots
          ...NoteColor.values.map((c) {
            final isSelected = color == c;
            final dotColor = c == NoteColor.none ? (isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15)) : c.accent(context);
            return GestureDetector(
              onTap: () => onColorChange(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: isSelected ? 22 : 16,
                height: isSelected ? 22 : 16,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: isSelected ? Border.all(color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.2), width: 2) : null,
                ),
              ),
            );
          }),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(72, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(s.save, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Formatting Toolbar ────────────────────────────────────────────────────────

class _FormattingToolbar extends StatelessWidget {
  final quill.QuillController controller;
  final Color accent;
  final bool isDark;
  final ColorScheme cs;

  const _FormattingToolbar({required this.controller, required this.accent, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final bgColor = isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04);

    return Container(
      height: 40,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dividerColor, width: 0.5),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Headings
            _FmtBtn(label: 'H1', isText: true, onTap: () => _toggleHeader(context, 1), isDark: isDark, cs: cs, isActive: _isHeaderActive(1), accent: accent),
            _FmtBtn(label: 'H2', isText: true, onTap: () => _toggleHeader(context, 2), isDark: isDark, cs: cs, isActive: _isHeaderActive(2), accent: accent),
            _FmtBtn(label: 'H3', isText: true, onTap: () => _toggleHeader(context, 3), isDark: isDark, cs: cs, isActive: _isHeaderActive(3), accent: accent),
            _Divider(color: dividerColor),
            // Text formatting
            _FmtBtn(
              icon: Icons.format_bold_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.bold),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.bold),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.format_italic_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.italic),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.italic),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.format_underline_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.underline),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.underline),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.format_strikethrough_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.strikeThrough),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.strikeThrough),
              accent: accent,
            ),
            _Divider(color: dividerColor),
            // Lists
            _FmtBtn(
              icon: Icons.format_list_bulleted_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.ul),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.ul),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.format_list_numbered_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.ol),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.ol),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.checklist_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.unchecked),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.unchecked),
              accent: accent,
            ),
            _Divider(color: dividerColor),
            // Alignment
            _FmtBtn(
              icon: Icons.format_align_left_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.leftAlignment),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.leftAlignment),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.format_align_center_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.centerAlignment),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.centerAlignment),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.format_align_right_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.rightAlignment),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.rightAlignment),
              accent: accent,
            ),
            _Divider(color: dividerColor),
            // Block
            _FmtBtn(
              icon: Icons.format_quote_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.blockQuote),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.blockQuote),
              accent: accent,
            ),
            _FmtBtn(
              icon: Icons.code_rounded,
              onTap: () => controller.formatSelection(quill.Attribute.codeBlock),
              isDark: isDark,
              cs: cs,
              isActive: _isActive(quill.Attribute.codeBlock),
              accent: accent,
            ),
            _Divider(color: dividerColor),
            // Indent
            _FmtBtn(icon: Icons.format_indent_decrease_rounded, onTap: () => controller.indentSelection(false), isDark: isDark, cs: cs, accent: accent),
            _FmtBtn(icon: Icons.format_indent_increase_rounded, onTap: () => controller.indentSelection(true), isDark: isDark, cs: cs, accent: accent),
            _Divider(color: dividerColor),
            // Clear formatting
            _FmtBtn(
              icon: Icons.format_clear_rounded,
              onTap: () {
                controller.formatSelection(quill.Attribute.clone(quill.Attribute.bold, null));
                controller.formatSelection(quill.Attribute.clone(quill.Attribute.italic, null));
                controller.formatSelection(quill.Attribute.clone(quill.Attribute.underline, null));
              },
              isDark: isDark,
              cs: cs,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }

  bool _isActive(quill.Attribute attr) {
    final style = controller.getSelectionStyle();
    final val = style.attributes[attr.key];
    return val != null && val.value != null;
  }

  bool _isHeaderActive(int level) {
    final style = controller.getSelectionStyle();
    final val = style.attributes[quill.Attribute.header.key];
    return val?.value == level;
  }

  void _toggleHeader(BuildContext context, int level) {
    final isActive = _isHeaderActive(level);
    controller.formatSelection(isActive ? quill.Attribute.clone(quill.Attribute.header, null) : quill.HeaderAttribute(level: level));
  }
}

// ── Tag Bar ───────────────────────────────────────────────────────────────────

class _TagBar extends StatelessWidget {
  final List<String> tags;
  final Color accent;
  final bool isDark;
  final ColorScheme cs;
  final AppStrings s;
  final TextEditingController tagCtrl;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _TagBar({
    required this.tags,
    required this.accent,
    required this.isDark,
    required this.cs,
    required this.s,
    required this.tagCtrl,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((t) => _RemovableTag(tag: t, accent: accent, onRemove: () => onRemove(t))).toList(),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: tagCtrl,
            onSubmitted: onAdd,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: s.addTag,
              hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.tag_rounded, size: 16, color: accent),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small toolbar button ──────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;
  final bool active;
  final Color? accent;
  final String? tooltip;

  const _Btn({required this.icon, required this.onTap, required this.isDark, required this.cs, this.active = false, this.accent, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btnColor = active
        ? (accent ?? cs.primary).withValues(alpha: 0.18)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07));
    final iconColor = active ? (accent ?? cs.primary) : (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.65));

    final btn = Material(
      color: btnColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

// ── Formatting toolbar button ─────────────────────────────────────────────────

class _FmtBtn extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool isText;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;
  final bool isActive;
  final Color accent;

  const _FmtBtn({
    this.icon,
    this.label,
    this.isText = false,
    required this.onTap,
    required this.isDark,
    required this.cs,
    this.isActive = false,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accent;
    final inactiveColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: isActive ? accent.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: isText
            ? Text(
                label!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? activeColor : inactiveColor),
              )
            : Icon(icon!, size: 16, color: isActive ? activeColor : inactiveColor),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 20, margin: const EdgeInsets.symmetric(horizontal: 4), color: color);
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _TagChip({required this.label, required this.active, required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? cs.primary : cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String tag;
  final Color accent;
  const _MiniTag({required this.tag, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(
        '#$tag',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: accent),
      ),
    );
  }
}

class _RemovableTag extends StatelessWidget {
  final String tag;
  final Color accent;
  final VoidCallback onRemove;
  const _RemovableTag({required this.tag, required this.accent, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accent),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 12, color: accent),
          ),
        ],
      ),
    );
  }
}

class _ActionDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionDot({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final bool danger;
  const _ContextMenuItem({required this.icon, required this.label, required this.cs, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? cs.error : cs.onSurface;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _relativeTime(DateTime dt, AppStrings s) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return s.justNow;
  if (diff.inHours < 1) return '${diff.inMinutes}${s.minutesAgo}';
  if (diff.inDays < 1) return '${diff.inHours}${s.hoursAgo}';
  if (diff.inDays < 7) return '${diff.inDays}${s.daysAgo}';
  return '${dt.day}/${dt.month}/${dt.year}';
}
