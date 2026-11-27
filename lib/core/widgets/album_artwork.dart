import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:soundwave/app/theme/app_colors.dart';

class AlbumArtwork extends StatelessWidget {
  final String? artworkUrl;
  final int? albumId;
  final int? songId;
  final String? songTitle;
  final String? songArtist;
  final double size;
  final double borderRadius;
  final bool hasGlow;
  final Color? glowColor;
  final Widget? overlay;

  const AlbumArtwork({
    super.key,
    this.artworkUrl,
    this.albumId,
    this.songId,
    this.songTitle,
    this.songArtist,
    required this.size,
    this.borderRadius = 18.0,
    this.hasGlow = false,
    this.glowColor,
    this.overlay,
  });

  /// Returns a filesystem path when [artworkPath] points to a local file (`file://` or path),
  /// or null for network URLs, bundled `assets/`, or `content://` URIs.
  static String? extractLocalFilePath(String? artworkPath) {
    if (artworkPath == null) return null;
    final trimmed = artworkPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('assets/') ||
        trimmed.startsWith('asset://') ||
        trimmed.startsWith('content://')) {
      return null;
    }
    if (trimmed.startsWith('file://')) {
      return Uri.tryParse(trimmed)?.toFilePath() ?? trimmed.substring(7);
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? AppColors.purple;

    Widget imageContent = _buildImageSource();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: effectiveGlowColor.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 4,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A new cover fades in over the old one instead of popping. The
            // key follows the artwork identity, so the switch only fires when
            // the song actually changes (not on every rebuild).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(
                  'art_${artworkUrl ?? ''}_${albumId ?? 0}_${songId ?? 0}',
                ),
                child: imageContent,
              ),
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }

  Widget _buildImageSource() {
    final placeholder = _buildPlaceholder();

    // 1. Offline/downloaded local cover banner file (works completely offline)
    final localFilePath = extractLocalFilePath(artworkUrl);
    if (!kIsWeb && localFilePath != null) {
      final file = File(localFilePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          key: ValueKey('file_art_$localFilePath'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildSecondarySource(placeholder),
        );
      }
    }

    return _buildSecondarySource(placeholder);
  }

  Widget _buildSecondarySource(Widget placeholder) {
    // 2. Android local MediaStore audio artwork if available
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (songId != null || albumId != null) {
        return _CachedOnAudioQueryArtwork(
          key: ValueKey('song_art_${songId}_album_$albumId'),
          songId: songId,
          albumId: albumId,
          size: size,
          borderRadius: borderRadius,
          placeholder: placeholder,
        );
      }
    }

    // 3. Network URL (with offline cache via CachedNetworkImage)
    if (artworkUrl != null &&
        (artworkUrl!.startsWith('http://') ||
            artworkUrl!.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: artworkUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(isLoading: true),
        errorWidget: (context, url, error) => placeholder,
      );
    }

    // 4. Bundled Flutter Asset Path
    if (artworkUrl != null && artworkUrl!.startsWith('assets/')) {
      return Image.asset(
        artworkUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    // 5. Default Procedural SoundWave Artwork
    return placeholder;
  }

  Widget _buildPlaceholder({bool isLoading = false}) {
    if (isLoading) {
      return Container(
        color: AppColors.secondaryBackground,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonBlue),
            ),
          ),
        ),
      );
    }

    return _SoundWaveArtworkFallback(
      title: songTitle,
      artist: songArtist,
      size: size,
      borderRadius: borderRadius,
    );
  }
}

/// Dynamic, deterministic SoundWave music illustration fallback.
/// Generates an individual neon gradient and waveform based on the track title and artist.
class _SoundWaveArtworkFallback extends StatelessWidget {
  final String? title;
  final String? artist;
  final double size;
  final double borderRadius;

  const _SoundWaveArtworkFallback({
    this.title,
    this.artist,
    required this.size,
    required this.borderRadius,
  });

  static const List<List<Color>> _gradientPalettes = [
    [Color(0xFF0F1E54), Color(0xFF3478F6), Color(0xFF8557F6)], // Electric Indigo
    [Color(0xFF1D0933), Color(0xFF8557F6), Color(0xFFE66BEF)], // Cosmic Magenta
    [Color(0xFF082236), Color(0xFF00D2FF), Color(0xFF3478F6)], // Neon Cyan
    [Color(0xFF261033), Color(0xFFFF5286), Color(0xFFA45CFF)], // Sunset Violet
    [Color(0xFF0E2A2E), Color(0xFF00F2FE), Color(0xFF4FACFE)], // Deep Aqua
    [Color(0xFF1A1040), Color(0xFF7557F6), Color(0xFF202A54)], // Midnight Glow
    [Color(0xFF2F0F3D), Color(0xFFE66BEF), Color(0xFF5A32A3)], // Neon Plum
    [Color(0xFF0B1736), Color(0xFF4D9EFF), Color(0xFF8557F6)], // SoundWave Royal
  ];

  @override
  Widget build(BuildContext context) {
    final seed = '${title ?? ''}_${artist ?? ''}';
    final paletteIndex = seed.isEmpty ? 0 : seed.hashCode.abs() % _gradientPalettes.length;
    final colors = _gradientPalettes[paletteIndex];

    final initial = (title != null && title!.trim().isNotEmpty)
        ? title!.trim().substring(0, 1).toUpperCase()
        : 'S';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle Vinyl Groove Rings
          CustomPaint(
            painter: _VinylGroovesPainter(color: Colors.white.withValues(alpha: 0.08)),
          ),

          // Central Waveform / Initial
          Center(
            child: size < 52
                ? Icon(
                    Icons.music_note_rounded,
                    size: size * 0.46,
                    color: Colors.white.withValues(alpha: 0.85),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Equalizer Waveform Bars
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBar(size * 0.16, Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          _buildBar(size * 0.30, Colors.white),
                          const SizedBox(width: 3),
                          _buildBar(size * 0.40, AppColors.neonBlue),
                          const SizedBox(width: 3),
                          _buildBar(size * 0.26, Colors.white),
                          const SizedBox(width: 3),
                          _buildBar(size * 0.14, Colors.white.withValues(alpha: 0.7)),
                        ],
                      ),
                      if (size >= 80) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (size * 0.15).clamp(10.0, 18.0),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double height, Color color) {
    return Container(
      width: (size * 0.045).clamp(2.0, 5.0),
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  final Color color;
  _VinylGroovesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final maxR = size.width * 0.44;
    for (double r = maxR * 0.35; r <= maxR; r += maxR * 0.22) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CachedOnAudioQueryArtwork extends StatefulWidget {
  final int? songId;
  final int? albumId;
  final double size;
  final double borderRadius;
  final Widget placeholder;

  const _CachedOnAudioQueryArtwork({
    super.key,
    this.songId,
    this.albumId,
    required this.size,
    required this.borderRadius,
    required this.placeholder,
  });

  @override
  State<_CachedOnAudioQueryArtwork> createState() =>
      _CachedOnAudioQueryArtworkState();
}

class _CachedOnAudioQueryArtworkState
    extends State<_CachedOnAudioQueryArtwork> {
  static final Map<String, Uint8List?> _memoryCache = {};
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant _CachedOnAudioQueryArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songId != oldWidget.songId || widget.albumId != oldWidget.albumId) {
      _loadArtwork();
    }
  }

  void _loadArtwork() {
    // 1. Try Song ID in cache
    if (widget.songId != null) {
      final songKey = 'song_${widget.songId}';
      if (_memoryCache.containsKey(songKey)) {
        _bytes = _memoryCache[songKey];
        return;
      }
    }

    // 2. Try Album ID in cache
    if (widget.albumId != null) {
      final albumKey = 'album_${widget.albumId}';
      if (_memoryCache.containsKey(albumKey)) {
        _bytes = _memoryCache[albumKey];
        return;
      }
    }

    // 3. Query native artwork: Try Song first (ArtworkType.AUDIO), fallback to Album (ArtworkType.ALBUM)
    if (widget.songId != null) {
      final songKey = 'song_${widget.songId}';
      OnAudioQuery()
          .queryArtwork(
        widget.songId!,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: (widget.size * 2).clamp(120.0, 600.0).toInt(),
        quality: 85,
      )
          .then((data) {
        if (data != null && data.isNotEmpty) {
          _memoryCache[songKey] = data;
          if (mounted) setState(() => _bytes = data);
        } else if (widget.albumId != null) {
          _queryAlbumArtwork();
        }
      }).catchError((_) {
        if (widget.albumId != null) _queryAlbumArtwork();
      });
    } else if (widget.albumId != null) {
      _queryAlbumArtwork();
    }
  }

  void _queryAlbumArtwork() {
    if (widget.albumId == null) return;
    final albumKey = 'album_${widget.albumId}';
    OnAudioQuery()
        .queryArtwork(
      widget.albumId!,
      ArtworkType.ALBUM,
      format: ArtworkFormat.JPEG,
      size: (widget.size * 2).clamp(120.0, 600.0).toInt(),
      quality: 85,
    )
        .then((data) {
      _memoryCache[albumKey] = data;
      if (widget.songId != null) {
        _memoryCache['song_${widget.songId}'] = data;
      }
      if (mounted) setState(() => _bytes = data);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.memory(
          _bytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return widget.placeholder;
  }
}
