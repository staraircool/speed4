import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  // speed display is handled directly in the build method (_speedKmh)

  Future<void> _showPitchPickerModal() async {
    // Ensure controllers reflect current indices
    try {
      _meterController.jumpToItem(_selectedMeterIndex);
      _cmController.jumpToItem(_selectedCmIndex);
    } catch (_) {}

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 320,
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _meterController,
                      itemExtent: 40,
                      onSelectedItemChanged: _onMeterChanged,
                      children: _meterValues.map((m) => Center(child: Text('$m m'))).toList(),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _cmController,
                      itemExtent: 40,
                      onSelectedItemChanged: _onCmChanged,
                      children: _centimeterValues.map((c) => Center(child: Text('${c.toString().padLeft(2, '0')} cm'))).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              // Tappable selector that opens a CupertinoPicker modal
              GestureDetector(
                onTap: _showPitchPickerModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_meterValues[_selectedMeterIndex]} m',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedCmIndex.toString().padLeft(2, '0')} cm',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _speedKmh == null ? '--' : _speedKmh!.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Text(
                          'km/h',
                          style: TextStyle(fontSize: 28, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Full-width ElevatedButton for start/end
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _running ? Colors.red.shade700 : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _toggleStartStop,
                  child: Text(
                    _running ? 'END' : 'START',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
