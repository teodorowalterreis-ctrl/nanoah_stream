import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/content_helper.dart';
import '../widgets/tv_focus_card.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _liveSubCategories = [
    'Todos',
    'Geral',
    'Notícias',
    'Desporto',
    'Entretenimento',
    'Música',
    'Infantil',
    'Religião',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _firstContentFocusNode = FocusNode();

  // 0: Canais ao Vivo | 1: Filmes | 2: Séries | 3: Novelas | 4: Listas | 5: Conta & Def.
  int _selectedSection = 0;
  bool _tvSubmenuExpanded = true;
  bool _isGridView = false; // Inicia em lista vertical rápida para TV
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _autoPlayEnabled = true;
  bool _translateEnToPt = true;
  bool _hideFailedStreams = true;
  String _userName = 'Visitante';
  String _selectedLiveCategory = 'Todos';
  String _searchQuery = '';

  List<dynamic> _liveCategories = [];
  List<dynamic> _movieCategories = [];
  final List<dynamic> _customPlaylists = [];
  final Set<String> _failedStreamUrls = {};

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _firstContentFocusNode.dispose();
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

  List<dynamic> _extractCategories(dynamic response) {
    if (response is Map && response['status'] == 'success') {
      final data = response['data'];
      if (data is List<dynamic>) return data;
    } else if (response is List<dynamic>) {
      return response;
    }
    return [];
  }

  void _mergeCategories(List<dynamic> target, List<dynamic> incoming) {
    for (final cat in incoming) {
      if (cat is! Map) continue;
      final catName = (cat['category_name'] ?? 'Geral').toString().trim();
      final rawItems = cat['items'];
      if (rawItems is! List<dynamic> || rawItems.isEmpty) continue;

      int existingIndex = -1;
      for (int i = 0; i < target.length; i++) {
        final existingCat = target[i];
        if (existingCat is Map &&
            (existingCat['category_name'] ?? '').toString().trim().toLowerCase() ==
                catName.toLowerCase()) {
          existingIndex = i;
          break;
        }
      }

      if (existingIndex >= 0 && target[existingIndex] is Map) {
        final existingMap = Map<String, dynamic>.from(target[existingIndex] as Map);
        final existingItems = List<dynamic>.from(existingMap['items'] as List<dynamic>? ?? []);
        existingItems.addAll(rawItems);
        existingMap['items'] = existingItems;
        target[existingIndex] = existingMap;
      } else {
        target.add({
          'category_name': catName.isEmpty ? 'Geral' : catName,
          'items': List<dynamic>.from(rawItems),
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.getContent('live'),
        ApiService.getContent('movie'),
        ApiService.getSaimoLive(),
        ApiService.getSaimoVod(),
      ]);

      final List<dynamic> mergedLive = [];
      final List<dynamic> mergedMovies = [];

      _mergeCategories(mergedLive, _extractCategories(results[0]));
      _mergeCategories(mergedMovies, _extractCategories(results[1]));
      _mergeCategories(mergedLive, _extractCategories(results[2]));
      _mergeCategories(mergedMovies, _extractCategories(results[3]));

      if (!mounted) return;
      setState(() {
        _liveCategories = mergedLive;
        _movieCategories = mergedMovies;
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

  bool _isSeriesItem(String cat, String title) {
    return cat.contains('serie') ||
        cat.contains('series') ||
        cat.contains('temporada') ||
        cat.contains('episodio') ||
        title.contains('serie') ||
        title.contains('temporada') ||
        title.contains('episodio');
  }

  bool _isNovelaItem(String cat, String title) {
    return cat.contains('novela') ||
        cat.contains('telenovela') ||
        title.contains('novela') ||
        title.contains('capitulo');
  }

  bool _isMovieItem(String cat, String title) {
    if (_isSeriesItem(cat, title) || _isNovelaItem(cat, title)) {
      return false;
    }
    return cat.contains('filme') ||
        cat.contains('movie') ||
        cat.contains('cinema') ||
        cat.contains('vod') ||
        cat.contains('ficcao') ||
        title.contains('filme');
  }

  bool _matchesSection(int section, String rawCategory, String rawTitle) {
    final cat = _normalizeText(rawCategory);
    final title = _normalizeText(rawTitle);

    switch (section) {
      case 0: // Canais ao Vivo
        return !_isMovieItem(cat, title) &&
            !_isSeriesItem(cat, title) &&
            !_isNovelaItem(cat, title);
      case 1: // Filmes
        return _isMovieItem(cat, title);
      case 2: // Séries
        return _isSeriesItem(cat, title);
      case 3: // Novelas
        return _isNovelaItem(cat, title);
      default:
        return true;
    }
  }

  bool _matchesLiveSubCategory(String rawCategory, String rawTitle) {
    if (_selectedSection != 0 || _selectedLiveCategory == 'Todos') {
      return true;
    }

    final filter = _normalizeText(_selectedLiveCategory);
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
            cat.contains('show') ||
            cat.contains('entreten');
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

  List<Map<String, dynamic>> _getFlattenedItems() {
    final query = _normalizeText(_searchQuery);
    final source = _selectedSection == 0
        ? <dynamic>[..._liveCategories, ..._movieCategories]
        : <dynamic>[..._movieCategories, ..._liveCategories];

    final List<Map<String, dynamic>> result = [];

    for (final cat in source) {
      if (cat is! Map) continue;
      final catName = (cat['category_name'] ?? 'Geral').toString();
      final rawItems = cat['items'] as List<dynamic>? ?? [];

      final translatedCat = ContentHelper.translateEnToPt(catName, enabled: _translateEnToPt);
      for (final item in rawItems) {
        if (item is! Map) continue;
        if (ContentHelper.isMarkedOffline(item)) continue;
        final playableUrl = ContentHelper.resolvePlayableUrl(item);
        if (playableUrl.isEmpty) continue;
        if (_hideFailedStreams && _failedStreamUrls.contains(playableUrl)) continue;
        final title = (item['title'] ?? 'Sem Título').toString();

        if (!_matchesSection(_selectedSection, catName, title)) continue;
        if (!_matchesLiveSubCategory(catName, title)) continue;

        final matchesSearch = query.isEmpty ||
            _normalizeText(title).contains(query) ||
            _normalizeText(catName).contains(query);

        if (matchesSearch) {
          final sources = item['sources'] is List<dynamic>
              ? List<dynamic>.from(item['sources'] as List<dynamic>)
              : <dynamic>[];
          final firstSource =
              (sources.isNotEmpty && sources.first is Map)
                  ? (sources.first as Map)
                  : null;

          result.add({
            'title': title,
            'stream_url': playableUrl,
            'logo_url': (item['logo_url'] ?? '').toString(),
            'category_name': translatedCat,
            'sources': sources,
            'referer': (item['referer'] ?? firstSource?['referer'] ?? '').toString(),
            'user_agent':
                (item['user_agent'] ?? firstSource?['user_agent'] ?? '').toString(),
          });
        }
      }
    }

    return result;
  }

  void _focusContentArea() {
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_firstContentFocusNode.canRequestFocus) {
        _firstContentFocusNode.requestFocus();
      }
    });
  }

  void _openPlayer(List<Map<String, dynamic>> items, int currentIndex) {
    final item = items[currentIndex];
    final List<dynamic> playlist = items
        .map((entry) => {
              'title': (entry['title'] ?? 'Sem Título').toString(),
              'stream_url': (entry['stream_url'] ?? '').toString(),
              'referer': (entry['referer'] ?? '').toString(),
              'user_agent': (entry['user_agent'] ?? '').toString(),
              'sources': entry['sources'] ?? const [],
            })
        .toList();

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

  String _currentSectionLabel() {
    switch (_selectedSection) {
      case 0:
        return _selectedLiveCategory == 'Todos'
            ? 'Canais ao Vivo · Todos'
            : 'Canais ao Vivo · $_selectedLiveCategory';
      case 1:
        return 'Filmes';
      case 2:
        return 'Séries';
      case 3:
        return 'Novelas';
      case 4:
        return 'Listas';
      case 5:
        return 'Conta & Def.';
      default:
        return 'Canais ao Vivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 245,
                      child: _buildLeftSidebar(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildRightContentPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.cyanAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'NANOAH STREAM',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          if (_selectedSection <= 3)
            _TvActionButton(
              icon: _isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
              label: _isGridView ? 'Lista' : 'Mosaico',
              accentColor: Colors.amberAccent,
              onTap: () => setState(() => _isGridView = !_isGridView),
            ),
          if (_selectedSection <= 3) const SizedBox(width: 8),
          _TvActionButton(
            icon: Icons.refresh_rounded,
            label: 'Atualizar',
            accentColor: Colors.cyanAccent,
            onTap: _loadData,
          ),
          const SizedBox(width: 8),
          _TvActionButton(
            icon: _isLoggedIn
                ? Icons.verified_user_rounded
                : Icons.account_circle_rounded,
            label: _isLoggedIn ? _userName : 'Conta',
            accentColor: Colors.pinkAccent,
            onTap: () => setState(() => _selectedSection = 5),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _focusContentArea();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _focusContentArea(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Pesquisar...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.cyanAccent,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A2438),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                _SidebarNavTile(
                  icon: Icons.live_tv_rounded,
                  label: 'Canais ao Vivo',
                  activeColor: Colors.cyanAccent,
                  isSelected: _selectedSection == 0,
                  trailingIcon: _tvSubmenuExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  onTap: () {
                    setState(() {
                      if (_selectedSection == 0) {
                        _tvSubmenuExpanded = !_tvSubmenuExpanded;
                      } else {
                        _selectedSection = 0;
                        _tvSubmenuExpanded = true;
                      }
                    });
                  },
                ),
                if (_selectedSection == 0 && _tvSubmenuExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4, bottom: 6),
                    child: Column(
                      children: _liveSubCategories.map((subCat) {
                        final isSubSelected = _selectedLiveCategory == subCat;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _SidebarNavTile(
                            icon: subCat == 'Todos'
                                ? Icons.apps_rounded
                                : Icons.label_important_rounded,
                            label: subCat,
                            compact: true,
                            activeColor: Colors.amberAccent,
                            isSelected: isSubSelected,
                            onTap: () {
                              setState(() {
                                _selectedSection = 0;
                                _selectedLiveCategory = subCat;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 4),
                _SidebarNavTile(
                  icon: Icons.movie_creation_rounded,
                  label: 'Filmes',
                  activeColor: Colors.amberAccent,
                  isSelected: _selectedSection == 1,
                  onTap: () => setState(() => _selectedSection = 1),
                ),
                const SizedBox(height: 4),
                _SidebarNavTile(
                  icon: Icons.tv_rounded,
                  label: 'Séries',
                  activeColor: Colors.purpleAccent,
                  isSelected: _selectedSection == 2,
                  onTap: () => setState(() => _selectedSection = 2),
                ),
                const SizedBox(height: 4),
                _SidebarNavTile(
                  icon: Icons.theater_comedy_rounded,
                  label: 'Novelas',
                  activeColor: Colors.pinkAccent,
                  isSelected: _selectedSection == 3,
                  onTap: () => setState(() => _selectedSection = 3),
                ),
                const Divider(color: Colors.white12, height: 16),
                _SidebarNavTile(
                  icon: Icons.playlist_add_rounded,
                  label: 'Listas',
                  activeColor: Colors.greenAccent,
                  isSelected: _selectedSection == 4,
                  onTap: () => setState(() => _selectedSection = 4),
                ),
                const SizedBox(height: 4),
                _SidebarNavTile(
                  icon: Icons.settings_rounded,
                  label: 'Conta & Def.',
                  activeColor: Colors.orangeAccent,
                  isSelected: _selectedSection == 5,
                  onTap: () => setState(() => _selectedSection = 5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightContentPanel() {
    if (_selectedSection == 4) {
      return _buildPlaylistsTab();
    }
    if (_selectedSection == 5) {
      return _buildSettingsTab();
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    final items = _getFlattenedItems();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _currentSectionLabel().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} itens',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum conteúdo disponível',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : _isGridView
                    ? _buildMosaicGrid(items)
                    : _buildVerticalChannelList(items),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalChannelList(List<Map<String, dynamic>> items) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = items[index];
        final title = (item['title'] ?? 'Sem Título').toString();
        final catName = (item['category_name'] ?? '').toString();
        return _FocusableListRow(
          focusNode: index == 0 ? _firstContentFocusNode : null,
          index: index,
          title: title,
          subtitle: catName,
          onTap: () => _openPlayer(items, index),
        );
      },
    );
  }

  Widget _buildMosaicGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final logoUrl = (item['logo_url'] ?? '').toString();
        return TvFocusCard(
          focusNode: index == 0 ? _firstContentFocusNode : null,
          onTap: () => _openPlayer(items, index),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A2438),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: logoUrl.isNotEmpty
                        ? Image.network(
                            logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.tv_rounded,
                              color: Colors.cyanAccent,
                              size: 36,
                            ),
                          )
                        : const Icon(
                            Icons.tv_rounded,
                            color: Colors.cyanAccent,
                            size: 36,
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
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: const Color(0xFF070B14),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _showAddPlaylistDialog,
            icon: const Icon(Icons.add),
            label: const Text(
              'Adicionar Lista de Reprodução',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _customPlaylists.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma lista extra adicionada ainda.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: _customPlaylists.length,
                    itemBuilder: (context, index) {
                      final pl = _customPlaylists[index];
                      return Card(
                        color: const Color(0xFF1A2438),
                        child: ListTile(
                          leading: const Icon(
                            Icons.playlist_play,
                            color: Colors.cyanAccent,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF1A2438),
            child: ListTile(
              leading: Icon(
                _isLoggedIn ? Icons.verified_user : Icons.person_outline,
                color: Colors.cyanAccent,
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
                    color: _isLoggedIn ? Colors.redAccent : Colors.cyanAccent,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1A2438),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DETALHES DO PERFIL',
                    style: TextStyle(
                      color: Colors.cyanAccent,
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
                    'Modo de visualização: ${_isGridView ? 'Mosaico' : 'Lista'}',
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
            color: const Color(0xFF1A2438),
            child: SwitchListTile(
              title: const Text(
                'Visualização em mosaico',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Desative para ver os canais em lista rápida',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              activeColor: Colors.cyanAccent,
              value: _isGridView,
              onChanged: (val) => setState(() => _isGridView = val),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1A2438),
            child: SwitchListTile(
              title: const Text(
                'Reprodução automática',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Iniciar o vídeo automaticamente ao abrir o canal',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              activeColor: Colors.cyanAccent,
              value: _autoPlayEnabled,
              onChanged: (val) => setState(() => _autoPlayEnabled = val),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1A2438),
            child: SwitchListTile(
              title: const Text(
                'Traduzir termos EN -> PT',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Traduz categorias em inglês para português',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              activeColor: Colors.cyanAccent,
              value: _translateEnToPt,
              onChanged: (val) => setState(() => _translateEnToPt = val),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1A2438),
            child: SwitchListTile(
              title: const Text(
                'Ocultar canais com falha na sessão',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '\${_failedStreamUrls.length} canal(is) marcado(s) na sessão',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              activeColor: Colors.cyanAccent,
              value: _hideFailedStreams,
              onChanged: (val) => setState(() => _hideFailedStreams = val),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1A2438),
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined,
                  color: Colors.grey),
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
            color: Color(0xFF1A2438),
            child: ListTile(
              leading: Icon(Icons.info_outline, color: Colors.cyanAccent),
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
        ],
      ),
    );
  }
}

bool _isTvSelectEvent(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final key = event.logicalKey;
  return key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA ||
      key.keyLabel == 'Select' ||
      key.keyLabel == 'Enter';
}

class _TvActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _TvActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_TvActionButton> createState() => _TvActionButtonState();
}

class _TvActionButtonState extends State<_TvActionButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        if (!mounted) return;
        setState(() => _hasFocus = focused);
      },
      onKeyEvent: (node, event) {
        if (_isTvSelectEvent(event)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _hasFocus
                ? widget.accentColor.withOpacity(0.24)
                : const Color(0xFF1A2438),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hasFocus ? widget.accentColor : Colors.white12,
              width: _hasFocus ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.accentColor, size: 18),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarNavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color activeColor;
  final bool isSelected;
  final bool compact;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.isSelected,
    this.compact = false,
    this.trailingIcon,
    required this.onTap,
  });

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hasFocus || widget.isSelected;
    return Focus(
      onFocusChange: (focused) {
        if (!mounted) return;
        setState(() => _hasFocus = focused);
      },
      onKeyEvent: (node, event) {
        if (_isTvSelectEvent(event)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 12,
            vertical: widget.compact ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: _hasFocus
                ? widget.activeColor.withOpacity(0.28)
                : (widget.isSelected
                    ? widget.activeColor.withOpacity(0.14)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hasFocus
                  ? widget.activeColor
                  : (widget.isSelected
                      ? widget.activeColor.withOpacity(0.5)
                      : Colors.transparent),
              width: _hasFocus ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: highlighted ? widget.activeColor : Colors.white60,
                size: widget.compact ? 16 : 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: highlighted ? Colors.white : Colors.white70,
                    fontSize: widget.compact ? 12 : 13,
                    fontWeight:
                        highlighted ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailingIcon != null)
                Icon(
                  widget.trailingIcon,
                  color: Colors.white54,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusableListRow extends StatefulWidget {
  final FocusNode? focusNode;
  final int index;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FocusableListRow({
    this.focusNode,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_FocusableListRow> createState() => _FocusableListRowState();
}

class _FocusableListRowState extends State<_FocusableListRow> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        if (!mounted) return;
        setState(() => _hasFocus = focused);
      },
      onKeyEvent: (node, event) {
        if (_isTvSelectEvent(event)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.cyanAccent.withOpacity(0.22)
                : const Color(0xFF1A2438),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hasFocus ? Colors.amberAccent : Colors.white10,
              width: _hasFocus ? 2.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor:
                    _hasFocus ? Colors.amberAccent : const Color(0xFF101827),
                child: Text(
                  '${widget.index + 1}',
                  style: TextStyle(
                    color: _hasFocus ? const Color(0xFF070B14) : Colors.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight:
                            _hasFocus ? FontWeight.w800 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle.isNotEmpty)
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: _hasFocus ? Colors.amberAccent : Colors.white54,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.play_circle_fill_rounded,
                color: _hasFocus ? Colors.amberAccent : Colors.cyanAccent,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}