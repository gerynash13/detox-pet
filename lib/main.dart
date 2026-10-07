import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'roast_api.dart';
import 'pet_screen.dart';
import 'tasks_screen.dart';

final navKey = GlobalKey<NavigatorState>();

void main() => runApp(MaterialApp(
  navigatorKey: navKey,
  home: const SpikePage(),
));

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});
  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('detox_pet/usage');
  bool _hasAccess = false;
  List<String> _events = [];

  final _taskCtl = TextEditingController(text: 'Math homework');
  String _roast = '';

  Future<void> _testRoast() async {
    setState(() => _roast = 'Thinking up something mean...');
    try {
      final r = await fetchRoast(
        app: 'Youtube', minutes: 15, task: _taskCtl.text);
        setState(() => _roast = r);
    } catch (e) {
      setState(() => _roast = 'Error: $e');
    }
  }

  Future<void> _checkAccess() async {
    final ok = await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    setState(() => _hasAccess = ok);
  }

  Future<void> _openSettings() => _channel.invokeMethod('openUsageSettings');
  Future<void> _allowNotifications() => _channel.invokeMethod('requestNotificationPermission');
  Future<void> _startTracker() => _channel.invokeMethod('startTracker');
  Future<void> _stopTracker() => _channel.invokeMethod('stopTracker');

  Future<void> _loadEvents() async {
    final list = await _channel.invokeListMethod<String>('getRecentEvents');
    setState(() => _events = list ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracker spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usage access: ${_hasAccess ? "GRANTED" : "not granted"}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ElevatedButton(onPressed: _openSettings, child: const Text('Open settings')),
              ElevatedButton(onPressed: _checkAccess, child: const Text('Check permission')),
              ElevatedButton(onPressed: _loadEvents, child: const Text('Load recent apps')),
              ElevatedButton(onPressed: _allowNotifications, child: const Text('Allow notifications')),
              ElevatedButton(onPressed: _startTracker, child: const Text('Start tracker')),
              ElevatedButton(onPressed: _stopTracker, child: const Text('Stop tracker')),
              ElevatedButton(
                onPressed: () => navKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const TasksScreen())), 
                  child: const Text('Tasks & XP'),)
            ]),
            TextField(
              controller: _taskCtl,
              decoration: const InputDecoration(labelText: 'Next task'),
            ),
            ElevatedButton(onPressed: _testRoast, child: const Text('Test roast')),
            Text(_roast),
            const Divider(),
            Expanded(
              child: ListView(
                children: _events.map((e) => Text(e)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPendingAlert();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingAlert();
    }
  }

  Future<void> _checkPendingAlert() async {
    final alert = await _channel.invokeMapMethod<String, dynamic>('getPendingAlert');
    if (alert == null) return;
    navKey.currentState?.push(MaterialPageRoute(
      builder: (_) => PetScreen(
        app: alert['app'] as String,
        minutes: (alert['minutes'] as num).toInt(),
      ),
    ));
  }
}