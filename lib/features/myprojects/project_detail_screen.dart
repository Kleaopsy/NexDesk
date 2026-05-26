import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';
import 'package:nexdesk/core/services/notes_service.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/project_service.dart';
import '../notes/notes_screen.dart' show NoteColorX;

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  final List<Task> tasks;
  final List<Task> allTasks;
  final List<Project> allProjects;
  final ProjectService service;
  final ValueChanged<List<Task>> onTasksUpdated;
  final ValueChanged<List<Project>> onProjectUpdated;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.tasks,
    required this.allTasks,
    required this.allProjects,
    required this.service,
    required this.onTasksUpdated,
    required this.onProjectUpdated,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late List<Task> _tasks;
  late Project _project;
  List<Note> _linkedNotes = [];
  bool _loadingNotes = true;
  TaskStatus? _taskFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tasks = List.from(widget.tasks);
    _project = widget.project;
    _loadNotes();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final notesService = NotesService();
    final all = await notesService.loadLocal();
    if (!mounted) return;
    setState(() {
      _linkedNotes = all.where((n) => _project.noteIds.contains(n.id)).toList();
      _loadingNotes = false;
    });
  }

  List<Task> get _filtered {
    if (_taskFilter == null) return _tasks;
    return _tasks.where((t) => t.status == _taskFilter).toList();
  }

  double get _progress => _project.progress(_tasks);

  Future<void> _addTask() async {
    final result = await _showTaskForm(context);
    if (result == null) return;
    final task = Task(
      id: const Uuid().v4(),
      projectId: _project.id,
      title: result.title,
      description: result.description,
      status: TaskStatus.todo,
      priority: result.priority,
      dueDate: result.dueDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final updated = await widget.service.saveTask(task, widget.allTasks);
    if (!mounted) return;
    setState(() => _tasks = updated.where((t) => t.projectId == _project.id).toList());
    widget.onTasksUpdated(updated);
  }

  Future<void> _editTask(Task task) async {
    final result = await _showTaskForm(context, task: task);
    if (result == null) return;
    final updated = await widget.service.saveTask(
      task.copyWith(title: result.title, description: result.description, priority: result.priority, dueDate: result.dueDate, updatedAt: DateTime.now()),
      widget.allTasks,
    );
    if (!mounted) return;
    setState(() => _tasks = updated.where((t) => t.projectId == _project.id).toList());
    widget.onTasksUpdated(updated);
  }

  Future<void> _updateTaskStatus(Task task, TaskStatus status) async {
    final updated = await widget.service.saveTask(task.copyWith(status: status, updatedAt: DateTime.now()), widget.allTasks);
    if (!mounted) return;
    setState(() => _tasks = updated.where((t) => t.projectId == _project.id).toList());
    widget.onTasksUpdated(updated);
  }

  Future<void> _deleteTask(Task task) async {
    final updated = await widget.service.deleteTask(task.id, widget.allTasks);
    if (!mounted) return;
    setState(() => _tasks = updated.where((t) => t.projectId == _project.id).toList());
    widget.onTasksUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final done = _tasks.where((t) => t.status == TaskStatus.done).length;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // Header
          Container(
            color: cs.surface,
            padding: EdgeInsets.fromLTRB(
              20,
              Platform.isMacOS ? 48 : 16, // ← macOS traffic lights için boşluk
              20,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: cs.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    const SizedBox(width: 8),
                    Text(_project.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _project.title,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface, letterSpacing: -0.3),
                          ),
                          if (_project.description.isNotEmpty)
                            Text(
                              _project.description,
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Progress badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _progress == 1.0 ? Colors.green.withValues(alpha: 0.12) : cs.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$done/${_tasks.length} · ${(_progress * 100).round()}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _progress == 1.0 ? Colors.green : cs.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                if (_tasks.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(_progress == 1.0 ? Colors.green : cs.primary),
                    ),
                  ),
                const SizedBox(height: 12),
                // Tabs
                TabBar(
                  controller: _tabs,
                  tabs: [
                    Tab(text: s.tasks),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.notes),
                          if (_project.noteIds.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(99)),
                              child: Text(
                                '${_project.noteIds.length}',
                                style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TasksTab(
                  tasks: _filtered,
                  allTasks: _tasks,
                  taskFilter: _taskFilter,
                  cs: cs,
                  s: s,
                  onFilterChange: (f) => setState(() => _taskFilter = f),
                  onAdd: _addTask,
                  onEdit: _editTask,
                  onDelete: _deleteTask,
                  onStatusChange: _updateTaskStatus,
                ),
                _NotesTab(
                  project: _project,
                  linkedNotes: _linkedNotes,
                  loading: _loadingNotes,
                  cs: cs,
                  s: s,
                  service: widget.service,
                  allProjects: widget.allProjects,
                  onProjectUpdated: (projects) {
                    widget.onProjectUpdated(projects);
                    final updated = projects.firstWhere((p) => p.id == _project.id, orElse: () => _project);
                    setState(() => _project = updated);
                    _loadNotes();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tasks Tab ─────────────────────────────────────────────────────────────────

class _TasksTab extends StatelessWidget {
  final List<Task> tasks;
  final List<Task> allTasks;
  final TaskStatus? taskFilter;
  final ColorScheme cs;
  final AppStrings s;
  final ValueChanged<TaskStatus?> onFilterChange;
  final VoidCallback onAdd;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onDelete;
  final void Function(Task, TaskStatus) onStatusChange;

  const _TasksTab({
    required this.tasks,
    required this.allTasks,
    required this.taskFilter,
    required this.cs,
    required this.s,
    required this.onFilterChange,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter + Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChipSmall(label: s.all, active: taskFilter == null, cs: cs, onTap: () => onFilterChange(null)),
                      const SizedBox(width: 6),
                      _FilterChipSmall(label: s.todo, active: taskFilter == TaskStatus.todo, cs: cs, onTap: () => onFilterChange(TaskStatus.todo)),
                      const SizedBox(width: 6),
                      _FilterChipSmall(
                        label: s.inProgress,
                        active: taskFilter == TaskStatus.inProgress,
                        cs: cs,
                        onTap: () => onFilterChange(TaskStatus.inProgress),
                      ),
                      const SizedBox(width: 6),
                      _FilterChipSmall(label: s.done, active: taskFilter == TaskStatus.done, cs: cs, onTap: () => onFilterChange(TaskStatus.done)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: Text(s.addTask),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text(s.noTasksYet, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _TaskTile(
                    task: tasks[i],
                    cs: cs,
                    s: s,
                    onEdit: () => onEdit(tasks[i]),
                    onDelete: () => onDelete(tasks[i]),
                    onStatusChange: (status) => onStatusChange(tasks[i], status),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Task Tile ─────────────────────────────────────────────────────────────────

class _TaskTile extends StatefulWidget {
  final Task task;
  final ColorScheme cs;
  final AppStrings s;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<TaskStatus> onStatusChange;

  const _TaskTile({required this.task, required this.cs, required this.s, required this.onEdit, required this.onDelete, required this.onStatusChange});

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final task = widget.task;

    final priorityColor = switch (task.priority) {
      TaskPriority.high => Colors.red,
      TaskPriority.medium => Colors.orange,
      TaskPriority.low => Colors.green,
    };

    final isDone = task.status == TaskStatus.done;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? cs.outlineVariant.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Row(
            children: [
              // Status toggle
              GestureDetector(
                onTap: () => widget.onStatusChange(
                  task.status == TaskStatus.done
                      ? TaskStatus.todo
                      : task.status == TaskStatus.todo
                      ? TaskStatus.inProgress
                      : TaskStatus.done,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? cs.primary
                        : task.status == TaskStatus.inProgress
                        ? cs.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    border: Border.all(
                      color: isDone
                          ? cs.primary
                          : task.status == TaskStatus.inProgress
                          ? cs.primary
                          : cs.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: isDone
                      ? Icon(Icons.check_rounded, size: 12, color: cs.onPrimary)
                      : task.status == TaskStatus.inProgress
                      ? Icon(Icons.more_horiz_rounded, size: 12, color: cs.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Priority dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: priorityColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDone ? cs.onSurface.withValues(alpha: 0.4) : cs.onSurface,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.description.isNotEmpty)
                      Text(
                        task.description,
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (task.dueDate != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${task.dueDate!.day}/${task.dueDate!.month}',
                  style: TextStyle(fontSize: 10, color: task.dueDate!.isBefore(DateTime.now()) && !isDone ? cs.error : cs.onSurfaceVariant),
                ),
              ],
              if (_hovered) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(Icons.close_rounded, size: 14, color: cs.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notes Tab ─────────────────────────────────────────────────────────────────

class _NotesTab extends StatelessWidget {
  final Project project;
  final List<Note> linkedNotes;
  final bool loading;
  final ColorScheme cs;
  final AppStrings s;
  final ProjectService service;
  final List<Project> allProjects;
  final ValueChanged<List<Project>> onProjectUpdated;

  const _NotesTab({
    required this.project,
    required this.linkedNotes,
    required this.loading,
    required this.cs,
    required this.s,
    required this.service,
    required this.allProjects,
    required this.onProjectUpdated,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Link note button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text('${linkedNotes.length} ${s.notes} ${s.linked}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showLinkNotesDialog(context),
                icon: const Icon(Icons.link_rounded, size: 14),
                label: Text(s.linkNote),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: linkedNotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text(s.noLinkedNotes, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: linkedNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final note = linkedNotes[i];
                    return _LinkedNoteTile(
                      note: note,
                      cs: cs,
                      onUnlink: () async {
                        final updated = await service.toggleNoteLink(project.id, note.id, allProjects);
                        onProjectUpdated(updated);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showLinkNotesDialog(BuildContext context) async {
    final notesService = NotesService();
    final allNotes = await notesService.loadLocal();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => _LinkNotesDialog(
        allNotes: allNotes,
        linkedIds: project.noteIds,
        cs: cs,
        onToggle: (noteId) async {
          final updated = await service.toggleNoteLink(project.id, noteId, allProjects);
          onProjectUpdated(updated);
        },
      ),
    );
  }
}

class _LinkedNoteTile extends StatefulWidget {
  final Note note;
  final ColorScheme cs;
  final VoidCallback onUnlink;

  const _LinkedNoteTile({required this.note, required this.cs, required this.onUnlink});

  @override
  State<_LinkedNoteTile> createState() => _LinkedNoteTileState();
}

class _LinkedNoteTileState extends State<_LinkedNoteTile> {
  bool _hovered = false;

  void _openNote(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, animation, __) => _NoteReaderOverlay(note: widget.note, animation: animation),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final note = widget.note;
    // Reconstruct NoteColor from stored data
    final noteColor = note.color;
    final hasColor = noteColor != NoteColor.none;
    final accentColor = hasColor ? noteColor.accent(context) : cs.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _openNote(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasColor ? noteColor.surface(context) : cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? (hasColor ? accentColor.withValues(alpha: 0.5) : cs.primary.withValues(alpha: 0.4))
                  : (hasColor ? accentColor.withValues(alpha: 0.2) : cs.outlineVariant.withValues(alpha: 0.25)),
              width: _hovered ? 1 : 0.5,
            ),
          ),
          child: Row(
            children: [
              // Color dot
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
              ),
              Icon(Icons.sticky_note_2_outlined, size: 16, color: hasColor ? accentColor : cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isNotEmpty ? note.title : 'Untitled',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.content.isNotEmpty)
                      Text(
                        note.content,
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Hover actions
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hovered ? 1.0 : 0.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 13, color: hasColor ? accentColor : cs.primary),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onUnlink,
                      child: Icon(Icons.link_off_rounded, size: 13, color: cs.error),
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

// ── Link Notes Dialog ─────────────────────────────────────────────────────────

class _LinkNotesDialog extends StatefulWidget {
  final List<Note> allNotes;
  final List<String> linkedIds;
  final ColorScheme cs;
  final ValueChanged<String> onToggle;

  const _LinkNotesDialog({required this.allNotes, required this.linkedIds, required this.cs, required this.onToggle});

  @override
  State<_LinkNotesDialog> createState() => _LinkNotesDialogState();
}

class _LinkNotesDialogState extends State<_LinkNotesDialog> {
  late List<String> _linked;

  @override
  void initState() {
    super.initState();
    _linked = List.from(widget.linkedIds);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 500),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Link Notes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, color: cs.outlineVariant.withValues(alpha: 0.4)),
              Flexible(
                child: widget.allNotes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('No notes available.', style: TextStyle(color: cs.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.allNotes.length,
                        itemBuilder: (_, i) {
                          final note = widget.allNotes[i];
                          final isLinked = _linked.contains(note.id);
                          return ListTile(
                            leading: Icon(
                              isLinked ? Icons.check_circle_rounded : Icons.sticky_note_2_outlined,
                              color: isLinked ? cs.primary : cs.onSurfaceVariant,
                              size: 18,
                            ),
                            title: Text(note.title.isNotEmpty ? note.title : 'Untitled', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                            subtitle: note.content.isNotEmpty
                                ? Text(
                                    note.content,
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                if (isLinked) {
                                  _linked.remove(note.id);
                                } else {
                                  _linked.add(note.id);
                                }
                              });
                              widget.onToggle(note.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Task Form ─────────────────────────────────────────────────────────────────

class _TaskFormResult {
  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime? dueDate;
  _TaskFormResult({required this.title, required this.description, required this.priority, this.dueDate});
}

Future<_TaskFormResult?> _showTaskForm(BuildContext context, {Task? task}) {
  return showDialog<_TaskFormResult>(
    context: context,
    builder: (_) => _TaskFormDialog(task: task),
  );
}

class _TaskFormDialog extends StatefulWidget {
  final Task? task;
  const _TaskFormDialog({this.task});

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late TaskPriority _priority;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task?.title ?? '');
    _descCtrl = TextEditingController(text: widget.task?.description ?? '');
    _priority = widget.task?.priority ?? TaskPriority.medium;
    _dueDate = widget.task?.dueDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.task != null;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Task' : 'New Task',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Task name *',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Priority
              Text(
                'Priority',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: TaskPriority.values.map((p) {
                  final color = switch (p) {
                    TaskPriority.high => Colors.red,
                    TaskPriority.medium => Colors.orange,
                    TaskPriority.low => Colors.green,
                  };
                  final label = switch (p) {
                    TaskPriority.high => 'High',
                    TaskPriority.medium => 'Medium',
                    TaskPriority.low => 'Low',
                  };
                  final isSelected = _priority == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.15) : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? color : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Due date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        _dueDate != null ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}' : 'Set due date (optional)',
                        style: TextStyle(fontSize: 13, color: _dueDate != null ? cs.onSurface : cs.onSurfaceVariant),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: Icon(Icons.close_rounded, size: 14, color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(
                        context,
                        _TaskFormResult(title: _titleCtrl.text.trim(), description: _descCtrl.text.trim(), priority: _priority, dueDate: _dueDate),
                      );
                    },
                    child: Text(isEdit ? 'Save' : 'Add'),
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

// ── Small shared ──────────────────────────────────────────────────────────────

class _FilterChipSmall extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _FilterChipSmall({required this.label, required this.active, required this.cs, required this.onTap});

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
          style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? cs.primary : cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
// ── Note Reader Overlay ───────────────────────────────────────────────────────

class _NoteReaderOverlay extends StatelessWidget {
  final Note note;
  final Animation<double> animation;

  const _NoteReaderOverlay({required this.note, required this.animation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final bg = note.color.surface(context);
    final accent = note.color.accent(context);
    final hasColor = note.color != NoteColor.none;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1.0).animate(curve), child: child),
        );
      },
      child: Scaffold(
        backgroundColor: bg, // ← note rengi
        body: Column(
          children: [
            // Toolbar
            Container(
              padding: EdgeInsets.fromLTRB(16, Platform.isMacOS ? 10 : 16, 16, 0),
              child: Row(
                children: [
                  SizedBox(width: Platform.isMacOS ? 72 : 0),
                  Material(
                    color: cs.surfaceContainerLow.withValues(alpha: 0.7),
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
                  // Read-only badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: cs.surfaceContainerHigh.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 11, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          s.readOnly,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (note.isPinned) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.push_pin_rounded, size: 14, color: hasColor ? accent : cs.primary.withValues(alpha: 0.7)),
                  ],
                  const Spacer(),
                  // Color indicator pill
                  if (hasColor)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                    ),
                  Text(_relativeTime(note.updatedAt), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Title
            if (note.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    note.title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  note.content.isEmpty ? s.emptyNote : note.content,
                  style: TextStyle(fontSize: 15, color: note.content.isEmpty ? cs.onSurfaceVariant : cs.onSurface.withValues(alpha: 0.85), height: 1.65),
                ),
              ),
            ),
            // Tags
            if (note.tags.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: hasColor ? accent.withValues(alpha: 0.2) : cs.outlineVariant.withValues(alpha: 0.25), width: 0.5)),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasColor ? accent.withValues(alpha: 0.15) : cs.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$t',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: hasColor ? accent : cs.primary),
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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
