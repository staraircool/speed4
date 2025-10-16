import 'package:flutter/material.dart';
import 'dart:async';
import 'speed_calc.dart';

void main() {
  runApp(const SpeedyApp());
}

class SpeedyApp extends StatelessWidget {
  const SpeedyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speedy Cricket',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SpeedHomePage(),
    );
  }
}

class SpeedHomePage extends StatefulWidget {
  const SpeedHomePage({super.key});

  @override
  State<SpeedHomePage> createState() => _SpeedHomePageState();
}

class _SpeedHomePageState extends State<SpeedHomePage> {
  late DateTime _startTime;
  late DateTime _endTime;
  bool _running = false;
  double _pitchMeters = 20.12; // default cricket pitch length in meters (22 yards)
  double? _speedKmh;
  String _status = 'Ready';

  void _start() {
    setState(() {
      _startTime = DateTime.now();
      _running = true;
      _status = 'Timing...';
      _speedKmh = null;
    });
  }

  void _end() {
    setState(() {
      _endTime = DateTime.now();
      _running = false;
      final duration = _endTime.difference(_startTime).inMilliseconds;
      if (duration <= 0) {
        _status = 'Invalid timing';
        _speedKmh = null;
      } else {
        final speed = calculateSpeedKmh(_pitchMeters, duration / 1000.0);
        _speedKmh = speed;
        _status = 'Done';
      }
    });
  }

  void _reset() {
    setState(() {
      _running = false;
      _speedKmh = null;
      _status = 'Ready';
    });
  }

  // uses calculateSpeedKmh from lib/speed_calc.dart

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speedy Cricket'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Cricket bowling speed meter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Status: $_status'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Pitch length (m):'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _pitchMeters.toStringAsFixed(2),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        setState(() => _pitchMeters = parsed);
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'e.g. 20.12',
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Text(
                  _speedText(),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _running ? null : _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _running ? _end : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('End'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _reset,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              child: const Text('Reset'),
            ),
            const SizedBox(height: 12),
            const Text('Instructions: Tap Start when you release the ball, Tap End when it reaches the batsman.'),
          ],
        ),
      ),
    );
  }

  String _speedText() {
    if (_speedKmh == null) return '-- km/h';
    return '${_speedKmh!.toStringAsFixed(1)} km/h';
  }
}
