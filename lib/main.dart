import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'speed_calc.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum Unit { kmh, mph }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();
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

  // AdMob rewarded ad state
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  bool _hasWatchedAdThisSession = false;
  bool _adRewardEarned = false; // temporary flag to detect reward during show

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
    // Preload rewarded ad for the session
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _meterController.dispose();
    _cmController.dispose();
    super.dispose();
  }

  void _loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: 'ca-app-pub-4420776878768276/1204620705',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          // attach callbacks
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              // dispose and clear
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdLoading = false;
              // if reward was earned, mark session flag and start
              if (_adRewardEarned) {
                _hasWatchedAdThisSession = true;
                _adRewardEarned = false;
                // Safe call to start measurement after ad finishes
                try {
                  _start();
                } catch (_) {}
              } else {
                // user didn't finish ad — inform them
                try {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Ad not completed. Tap Start to try again.')));
                } catch (_) {}
              }
              // preload next ad for future sessions if needed
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdLoading = false;
              try {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to show ad. Starting now.')));
              } catch (_) {}
              // fallback: start immediately
              try {
                _start();
              } catch (_) {}
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<void> _maybeShowAdThenStart() async {
    if (_running) return; // already running
    if (_hasWatchedAdThisSession) {
      _start();
      return;
    }
    // if rewarded ad available, show it
    if (_rewardedAd != null) {
      try {
        _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
          // user earned the reward — mark it
          _adRewardEarned = true;
        });
      } catch (_) {
        // in case showing fails, fallback to start
        _start();
      }
    } else {
      // ad not ready: start immediately and request ad in background
      _start();
      _loadRewardedAd();
    }
  }

  // _toggleStartStop removed; Start button uses ad-aware flow directly.

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
                onTap: () {
                  Navigator.of(context).pop();
                  _showShop();
                }),
            ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Donate Us'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDonate();
                }),
            ListTile(
                leading: const Icon(Icons.feedback),
                title: const Text('Leave a Feedback'),
                onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  Future<void> _showShop() async {
    final products = [
      {
        'title': 'Bushnell Velocity Speed Gun',
        'image':
            'https://m.media-amazon.com/images/I/51sB7MaUNNL._AC_UF1000,1000_QL80_.jpg',
        'link': 'https://amzn.to/46WleYl'
      },
      {
        'title': 'Sports Radar Speed Gun SR3600',
        'image':
            'https://m.media-amazon.com/images/I/81dd95jl4bL._AC_SL1500_.jpg',
        'link': 'https://amzn.to/4nWDkQb'
      },
      {
        'title': 'Bushnell Velocity and Trade Speed Gun',
        'image':
            'https://m.media-amazon.com/images/I/51Us6TGC6xL._AC_SL1152_.jpg',
        'link': 'https://amzn.to/4nbOMpN'
      },
      {
        'title': 'SS T20 Legend Club Kashmir Willow',
        'image':
            'https://m.media-amazon.com/images/I/61YCUKSde1L._AC_SL1500_.jpg',
        'link': 'https://amzn.to/4nUIXhw'
      },
      {
        'title': 'SS english Willow Original',
        'image':
            'https://m.media-amazon.com/images/I/71i6gwNyjhL._AC_SL1500_.jpg',
        'link': 'https://amzn.to/43r99YT'
      },
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Shop',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = products[i];
                    return Row(
                      children: [
                        Image.network(p['image']!,
                            width: 96, height: 96, fit: BoxFit.cover),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['title']!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final url = p['link']!;
                                  await launchUrlString(url);
                                },
                                child: const Text('Buy'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDonate() async {
    const address = 'TSmwcK5UYd6cHdMvSqmEZcjW3wR12wMe37';
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Donate Us',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Address (USDT, TRON/TRC20):'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: SelectableText(address)),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: address));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Address copied to clipboard')));
                    },
                  )
                ],
              ),
              const SizedBox(height: 12),
              const Text('Currency: USDT'),
              const SizedBox(height: 6),
              const Text('Network: TRON (TRC20)'),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close')),
            ],
          ),
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
                    if (_useHold) {
                      // for hold mode, check ad before starting
                      _maybeShowAdThenStart();
                    }
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
                    onPressed: _useHold
                        ? null
                        : () async {
                            if (!_running) {
                              await _maybeShowAdThenStart();
                            } else {
                              _end();
                            }
                          },
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
