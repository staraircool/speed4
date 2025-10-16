import 'package:flutter/material.dart';
import 'dart:async';
import 'speed_calc.dart';

void main() {
  runApp(const SpeedyApp());
}

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
      title: 'Speedy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
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
  double _pitchMeters = 20.0;
  double? _speedKmh;
  String _instructions =
      '1) Set the pitch length (meters)\n2) Press START when you release the ball\n3) Press STOP when the ball reaches the batsman';

  final List<int> _presetMeters = List<int>.generate(21, (i) => 10 + i); // 10..30
  int? _selectedMeterIndex;

  @override
  void initState() {
    super.initState();
    _selectedMeterIndex = _presetMeters.indexOf(20);
    _pitchMeters = 20.0;
  }

  void _toggleStartStop() {
    if (!_running) {
      setState(() {
        _startTime = DateTime.now();
        _running = true;
        _speedKmh = null;
      });
    } else {
      setState(() {
        _endTime = DateTime.now();
        _running = false;
        final durationMs = _endTime.difference(_startTime).inMilliseconds;
        if (durationMs <= 0) {
          _speedKmh = null;
        } else {
          _speedKmh = calculateSpeedKmh(_pitchMeters, durationMs / 1000.0);
        }
      });
    }
  }

  void _selectMeter(int index) {
    setState(() {
      _selectedMeterIndex = index;
      _pitchMeters = _presetMeters[index].toDouble();
    });
  }

  Future<void> _askCustomMeter() async {
    final controller = TextEditingController(text: _pitchMeters.toStringAsFixed(2));
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom pitch length (meters)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'e.g. 18.5'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              Navigator.of(context).pop(val);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      setState(() {
        _pitchMeters = result;
        _selectedMeterIndex = null; // custom
      });
    }
  }

  Future<void> _editInstructions() async {
    final controller = TextEditingController(text: _instructions);
    final ok = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instructions'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (ok == true) {
      setState(() {
        _instructions = controller.text;
      });
    }
  }

  void _showInstructionsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instructions'),
        content: SingleChildScrollView(child: Text(_instructions)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editInstructions();
              },
              child: const Text('Edit')),
        ],
      ),
    );
  }

  String _speedText() {
    if (_speedKmh == null) return '-- km/h';
    return '${_speedKmh!.toStringAsFixed(1)} km/h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Row(
          children: [
            Text('Speedy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(width: 8),
            Text('Cricket', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'Instructions',
              onPressed: _showInstructionsDialog,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'SELECT PITCH LENGTH',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetMeters.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index < _presetMeters.length) {
                      final meters = _presetMeters[index];
                      final selected = _selectedMeterIndex == index;
                      return GestureDetector(
                        onTap: () => _selectMeter(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 84,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: selected ? [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))] : null,
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${meters.toString()} m', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black)),
                            ],
                          ),
                        ),
                      );
                    } else {
                      final custom = _selectedMeterIndex == null;
                      return GestureDetector(
                        onTap: _askCustomMeter,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: custom ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit, color: custom ? Colors.white : Colors.black54),
                              const SizedBox(height: 4),
                              Text('Custom', style: TextStyle(color: custom ? Colors.white : Colors.black54)),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Text(
                    _speedText(),
                    style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _toggleStartStop,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: _running ? [Colors.redAccent, Colors.red] : [Colors.green, Colors.greenAccent]),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 6))],
                    ),
                    child: Center(
                      child: Text(
                        _running ? 'STOP' : 'START',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
