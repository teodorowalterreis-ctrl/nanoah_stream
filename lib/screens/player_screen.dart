import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final List? channels;
  final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.channels,
    this.initialIndex = 0,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showControls = true;

  late List _playlist;
  late int _currentIndex;

  String get _currentTitle {
    if (_playlist.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _playlist.length) {
      return (_playlist[_currentIndex]['title'] ?? widget.title).toString();
    }
    return widget.title;
  }

  String get _currentUrl {
    if (_playlist.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _playlist.length) {
      return (_playlist[_currentIndex]['stream_url'] ?? widget.streamUrl)
          .toString();
    }
    return widget.streamUrl;
  }

  bool get _canGoPrevious => _playlist.length > 1 && _currentIndex > 0;

  bool get _canGoNext =>
      _playlist.length > 1 && _currentIndex < _playlist.length - 1;

  @override
  void initState() {
    super.initState();
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

  Future<void> _initVideoPlayer(String rawUrl) async {
    final oldController = _controller;
    _controller = null;

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _errorMessage = null;
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

      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _isInitialized = true;
      });
      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
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
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _controller?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showControls = !_showControls),
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
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
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
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 32,
                          tooltip: 'Canal anterior',
                          icon: Icon(
                            Icons.skip_previous_rounded,
                            color:
                                _canGoPrevious ? Colors.white : Colors.white24,
                          ),
                          onPressed: _canGoPrevious ? _previousChannel : null,
                        ),
                        IconButton(
                          iconSize: 40,
                          tooltip: isPlaying ? 'Pausar' : 'Reproduzir',
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: Colors.blueAccent,
                          ),
                          onPressed: _isInitialized ? _togglePlayPause : null,
                        ),
                        IconButton(
                          iconSize: 32,
                          tooltip: 'Próximo canal',
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: _canGoNext ? Colors.white : Colors.white24,
                          ),
                          onPressed: _canGoNext ? _nextChannel : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}