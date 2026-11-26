class ContentHelper {
  static const Map<String, String> _exactTranslations = {
    'all': 'Todos',
    'live': 'Ao Vivo',
    'live tv': 'Canais ao Vivo',
    'general': 'Geral',
    'news': 'Notícias',
    'sports': 'Desporto',
    'sport': 'Desporto',
    'movies': 'Filmes',
    'movie': 'Filme',
    'series': 'Séries',
    'tv shows': 'Séries',
    'kids': 'Infantil',
    'children': 'Infantil',
    'music': 'Música',
    'entertainment': 'Entretenimento',
    'documentary': 'Documentários',
    'documentaries': 'Documentários',
    'action': 'Ação',
    'adventure': 'Aventura',
    'comedy': 'Comédia',
    'drama': 'Drama',
    'horror': 'Terror',
    'sci-fi': 'Ficção Científica',
    'science fiction': 'Ficção Científica',
    'romance': 'Romance',
    'thriller': 'Suspense',
    'animation': 'Animação',
    'family': 'Família',
    'religion': 'Religião',
    'religious': 'Religião',
    'season': 'Temporada',
    'episode': 'Episódio',
    'subtitled': 'Legendado',
    'dubbed': 'Dublado',
    'vod': 'Sob Demanda',
  };

  static const Map<String, String> _phraseTranslations = {
    'live tv': 'TV ao vivo',
    'science fiction': 'ficção científica',
    'tv shows': 'séries de TV',
    'season': 'temporada',
    'episode': 'episódio',
    'movies': 'filmes',
    'movie': 'filme',
    'series': 'séries',
    'news': 'notícias',
    'sports': 'desporto',
    'sport': 'desporto',
    'kids': 'infantil',
    'music': 'música',
    'entertainment': 'entretenimento',
    'documentary': 'documentário',
    'documentaries': 'documentários',
    'action': 'ação',
    'adventure': 'aventura',
    'comedy': 'comédia',
    'drama': 'drama',
    'horror': 'terror',
    'romance': 'romance',
    'thriller': 'suspense',
    'animation': 'animação',
    'family': 'família',
    'dubbed': 'dublado',
    'subtitled': 'legendado',
  };

  static String translateEnToPt(String text, {required bool enabled}) {
    final trimmed = text.trim();
    if (!enabled || trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();
    final exact = _exactTranslations[lower];
    if (exact != null) return exact;

    String result = trimmed;
    _phraseTranslations.forEach((en, pt) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(en)}\\b', caseSensitive: false),
        pt,
      );
    });

    if (result.isNotEmpty && result[0] == result[0].toLowerCase()) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    return result.trim();
  }

  static bool isValidStreamUrl(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return false;
    final uri = Uri.tryParse(clean);
    if (uri == null) return false;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.trim().isNotEmpty;
  }

  static bool isMarkedOffline(Map item) {
    final boolFlags = [item['is_online'], item['online'], item['active']];
    for (final flag in boolFlags) {
      if (flag == false) return true;
      if (flag is String) {
        final f = flag.trim().toLowerCase();
        if (f == 'false' || f == '0' || f == 'no' || f == 'offline') {
          return true;
        }
      }
    }

    final status = (item['status'] ?? item['stream_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'offline' ||
        status == 'inactive' ||
        status == 'dead' ||
        status == 'down' ||
        status == 'unavailable') {
      return true;
    }

    return false;
  }

  static String resolvePlayableUrl(Map item) {
    final direct = (item['stream_url'] ?? '').toString().trim();
    if (isValidStreamUrl(direct)) return direct;

    final sources = item['sources'];
    if (sources is List) {
      for (final src in sources) {
        if (src is Map) {
          final candidate = (src['url'] ?? src['stream_url'] ?? '')
              .toString()
              .trim();
          if (isValidStreamUrl(candidate)) return candidate;
        }
      }
    }

    return '';
  }
}