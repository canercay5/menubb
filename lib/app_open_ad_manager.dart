import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager {
  // TEST ID: Gerçek yayında kendi ID'n ile değiştir!
  String adUnitId = "ca-app-pub-3940256099942544/9257395921";
  
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;

  /// Reklamı yükle
  void loadAd() {
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          print('Reklam başarıyla yüklendi.');
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('Reklam yüklenemedi: $error');
        },
      ),
    );
  }

  /// Reklamı göster
  void showAdIfAvailable() {
    if (_appOpenAd == null) {
      print("Reklam henüz hazır değil (null)");
      loadAd();
      return;
    }
    if (_isShowingAd) return;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAd = true,
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd(); // Bir sonraki açılış için hazırla
      },
    );
    print("Reklam gösteriliyor...");
    _appOpenAd!.show();
  }
}