import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Configuration for ad unit ids. Replace empty strings with your production IDs.
class AdsConfig {
  // Android example IDs (leave empty to show placeholders)
  static const String appOpenAdUnitId = 'ca-app-pub-4420776878768276/8951055261';
  static const String interstitialAdUnitId = '';
  static const String bannerAdUnitId = 'ca-app-pub-4420776878768276/7954055402';
  static const String rewardedAdUnitId = 'ca-app-pub-4420776878768276/1204620705';
}

/// Simple Banner widget that shows a real BannerAd when `unitId` is provided,
/// otherwise a lightweight placeholder so the layout is predictable.
class BannerAdWidget extends StatefulWidget {
  final String unitId;
  final double height;
  const BannerAdWidget({Key? key, required this.unitId, this.height = 50})
      : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.unitId.isNotEmpty) {
      _bannerAd = BannerAd(
        size: AdSize.banner,
        adUnitId: widget.unitId,
        listener: BannerAdListener(onAdLoaded: (_) {
          setState(() => _isLoaded = true);
        }, onAdFailedToLoad: (ad, err) {
          ad.dispose();
          setState(() {
            _isLoaded = false;
            _bannerAd = null;
          });
        }),
        request: const AdRequest(),
      );
      _bannerAd!.load();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unitId.isEmpty) {
      // Placeholder box so the space is kept and easily findable in UI for replacement
      return Container(
        height: widget.height,
        color: Colors.grey.shade200,
        child: const Center(child: Text('Ad placeholder')),
      );
    }
    if (_isLoaded && _bannerAd != null) {
      return SizedBox(
        height: widget.height,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    // loading
    return SizedBox(
        height: widget.height,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
  }
}

/// Simple manager for App Open and Interstitial ads. Uses provided IDs from
/// `AdsConfig`. If ids are empty, manager becomes a no-op.
class AdsManager {
  AdsManager._private();
  static final AdsManager instance = AdsManager._private();

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  bool _isLoadingAppOpen = false;
  bool _isLoadingInterstitial = false;

  void loadAppOpenAd() {
    final id = AdsConfig.appOpenAdUnitId;
    if (id.isEmpty) return;
    if (_isLoadingAppOpen || _appOpenAd != null) return;
    _isLoadingAppOpen = true;
    AppOpenAd.load(
        adUnitId: id,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isLoadingAppOpen = false;
        }, onAdFailedToLoad: (err) {
          _isLoadingAppOpen = false;
          _appOpenAd = null;
        }));
  }

  void showAppOpenAdIfAvailable() {
    if (_appOpenAd == null) return;
    final ad = _appOpenAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );
    try {
      ad.show();
    } catch (_) {}
  }

  void loadInterstitial() {
    final id = AdsConfig.interstitialAdUnitId;
    if (id.isEmpty) return;
    if (_isLoadingInterstitial || _interstitialAd != null) return;
    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  /// Show interstitial and call [onComplete] after it's dismissed (or
  /// immediately if no ad). Use this for app-close ads.
  void showInterstitial({VoidCallback? onComplete}) {
    if (_interstitialAd == null) {
      onComplete?.call();
      return;
    }
    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
        onComplete?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
        onComplete?.call();
      },
    );
    try {
      ad.show();
    } catch (_) {
      onComplete?.call();
    }
  }
}
