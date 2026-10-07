import 'package:flutter/material.dart';
import 'storage.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _ctl = TextEditingController();
  List<Task> _tasks = [];
  int _xp = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await Store.loadTasks();
    final x = await Store.loadXp();
    setState(() {
      _tasks = t;
      _xp = x;
    });
  }

  Future<void> _add() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    setState(() => _tasks.add(Task(text)));
    _ctl.clear();
    await Store.saveTasks(_tasks);
  }

  Future<void> _toggle(Task t) async {
    setState(() {
      t.done = !t.done;
      _xp += t.done ? Store.xpPerTask : -Store.xpPerTask;
      if (_xp < 0) _xp = 0;
    });
    await Store.saveTasks(_tasks);
    await Store.saveXp(_xp);
  }

  Future<void> _remove(Task t) async {
    setState(() => _tasks.remove(t));
    await Store.saveTasks(_tasks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks & XP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Store.titleFor(_xp),
                style: Theme.of(context).textTheme.headlineSmall),
            Text('$_xp XP'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  decoration: const InputDecoration(labelText: 'Add a task'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(onPressed: _add, icon: const Icon(Icons.add)),
            ]),
            Expanded(
              child: ListView(
                children: _tasks
                    .map((t) => Dismissible(
                          key: ObjectKey(t),
                          onDismissed: (_) => _remove(t),
                          child: CheckboxListTile(
                            value: t.done,
                            onChanged: (_) => _toggle(t),
                            title: Text(t.text,
                                style: TextStyle(
                                    decoration: t.done
                                        ? TextDecoration.lineThrough
                                        : null)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}