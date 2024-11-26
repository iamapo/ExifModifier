import 'dart:ui';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  BannerAd? bannerAd;
  bool isAdReady = false;

  void initializeAd(VoidCallback onAdLoaded, Function onAdFailed) {
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-2229498003007416~8867984154',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailed(error);
        },
      ),
    )..load();
  }

  void dispose() {
    bannerAd?.dispose();
  }
}