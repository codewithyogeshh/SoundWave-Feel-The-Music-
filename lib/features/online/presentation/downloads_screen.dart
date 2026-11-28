import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/online/services/download_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/download_provider.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/online_music_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

/// One place for offline audio: how much space the downloads take, what is
/// still running, what failed, and batch download/delete for several tracks.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};
  final Map<String, SongModel> _toDownload = <String, SongModel>{};

  String _usageSignature = '';
  int _usageBytes = 0;
  bool _usageReady = false;
  bool _refreshingUsage = false;
  final Map<String, int> _sizes = <String, int>{};

  /// Measures the downloads only when the set on disk actually changed, so
  /// progress updates do not stat every file again on each rebuild.
  void _ensureUsage(List<SongModel> songs) {
    final signature = songs
        .map((s) => '${s.id}:${s.audioPath}:${s.artworkPath}')
        .join('|');
    if (signature == _usageSignature || _refreshingUsage) return;
    _usageSignature = signature;
    // Post-frame so an empty list (which resolves without awaiting) cannot
    // call setState while this build is still running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshUsage(songs);
    });
  }

  Future<void> _refreshUsage(List<SongModel> songs) async {
    _refreshingUsage = true;
    final sizes = <String, int>{};
    var total = 0;
    for (final song in songs) {
      final bytes = await DownloadService.downloadedBytes(song);
      sizes[song.id] = bytes;
      total += bytes;
    }
    _refreshingUsage = false;
    if (!mounted) return;
    setState(() {
      _sizes
        ..clear()
        ..addAll(sizes);
      _usageBytes = total;
      _usageReady = true;
    });
  }

  void _toggleSelecting() {
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = !_selecting;
      _selectedIds.clear();
    });
  }

  void _toggleSongSelection(SongModel song) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.remove(song.id)) {
        _selectedIds.add(song.id);
      }
    });
  }

  void _togglePendingDownload(SongModel song) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_toDownload.remove(song.id) == null) {
        _toDownload[song.id] = song;
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _deleteSong(SongModel song) async {
    await ref.read(downloadProvider.notifier).removeDownload(song);
    if (!mounted) return;
    setState(() => _selectedIds.remove(song.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${song.title}" from downloads'),
        backgroundColor: AppColors.secondaryBackground,
      ),
    );
  }

  Future<void> _deleteSelected(List<SongModel> downloaded) async {
    final songs = downloaded
        .where((s) => _selectedIds.contains(s.id))
        .toList(growable: false);
    if (songs.isEmpty) return;

    final confirmed = await _confirm(
      title: 'Delete ${songs.length} downloads?',
      message:
          'This frees ${_formatBytes(await DownloadService.totalDownloadedBytes(songs))} '
          'and removes them from your offline library.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;

    await ref.read(downloadProvider.notifier).removeDownloads(songs);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted ${songs.length} ${songs.length == 1 ? 'download' : 'downloads'}',
        ),
        backgroundColor: AppColors.secondaryBackground,
      ),
    );
  }

  Future<void> _downloadSelected() async {
    final songs = _toDownload.values.toList(growable: false);
    if (songs.isEmpty) return;

    setState(() => _toDownload.clear());
    final succeeded = await ref
        .read(downloadProvider.notifier)
        .downloadMany(songs);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded == songs.length
              ? 'Downloaded ${songs.length} ${songs.length == 1 ? 'song' : 'songs'}'
              : '$succeeded of ${songs.length} songs downloaded — retry the rest below',
        ),
        backgroundColor: AppColors.secondaryBackground,
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    final activeTheme = ref.read(themeProvider);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: activeTheme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: activeTheme.highlightColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final downloadState = ref.watch(downloadProvider);
    final activeTheme = ref.watch(themeProvider);
    final downloaded = libState.downloadedSongs;

    _ensureUsage(downloaded);

    final active = downloadState.activeSongs.values.toList(growable: false);
    final failed = downloadState.retryableSongs;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(activeTheme, downloaded),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: _selecting ? 150 : 32,
                  ),
                  children: [
                    _buildUsageCard(activeTheme, downloaded, active, failed),
                    if (active.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Downloading',
                        trailing: '${active.length} in progress',
                      ),
                      ...active.map(
                        (song) => _buildActiveTile(activeTheme, song, downloadState),
                      ),
                    ],
                    if (failed.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Needs attention',
                        trailing: 'Retry all',
                        onTrailingTap: () =>
                            ref.read(downloadProvider.notifier).retryAll(),
                      ),
                      ...failed.map(
                        (song) => _buildFailedTile(
                          activeTheme,
                          song,
                          downloadState.failedDownloads[song.id] ?? 'Download failed',
                        ),
                      ),
                    ],
                    _buildSectionHeader(
                      'On this device',
                      trailing: downloaded.isEmpty
                          ? null
                          : '${downloaded.length} ${downloaded.length == 1 ? 'song' : 'songs'}',
                    ),
                    if (downloaded.isEmpty)
                      _buildEmptyDownloads(activeTheme)
                    else
                      ...downloaded.map(
                        (song) => _buildDownloadedTile(
                          activeTheme,
                          song,
                          downloaded,
                          downloadState,
                        ),
                      ),
                    _buildSectionHeader(
                      'Download more',
                      trailing: _toDownload.isEmpty
                          ? 'Popular right now'
                          : '${_toDownload.length} selected',
                    ),
                    _buildPopularSection(activeTheme, libState, downloadState),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _selecting
          ? _buildSelectionBar(activeTheme, downloaded)
          : null,
    );
  }

  Widget _buildHeader(AppThemeType activeTheme, List<SongModel> downloaded) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).maybePop();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (rect) =>
                      activeTheme.primaryGradient.createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'Downloads',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  'Offline audio and storage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.artistName.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: activeTheme.highlightColor.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          if (downloaded.isNotEmpty)
            TextButton(
              onPressed: _toggleSelecting,
              child: Text(
                _selecting ? 'Done' : 'Select',
                style: TextStyle(
                  color: activeTheme.primaryAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsageCard(
    AppThemeType activeTheme,
    List<SongModel> downloaded,
    List<SongModel> active,
    List<SongModel> failed,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: GlassCard(
        borderRadius: 24,
        blur: 14,
        color: AppColors.glassWhiteMedium,
        borderColor: activeTheme.primaryAccent.withValues(alpha: 0.28),
        padding: const EdgeInsets.all(18),
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/storage');
        },
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: activeTheme.accentGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.offline_pin_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _usageReady ? _formatBytes(_usageBytes) : 'Checking storage…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${downloaded.length} ${downloaded.length == 1 ? 'song' : 'songs'} stored offline'
                    '${active.isEmpty ? '' : ' • ${active.length} downloading'}'
                    '${failed.isEmpty ? '' : ' • ${failed.length} failed'}'
                    ' • Storage Manager',
                    maxLines: 2,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: activeTheme.primaryAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? trailing,
    VoidCallback? onTrailingTap,
  }) {
    final activeTheme = ref.watch(themeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: activeTheme.accentGradient,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: activeTheme.highlightColor.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing,
                style: TextStyle(
                  color: onTrailingTap == null
                      ? AppColors.textMuted
                      : activeTheme.primaryAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTile(
    AppThemeType activeTheme,
    SongModel song,
    DownloadState downloadState,
  ) {
    final progress = downloadState.getProgress(song.id).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GlassCard(
        borderRadius: 18,
        blur: 0,
        color: AppColors.glassWhiteMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            AlbumArtwork(
              size: 44,
              borderRadius: 12,
              artworkUrl: song.artworkPath,
              songId: song.rawId,
              songTitle: song.title,
              songArtist: song.artist,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        activeTheme.primaryAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: activeTheme.primaryAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedTile(
    AppThemeType activeTheme,
    SongModel song,
    String error,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GlassCard(
        borderRadius: 18,
        blur: 0,
        color: AppColors.glassWhiteMedium,
        borderColor: Colors.redAccent.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Retry download',
              icon: Icon(
                Icons.refresh_rounded,
                color: activeTheme.primaryAccent,
                size: 20,
              ),
              onPressed: () =>
                  ref.read(downloadProvider.notifier).retry(song),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
              onPressed: () =>
                  ref.read(downloadProvider.notifier).dismissFailure(song.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedTile(
    AppThemeType activeTheme,
    SongModel song,
    List<SongModel> downloaded,
    DownloadState downloadState,
  ) {
    final isSelected = _selectedIds.contains(song.id);
    final isPlaying = ref.watch(
      playerProvider.select((p) => p.currentSong?.id == song.id),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GlassCard(
        borderRadius: 18,
        blur: 0,
        color: isSelected
            ? activeTheme.primaryAccent.withValues(alpha: 0.16)
            : AppColors.glassWhiteMedium,
        borderColor: isSelected
            ? activeTheme.primaryAccent.withValues(alpha: 0.6)
            : AppColors.glassBorderSubtle,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onTap: () {
          if (_selecting) {
            _toggleSongSelection(song);
            return;
          }
          HapticFeedback.selectionClick();
          ref.read(playerProvider.notifier).playTrack(song, queue: downloaded);
          ref.read(libraryProvider.notifier).recordPlayed(song);
        },
        child: Row(
          children: [
            if (_selecting)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? activeTheme.primaryAccent
                      : AppColors.textMuted,
                  size: 20,
                ),
              ),
            AlbumArtwork(
              size: 48,
              borderRadius: 13,
              artworkUrl: song.artworkPath,
              songId: song.rawId,
              songTitle: song.title,
              songArtist: song.artist,
              hasGlow: isPlaying,
              glowColor: activeTheme.primaryAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.songTitle.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.artistName.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if ((_sizes[song.id] ?? 0) > 0)
                        Text(
                          '•  ${_formatBytes(_sizes[song.id]!)}',
                          style: AppTextStyles.artistName.copyWith(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_selecting)
              IconButton(
                tooltip: 'Delete download',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textMuted,
                  size: 19,
                ),
                onPressed: downloadState.isDownloading(song.id)
                    ? null
                    : () => _deleteSong(song),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDownloads(AppThemeType activeTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        borderRadius: 20,
        blur: 0,
        color: AppColors.glassWhiteMedium,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              color: activeTheme.primaryAccent.withValues(alpha: 0.8),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'No offline downloads yet',
              style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a few tracks below and they will download for offline playback.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularSection(
    AppThemeType activeTheme,
    LibraryState libState,
    DownloadState downloadState,
  ) {
    final trending = ref.watch(onlineTrendingProvider);

    return trending.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not load songs to download right now.',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(onlineTrendingProvider),
              child: Text(
                'Retry',
                style: TextStyle(color: activeTheme.primaryAccent),
              ),
            ),
          ],
        ),
      ),
      data: (songs) {
        final candidates = songs
            .where(
              (song) =>
                  !libState.isDownloaded(song.id) &&
                  !downloadState.isDownloading(song.id) &&
                  !downloadState.failedSongs.containsKey(song.id),
            )
            .take(8)
            .toList(growable: false);

        if (candidates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Everything popular is already saved offline.',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          );
        }

        return Column(
          children: [
            ...candidates.map((song) {
              final selected = _toDownload.containsKey(song.id);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
                child: GlassCard(
                  borderRadius: 16,
                  blur: 0,
                  color: selected
                      ? activeTheme.primaryAccent.withValues(alpha: 0.14)
                      : AppColors.glassWhiteMedium,
                  borderColor: selected
                      ? activeTheme.primaryAccent.withValues(alpha: 0.5)
                      : AppColors.glassBorderSubtle,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  onTap: () => _togglePendingDownload(song),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        color: selected
                            ? activeTheme.primaryAccent
                            : AppColors.textMuted,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      AlbumArtwork(
                        size: 40,
                        borderRadius: 11,
                        artworkUrl: song.artworkPath,
                        songId: song.rawId,
                        songTitle: song.title,
                        songArtist: song.artist,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.songTitle.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.artistName.copyWith(
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: GradientButton.pill(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                gradient: activeTheme.accentGradient,
                onPressed: _toDownload.isEmpty ? null : _downloadSelected,
                text: _toDownload.isEmpty
                    ? 'Select songs to download'
                    : 'Download ${_toDownload.length} ${_toDownload.length == 1 ? 'song' : 'songs'}',
                icon: Icons.download_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionBar(AppThemeType activeTheme, List<SongModel> downloaded) {
    final count = _selectedIds.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 0
                    ? 'Select downloads to remove'
                    : '$count selected',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            GradientButton.pill(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.deepOrangeAccent],
              ),
              onPressed: count == 0 ? null : () => _deleteSelected(downloaded),
              text: 'Delete',
              icon: Icons.delete_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
