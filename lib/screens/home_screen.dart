import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/tv_focus_card.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _liveCategories = [];
  List<dynamic> _movieCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);

    // Carrega Canais Ao Vivo e Filmes em paralelo
    final liveRes = await ApiService.getContent('live');
    final movieRes = await ApiService.getContent('movie');

    setState(() {
      if (liveRes['status'] == 'success') _liveCategories = liveRes['data'];
      if (movieRes['status'] == 'success') _movieCategories = movieRes['data'];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Fundo ultra-moderno minimalista
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          "NANOAH STREAM",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 3,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: "CANAIS AO VIVO"),
            Tab(text: "FILMES & VOD"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList(_liveCategories),
                _buildCategoryList(_movieCategories),
              ],
            ),
    );
  }

  Widget _buildCategoryList(List<dynamic> categories) {
    if (categories.isEmpty) {
      const Center(
        child: Text("Nenhum conteúdo disponível", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, catIndex) {
        final category = categories[catIndex];
        final items = category['items'] as List<dynamic>;

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                category['category_name'].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, itemIndex) {
                  final item = items[itemIndex];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: SizedBox(
                      width: 130,
                      child: TvFocusCard(
                        onTap: () {
                          // Abre o player de vídeo ao clicar no item
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerScreen(
                                streamUrl: item['stream_url'],
                                title: item['title'],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: item['logo_url'] != null && item['logo_url'].toString().isNotEmpty
                                      ? Image.network(
                                          item['logo_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => const Icon(Icons.movie, color: Colors.grey, size: 40),
                                        )
                                      : const Icon(Icons.tv, color: Colors.blueAccent, size: 40),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  item['title'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}