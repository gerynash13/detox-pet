import 'dart:async';
import 'package:flutter/material.dart';
import 'roast_api.dart';
import 'storage.dart';
import 'memory.dart';

class PetScreen extends StatefulWidget {
  final String app;
  final int minutes;
  const PetScreen({super.key, required this.app, required this.minutes});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  String _full = '';
  String _shown = '';
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final task = await Store.nextTask();
      final title = Store.titleFor(await Store.loadXp());
      final history = await PetMemory.buildBullets();
      _full = await fetchRoast(
        app: widget.app,
        minutes: widget.minutes,
        task: task,
        title: title,
        history: history,
      );
    } catch (_) {
      _full = "My brain is offline, but my eyes work fine. "
          "Put the phone down.";
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _timer = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (_shown.length >= _full.length) {
        t.cancel();
        return;
      }
      setState(() => _shown = _full.substring(0, _shown.length + 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _loading ? '...' : _shown,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 24),
              // Placeholder pet. We'll swap in real "annoyed" art later.
              const Icon(Icons.pets, size: 120),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fine. Back to work.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}