import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/notes_service.dart';

// ── Color helpers ─────────────────────────────────────────────────────────────

extension NoteColorX on NoteColor {
  Color surface(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (this) {
      NoteColor.none => cs.surface,
      NoteColor.red => const Color(0xFFFFF0F0),
      NoteColor.orange => const Color(0xFFFFF4E6),
      NoteColor.yellow => const Color(0xFFFFFDE6),
      NoteColor.green => const Color(0xFFF0FFF4),
      NoteColor.blue => const Color(0xFFEFF6FF),
      NoteColor.purple => const Color(0xFFF5F0FF),
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

  String get emoji => switch (this) {
    NoteColor.none => '⬜',
    NoteColor.red => '🔴',
    NoteColor.orange => '🟠',
    NoteColor.yellow => '🟡',
    NoteColor.green => '🟢',
    NoteColor.blue => '🔵',
    NoteColor.purple => '🟣',
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _service = NotesService();
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
      // Auto-sync when connection restored
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
        final inTitle = n.title.toLowerCase().contains(q);
        final inContent = n.content.toLowerCase().contains(q);
        final inTags = n.tags.any((t) => t.toLowerCase().contains(q));
        // Hashtag search: #tag
        final isHashtag = q.startsWith('#');
        if (isHashtag) {
          final tag = q.substring(1);
          return n.tags.any((t) => t.toLowerCase().contains(tag));
        }
        return inTitle || inContent || inTags;
      }).toList();
    }
    setState(() => _filtered = result);
  }

  Set<String> get _allTags => _notes.expand((n) => n.tags).toSet();

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.of(context).push<Note?>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, __) =>
            _NoteEditorPage(note: note, animation: animation),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
      ),
    );
    if (result == null) return;
    final updated = await _service.saveNote(result, _notes);
    if (!mounted) return;
    setState(() => _notes = updated);
    _applyFilter();
  }

  Future<void> _deleteNote(String id) async {
    final updated = await _service.deleteNote(id, _notes);
    if (!mounted) return;
    setState(() => _notes = updated);
    _applyFilter();
  }

  Future<void> _togglePin(Note note) async {
    final updated = note.copyWith(
      isPinned: !note.isPinned,
      updatedAt: DateTime.now(),
    );
    final list = await _service.saveNote(updated, _notes);
    if (!mounted) return;
    setState(() => _notes = list);
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          _buildTopBar(cs),
          _buildFilterBar(cs),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? _buildEmpty(cs)
                : _isGrid
                ? _buildGrid()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Notes',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _online ? Colors.green : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _online
                          ? 'Synced · ${_notes.length} notes'
                          : 'Offline · local only',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Layout toggle
          _IconToggle(
            icon: _isGrid ? Icons.list_rounded : Icons.grid_view_rounded,
            onTap: () => setState(() {
              _isGrid = !_isGrid;
            }),
            cs: cs,
          ),
          const SizedBox(width: 8),
          // New note
          FilledButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New Note'),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: Column(
        children: [
          // Search
          TextField(
            onChanged: (v) {
              _search = v;
              _applyFilter();
            },
            style: TextStyle(fontSize: 13, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search notes or #tag...',
              hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          // Tag chips
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
                      _activeTag = null;
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
                          _activeTag = _activeTag == tag ? null : tag;
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final note = _filtered[i];
        return _NoteCard(
          key: ValueKey(note.id),
          note: note,
          onTap: () => _openEditor(note: note),
          onDelete: () => _deleteNote(note.id),
          onPin: () => _togglePin(note),
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
        );
      },
    );
  }

  // ── Empty ──────────────────────────────────────────────────────────────────

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sticky_note_2_outlined,
            size: 52,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            _search.isNotEmpty || _activeTag != null
                ? 'No matching notes'
                : 'No notes yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _search.isNotEmpty || _activeTag != null
                ? 'Try a different search or tag'
                : 'Tap "New Note" to get started',
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

  const _NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = widget.note;
    final bg = note.color.surface(context);
    final accent = note.color.accent(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.3),
              width: _hovered ? 1.5 : 0.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
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
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: accent,
                      ),
                    ),
                  if (note.title.isNotEmpty) ...[
                    Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                  ],
                  Expanded(
                    child: Text(
                      note.content.isEmpty ? 'Empty note' : note.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: note.content.isEmpty
                            ? cs.onSurfaceVariant
                            : cs.onSurface.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tags
                  if (note.tags.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: note.tags
                          .take(3)
                          .map((t) => _MiniTag(tag: t, accent: accent))
                          .toList(),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(note.updatedAt),
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              // Action buttons on hover
              if (_hovered)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionDot(
                        icon: note.isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        color: accent,
                        onTap: widget.onPin,
                      ),
                      const SizedBox(width: 4),
                      _ActionDot(
                        icon: Icons.close_rounded,
                        color: cs.error,
                        onTap: widget.onDelete,
                      ),
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

  const _NoteListTile({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
  });

  @override
  State<_NoteListTile> createState() => _NoteListTileState();
}

class _NoteListTileState extends State<_NoteListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = widget.note;
    final bg = note.color.surface(context);
    final accent = note.color.accent(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.3),
              width: _hovered ? 1.5 : 0.5,
            ),
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (note.content.isNotEmpty)
                      Text(
                        note.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        children: note.tags
                            .take(4)
                            .map((t) => _MiniTag(tag: t, accent: accent))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _relativeTime(note.updatedAt),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
              if (_hovered) ...[
                const SizedBox(width: 8),
                _ActionDot(
                  icon: note.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: accent,
                  onTap: widget.onPin,
                ),
                const SizedBox(width: 4),
                _ActionDot(
                  icon: Icons.close_rounded,
                  color: cs.error,
                  onTap: widget.onDelete,
                ),
              ],
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

  void _save() {
    final note = Note(
      id: widget.note?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      tags: _tags,
      color: _color,
      isPinned: _isPinned,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    Navigator.pop(context, note);
  }

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
    final bg = _color.surface(context);
    final accent = _color.accent(context);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: widget.animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // Toolbar
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                Platform.isMacOS ? 8 : 16,
                16,
                0,
              ),
              child: Row(
                children: [
                  // Back
                  SizedBox(width: Platform.isMacOS ? 70 : 0),
                  _ToolbarBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                    cs: cs,
                  ),
                  const SizedBox(width: 8),
                  // Pin
                  _ToolbarBtn(
                    icon: _isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    onTap: () => setState(() => _isPinned = !_isPinned),
                    cs: cs,
                    active: _isPinned,
                    accent: accent,
                  ),
                  const Spacer(),
                  // Color picker
                  ..._colorDots(cs),
                  const SizedBox(width: 8),
                  // Save
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _titleCtrl,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    letterSpacing: -0.5,
                  ),
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
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface.withValues(alpha: 0.85),
                    height: 1.65,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your note...',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            // Tag input + chips
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags
                          .map(
                            (t) => _RemovableTag(
                              tag: t,
                              accent: accent,
                              onRemove: () => setState(() => _tags.remove(t)),
                            ),
                          )
                          .toList(),
                    ),
                  if (_tags.isNotEmpty) const SizedBox(height: 8),
                  TextField(
                    controller: _tagCtrl,
                    onSubmitted: _addTag,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Add tag (press Enter)...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.tag_rounded,
                        size: 16,
                        color: accent,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerLow.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
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
      final dotColor = c == NoteColor.none
          ? cs.surfaceContainerHigh
          : c.accent(context);
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
            border: isSelected
                ? Border.all(
                    color: cs.onSurface.withValues(alpha: 0.3),
                    width: 2,
                  )
                : null,
          ),
        ),
      );
    }).toList();
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _IconToggle({
    required this.icon,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.active,
    required this.cs,
    required this.onTap,
  });

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
          border: Border.all(
            color: active
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? cs.primary : cs.onSurfaceVariant,
          ),
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
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: accent,
        ),
      ),
    );
  }
}

class _RemovableTag extends StatelessWidget {
  final String tag;
  final Color accent;
  final VoidCallback onRemove;

  const _RemovableTag({
    required this.tag,
    required this.accent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$tag',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: accent,
            ),
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

  const _ActionDot({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
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

  const _ToolbarBtn({
    required this.icon,
    required this.onTap,
    required this.cs,
    this.active = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? (accent ?? cs.primary).withValues(alpha: 0.12)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: active ? (accent ?? cs.primary) : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
