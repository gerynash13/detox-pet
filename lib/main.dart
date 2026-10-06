import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: SpikePage()));

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});
  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  static const _channel = MethodChannel('detox_pet/usage');
  bool _hasAccess = false;
  List<String> _events = [];

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
            ]),
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
}