import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/tv_focus_card.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _quickCategories = [
    'Todos',
    'Geral',
    'Notícias',
    'Filmes',
    'Série',
    'Religião',
    'Música',
    'Entretenimento',
    'Desporto',
    'Infantil',
  ];

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  int _navIndex = 0;
  bool _isGridView = true;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _autoPlayEnabled = true;
  String _userName = 'Visitante';
  String _selectedCategory = 'Todos';
  String _searchQuery = '';

  List<dynamic> _liveCategories = [];
  List<dynamic> _movieCategories = [];
  final List _customPlaylists = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSession();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    final savedName = prefs.getString('user_name');

    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _userName = (savedName != null && savedName.trim().isNotEmpty)
          ? savedName.trim()
          : (loggedIn ? 'Utilizador Nanoah' : 'Visitante');
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final liveRes = await ApiService.getContent('live');
      final movieRes = await ApiService.getContent('movie');

      if (!mounted) return;
      setState(() {
        if (liveRes is Map && liveRes['status'] == 'success') {
          _liveCategories = liveRes['data'] ?? [];
        } else if (liveRes is List) {
          _liveCategories = liveRes;
        }

        if (movieRes is Map && movieRes['status'] == 'success') {
          _movieCategories = movieRes['data'] ?? [];
        } else if (movieRes is List) {
          _movieCategories = movieRes;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint("Erro ao carregar dados na Home: $e");
    }
  }

  String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .trim();
  }

  bool _matchesCategoryFilter(String rawCategory, String rawTitle) {
    if (_selectedCategory == 'Todos') return true;

    final filter = _normalizeText(_selectedCategory);
    final cat = _normalizeText(rawCategory);
    final title = _normalizeText(rawTitle);

    if (cat.contains(filter) || title.contains(filter)) {
      return true;
    }

    switch (filter) {
      case 'noticias':
        return cat.contains('news') ||
            cat.contains('jornal') ||
            title.contains('news') ||
            title.contains('jornal');
      case 'musica':
        return cat.contains('music') ||
            title.contains('trace') ||
            title.contains('mtv') ||
            title.contains('music');
      case 'desporto':
        return cat.contains('esporte') ||
            cat.contains('sport') ||
            cat.contains('futebol') ||
            title.contains('sport') ||
            title.contains('futebol');
      case 'filmes':
        return cat.contains('filme') ||
            cat.contains('movie') ||
            cat.contains('cinema') ||
            cat.contains('ficcao');
      case 'serie':
        return cat.contains('serie') ||
            cat.contains('series') ||
            cat.contains('temporada') ||
            cat.contains('episodio') ||
            title.contains('serie') ||
            title.contains('temporada');
      case 'infantil':
        return cat.contains('kids') ||
            cat.contains('crianca') ||
            cat.contains('desenho') ||
            title.contains('kids') ||
            title.contains('cartoon');
      case 'religiao':
        return cat.contains('gospel') ||
            cat.contains('igreja') ||
            cat.contains('catolic') ||
            cat.contains('evangel');
      case 'entretenimento':
        return cat.contains('varied') ||
            cat.contains('novela') ||
            cat.contains('show') ||
            cat.contains('serie');
      case 'geral':
        return cat.contains('geral') ||
            cat.contains('aberta') ||
            cat.contains('nacional') ||
            cat.contains('internacional') ||
            cat.contains('ao vivo');
      default:
        return false;
    }
  }

  List<dynamic> _filterCategories(List<dynamic> categories) {
    final query = _normalizeText(_searchQuery);
    final List<dynamic> filtered = [];

    for (final cat in categories) {
      if (cat is! Map) continue;
      final catName = (cat['category_name'] ?? 'Categoria').toString();
      final rawItems = cat['items'] as List<dynamic>? ?? [];
      final List<dynamic> matchingItems = [];

      for (final item in rawItems) {
        if (item is! Map) continue;
        final title = (item['title'] ?? 'Sem Título').toString();
        final matchesCat = _matchesCategoryFilter(catName, title);
        final matchesSearch = query.isEmpty ||
            _normalizeText(title).contains(query) ||
            _normalizeText(catName).contains(query);

        if (matchesCat && matchesSearch) {
          matchingItems.add(item);
        }
      }

      if (matchingItems.isNotEmpty) {
        filtered.add({
          ...cat,
          'items': matchingItems,
        });
      }
    }

    return filtered;
  }

  void _openPlayer(List<dynamic> categoryItems, int currentIndex) {
    final item = categoryItems[currentIndex];
    final List playlist = [];

    for (final entry in categoryItems) {
      if (entry is Map) {
        playlist.add({
          'title': (entry['title'] ?? 'Sem Título').toString(),
          'stream_url': (entry['stream_url'] ?? '').toString(),
        });
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          streamUrl: (item['stream_url'] ?? '').toString(),
          title: (item['title'] ?? 'Sem Título').toString(),
          channels: playlist,
          initialIndex: currentIndex,
          autoPlay: _autoPlayEnabled,
        ),
      ),
    );
  }

  void _showAddPlaylistDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Adicionar Lista de Reprodução',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nome da lista',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'URL / Link da lista',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isNotEmpty && url.isNotEmpty) {
                setState(() {
                  _customPlaylists.add({'name': name, 'url': url});
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lista "$name" adicionada.')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showLoginDialog() {
    final userController = TextEditingController(
      text: _isLoggedIn ? _userName : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Text(
          _isLoggedIn ? 'Sessão Ativa' : 'Entrar na Conta',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: _isLoggedIn
            ? Text(
                'Sessão iniciada como $_userName.',
                style: const TextStyle(color: Colors.white70),
              )
            : TextField(
                controller: userController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Utilizador ou E-mail',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
          ),
          if (_isLoggedIn)
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                await ApiService.logout();
                if (!mounted) return;
                setState(() {
                  _isLoggedIn = false;
                  _userName = 'Visitante';
                });
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Sessão encerrada.')),
                );
              },
              child: const Text(
                'Sair da conta',
                style: TextStyle(color: Colors.redAccent),
              ),
            )
          else
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final nome = userController.text.trim();
                final resolvedName = nome.isEmpty ? 'Utilizador Nanoah' : nome;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_logged_in', true);
                await prefs.setString('user_name', resolvedName);

                if (!mounted) return;
                setState(() {
                  _isLoggedIn = true;
                  _userName = resolvedName;
                });
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Bem-vindo, $_userName!')),
                );
              },
              child: const Text('Entrar'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
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
        actions: [
          if (_navIndex == 0)
            IconButton(
              tooltip: _isGridView ? 'Ver em lista' : 'Ver em molduras',
              icon: Icon(
                _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                color: Colors.blueAccent,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
          IconButton(
            tooltip: 'Atualizar canais',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
        bottom: _navIndex == 0
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                indicatorWeight: 3,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: "CANAIS AO VIVO"),
                  Tab(text: "FILMES & VOD"),
                ],
              )
            : null,
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        backgroundColor: const Color(0xFF111827),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _navIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv_rounded),
            label: 'Canais',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_add_rounded),
            label: 'Listas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Conta & Def.',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_navIndex == 1) {
      return _buildPlaylistsTab();
    }
    if (_navIndex == 2) {
      return _buildSettingsTab();
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(_filterCategories(_liveCategories)),
              _buildCategoryList(_filterCategories(_movieCategories)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Pesquisar canal...',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white54, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1F2937),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _quickCategories[index];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.blueAccent,
                  backgroundColor: const Color(0xFF1F2937),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<dynamic> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum conteúdo disponível",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, catIndex) {
        final category = categories[catIndex];
        final items = category['items'] as List<dynamic>? ?? [];
        final categoryName =
            (category['category_name'] ?? 'Categoria').toString().toUpperCase();

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  "${items.length} itens",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isGridView
                ? _buildHorizontalCards(items)
                : _buildCompactList(items, categoryName),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildHorizontalCards(List<dynamic> items) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, itemIndex) {
          final item = items[itemIndex];
          final logoUrl = (item['logo_url'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SizedBox(
              width: 130,
              child: TvFocusCard(
                onTap: () => _openPlayer(items, itemIndex),
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
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: logoUrl.isNotEmpty
                              ? Image.network(
                                  logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.movie,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                )
                              : const Icon(
                                  Icons.tv,
                                  color: Colors.blueAccent,
                                  size: 40,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          (item['title'] ?? 'Sem Título').toString(),
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
    );
  }

  Widget _buildCompactList(List<dynamic> items, String categoryName) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final item = items[index];
          final title = (item['title'] ?? 'Sem Título').toString();
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1F2937),
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              categoryName,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.play_circle_fill,
              color: Colors.blueAccent,
            ),
            onTap: () => _openPlayer(items, index),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _showAddPlaylistDialog,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar Lista de Reprodução'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _customPlaylists.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma lista extra adicionada ainda.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _customPlaylists.length,
                    itemBuilder: (context, index) {
                      final pl = _customPlaylists[index];
                      return Card(
                        color: const Color(0xFF1F2937),
                        child: ListTile(
                          leading: const Icon(
                            Icons.playlist_play,
                            color: Colors.blueAccent,
                          ),
                          title: (pl['name'] ?? '').toString().isEmpty
                              ? const SizedBox.shrink()
                              : Text(
                                  (pl['name'] ?? '').toString(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                          subtitle: Text(
                            (pl['url'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white54),
                            onPressed: () {
                              setState(() => _customPlaylists.removeAt(index));
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF1F2937),
          child: ListTile(
            leading: Icon(
              _isLoggedIn ? Icons.verified_user : Icons.person_outline,
              color: Colors.blueAccent,
            ),
            title: Text(
              _isLoggedIn ? 'Conta: $_userName' : 'Não autenticado',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              _isLoggedIn ? 'Sessão ativa' : 'Toque para entrar na conta',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            trailing: TextButton(
              onPressed: _showLoginDialog,
              child: Text(
                _isLoggedIn ? 'Sair' : 'Entrar',
                style: TextStyle(
                  color: _isLoggedIn ? Colors.redAccent : Colors.blueAccent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1F2937),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DETALHES DO PERFIL',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Utilizador: $_userName',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estado da sessão: ${_isLoggedIn ? 'Autenticado' : 'Visitante'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modo de visualização: ${_isGridView ? 'Molduras' : 'Lista'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reprodução automática: ${_autoPlayEnabled ? 'Ativada' : 'Desativada'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Listas guardadas: ${_customPlaylists.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1F2937),
          child: SwitchListTile(
            title: const Text(
              'Visualização em molduras',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Desative para ver os canais em lista organizada',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            activeColor: Colors.blueAccent,
            value: _isGridView,
            onChanged: (val) => setState(() => _isGridView = val),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1F2937),
          child: SwitchListTile(
            title: const Text(
              'Reprodução automática',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Iniciar o vídeo automaticamente ao abrir o canal',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            activeColor: Colors.blueAccent,
            value: _autoPlayEnabled,
            onChanged: (val) => setState(() => _autoPlayEnabled = val),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1F2937),
          child: ListTile(
            leading:
                const Icon(Icons.cleaning_services_outlined, color: Colors.grey),
            title: const Text(
              'Limpar listas adicionadas',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${_customPlaylists.length} lista(s) guardada(s)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            onTap: _customPlaylists.isEmpty
                ? null
                : () {
                    setState(() => _customPlaylists.clear());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Listas extra removidas.')),
                    );
                  },
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          color: Color(0xFF1F2937),
          child: ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blueAccent),
            title: Text(
              'NANOAH STREAM',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Versão 1.0.0',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isLoggedIn ? 'Perfil ativo: $_userName' : 'Perfil de visitante',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              TextButton(
                onPressed: _showLoginDialog,
                child: Text(
                  _isLoggedIn ? 'Gerir sessão' : 'Entrar',
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}