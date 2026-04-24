import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';
import '../../core/services/archive_service.dart';
import '../../core/services/notes_service.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _service = ArchiveService();
  final _notesService = NotesService();
  List<ArchivedItem> _items = [];
  List<ArchivedItem> _filtered = [];
  bool _loading = true;
  bool _online = false;
  bool _isGrid = true;
  String _search = '';
  ArchivedItemType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final items = await _service.syncAndLoad();
    final online = await _service.isOnline();
    if (!mounted) return;
    setState(() {
      _items = items;
      _online = online;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    var result = List<ArchivedItem>.from(_items);
    if (_typeFilter != null) {
      result = result.where((i) => i.type == _typeFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((i) => i.title.toLowerCase().contains(q) || i.preview.toLowerCase().contains(q)).toList();
    }
    setState(() => _filtered = result);
  }

  Future<void> _delete(String id, AppStrings s) async {
    final confirmed = await _showConfirm(title: s.deletePermanently, message: s.thisItemWillBeDeletedForever, confirmLabel: s.delete, isDangerous: true);
    if (confirmed != true) return;
    final updated = await _service.deleteItem(id, _items);
    if (!mounted) return;
    setState(() => _items = updated);
    _applyFilter();
  }

  Future<void> _restore(ArchivedItem item) async {
    final currentNotes = await _notesService.loadLocal();
    final updated = await _service.restoreNote(item, _items, _notesService, currentNotes);
    if (!mounted) return;
    setState(() => _items = updated);
    _applyFilter();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('"${item.title}" moved back to Notes'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  void _openReader(ArchivedItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, __) => _ArchiveReaderPage(item: item, animation: animation),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  Future<bool?> _showConfirm({required String title, required String message, required String confirmLabel, bool isDangerous = false}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(title: title, message: message, confirmLabel: confirmLabel, isDangerous: isDangerous),
    );
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
                ? _buildGrid(cs, s)
                : _buildList(cs, s),
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
                Text(s.archive, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5)),
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
                      _online ? '${s.syncedCloud} · ${_items.length} ${s.items}' : s.offlineOnly,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Grid/List toggle
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
              hintText: s.searchArchive,
              hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: s.all,
                  active: _typeFilter == null,
                  cs: cs,
                  onTap: () {
                    _typeFilter = null;
                    _applyFilter();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: s.notes,
                  icon: Icons.sticky_note_2_outlined,
                  active: _typeFilter == ArchivedItemType.note,
                  cs: cs,
                  onTap: () {
                    _typeFilter = _typeFilter == ArchivedItemType.note ? null : ArchivedItemType.note;
                    _applyFilter();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid ───────────────────────────────────────────────────────────────────

  Widget _buildGrid(ColorScheme cs, AppStrings s) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final item = _filtered[i];
        return _ArchiveCard(
          key: ValueKey(item.id),
          item: item,
          cs: cs,
          s: s,
          onTap: () => _openReader(item),
          onRestore: () => _restore(item),
          onDelete: () => _delete(item.id, s),
        );
      },
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList(ColorScheme cs, AppStrings s) {
    final groups = <String, List<ArchivedItem>>{};
    for (final item in _filtered) {
      final key = _dateGroup(item.archivedAt, s);
      groups.putIfAbsent(key, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      itemCount: groups.length,
      itemBuilder: (_, gi) {
        final group = groups.entries.elementAt(gi);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8, top: gi == 0 ? 0 : 16),
              child: Text(
                group.key,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5),
              ),
            ),
            ...group.value.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ArchiveTile(
                  item: item,
                  cs: cs,
                  s: s,
                  onTap: () => _openReader(item),
                  onRestore: () => _restore(item),
                  onDelete: () => _delete(item.id, s),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(ColorScheme cs, AppStrings s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined, size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Text(
            _search.isNotEmpty ? s.noMatchingItems : s.archiveEmpty,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(_search.isNotEmpty ? s.tryDifferentSearch : s.archivedNotesAppearHere, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Archive Card (Grid) ────────────────────────────────────────────────────────

class _ArchiveCard extends StatefulWidget {
  final ArchivedItem item;
  final ColorScheme cs;
  final AppStrings s;
  final VoidCallback onTap;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchiveCard({super.key, required this.item, required this.cs, required this.s, required this.onTap, required this.onRestore, required this.onDelete});

  @override
  State<_ArchiveCard> createState() => _ArchiveCardState();
}

class _ArchiveCardState extends State<_ArchiveCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final s = widget.s;
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? cs.outlineVariant.withValues(alpha: 0.6) : cs.outlineVariant.withValues(alpha: 0.3),
              width: _hovered ? 1.5 : 0.5,
            ),
            boxShadow: _hovered ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))] : [],
          ),
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Archive badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.archive_outlined, size: 10, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(_formatDate(item.archivedAt, s), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (item.title.isNotEmpty) ...[
                    Text(
                      item.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                  ],
                  Expanded(
                    child: Text(
                      item.preview.isEmpty ? s.emptyNote : item.preview,
                      style: TextStyle(fontSize: 12, color: item.preview.isEmpty ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.75), height: 1.5),
                      overflow: TextOverflow.fade,
                    ),
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
                      _ActionDot(icon: Icons.unarchive_rounded, color: cs.primary, onTap: widget.onRestore, tooltip: s.moveToNotes),
                      const SizedBox(width: 4),
                      _ActionDot(icon: Icons.delete_forever_rounded, color: cs.error, onTap: widget.onDelete, tooltip: s.deleteForever),
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

// ── Archive Tile (List) ────────────────────────────────────────────────────────

class _ArchiveTile extends StatefulWidget {
  final ArchivedItem item;
  final ColorScheme cs;
  final AppStrings s;
  final VoidCallback onTap;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchiveTile({required this.item, required this.cs, required this.s, required this.onTap, required this.onRestore, required this.onDelete});

  @override
  State<_ArchiveTile> createState() => _ArchiveTileState();
}

class _ArchiveTileState extends State<_ArchiveTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final s = widget.s;
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? cs.outlineVariant.withValues(alpha: 0.6) : cs.outlineVariant.withValues(alpha: 0.3),
              width: _hovered ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.sticky_note_2_outlined, size: 17, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isNotEmpty ? item.title : 'Untitled',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.preview,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(_formatDate(item.archivedAt, s), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hovered ? 1.0 : 0.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TileBtn(icon: Icons.unarchive_rounded, label: s.moveToNotes, color: cs.primary, onTap: widget.onRestore, cs: cs),
                    const SizedBox(width: 6),
                    _TileBtn(icon: Icons.delete_forever_rounded, label: s.deleteForever, color: cs.error, onTap: widget.onDelete, cs: cs),
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

// ── Archive Reader Page ────────────────────────────────────────────────────────

class _ArchiveReaderPage extends StatelessWidget {
  final ArchivedItem item;
  final Animation<double> animation;

  const _ArchiveReaderPage({required this.item, required this.animation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final note = item.toNote();
    final content = note?.content ?? item.preview;
    final tags = note?.tags ?? [];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve), child: child),
        );
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Column(
          children: [
            // Toolbar
            Container(
              padding: EdgeInsets.fromLTRB(16, Platform.isMacOS ? 10 : 16, 16, 0),
              child: Row(
                children: [
                  SizedBox(width: Platform.isMacOS ? 72 : 0),
                  // Back
                  Material(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_rounded, size: 18, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Archive badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.archive_outlined, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text(
                          s.archived,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Archive date
                  Text(_formatDate(item.archivedAt, s), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Title
            if (item.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Content — read-only, scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.topLeft, // ← İçeriği sol üste yaslar
                  child: Text(
                    content.isEmpty ? s.emptyNote : content,
                    // textAlign: TextAlign.start, // Bazı durumlarda buna da ihtiyaç olabilir
                    style: TextStyle(fontSize: 15, color: content.isEmpty ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.85), height: 1.65),
                  ),
                ),
              ),
            ),
            // Tags
            if (tags.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25), width: 0.5)),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '#$t',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.primary),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Small reusables ───────────────────────────────────────────────────────────

class _ActionDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const _ActionDot({required this.icon, required this.color, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final dot = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, size: 13, color: color),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: dot);
    return dot;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _FilterChip({required this.label, this.icon, required this.active, required this.cs, required this.onTap});

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: active ? cs.primary : cs.onSurfaceVariant), const SizedBox(width: 4)],
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? cs.primary : cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _TileBtn({required this.icon, required this.label, required this.color, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDangerous;

  const _ConfirmDialog({required this.title, required this.message, required this.confirmLabel, this.isDangerous = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 32, offset: const Offset(0, 12))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
              const SizedBox(height: 10),
              Text(message, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDangerous ? cs.error : cs.primary,
                      foregroundColor: isDangerous ? cs.onError : cs.onPrimary,
                    ),
                    child: Text(confirmLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _dateGroup(DateTime dt, AppStrings s) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(date).inDays;
  if (diff == 0) return s.today;
  if (diff == 1) return s.yesterday;
  if (diff < 7) return s.thisWeek;
  if (diff < 30) return s.thisMonth;
  return '${dt.year}';
}

String _formatDate(DateTime dt, AppStrings s) {
  final months = [s.january, s.february, s.march, s.april, s.may, s.june, s.july, s.august, s.september, s.october, s.november, s.december];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}
