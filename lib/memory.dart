import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage.dart';

class Intervention {
  final DateTime time;
  final String app;
  final int minutes;
  Intervention(this.time, this.app, this.minutes);
}

class PetMemory {
  static Future<List<Intervention>> loadInterventions() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // pick up entries written by the Kotlin service
    final raw = p.getString('interventions');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Intervention(
              DateTime.fromMillisecondsSinceEpoch((e['t'] as num).toInt()),
              e['app'] as String,
              (e['min'] as num).toInt(),
            ))
        .toList();
  }

  /// A few short facts about recent habits, for the pet's prompt.
  static Future<List<String>> buildBullets() async {
    final all = await loadInterventions();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = all.where((i) => i.time.isAfter(cutoff)).toList();
    final bullets = <String>[];
    if (recent.isEmpty) return bullets;

    bullets.add('Caught scrolling ${recent.length} time(s) in the last 7 days.');

    final byApp = <String, int>{};
    for (final i in recent) {
      byApp[i.app] = (byApp[i.app] ?? 0) + 1;
    }
    final topApp = byApp.entries.reduce((a, b) => a.value >= b.value ? a : b);
    bullets.add('Biggest weakness: ${topApp.key} (${topApp.value} time(s)).');

    final byHour = <int, int>{};
    for (final i in recent) {
      byHour[i.time.hour] = (byHour[i.time.hour] ?? 0) + 1;
    }
    final peak = byHour.entries.reduce((a, b) => a.value >= b.value ? a : b);
    bullets.add('Most vulnerable around ${peak.key}:00.');

    final now = DateTime.now();
    final today = recent
        .where((i) =>
            i.time.year == now.year &&
            i.time.month == now.month &&
            i.time.day == now.day)
        .length;
    if (today > 1) bullets.add('Already caught $today times today.');

    final tasks = await Store.loadTasks();
    if (tasks.isNotEmpty) {
      final done = tasks.where((t) => t.done).length;
      bullets.add('Tasks done: $done of ${tasks.length}.');
    }
    return bullets;
  }
}