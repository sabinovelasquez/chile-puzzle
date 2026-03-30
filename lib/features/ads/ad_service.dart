import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;

  static void initialize() {
    MobileAds.instance.initialize();
  }

  static void loadInterstitial() {
    String adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712' // Default Test Android string
        : 'ca-app-pub-3940256099942544/4411468910'; // Default Test iOS string

    InterstitialAd.load(
      adUnitId: adUnitId,
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
