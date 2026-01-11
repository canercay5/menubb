import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // Uygulama başlamadan önce yerel tarih formatlarını hazırlıyoruz
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  runApp(const IbbMenuApp());
}

// --- DOMAIN MODELS ---
// DDD prensiplerine uygun veri modelleri
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

  // Akşam menüsündeki salatbar ayrımı için kontrol
  bool get isSalatbar => category.toLowerCase().contains('salatbar');
}

class DayMenu {
  final String date;
  final List<MealItem> kahvalti;
  final List<MealItem> aksam;

  DayMenu({required this.date, required this.kahvalti, required this.aksam});
}

// --- ANA UYGULAMA YAPISI ---
class IbbMenuApp extends StatelessWidget {
  const IbbMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İBB Yurt Menü',
      theme: ThemeData(
        useMaterial3: true,
        // İBB Kurumsal Renkleri (Kırmızı ve Lacivert)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE30613),
          primary: const Color(0xFFE30613),
          secondary: const Color(0xFF1C3B68),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE30613),
          foregroundColor: Colors.white,
          elevation: 4,
          centerTitle: true,
        ),
      ),
      home: const MenuPage(),
    );
  }
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final String url = "https://raw.githubusercontent.com/emirozd/menubb/refs/heads/main/src/data/menu.json";
  late Future<List<DayMenu>> _menuFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Veriyi GitHub'dan çekme fonksiyonu
  void _loadData() {
    setState(() {
      _menuFuture = _fetchMenus();
    });
  }

  Future<List<DayMenu>> _fetchMenus() async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        List<DayMenu> menus = [];
        
        data.forEach((date, content) {
          menus.add(DayMenu(
            date: date,
            kahvalti: (content['kahvalti'] as List? ?? []).map((e) => MealItem.fromJson(e)).toList(),
            aksam: (content['aksam'] as List? ?? []).map((e) => MealItem.fromJson(e)).toList(),
          ));
        });
        
        // Tarihe göre sıralama (Eskiden yeniye)
        menus.sort((a, b) => a.date.compareTo(b.date));
        return menus;
      }
      throw Exception("Sunucuya ulaşılamadı");
    } catch (e) {
      throw Exception("Bağlantı hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("İBB YURT YEMEK MENÜSÜ", 
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            unselectedLabelColor: Colors.white70,
            labelColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "SABAH", icon: Icon(Icons.wb_twilight_rounded)),
              Tab(text: "AKŞAM", icon: Icon(Icons.nightlight_round_sharp)),
            ],
          ),
        ),
        // TabBarView sayfalar arası kaydırmayı otomatik sağlar
        body: FutureBuilder<List<DayMenu>>(
          future: _menuFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Hata: ${snapshot.error}"));
            }

            final menus = snapshot.data ?? [];
            return TabBarView(
              children: [
                _buildRefreshableList(menus, true),
                _buildRefreshableList(menus, false),
              ],
            );
          },
        ),
      ),
    );
  }

  // Aşağı çekince güncellenen liste yapısı
  Widget _buildRefreshableList(List<DayMenu> menus, bool isMorning) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadData();
        await _menuFuture;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        itemCount: menus.length,
        itemBuilder: (context, index) {
          final dayMenu = menus[index];
          final items = isMorning ? dayMenu.kahvalti : dayMenu.aksam;
          
          DateTime parsedDate = DateTime.parse(dayMenu.date);
          String dayName = DateFormat('EEEE', 'tr_TR').format(parsedDate);
          String dayMonth = DateFormat('dd MMMM', 'tr_TR').format(parsedDate);
          
          // Bugünün tarihini kontrol etme
          bool isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dayMenu.date;

          return Card(
            elevation: isToday ? 8 : 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              // Bugün ise kırmızı çerçeve ekle
              side: isToday 
                  ? const BorderSide(color: Color(0xFFE30613), width: 2) 
                  : BorderSide.none,
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFFE30613) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('dd').format(parsedDate), 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 18,
                            color: isToday ? Colors.white : Colors.black87
                          )),
                      Text(DateFormat('MMM').format(parsedDate).toUpperCase(), 
                          style: TextStyle(
                            fontSize: 10, 
                            color: isToday ? Colors.white : Colors.black54
                          )),
                    ],
                  ),
                ),
                title: Text(
                  dayName.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isToday ? const Color(0xFFE30613) : const Color(0xFF1C3B68),
                  ),
                ),
                subtitle: Text(dayMonth, style: const TextStyle(fontSize: 13)),
                children: [
                  const Divider(indent: 16, endIndent: 16, height: 1),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const ListTile(title: Text("Bu öğün için menü girilmemiş.")),
                  ...items.map((meal) => _buildMealTile(meal)).toList(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Menü içindeki her bir satır (Yemek ve Kalori)
  Widget _buildMealTile(MealItem meal) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Icon(
        meal.isSalatbar ? Icons.eco_rounded : Icons.restaurant_menu_rounded,
        size: 20,
        color: meal.isSalatbar ? Colors.green.shade600 : Colors.blueGrey.shade300,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(meal.name, 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          // Salatbar ise yeşil bir etiket göster
          if (meal.isSalatbar)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Text("SALATBAR", 
                  style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      trailing: Text(
        meal.calories,
        style: TextStyle(
          fontSize: 12, 
          color: Colors.red.shade900, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }
}