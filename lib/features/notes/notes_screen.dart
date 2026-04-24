import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/archive_service.dart';
import '../../core/services/notes_service.dart';

// ── Color helpers ─────────────────────────────────────────────────────────────
extension NoteColorX on NoteColor {
  Color surface(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      NoteColor.none => cs.surface,
      NoteColor.red => isDark ? const Color(0xFF2D1515) : const Color(0xFFFFF0F0),
      NoteColor.orange => isDark ? const Color(0xFF2D1E0A) : const Color(0xFFFFF4E6),
      NoteColor.yellow => isDark ? const Color(0xFF2D2A0A) : const Color(0xFFFFFDE6),
      NoteColor.green => isDark ? const Color(0xFF0F2D1A) : const Color(0xFFF0FFF4),
      NoteColor.blue => isDark ? const Color(0xFF0D1E2D) : const Color(0xFFEFF6FF),
      NoteColor.purple => isDark ? const Color(0xFF1A0D2D) : const Color(0xFFF5F0FF),
    };
  }

  Color accent(BuildContext context) {
    return switch (this) {
      NoteColor.none => Theme.of(context).colorScheme.primary,
      NoteColor.red => const Color(0xFFE53E3E),
      NoteColor.orange => const Color(0xFFDD6B20),
      NoteColor.yellow => const Color(0xFFD69E2E),
      NoteColor.green => const Color(0xFF38A169),
      NoteColor.blue => const Color(0xFF3182CE),
      NoteColor.purple => const Color(0xFF805AD5),
    };
  }
}

// ── Result type for editor ────────────────────────────────────────────────────

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
    final AppStrings s = AppStrings.of(context);
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
    final AppStrings s = AppStrings.of(context);

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

  // ── Top bar ────────────────────────────────────────────────────────────────

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
          // Layout toggle
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

  // ── Filter bar ─────────────────────────────────────────────────────────────

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

  // ── Grid ───────────────────────────────────────────────────────────────────

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

  // ── List ───────────────────────────────────────────────────────────────────

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

  // ── Empty ──────────────────────────────────────────────────────────────────

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

// ── Note Card (Grid) ──────────────────────────────────────────────────────────

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
            label: widget.note.isPinned ? 'Unpin' : 'Pin',
            cs: cs,
          ),
        ),
        PopupMenuItem(
          onTap: widget.onArchive,
          child: _ContextMenuItem(icon: Icons.archive_outlined, label: 'Archive', cs: cs),
        ),
        PopupMenuItem(
          onTap: widget.onDelete,
          child: _ContextMenuItem(icon: Icons.delete_outline_rounded, label: 'Delete', cs: cs, danger: true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final AppStrings s = AppStrings.of(context);
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
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Icon(Icons.push_pin_rounded, size: 13, color: accent),
                    ),
                  if (note.title.isNotEmpty) ...[
                    Text(
                      note.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                  ],
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final AppStrings s = AppStrings.of(context);
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

  void _showContextMenu(BuildContext context, ColorScheme cs) {
    final AppStrings s = AppStrings.of(context);
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
  late final TextEditingController _contentCtrl;
  late final TextEditingController _tagCtrl;
  late List<String> _tags;
  late NoteColor _color;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _contentCtrl = TextEditingController(text: n?.content ?? '');
    _tagCtrl = TextEditingController();
    _tags = List<String>.from(n?.tags ?? []);
    _color = n?.color ?? NoteColor.none;
    _isPinned = n?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Note _buildNote() => Note(
    id: widget.note?.id ?? const Uuid().v4(),
    title: _titleCtrl.text.trim(),
    content: _contentCtrl.text.trim(),
    tags: _tags,
    color: _color,
    isPinned: _isPinned,
    createdAt: widget.note?.createdAt ?? DateTime.now(),
    updatedAt: DateTime.now(),
  );

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
    final AppStrings s = AppStrings.of(context);
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
            // Toolbar
            Container(
              padding: EdgeInsets.fromLTRB(16, Platform.isMacOS ? 10 : 16, 16, 0),
              child: Row(
                children: [
                  SizedBox(width: Platform.isMacOS ? 72 : 0),
                  // Back
                  _ToolbarBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context), cs: cs),
                  const SizedBox(width: 6),
                  // Pin toggle
                  _ToolbarBtn(
                    icon: _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    onTap: () => setState(() => _isPinned = !_isPinned),
                    cs: cs,
                    active: _isPinned,
                    accent: accent,
                  ),
                  const SizedBox(width: 6),
                  // Archive
                  _ToolbarBtn(icon: Icons.archive_outlined, onTap: _archive, cs: cs, tooltip: s.archiveThisNote),
                  const Spacer(),
                  // Color picker
                  ..._colorDots(cs),
                  const SizedBox(width: 10),
                  // Save
                  FilledButton(
                    onPressed: _save,
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
            ),
            const SizedBox(height: 16),
            // Title
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
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  autofocus: widget.note == null,
                  style: TextStyle(fontSize: 15, color: cs.onSurface.withValues(alpha: 0.85), height: 1.65),
                  decoration: InputDecoration(
                    hintText: s.writeYourNote,
                    hintStyle: TextStyle(fontSize: 15, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            // Tag bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25), width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags.map((t) => _RemovableTag(tag: t, accent: accent, onRemove: () => setState(() => _tags.remove(t)))).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _tagCtrl,
                    onSubmitted: _addTag,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: s.addTag,
                      hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      prefixIcon: Icon(Icons.tag_rounded, size: 16, color: accent),
                      filled: true,
                      fillColor: cs.surfaceContainerLow.withValues(alpha: 0.6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _colorDots(ColorScheme cs) {
    return NoteColor.values.map((c) {
      final isSelected = _color == c;
      final dotColor = c == NoteColor.none ? cs.surfaceContainerHigh : c.accent(context);
      return GestureDetector(
        onTap: () => setState(() => _color = c),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isSelected ? 22 : 16,
          height: isSelected ? 22 : 16,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            border: isSelected ? Border.all(color: cs.onSurface.withValues(alpha: 0.25), width: 2) : null,
          ),
        ),
      );
    }).toList();
  }
}

// ── Reusable small widgets ────────────────────────────────────────────────────

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

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool active;
  final Color? accent;
  final String? tooltip;

  const _ToolbarBtn({required this.icon, required this.onTap, required this.cs, this.active = false, this.accent, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: active ? (accent ?? cs.primary).withValues(alpha: 0.12) : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: active ? (accent ?? cs.primary) : cs.onSurfaceVariant),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
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
