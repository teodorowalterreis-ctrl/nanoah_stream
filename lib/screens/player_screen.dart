import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final List? channels;
  final int initialIndex;
  final bool autoPlay;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.channels,
    this.initialIndex = 0,
    this.autoPlay = true,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _screenChannel =
      MethodChannel('nanoah_stream/keep_screen_on');
  static const Duration _controlsHideDelay = Duration(seconds: 5);

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showControls = true;
  bool _wasPlayingBeforePause = false;

  Timer? _hideTimer;
  final FocusNode _rootFocusNode = FocusNode();
  final FocusNode _prevFocusNode = FocusNode();
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _nextFocusNode = FocusNode();

  late List _playlist;
  late int _currentIndex;

  Map<dynamic, dynamic>? get _currentItemMap {
    if (_playlist.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _playlist.length &&
        _playlist[_currentIndex] is Map) {
      return _playlist[_currentIndex] as Map<dynamic, dynamic>;
    }
    return null;
  }

  String get _currentTitle {
    final item = _currentItemMap;
    if (item != null && item['title'] != null) {
      return item['title'].toString();
    }
    return widget.title;
  }

  String get _currentUrl {
    final item = _currentItemMap;
    if (item != null && item['stream_url'] != null) {
      return item['stream_url'].toString();
    }
    return widget.streamUrl;
  }

  String _readEpgField(List<String> keys) {
    final item = _currentItemMap;
    if (item == null) return '';

    for (final key in keys) {
      final val = item[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }

    final epg = item['epg'];
    if (epg is Map) {
      for (final key in keys) {
        final val = epg[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString().trim();
        }
      }
    }

    return '';
  }

  String get _previousProgram => _readEpgField(
      ['previous_program', 'epg_previous', 'prev_program', 'previous']);

  String get _currentProgram => _readEpgField(
      ['current_program', 'epg_current', 'now_playing', 'current']);

  String get _nextProgram => _readEpgField(
      ['next_program', 'epg_next', 'following_program', 'next']);

  bool get _hasEpgData =>
      _previousProgram.isNotEmpty ||
      _currentProgram.isNotEmpty ||
      _nextProgram.isNotEmpty;

  Map<String, String> _resolveHeadersForCurrentItem() {
    final Map<String, String> headers = {};
    final item = _currentItemMap;
    if (item == null) return headers;

    String referer = (item['referer'] ?? '').toString().trim();
    String userAgent = (item['user_agent'] ?? '').toString().trim();

    if ((referer.isEmpty || userAgent.isEmpty) && item['sources'] is List) {
      for (final src in (item['sources'] as List)) {
        if (src is Map) {
          final srcUrl = (src['url'] ?? '').toString().trim();
          if (srcUrl == _currentUrl.trim() || srcUrl.isNotEmpty) {
            if (referer.isEmpty) {
              referer = (src['referer'] ?? '').toString().trim();
            }
            if (userAgent.isEmpty) {
              userAgent = (src['user_agent'] ?? '').toString().trim();
            }
            if (srcUrl == _currentUrl.trim()) break;
          }
        }
      }
    }

    if (referer.isNotEmpty) {
      headers['Referer'] = referer;
    }
    if (userAgent.isNotEmpty) {
      headers['User-Agent'] = userAgent;
    }

    return headers;
  }

  bool get _canGoPrevious => _playlist.length > 1 && _currentIndex > 0;

  bool get _canGoNext =>
      _playlist.length > 1 && _currentIndex < _playlist.length - 1;

  List<FocusNode> get _enabledTransportNodes {
    final nodes = <FocusNode>[];
    if (_canGoPrevious) nodes.add(_prevFocusNode);
    if (_isInitialized && _controller != null) nodes.add(_playPauseFocusNode);
    if (_canGoNext) nodes.add(_nextFocusNode);
    return nodes;
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _scheduleHideTimer() {
    _cancelHideTimer();
    final playing = _controller?.value.isPlaying ?? false;
    if (!_showControls || !playing || _errorMessage != null) return;

    _hideTimer = Timer(_controlsHideDelay, () {
      if (!mounted) return;
      final stillPlaying = _controller?.value.isPlaying ?? false;
      if (stillPlaying && _errorMessage == null) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _revealControls({bool focusPlayPause = false}) {
    _cancelHideTimer();
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }
    _scheduleHideTimer();

    if (focusPlayPause) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_showControls) return;
        if (_playPauseFocusNode.canRequestFocus) {
          _playPauseFocusNode.requestFocus();
        }
      });
    }
  }

  void _toggleControls() {
    if (_showControls) {
      _cancelHideTimer();
      setState(() {
        _showControls = false;
      });
    } else {
      _revealControls(focusPlayPause: true);
    }
  }

  void _moveTransportFocus(int delta) {
    final nodes = _enabledTransportNodes;
    if (nodes.isEmpty) return;

    final currentIdx = nodes.indexWhere((n) => n.hasFocus);
    final nextIdx = currentIdx < 0
        ? (delta > 0 ? 0 : nodes.length - 1)
        : (currentIdx + delta).clamp(0, nodes.length - 1);

    nodes[nextIdx].requestFocus();
    _scheduleHideTimer();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      return KeyEventResult.ignored;
    }

    if (!_showControls) {
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.mediaPlayPause) {
        _revealControls(focusPlayPause: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    _scheduleHideTimer();

    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveTransportFocus(-1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _moveTransportFocus(1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_canGoNext) {
        _nextChannel();
        _revealControls(focusPlayPause: true);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_canGoPrevious) {
        _previousChannel();
        _revealControls(focusPlayPause: true);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _togglePlayPause();
        return KeyEventResult.handled;
      }
      if (_prevFocusNode.hasFocus && _canGoPrevious) {
        _previousChannel();
      } else if (_nextFocusNode.hasFocus && _canGoNext) {
        _nextChannel();
      } else {
        _togglePlayPause();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _setKeepScreenOn(bool enable) async {
    try {
      await _screenChannel.invokeMethod<void>('setKeepScreenOn', {
        'enable': enable,
      });
    } catch (_) {
      // Ignora se o canal nativo não estiver registado no lado Android
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.channels != null && widget.channels!.isNotEmpty) {
      _playlist = widget.channels!;
      _currentIndex =
          widget.initialIndex.clamp(0, _playlist.length - 1).toInt();
    } else {
      _playlist = [
        {'title': widget.title, 'stream_url': widget.streamUrl},
      ];
      _currentIndex = 0;
    }
    _initVideoPlayer(_currentUrl);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _cancelHideTimer();
      _wasPlayingBeforePause = controller.value.isPlaying;
      if (_wasPlayingBeforePause) {
        controller.pause();
      }
      _setKeepScreenOn(false);
    } else if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _setKeepScreenOn(true);
      if (_wasPlayingBeforePause && widget.autoPlay) {
        controller.play();
        _revealControls();
      }
    }
  }

  Future<void> _initVideoPlayer(String rawUrl) async {
    _cancelHideTimer();
    final oldController = _controller;
    _controller = null;

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _errorMessage = null;
        _showControls = true;
      });
    }

    await oldController?.dispose();

    try {
      final cleanUrl = rawUrl.trim();
      if (cleanUrl.isEmpty) {
        throw Exception('URL do vídeo está vazio.');
      }

      final uri = Uri.tryParse(cleanUrl);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        throw Exception('URL inválido ou sem http/https: "$cleanUrl"');
      }

      final headers = _resolveHeadersForCurrentItem();
      final controller = headers.isNotEmpty
          ? VideoPlayerController.networkUrl(uri, httpHeaders: headers)
          : VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();
      await controller.setLooping(true);
      await _setKeepScreenOn(true);

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      if (widget.autoPlay) {
        await controller.play();
        _revealControls(focusPlayPause: true);
      }
    } catch (e) {
      _cancelHideTimer();
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _showControls = true;
      });
    }
  }

  void _previousChannel() {
    if (!_canGoPrevious) return;
    setState(() {
      _currentIndex--;
    });
    _initVideoPlayer(_currentUrl);
  }

  void _nextChannel() {
    if (!_canGoNext) return;
    setState(() {
      _currentIndex++;
    });
    _initVideoPlayer(_currentUrl);
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null || !_isInitialized) return;
    final playing = controller.value.isPlaying;
    setState(() {
      if (playing) {
        controller.pause();
        _cancelHideTimer();
        _showControls = true;
      } else {
        controller.play();
        _showControls = true;
        _scheduleHideTimer();
      }
    });
  }

  @override
  void dispose() {
    _cancelHideTimer();
    _rootFocusNode.dispose();
    _prevFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _nextFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _setKeepScreenOn(false);
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildTransportButton({
    required FocusNode focusNode,
    required bool enabled,
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return Focus(
      focusNode: focusNode,
      canRequestFocus: enabled,
      onFocusChange: (_) {
        if (mounted) {
          setState(() {});
          if (_showControls) _scheduleHideTimer();
        }
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: isFocused
                  ? Colors.white.withOpacity(0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isFocused ? Colors.lightBlueAccent : Colors.transparent,
                width: 2,
              ),
            ),
            child: IconButton(
              iconSize: 34,
              tooltip: tooltip,
              icon: icon,
              onPressed: enabled
                  ? () {
                      _scheduleHideTimer();
                      onPressed?.call();
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpgBanner() {
    final nowText = _currentProgram.isNotEmpty
        ? _currentProgram
        : (_hasEpgData ? _currentTitle : '$_currentTitle • Transmissão ativa');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _currentProgram.isNotEmpty ? 'AGORA' : 'CANAL',
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nowText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          if (_previousProgram.isNotEmpty || _nextProgram.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (_previousProgram.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Anterior: $_previousProgram',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (_previousProgram.isNotEmpty && _nextProgram.isNotEmpty)
                  const SizedBox(width: 12),
                if (_nextProgram.isNotEmpty)
                  Expanded(
                    child: Text(
                      'A seguir: $_nextProgram',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            children: [
              Center(
                child: _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'FALHA AO REPRODUZIR VÍDEO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'URL: $_currentUrl',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _initVideoPlayer(_currentUrl),
                                  icon: const Icon(Icons.refresh,
                                      color: Colors.white, size: 18),
                                  label: const Text(
                                    'Tentar novamente',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (_canGoNext)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _nextChannel,
                                    icon: const Icon(Icons.skip_next_rounded,
                                        size: 18),
                                    label: const Text('Próximo canal'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : _isInitialized && _controller != null
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          )
                        : const CircularProgressIndicator(
                            color: Colors.blueAccent),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _currentTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_playlist.length > 1)
                              Text(
                                '${_currentIndex + 1}/${_playlist.length}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.88),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildEpgBanner(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildTransportButton(
                                  focusNode: _prevFocusNode,
                                  enabled: _canGoPrevious,
                                  tooltip: 'Canal anterior',
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    color: _canGoPrevious
                                        ? Colors.white
                                        : Colors.white24,
                                  ),
                                  onPressed:
                                      _canGoPrevious ? _previousChannel : null,
                                ),
                                _buildTransportButton(
                                  focusNode: _playPauseFocusNode,
                                  enabled: _isInitialized,
                                  tooltip: isPlaying ? 'Pausar' : 'Reproduzir',
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_filled_rounded,
                                    color: Colors.blueAccent,
                                    size: 40,
                                  ),
                                  onPressed:
                                      _isInitialized ? _togglePlayPause : null,
                                ),
                                _buildTransportButton(
                                  focusNode: _nextFocusNode,
                                  enabled: _canGoNext,
                                  tooltip: 'Próximo canal',
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color: _canGoNext
                                        ? Colors.white
                                        : Colors.white24,
                                  ),
                                  onPressed: _canGoNext ? _nextChannel : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}