import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nexdesk/core/l10n/app_strings.dart';
import 'package:nexdesk/core/services/notes_service.dart';
import 'package:nexdesk/core/services/project_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _projectService = ProjectService();
  final _notesService = NotesService();

  List<Project> _projects = [];
  List<Task> _tasks = [];
  List<Note> _notes = [];
  bool _loading = true;

  double _cpuUsage = 0;
  double _ramUsage = 0;
  double _ramTotal = 0;
  double _ramUsed = 0;
  Timer? _sysTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchSystemStats(); // initState içinde
    _sysTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchSystemStats());
  }

  @override
  void dispose() {
    _sysTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final result = await _projectService.syncAndLoad();
    final notes = await _notesService.loadLocal();
    if (!mounted) return;
    setState(() {
      _projects = result.projects;
      _tasks = result.tasks;
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _fetchSystemStats() async {
    try {
      if (Platform.isMacOS) {
        // CPU — user + sys toplamı, iki farklı format destekli
        final cpuResult = await Process.run('sh', [
          '-c',
          r"""
    output=$(top -l 2 -n 0 -s 1 2>/dev/null | grep -iE "^CPU" | tail -1)
    user=$(echo "$output" | grep -oE "[0-9]+\.?[0-9]*%? user" | grep -oE "[0-9]+\.?[0-9]*" | head -1)
    sys=$(echo "$output"  | grep -oE "[0-9]+\.?[0-9]*%? sys"  | grep -oE "[0-9]+\.?[0-9]*" | head -1)
    user=${user:-0}
    sys=${sys:-0}
    echo "$user $sys"
  """,
        ]);

        final parts = cpuResult.stdout.toString().trim().split(' ');
        final user = double.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
        final sys = double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        final cpu = (user + sys).clamp(0.0, 100.0);
        // RAM
        final vmResult = await Process.run('vm_stat', []);
        final sysctlResult = await Process.run('sysctl', ['-n', 'hw.memsize']);
        final totalBytes = double.tryParse(sysctlResult.stdout.toString().trim()) ?? 0;
        final totalGB = totalBytes / (1024 * 1024 * 1024);

        final vmText = vmResult.stdout.toString();
        double pages(String key) {
          final match = RegExp('$key:\\s+(\\d+)').firstMatch(vmText);
          return double.tryParse(match?.group(1) ?? '0') ?? 0;
        }

        const pageSize = 16384.0;
        final usedBytes = (pages('Pages active') + pages('Pages wired down')) * pageSize;
        final usedGB = usedBytes / (1024 * 1024 * 1024);

        if (mounted) {
          setState(() {
            _cpuUsage = cpu;
            _ramTotal = totalGB;
            _ramUsed = usedGB;
            _ramUsage = (usedGB / totalGB * 100).clamp(0, 100);
          });
        }
      } else if (Platform.isWindows) {
        // CPU
        final cpuResult = await Process.run('wmic', ['cpu', 'get', 'loadpercentage', '/value']);
        final cpuMatch = RegExp(r'LoadPercentage=(\d+)').firstMatch(cpuResult.stdout.toString());
        final cpu = double.tryParse(cpuMatch?.group(1) ?? '0') ?? 0;

        // RAM
        final ramResult = await Process.run('wmic', ['OS', 'get', 'TotalVisibleMemorySize,FreePhysicalMemory', '/value']);
        final ramText = ramResult.stdout.toString();
        final totalMatch = RegExp(r'TotalVisibleMemorySize=(\d+)').firstMatch(ramText);
        final freeMatch = RegExp(r'FreePhysicalMemory=(\d+)').firstMatch(ramText);
        final totalKB = double.tryParse(totalMatch?.group(1) ?? '0') ?? 0;
        final freeKB = double.tryParse(freeMatch?.group(1) ?? '0') ?? 0;
        final usedKB = totalKB - freeKB;

        if (mounted) {
          setState(() {
            _cpuUsage = cpu.clamp(0, 100);
            _ramTotal = totalKB / (1024 * 1024);
            _ramUsed = usedKB / (1024 * 1024);
            _ramUsage = (usedKB / totalKB * 100).clamp(0, 100);
          });
        }
      }
    } catch (e) {
      debugPrint('System stats error: $e');
    }
  }

  // _greeting getter
  String get _greeting {
    final h = DateTime.now().hour;
    // AppStrings'e erişim yok burada, build'de çözelim
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);

    final activeProjects = _projects.where((p) => p.status == ProjectStatus.active).toList();
    final doneTasks = _tasks.where((t) => t.status == TaskStatus.done).length;
    final pendingTasks = _tasks.where((t) => t.status != TaskStatus.done).length;
    final overdueTasks = _tasks.where((t) {
      if (t.dueDate == null || t.status == TaskStatus.done) return false;
      return t.dueDate!.isBefore(DateTime.now());
    }).toList();
    final upcomingTasks = _tasks.where((t) {
      if (t.dueDate == null || t.status == TaskStatus.done) return false;
      final diff = t.dueDate!.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 7;
    }).toList()..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    String dateLabel(AppStrings s) {
      final now = DateTime.now();
      final days = [s.monday, s.tuesday, s.wednesday, s.thursday, s.friday, s.saturday, s.sunday];
      final months = [s.january, s.february, s.march, s.april, s.may, s.june, s.july, s.august, s.september, s.october, s.november, s.december];
      return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Greeting ────────────────────────────────────────────
                  // Greeting Text widget
                  Text(
                    _greeting == 'morning'
                        ? s.goodMorning
                        : _greeting == 'afternoon'
                        ? s.goodAfternoon
                        : s.goodEvening,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(dateLabel(s), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 24),

                  // ── Summary cards ────────────────────────────────────────
                  Row(
                    children: [
                      _SummaryCard(
                        icon: Icons.rocket_launch_rounded,
                        label: s.activeProjects,
                        value: '${activeProjects.length}',
                        sub: '${_projects.length} ${s.total}',
                        color: cs.primary,
                        cs: cs,
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        icon: Icons.task_alt_rounded,
                        label: s.tasksDoneLabel,
                        value: '$doneTasks',
                        sub: '$pendingTasks ${s.pending}',
                        color: Colors.green,
                        cs: cs,
                      ),
                      const SizedBox(width: 12),
                      _SummaryCard(
                        icon: Icons.sticky_note_2_outlined,
                        label: s.notes,
                        value: '${_notes.length}',
                        sub: s.quickNotesLabel,
                        color: const Color(0xFFDD6B20),
                        cs: cs,
                      ),
                      if (overdueTasks.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        _SummaryCard(
                          icon: Icons.warning_amber_rounded,
                          label: s.overdue,
                          value: '${overdueTasks.length}',
                          sub: s.tasksPastDue,
                          color: cs.error,
                          cs: cs,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Active Projects + System Stats row ───────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active projects
                      Expanded(
                        flex: 3,
                        child: _Section(
                          title: s.activeProjects,
                          cs: cs,
                          child: activeProjects.isEmpty
                              ? _EmptyHint(icon: Icons.rocket_launch_outlined, text: s.noActiveProjects, cs: cs)
                              : Column(
                                  children: activeProjects
                                      .take(5)
                                      .map((p) => _ProjectRow(project: p, tasks: _tasks.where((t) => t.projectId == p.id).toList(), cs: cs))
                                      .toList(),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // System stats
                      Expanded(
                        flex: 2,
                        child: _Section(
                          title: s.systemResources,
                          cs: cs,
                          child: Column(
                            children: [
                              _SystemGauge(label: 'CPU', value: _cpuUsage, color: _gaugeColor(_cpuUsage), unit: '%', cs: cs),
                              const SizedBox(height: 16),
                              _SystemGauge(
                                label: 'RAM',
                                value: _ramUsage,
                                color: _gaugeColor(_ramUsage),
                                unit: '%',
                                sub: '${_ramUsed.toStringAsFixed(1)} / ${_ramTotal.toStringAsFixed(1)} GB',
                                cs: cs,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Upcoming tasks ───────────────────────────────────────
                  if (upcomingTasks.isNotEmpty || overdueTasks.isNotEmpty)
                    _Section(
                      title: s.upcomingOverdue,
                      cs: cs,
                      child: Column(
                        children: [
                          ...overdueTasks
                              .take(3)
                              .map(
                                (t) => _TaskRow(
                                  task: t,
                                  project: _projects.firstWhere((p) => p.id == t.projectId, orElse: () => _projects.first),
                                  isOverdue: true,
                                  cs: cs,
                                ),
                              ),
                          ...upcomingTasks
                              .take(5)
                              .map(
                                (t) => _TaskRow(
                                  task: t,
                                  project: _projects.firstWhere((p) => p.id == t.projectId, orElse: () => _projects.first),
                                  isOverdue: false,
                                  cs: cs,
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

  Color _gaugeColor(double v) {
    if (v < 50) return Colors.green;
    if (v < 80) return const Color(0xFFDD6B20);
    return Colors.red;
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final ColorScheme cs;

  const _SummaryCard({required this.icon, required this.label, required this.value, required this.sub, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  ),
                  Text(sub, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final ColorScheme cs;

  const _Section({required this.title, required this.child, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface, letterSpacing: -0.1),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Project Row ───────────────────────────────────────────────────────────────

class _ProjectRow extends StatelessWidget {
  final Project project;
  final List<Task> tasks;
  final ColorScheme cs;

  const _ProjectRow({required this.project, required this.tasks, required this.cs});

  @override
  Widget build(BuildContext context) {
    final progress = project.progress(tasks);
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final color = progress == 1.0 ? Colors.green : cs.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(project.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  project.title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$done/${tasks.length}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(width: 6),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: cs.surfaceContainerHigh, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }
}

// ── System Gauge ──────────────────────────────────────────────────────────────

class _SystemGauge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String unit;
  final String? sub;
  final ColorScheme cs;

  const _SystemGauge({required this.label, required this.value, required this.color, required this.unit, this.sub, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
            ),
            const Spacer(),
            Text(
              '${value.round()}$unit',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: value / 100, minHeight: 8, backgroundColor: cs.surfaceContainerHigh, valueColor: AlwaysStoppedAnimation(color)),
        ),
        if (sub != null) ...[const SizedBox(height: 4), Text(sub!, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))],
      ],
    );
  }
}

// ── Task Row ──────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final Task task;
  final Project project;
  final bool isOverdue;
  final ColorScheme cs;

  const _TaskRow({required this.task, required this.project, required this.isOverdue, required this.cs});

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.priority) {
      TaskPriority.high => Colors.red,
      TaskPriority.medium => const Color(0xFFDD6B20),
      TaskPriority.low => Colors.green,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isOverdue ? cs.error.withValues(alpha: 0.05) : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOverdue ? cs.error.withValues(alpha: 0.2) : cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        children: [
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${project.emoji} ${project.title}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (task.dueDate != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isOverdue ? cs.error.withValues(alpha: 0.1) : cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${task.dueDate!.day}/${task.dueDate!.month}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isOverdue ? cs.error : cs.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme cs;

  const _EmptyHint({required this.icon, required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
