import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────

enum ProjectStatus { active, completed, onHold, archived }

enum TaskStatus { todo, inProgress, done }

enum TaskPriority { low, medium, high }

// ── Task model ─────────────────────────────────────────────────────────────────

class Task {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({String? title, String? description, TaskStatus? status, TaskPriority? priority, DateTime? dueDate, DateTime? updatedAt}) => Task(
    id: id,
    projectId: projectId,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'description': description,
    'status': status.name,
    'priority': priority.name,
    'dueDate': dueDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Task.fromMap(Map<String, dynamic> m) => Task(
    id: m['id'] as String,
    projectId: m['projectId'] as String? ?? '',
    title: m['title'] as String? ?? '',
    description: m['description'] as String? ?? '',
    status: TaskStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => TaskStatus.todo),
    priority: TaskPriority.values.firstWhere((p) => p.name == m['priority'], orElse: () => TaskPriority.medium),
    dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate'] as String) : null,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
  );
}

// ── Project model ──────────────────────────────────────────────────────────────

class Project {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final ProjectStatus status;
  final List<String> noteIds; // Linked note IDs
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.status,
    required this.noteIds,
    required this.createdAt,
    required this.updatedAt,
  });

  Project copyWith({String? title, String? description, String? emoji, ProjectStatus? status, List<String>? noteIds, DateTime? updatedAt}) => Project(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    emoji: emoji ?? this.emoji,
    status: status ?? this.status,
    noteIds: noteIds ?? this.noteIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'emoji': emoji,
    'status': status.name,
    'noteIds': noteIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Project.fromMap(Map<String, dynamic> m) => Project(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    description: m['description'] as String? ?? '',
    emoji: m['emoji'] as String? ?? '📁',
    status: ProjectStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => ProjectStatus.active),
    noteIds: List<String>.from(m['noteIds'] as List? ?? []),
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
  );

  // Computed progress based on tasks
  double progress(List<Task> tasks) {
    final mine = tasks.where((t) => t.projectId == id).toList();
    if (mine.isEmpty) return 0;
    final done = mine.where((t) => t.status == TaskStatus.done).length;
    return done / mine.length;
  }
}

// ── Service ────────────────────────────────────────────────────────────────────

class ProjectService {
  static const _projectsKey = 'projects_v1';
  static const _tasksKey = 'tasks_v1';

  // ── Connectivity ───────────────────────────────────────────────────────────

  Future<bool> isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r.first != ConnectivityResult.none;
  }

  // ── Local — Projects ───────────────────────────────────────────────────────

  Future<List<Project>> loadProjectsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_projectsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Project.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveProjectsLocal(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_projectsKey, jsonEncode(projects.map((p) => p.toMap()).toList()));
  }

  // ── Local — Tasks ──────────────────────────────────────────────────────────

  Future<List<Task>> loadTasksLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Task.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveTasksLocal(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksKey, jsonEncode(tasks.map((t) => t.toMap()).toList()));
  }

  // ── Firebase ───────────────────────────────────────────────────────────────

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _projectsCol() {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('projects');
  }

  CollectionReference<Map<String, dynamic>>? _tasksCol() {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('tasks');
  }

  Future<List<Project>> _fetchProjectsRemote() async {
    final col = _projectsCol();
    if (col == null) return [];
    final snap = await col.orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => Project.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<List<Task>> _fetchTasksRemote() async {
    final col = _tasksCol();
    if (col == null) return [];
    final snap = await col.orderBy('updatedAt', descending: true).get();
    return snap.docs.map((d) => Task.fromMap({...d.data(), 'id': d.id})).toList();
  }

  Future<void> _pushProjectsBatch(List<Project> projects) async {
    final col = _projectsCol();
    if (col == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final p in projects) {
      batch.set(col.doc(p.id), p.toMap()..remove('id'));
    }
    await batch.commit();
  }

  Future<void> _pushTasksBatch(List<Task> tasks) async {
    final col = _tasksCol();
    if (col == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final t in tasks) {
      batch.set(col.doc(t.id), t.toMap()..remove('id'));
    }
    await batch.commit();
  }

  // ── Merge — newest updatedAt wins ──────────────────────────────────────────

  List<Project> _mergeProjects(List<Project> local, List<Project> remote) {
    final map = <String, Project>{};
    for (final p in [...local, ...remote]) {
      final ex = map[p.id];
      if (ex == null || p.updatedAt.isAfter(ex.updatedAt)) map[p.id] = p;
    }
    return map.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<Task> _mergeTasks(List<Task> local, List<Task> remote) {
    final map = <String, Task>{};
    for (final t in [...local, ...remote]) {
      final ex = map[t.id];
      if (ex == null || t.updatedAt.isAfter(ex.updatedAt)) map[t.id] = t;
    }
    return map.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Load everything locally, sync with Firebase if online.
  Future<({List<Project> projects, List<Task> tasks})> syncAndLoad() async {
    final localProjects = await loadProjectsLocal();
    final localTasks = await loadTasksLocal();

    if (!await isOnline()) {
      return (projects: localProjects, tasks: localTasks);
    }

    try {
      final remoteProjects = await _fetchProjectsRemote();
      final remoteTasks = await _fetchTasksRemote();

      final mergedProjects = _mergeProjects(localProjects, remoteProjects);
      final mergedTasks = _mergeTasks(localTasks, remoteTasks);

      await _saveProjectsLocal(mergedProjects);
      await _saveTasksLocal(mergedTasks);
      await _pushProjectsBatch(mergedProjects);
      await _pushTasksBatch(mergedTasks);

      return (projects: mergedProjects, tasks: mergedTasks);
    } catch (_) {
      return (projects: localProjects, tasks: localTasks);
    }
  }

  /// Save a project locally and push if online.
  Future<List<Project>> saveProject(Project project, List<Project> current) async {
    final updated = _mergeProjects([project], current.where((p) => p.id != project.id).toList());
    await _saveProjectsLocal(updated);
    if (await isOnline()) {
      try {
        await _pushProjectsBatch([project]);
      } catch (_) {}
    }
    return updated;
  }

  /// Delete a project and all its tasks.
  Future<({List<Project> projects, List<Task> tasks})> deleteProject(String projectId, List<Project> currentProjects, List<Task> currentTasks) async {
    final updatedProjects = currentProjects.where((p) => p.id != projectId).toList();
    final updatedTasks = currentTasks.where((t) => t.projectId != projectId).toList();

    await _saveProjectsLocal(updatedProjects);
    await _saveTasksLocal(updatedTasks);

    if (await isOnline()) {
      try {
        final uid = _uid;
        if (uid != null) {
          final batch = FirebaseFirestore.instance.batch();
          batch.delete(_projectsCol()!.doc(projectId));
          // Delete all tasks for this project
          for (final t in currentTasks.where((t) => t.projectId == projectId)) {
            batch.delete(_tasksCol()!.doc(t.id));
          }
          await batch.commit();
        }
      } catch (_) {}
    }

    return (projects: updatedProjects, tasks: updatedTasks);
  }

  /// Save a task locally and push if online.
  Future<List<Task>> saveTask(Task task, List<Task> current) async {
    final updated = _mergeTasks([task], current.where((t) => t.id != task.id).toList());
    await _saveTasksLocal(updated);
    if (await isOnline()) {
      try {
        await _pushTasksBatch([task]);
      } catch (_) {}
    }
    return updated;
  }

  /// Delete a task.
  Future<List<Task>> deleteTask(String taskId, List<Task> current) async {
    final updated = current.where((t) => t.id != taskId).toList();
    await _saveTasksLocal(updated);
    if (await isOnline()) {
      try {
        await _tasksCol()?.doc(taskId).delete();
      } catch (_) {}
    }
    return updated;
  }

  /// Link/unlink a note to a project.
  Future<List<Project>> toggleNoteLink(String projectId, String noteId, List<Project> current) async {
    final project = current.firstWhere((p) => p.id == projectId);
    final noteIds = List<String>.from(project.noteIds);
    if (noteIds.contains(noteId)) {
      noteIds.remove(noteId);
    } else {
      noteIds.add(noteId);
    }
    final updated = project.copyWith(noteIds: noteIds, updatedAt: DateTime.now());
    return saveProject(updated, current);
  }
}
