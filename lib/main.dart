import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'speed_calc.dart';

enum Unit { kmh, mph }

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
  // history stored in base km/h
  final List<double> _history = [];
  double _animatedSpeedStart = 0.0;
  double _animatedSpeedEnd = 0.0;
  // instructions removed

  bool _vibrationEnabled = false;
  bool _useHold = false; // false -> Tap (default), true -> Hold

  final List<int> _meterValues =
      List<int>.generate(31, (i) => 10 + i); // 10..40
  final List<int> _centimeterValues =
      List<int>.generate(101, (i) => i); // 0..100
  late FixedExtentScrollController _meterController;
  late FixedExtentScrollController _cmController;
  int _selectedMeterIndex = 10; // default index corresponds to 20m
  int _selectedCmIndex = 0;
  // unit selection
  Unit _selectedUnit = Unit.kmh;

  @override
  void initState() {
    super.initState();
    _selectedMeterIndex = _meterValues.indexOf(20);
    _selectedCmIndex = 0;
    _pitchMeters =
        _meterValues[_selectedMeterIndex] + (_selectedCmIndex / 100.0);
    _meterController =
        FixedExtentScrollController(initialItem: _selectedMeterIndex);
    _cmController = FixedExtentScrollController(initialItem: _selectedCmIndex);
  }

  void _toggleStartStop() {
    if (!_running) {
      _start();
    } else {
      _end();
    }
  }

  void _start() {
    setState(() {
      _startTime = DateTime.now();
      _running = true;
      _speedKmh = null;
      _animatedSpeedStart = _animatedSpeedEnd;
      _animatedSpeedEnd = _animatedSpeedStart;
    });
  }

  void _end() {
    setState(() {
      _endTime = DateTime.now();
      _running = false;
      final durationMs = _endTime.difference(_startTime).inMilliseconds;
      if (durationMs <= 0) {
        _speedKmh = null;
      } else {
        _speedKmh = calculateSpeedKmh(_pitchMeters, durationMs / 1000.0);
        // push to history (store km/h base)
        if (_speedKmh != null) {
          _history.add(_speedKmh!);
          if (_history.length > 6) _history.removeAt(0);
          // update animation targets (convert to selected unit for display)
          final displayVal =
              _selectedUnit == Unit.kmh ? _speedKmh! : (_speedKmh! * 0.621371);
          _animatedSpeedStart = _animatedSpeedEnd;
          _animatedSpeedEnd = displayVal;
          if (_vibrationEnabled) {
            try {
              HapticFeedback.vibrate();
            } catch (_) {}
          }
        }
      }
    });
  }

  void _onMeterChanged(int index) {
    setState(() {
      _selectedMeterIndex = index;
      _pitchMeters =
          _meterValues[_selectedMeterIndex] + (_selectedCmIndex / 100.0);
    });
  }

  void _onCmChanged(int index) {
    setState(() {
      _selectedCmIndex = index;
      _pitchMeters =
          _meterValues[_selectedMeterIndex] + (_selectedCmIndex / 100.0);
      // if user selects 100 cm, we convert to +1m logically (handled by calculation)
    });
  }

  // Instructions have been removed from the main UI.

  // Instructions are accessible via the nav menu (Edit kept available)

  void _showNavMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () => Navigator.of(context).pop()),
            ListTile(
              leading: Icon(_vibrationEnabled
                  ? Icons.vibration
                  : Icons.vibration_outlined),
              title: const Text('Vibration'),
              trailing: Switch(
                value: _vibrationEnabled,
                onChanged: (v) => setState(() => _vibrationEnabled = v),
              ),
            ),
            ListTile(
                leading: const Icon(Icons.shop),
                title: const Text('Shop'),
                onTap: () => Navigator.of(context).pop()),
            ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Donate Us'),
                onTap: () => Navigator.of(context).pop()),
            ListTile(
                leading: const Icon(Icons.feedback),
                title: const Text('Leave a Feedback'),
                onTap: () => Navigator.of(context).pop()),
          ],
        ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                      children: _meterValues
                          .map((m) => Center(child: Text('$m m')))
                          .toList(),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _cmController,
                      itemExtent: 40,
                      onSelectedItemChanged: _onCmChanged,
                      children: _centimeterValues
                          .map((c) => Center(
                              child:
                                  Text('${c.toString().padLeft(2, '0')} cm')))
                          .toList(),
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

  Future<void> _showUnitPickerModal() async {
    final units = ['KPH', 'MPH'];
    int currentIndex = _selectedUnit == Unit.kmh ? 0 : 1;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 220,
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: currentIndex),
                itemExtent: 40,
                onSelectedItemChanged: (i) {
                  setState(() {
                    _selectedUnit = (i == 0) ? Unit.kmh : Unit.mph;
                  });
                },
                children: units.map((u) => Center(child: Text(u))).toList(),
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
            Text('Speedy',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: _showNavMenu,
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
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              // Tappable selector that opens a CupertinoPicker modal
              GestureDetector(
                onTap: _showPitchPickerModal,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedCmIndex.toString().padLeft(2, '0')} cm',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Unit selector (opens modal)
              GestureDetector(
                onTap: _showUnitPickerModal,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedUnit == Unit.kmh ? 'KPH' : 'MPH',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // History bar (last 6 speeds)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    final idx = _history.length - 6 + i;
                    if (idx < 0 || idx >= _history.length) {
                      return Expanded(
                        child: Center(
                            child: Text('--',
                                style: TextStyle(color: Colors.grey.shade400))),
                      );
                    }
                    final valKmh = _history[idx];
                    final displayVal = _selectedUnit == Unit.kmh
                        ? valKmh
                        : (valKmh * 0.621371);
                    final fastest = _history.isNotEmpty &&
                        valKmh == _history.reduce((a, b) => a > b ? a : b);
                    return Expanded(
                      child: Center(
                        child: Text(
                          displayVal.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: fastest ? Colors.red : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              // Tap / Hold selector bar
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _useHold = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: _useHold ? Colors.transparent : Colors.black12,
                          child: const Center(child: Text('Tap')),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _useHold = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: _useHold ? Colors.black12 : Colors.transparent,
                          child: const Center(child: Text('Hold')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: _animatedSpeedStart, end: _animatedSpeedEnd),
                    duration: const Duration(milliseconds: 700),
                    builder: (context, value, child) {
                      final displayText =
                          _speedKmh == null ? '--' : value.toStringAsFixed(1);
                      return Text(
                        displayText,
                        style: const TextStyle(
                            fontSize: 96, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Full-width ElevatedButton for start/end
              SizedBox(
                width: double.infinity,
                child: Listener(
                  onPointerDown: (_) {
                    if (_useHold) _start();
                  },
                  onPointerUp: (_) {
                    if (_useHold) _end();
                  },
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _running ? Colors.red.shade700 : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _useHold ? null : _toggleStartStop,
                    child: Text(
                      _running ? 'END' : 'START',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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
