import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;

  static void initialize() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    MobileAds.instance.initialize();
  }

  static const String _interstitialAdUnitId = 'ca-app-pub-1612904750122173/3891326939';

  static void loadInterstitial() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            print('InterstitialAd failed to load: $error');
          }
          _isAdLoaded = false;
        },
      ),
    );
  }

  static void showInterstitial({required Function onAdDismissed}) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      onAdDismissed();
      return;
    }
    
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isAdLoaded = false;
          onAdDismissed();
          loadInterstitial(); // Pre-load next ad
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdLoaded = false;
          onAdDismissed();
          loadInterstitial();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      onAdDismissed(); 
      loadInterstitial();
    }
  }
}
