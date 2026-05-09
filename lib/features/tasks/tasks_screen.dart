import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';
import '../../core/services/project_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _service = ProjectService();
  List<Project> _projects = [];
  List<Task> _tasks = [];
  bool _loading = true;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final result = await _service.syncAndLoad();
    if (!mounted) return;
    setState(() {
      _projects = result.projects;
      _tasks = result.tasks;
      _loading = false;
    });
  }

  List<Task> get _filtered {
    if (_selectedProjectId == null) return _tasks;
    return _tasks.where((t) => t.projectId == _selectedProjectId).toList();
  }

  Future<void> _updateTaskStatus(Task task, TaskStatus status) async {
    final updated = await _service.saveTask(task.copyWith(status: status, updatedAt: DateTime.now()), _tasks);
    if (!mounted) return;
    setState(() => _tasks = updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // No projects — redirect prompt
    if (_projects.isEmpty) {
      return Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rocket_launch_outlined, size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 14),
              Text(
                s.noProjectsForTasks,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  // Navigate to My Projects tab — index 1
                  // This needs to be wired up via the shell
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(s.goToProjects),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          _buildTopBar(cs, s),
          _buildProjectFilter(cs),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(s.noTasksYet, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                  )
                : _buildKanban(cs, s),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, AppStrings s) {
    final project = _selectedProjectId != null ? _projects.firstWhere((p) => p.id == _selectedProjectId, orElse: () => _projects.first) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Row(
        children: [
          Text(
            project != null ? '${project.emoji} ${project.title}' : s.tasks,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
          ),
          const Spacer(),
          // Progress summary
          if (_filtered.isNotEmpty) ...[
            Text(
              '${_filtered.where((t) => t.status == TaskStatus.done).length}/${_filtered.length} ${s.done}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectFilter(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: SizedBox(
        height: 28,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _FilterChip(label: 'All', active: _selectedProjectId == null, cs: cs, onTap: () => setState(() => _selectedProjectId = null)),
            const SizedBox(width: 6),
            ..._projects.map(
              (p) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _FilterChip(
                  label: '${p.emoji} ${p.title}',
                  active: _selectedProjectId == p.id,
                  cs: cs,
                  onTap: () => setState(() => _selectedProjectId = p.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanban(ColorScheme cs, AppStrings s) {
    final columns = [
      (TaskStatus.todo, s.todo, cs.surfaceContainerLow),
      (TaskStatus.inProgress, s.inProgress, cs.primaryContainer.withValues(alpha: 0.3)),
      (TaskStatus.done, s.done, Colors.green.withValues(alpha: 0.08)),
    ];

    return Row(
      children: columns.map((col) {
        final colTasks = _filtered.where((t) => t.status == col.$1).toList();
        return Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            decoration: BoxDecoration(color: col.$3, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                // Column header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      Text(
                        col.$2,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          '${colTasks.length}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tasks
                Expanded(
                  child: colTasks.isEmpty
                      ? Center(
                          child: Text('—', style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.3))),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          itemCount: colTasks.length,
                          itemBuilder: (_, i) =>
                              _KanbanCard(task: colTasks[i], cs: cs, projects: _projects, onStatusChange: (status) => _updateTaskStatus(colTasks[i], status)),
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Kanban Card ───────────────────────────────────────────────────────────────

class _KanbanCard extends StatefulWidget {
  final Task task;
  final ColorScheme cs;
  final List<Project> projects;
  final ValueChanged<TaskStatus> onStatusChange;

  const _KanbanCard({required this.task, required this.cs, required this.projects, required this.onStatusChange});

  @override
  State<_KanbanCard> createState() => _KanbanCardState();
}

class _KanbanCardState extends State<_KanbanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final task = widget.task;
    final project = widget.projects.where((p) => p.id == task.projectId).firstOrNull;

    final priorityColor = switch (task.priority) {
      TaskPriority.high => Colors.red,
      TaskPriority.medium => Colors.orange,
      TaskPriority.low => Colors.green,
    };

    final isDone = task.status == TaskStatus.done;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _hovered ? cs.outlineVariant.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
          boxShadow: _hovered ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: priorityColor),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDone ? cs.onSurface.withValues(alpha: 0.4) : cs.onSurface,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (project != null) ...[
              const SizedBox(height: 6),
              Text('${project.emoji} ${project.title}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ],
            if (task.dueDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 10, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    '${task.dueDate!.day}/${task.dueDate!.month}',
                    style: TextStyle(fontSize: 10, color: task.dueDate!.isBefore(DateTime.now()) && !isDone ? cs.error : cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            if (_hovered) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: TaskStatus.values.where((s) => s != task.status).map((s) {
                  final label = switch (s) {
                    TaskStatus.todo => '→ Todo',
                    TaskStatus.inProgress => '→ In Progress',
                    TaskStatus.done => '→ Done',
                  };
                  return GestureDetector(
                    onTap: () => widget.onStatusChange(s),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(4)),
                      child: Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.cs, required this.onTap});

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
