import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Singleton that owns the AdMob SDK initialisation and rewarded ad lifecycle.
///
/// Usage:
///   1. Call [AdService().initialize()] in [main()] before [runApp].
///   2. Call [AdService().preloadRewarded()] in HomeScreen.initState.
///   3. Check [isRewardedAdReady] before offering the "Watch Ad" button.
///   4. Drop [BannerAdWidget] anywhere in the widget tree — it self-manages.
class AdService {
  // ── Test ad unit IDs (replace with real IDs before release) ───────────────
  static const String bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _sdkInitialised = false;
  RewardedAd? _rewardedAd;
  bool _loadingRewarded = false;

  // ── SDK initialisation ─────────────────────────────────────────────────────

  /// Must be called once before any ad is loaded (e.g. in main() or initState).
  Future<void> initialize() async {
    if (_sdkInitialised) return;
    await MobileAds.instance.initialize();
    _sdkInitialised = true;
    debugPrint('[AdService] MobileAds SDK initialised');
  }

  // ── Rewarded ad ────────────────────────────────────────────────────────────

  /// Initialises the SDK (once) and pre-loads the rewarded ad.
  Future<void> preloadRewarded() async {
    await initialize();
    _loadRewardedAd();
  }

  // Kept for backward compatibility with existing callers.
  Future<void> preload() => preloadRewarded();

  bool get isRewardedAdReady => _rewardedAd != null;

  void _loadRewardedAd() {
    if (_loadingRewarded || !_sdkInitialised) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _loadingRewarded = false;
          debugPrint('[AdService] Rewarded ad loaded ✓');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _loadingRewarded = false;
          debugPrint('[AdService] Rewarded ad failed: $error — retrying in 30s');
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  /// Shows the rewarded ad.
  /// [onRewarded] fires when the user earns the reward.
  /// [onFailed] fires when the ad is not ready or cannot be shown.
  void showRewardedAd({
    required void Function() onRewarded,
    void Function()? onFailed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('[AdService] showRewardedAd — not ready');
      onFailed?.call();
      return;
    }

    bool earnedReward = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        debugPrint('[AdService] Rewarded ad dismissed — reloading');
        
        // Trigger the callback AFTER the ad is fully closed, so it doesn't
        // happen while the ad end-card is still visible.
        if (earnedReward) {
          onRewarded();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        debugPrint('[AdService] Rewarded ad failed to show: $error');
        onFailed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('[AdService] Reward earned: ${reward.amount} ${reward.type}');
        earnedReward = true;
      },
    );
  }
}

// ── Banner ad widget ──────────────────────────────────────────────────────────

/// Self-contained widget that initialises the SDK, loads a 320×50 banner,
/// and renders it. Returns [SizedBox.shrink] until the ad is ready.
/// Automatically disposes the ad when removed from the tree.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    // Ensure SDK is initialised before creating the ad.
    await AdService().initialize();
    if (!mounted) return;

    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
          debugPrint('[BannerAdWidget] Banner loaded ✓');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[BannerAdWidget] Failed to load: $error');
          ad.dispose();
          // Retry after 30 s so we don't hammer the server.
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _loadBanner();
          });
        },
      ),
    );

    ad.load();
    if (mounted) setState(() => _bannerAd = ad);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
