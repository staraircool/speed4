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

  final List<int> _meterValues = List<int>.generate(31, (i) => 10 + i); // 10..40
  final List<int> _centimeterValues = List<int>.generate(101, (i) => i); // 0..100
  late FixedExtentScrollController _meterController;
  late FixedExtentScrollController _cmController;
  int _selectedMeterIndex = 10; // default index corresponds to 20m
  int _selectedCmIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedMeterIndex = _meterValues.indexOf(20);
    _selectedCmIndex = 0;
    _pitchMeters = _meterValues[_selectedMeterIndex] + (_selectedCmIndex / 100.0);
    _meterController = FixedExtentScrollController(initialItem: _selectedMeterIndex);
    _cmController = FixedExtentScrollController(initialItem: _selectedCmIndex);
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

  void _onMeterChanged(int index) {
    setState(() {
      _selectedMeterIndex = index;
      _pitchMeters = _meterValues[_selectedMeterIndex] + (_selectedCmIndex / 100.0);
    });
  }

  void _onCmChanged(int index) {
    setState(() {
      _selectedCmIndex = index;
      _pitchMeters = _meterValues[_selectedMeterIndex] + (_selectedCmIndex / 100.0);
      // if user selects 100 cm, we convert to +1m logically (handled by calculation)
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
      // Convert result into meters and centimeters, clamp to available ranges
      int meters = result.floor();
      int cm = ((result - meters) * 100).round();
      if (cm >= 100) {
        meters += 1;
        cm = 0;
      }
      if (meters < _meterValues.first) meters = _meterValues.first;
      if (meters > _meterValues.last) meters = _meterValues.last;
      final meterIndex = _meterValues.indexOf(meters);
      final cmIndex = cm.clamp(0, _centimeterValues.length - 1);

      setState(() {
        _pitchMeters = meters + (cm / 100.0);
        _selectedMeterIndex = meterIndex;
        _selectedCmIndex = cmIndex;
      });

      // Move controllers to reflect custom choice
      try {
        _meterController.jumpToItem(meterIndex);
        _cmController.jumpToItem(cmIndex);
      } catch (_) {}
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
              Column(
                children: [
                  Text(
                    'Choose the length: ${_meterValues[_selectedMeterIndex]} {meters} * ${_selectedCmIndex.toString().padLeft(2, '0')} [centimeters]',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Meters picker
                        SizedBox(
                          width: 140,
                          child: ListWheelScrollView.useDelegate(
                            controller: _meterController,
                            itemExtent: 40,
                            diameterRatio: 1.2,
                            onSelectedItemChanged: _onMeterChanged,
                            physics: const FixedExtentScrollPhysics(),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _meterValues.length,
                              builder: (context, index) {
                                final meters = _meterValues[index];
                                final selected = index == _selectedMeterIndex;
                                return Center(
                                  child: Text(
                                    '${meters} m',
                                    style: TextStyle(fontSize: selected ? 18 : 14, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                        color: selected ? Theme.of(context).colorScheme.primary : Colors.black87),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Centimeters picker
                        SizedBox(
                          width: 120,
                          child: ListWheelScrollView.useDelegate(
                            controller: _cmController,
                            itemExtent: 40,
                            diameterRatio: 1.2,
                            onSelectedItemChanged: _onCmChanged,
                            physics: const FixedExtentScrollPhysics(),
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _centimeterValues.length,
                              builder: (context, index) {
                                final cm = _centimeterValues[index];
                                final selected = index == _selectedCmIndex;
                                return Center(
                                  child: Text(
                                    '${cm.toString().padLeft(2, '0')} cm',
                                    style: TextStyle(fontSize: selected ? 18 : 14, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                        color: selected ? Theme.of(context).colorScheme.primary : Colors.black87),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // cricket ball base
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _running ? Colors.red.shade700 : Colors.red.shade600,
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 6))],
                          ),
                        ),
                        // seam lines (simple)
                        Transform.rotate(
                          angle: 0.35,
                          child: Container(
                            width: 100,
                            height: 6,
                            decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        Transform.rotate(
                          angle: -0.35,
                          child: Container(
                            width: 100,
                            height: 6,
                            decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        // center label
                        Text(
                          _running ? 'STOP' : 'START',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
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
