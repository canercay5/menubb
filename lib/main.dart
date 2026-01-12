import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// --- RENK SABİTLERİ (Solid/Net Renkler) ---
const Color kIndigo = Color(0xFF3B4EAF);
const Color kGreen = Color(0xFF10AF79);
const Color kOffWhite = Color(0xFFFAF9F6);
const Color kWhite = Color(0xFFFFFFFF);

// --- REKLAM YÖNETİCİSİ (Singleton) ---
class AppOpenAdManager {
  // TEST ID: Gerçek yayında AdMob panelindeki kendi ID'n ile değiştir!
  String adUnitId = "ca-app-pub-3940256099942544/9257395921";
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;

  void loadAd() {
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Reklam başarıyla yüklendi.');
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) => debugPrint('Reklam yüklenemedi: $error'),
      ),
    );
  }

  void showAdIfAvailable() {
    if (_appOpenAd == null) {
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
        loadAd();
      },
    );
    _appOpenAd!.show();
  }
}

// Global reklam yöneticisi
final adManager = AppOpenAdManager();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 1. SDK başlatma işlemlerini başlat ama uygulamayı engelleme
    MobileAds.instance.initialize();
    
    // 2. Tarih formatını güvenli bir şekilde başlat
    await initializeDateFormatting('tr_TR', null);

    // 3. Reklamı yüklemeye başla (Arka planda çalışsın)
    adManager.loadAd();
    
  } catch (e) {
    debugPrint("Başlatma hatası: $e");
  }

  // Her durumda uygulamayı başlat
  runApp(const UltimateMenuApp());
}

class MealItem {
  final String name;
  final String category;
  final String calories;

  MealItem({required this.name, required this.category, required this.calories});

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      calories: json['calories'] ?? '',
    );
  }
  bool get isSalatbar => category.toLowerCase().contains('salatbar');
}

class DayMenu {
  final String date;
  final List<MealItem> kahvalti;
  final List<MealItem> aksam;
  DayMenu({required this.date, required this.kahvalti, required this.aksam});

  DateTime get dateTime => DateTime.parse(date);
}

// --- ANA UYGULAMA YAPISI ---
class UltimateMenuApp extends StatefulWidget {
  const UltimateMenuApp({super.key});

  @override
  State<UltimateMenuApp> createState() => _UltimateMenuAppState();
}

class _UltimateMenuAppState extends State<UltimateMenuApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Açılışta 3 saniye sonra reklamı göster
    Future.delayed(const Duration(seconds: 3), () {
      adManager.showAdIfAvailable();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plandan öne gelince reklam göster
    if (state == AppLifecycleState.resumed) {
      adManager.showAdIfAvailable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kOffWhite,
        colorScheme: ColorScheme.fromSeed(seedColor: kIndigo, primary: kIndigo),
      ),
      home: const MenuPage(),
    );
  }
}

// --- MENÜ SAYFASI ---
class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final String url = "https://raw.githubusercontent.com/canercay5/menubb/main/data/menu.json";
  
  // GlobalKey listeleri ile her karta odaklanma imkanı
  final Map<String, GlobalKey> _morningKeys = {};
  final Map<String, GlobalKey> _eveningKeys = {};
  
  late Future<List<DayMenu>> _menuFuture;
  List<DayMenu> _allMenus = [];

  @override
  void initState() {
    super.initState();
    _menuFuture = _fetchMenus();
  }

  void _scrollToToday(int tabIndex) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final targetKey = (tabIndex == 0) ? _morningKeys[todayStr] : _eveningKeys[todayStr];

    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.fastLinearToSlowEaseIn,
        alignment: 0.5, // EKRANIN TAM ORTASINA HİZALAMA
      );
    }
  }

  Future<List<DayMenu>> _fetchMenus() async {
    try {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      List<DayMenu> menus = [];
      
      data.forEach((date, content) {
        menus.add(DayMenu(
          date: date,
          kahvalti: (content['kahvalti'] as List? ?? []).map((e) => MealItem.fromJson(e)).toList(),
          aksam: (content['aksam'] as List? ?? []).map((e) => MealItem.fromJson(e)).toList(),
        ));
        _morningKeys[date] = GlobalKey();
        _eveningKeys[date] = GlobalKey();
      });

      menus.sort((a, b) => a.date.compareTo(b.date));
      _allMenus = menus;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () => _scrollToToday(0));
      });

      return menus;
    } else {
      // Sunucu 200 dönmezse (404 vb.) boş liste döndür ki uygulama açılsın
      debugPrint("Sunucu hatası: ${response.statusCode}");
      return [];
    }
  } catch (e) {
    // İnternet yoksa veya başka bir hata olursa buraya düşer
    debugPrint("Veri çekilemedi: $e");
    return []; // Uygulama logoda kalmasın diye boş liste döndürüyoruz
  }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("YEMEK LİSTESİ", style: TextStyle(fontWeight: FontWeight.w900, color: kIndigo)),
          centerTitle: true,
          backgroundColor: kOffWhite,
        ),
        body: FutureBuilder<List<DayMenu>>(
          future: _menuFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: kIndigo));
            }
            return TabBarView(
              children: [
                _buildScrollableList(_allMenus, true, _morningKeys),
                _buildScrollableList(_allMenus, false, _eveningKeys),
              ],
            );
          },
        ),
        floatingActionButton: Builder(builder: (context) {
          return FloatingActionButton(
            onPressed: () => _scrollToToday(DefaultTabController.of(context).index),
            backgroundColor: kGreen,
            elevation: 12,
            child: const Icon(Icons.calendar_month_rounded, color: kWhite, size: 32),
          );
        }),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: kWhite,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: const TabBar(
            labelColor: kIndigo,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kIndigo,
            indicatorWeight: 6,
            tabs: [
              Tab(icon: Icon(Icons.sunny), text: "Sabah"),
              Tab(icon: Icon(Icons.nights_stay), text: "Akşam"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableList(List<DayMenu> menus, bool isMorning, Map<String, GlobalKey> keys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      child: Column(
        children: menus.map((menu) {
          bool isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == menu.date;
          final items = isMorning ? menu.kahvalti : menu.aksam;

          return Container(
            key: keys[menu.date],
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              // BUGÜN İÇİN YEŞİL GLOW EFEKTİ
              boxShadow: isToday ? [
                const BoxShadow(
                  color: kGreen,
                  blurRadius: 25,
                  spreadRadius: 3,
                )
              ] : [],
            ),
            child: Card(
              elevation: 0,
              color: kWhite,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: isToday ? kGreen : const Color(0xFFEEEEEE), width: 2.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE', 'tr_TR').format(menu.dateTime).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w900, color: kIndigo, fontSize: 22),
                            ),
                            Text(
                              DateFormat('dd MMMM yyyy', 'tr_TR').format(menu.dateTime),
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        if (isToday) const Icon(Icons.verified_rounded, color: kGreen, size: 36),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1, thickness: 2, color: kOffWhite),
                    const SizedBox(height: 18),
                    if (isMorning) 
                      ...items.map((m) => _buildMealRow(m))
                    else 
                      ..._buildGroupedAksam(items),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildGroupedAksam(List<MealItem> items) {
    final normal = items.where((i) => !i.isSalatbar).toList();
    final salat = items.where((i) => i.isSalatbar).toList();
    return [
      if (normal.isNotEmpty) _sectionHeader("ANA YEMEK LİSTESİ"),
      ...normal.map((m) => _buildMealRow(m)),
      if (salat.isNotEmpty) ...[
        const SizedBox(height: 20),
        _sectionHeader("SALATA BAR"),
        ...salat.map((m) => _buildMealRow(m)),
      ]
    ];
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kGreen, letterSpacing: 1.5)),
    );
  }

  Widget _buildMealRow(MealItem meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: kIndigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(meal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: kIndigo, borderRadius: BorderRadius.circular(14)),
            child: Text(meal.calories, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kWhite)),
          ),
        ],
      ),
    );
  }
}