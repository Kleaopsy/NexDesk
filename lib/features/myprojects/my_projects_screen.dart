import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/project_service.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _service = ProjectService();
  List<Project> _projects = [];
  List<Task> _tasks = [];
  bool _loading = true;
  bool _online = false;
  ProjectStatus? _filter;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final result = await _service.syncAndLoad();
    final online = await _service.isOnline();
    if (!mounted) return;
    setState(() {
      _projects = result.projects;
      _tasks = result.tasks;
      _online = online;
      _loading = false;
    });
  }

  List<Project> get _filtered {
    if (_filter == null) return _projects;
    return _projects.where((p) => p.status == _filter).toList();
  }

  Future<void> _createProject() async {
    final result = await _showProjectForm(context);
    if (result == null) return;
    final project = Project(
      id: const Uuid().v4(),
      title: result.title,
      description: result.description,
      emoji: result.emoji,
      status: ProjectStatus.active,
      noteIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final updated = await _service.saveProject(project, _projects);
    if (!mounted) return;
    setState(() => _projects = updated);
  }

  Future<void> _editProject(Project project) async {
    final result = await _showProjectForm(context, project: project);
    if (result == null) return;
    final updated = await _service.saveProject(
      project.copyWith(title: result.title, description: result.description, emoji: result.emoji, updatedAt: DateTime.now()),
      _projects,
    );
    if (!mounted) return;
    setState(() => _projects = updated);
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await _showConfirm(title: 'Delete project', message: 'This will permanently delete "${project.title}" and all its tasks.');
    if (confirmed != true || !mounted) return;
    final result = await _service.deleteProject(project.id, _projects, _tasks);
    if (!mounted) return;
    setState(() {
      _projects = result.projects;
      _tasks = result.tasks;
    });
  }

  void _openProject(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          tasks: _tasks.where((t) => t.projectId == project.id).toList(),
          allTasks: _tasks,
          service: _service,
          onTasksUpdated: (tasks) => setState(() => _tasks = tasks),
          onProjectUpdated: (projects) => setState(() => _projects = projects),
          allProjects: _projects,
        ),
      ),
    );
  }

  Future<bool?> _showConfirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
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
                : _buildGrid(cs, s),
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
                Text(s.myProjects, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5)),
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
                      _online ? '${s.syncedCloud} · ${_projects.length} ${s.projects}' : s.offlineOnly,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(s.newProject),
            style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme cs, AppStrings s) {
    final filters = [(null, s.all), (ProjectStatus.active, s.active), (ProjectStatus.onHold, s.onHold), (ProjectStatus.completed, s.completed)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: SizedBox(
        height: 28,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: filters
              .map(
                (f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChip(label: f.$2, active: _filter == f.$1, cs: cs, onTap: () => setState(() => _filter = f.$1)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme cs, AppStrings s) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.2),
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final project = _filtered[i];
        final projectTasks = _tasks.where((t) => t.projectId == project.id).toList();
        return _ProjectCard(
          project: project,
          tasks: projectTasks,
          cs: cs,
          s: s,
          onTap: () => _openProject(project),
          onEdit: () => _editProject(project),
          onDelete: () => _deleteProject(project),
          onStatusChange: (status) async {
            final updated = await _service.saveProject(project.copyWith(status: status, updatedAt: DateTime.now()), _projects);
            if (mounted) setState(() => _projects = updated);
          },
        );
      },
    );
  }

  Widget _buildEmpty(ColorScheme cs, AppStrings s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rocket_launch_outlined, size: 52, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Text(
            s.noProjectsYet,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(s.createYourFirstProject, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Project Card ───────────────────────────────────────────────────────────────

class _ProjectCard extends StatefulWidget {
  final Project project;
  final List<Task> tasks;
  final ColorScheme cs;
  final AppStrings s;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProjectStatus> onStatusChange;

  const _ProjectCard({
    required this.project,
    required this.tasks,
    required this.cs,
    required this.s,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final project = widget.project;
    final tasks = widget.tasks;
    final progress = project.progress(tasks);
    final done = tasks.where((t) => t.status == TaskStatus.done).length;

    final statusColor = switch (project.status) {
      ProjectStatus.active => Colors.green,
      ProjectStatus.onHold => Colors.orange,
      ProjectStatus.completed => cs.primary,
      ProjectStatus.archived => cs.onSurfaceVariant,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTap: () => _showContextMenu(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? cs.outlineVariant.withValues(alpha: 0.6) : cs.outlineVariant.withValues(alpha: 0.3),
              width: _hovered ? 1.5 : 0.5,
            ),
            boxShadow: _hovered ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(project.emoji, style: const TextStyle(fontSize: 28)),
                  const Spacer(),
                  // Status dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface, letterSpacing: -0.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  project.description,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              // Progress bar
              if (tasks.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$done/${tasks.length} ${widget.s.tasksDone}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: progress == 1.0 ? Colors.green : cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: cs.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(progress == 1.0 ? Colors.green : cs.primary),
                  ),
                ),
              ] else
                Text(widget.s.noTasksYet, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              // Notes badge
              if (project.noteIds.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${project.noteIds.length} ${widget.s.notes}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final cs = widget.cs;
    final s = widget.s;
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
          onTap: widget.onEdit,
          child: _MenuItem(icon: Icons.edit_outlined, label: s.edit, cs: cs),
        ),
        PopupMenuItem(
          onTap: () => widget.onStatusChange(widget.project.status == ProjectStatus.completed ? ProjectStatus.active : ProjectStatus.completed),
          child: _MenuItem(
            icon: widget.project.status == ProjectStatus.completed ? Icons.restart_alt_rounded : Icons.check_circle_outline_rounded,
            label: widget.project.status == ProjectStatus.completed ? s.markActive : s.markComplete,
            cs: cs,
          ),
        ),
        PopupMenuItem(
          onTap: widget.onDelete,
          child: _MenuItem(icon: Icons.delete_outline_rounded, label: s.delete, cs: cs, danger: true),
        ),
      ],
    );
  }
}

// ── Project Form ───────────────────────────────────────────────────────────────

class _ProjectFormResult {
  final String title;
  final String description;
  final String emoji;
  _ProjectFormResult({required this.title, required this.description, required this.emoji});
}

Future<_ProjectFormResult?> _showProjectForm(BuildContext context, {Project? project}) {
  return showDialog<_ProjectFormResult>(
    context: context,
    builder: (_) => _ProjectFormDialog(project: project),
  );
}

class _ProjectFormDialog extends StatefulWidget {
  final Project? project;
  const _ProjectFormDialog({this.project});

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _emoji;

  static const _emojis = ['📁', '🚀', '💡', '🎯', '🔧', '📊', '🎨', '📝', '🌟', '⚡', '🔥', '🏆', '💼', '🌐', '🔬', '🎮'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.project?.title ?? '');
    _descCtrl = TextEditingController(text: widget.project?.description ?? '');
    _emoji = widget.project?.emoji ?? '📁';
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
    final isEdit = widget.project != null;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
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
                isEdit ? 'Edit Project' : 'New Project',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurface),
              ),
              const SizedBox(height: 20),
              // Emoji picker
              Text(
                'Icon',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _emojis
                    .map(
                      (e) => GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _emoji == e ? cs.primaryContainer : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _emoji == e ? cs.primary.withValues(alpha: 0.4) : Colors.transparent),
                          ),
                          child: Center(child: Text(e, style: const TextStyle(fontSize: 18))),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              // Title
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Project name *',
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
              // Description
              TextField(
                controller: _descCtrl,
                maxLines: 3,
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(context, _ProjectFormResult(title: _titleCtrl.text.trim(), description: _descCtrl.text.trim(), emoji: _emoji));
                    },
                    child: Text(isEdit ? 'Save' : 'Create'),
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

// ── Small reusables ───────────────────────────────────────────────────────────

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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final bool danger;

  const _MenuItem({required this.icon, required this.label, required this.cs, this.danger = false});

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
