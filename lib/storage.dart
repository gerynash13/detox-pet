import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Task {
  String text;
  bool done;
  Task(this.text, {this.done = false});

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory Task.fromJson(Map<String, dynamic> j) =>
      Task(j['text'] as String, done: j['done'] as bool);
}

class Store {
  static const _tasksKey = 'tasks';
  static const _xpKey = 'xp';
  static const xpPerTask = 20;

  static Future<List<Task>> loadTasks() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_tasksKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _tasksKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  static Future<int> loadXp() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_xpKey) ?? 0;
  }

  static Future<void> saveXp(int xp) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_xpKey, xp < 0 ? 0 : xp);
  }

  /// The first task that isn't done yet, or null.
  static Future<String?> nextTask() async {
    final tasks = await loadTasks();
    for (final t in tasks) {
      if (!t.done) return t.text;
    }
    return null;
  }

  static String titleFor(int xp) {
    if (xp >= 600) return 'The Chosen One';
    if (xp >= 300) return 'Master of Discipline';
    if (xp >= 100) return 'Focus Apprentice';
    return 'Filthy Casual Scroller';
  }
}