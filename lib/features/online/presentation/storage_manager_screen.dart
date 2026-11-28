import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

/// How much room the offline library takes: total size, where the songs live
/// (phone Music folder or hidden app storage), which songs are the heaviest,
/// and one place to free space again.
class StorageManagerScreen extends ConsumerStatefulWidget {
  const StorageManagerScreen({super.key, this.initialSelection = false});

  /// Opens straight into selection mode, for the "Clean up" entry points.
  final bool initialSelection;

  @override
  ConsumerState<StorageManagerScreen> createState() =>
      _StorageManagerScreenState();
}

class _StorageManagerScreenState extends ConsumerState<StorageManagerScreen> {
  bool _measuring = true;
  int _audioBytes = 0;
  int _phoneBytes = 0;
  int _inAppBytes = 0;
  int? _freeBytes;
  String _signature = '';
  final Map<String, int> _sizes = <String, int>{};
  final Set<String> _selectedIds = <String>{};
  late bool _selecting = widget.initialSelection;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measure(ref.read(libraryProvider).downloadedSongs);
    });
  }

  Future<void> _measure(List<SongModel> songs) async {
    final sizes = <String, int>{};
    var phone = 0;
    var inApp = 0;
    for (final song in songs) {
      final bytes = await DownloadService.downloadedBytes(song);
      sizes[song.id] = bytes;
      if (_livesInPhoneFolder(song)) {
        phone += bytes;
      } else {
        inApp += bytes;
      }
    }
    final free = await DownloadService.deviceFreeBytes();
    if (!mounted) return;
    setState(() {
      _sizes
        ..clear()
        ..addAll(sizes);
      _phoneBytes = phone;
      _inAppBytes = inApp;
      _audioBytes = phone + inApp;
      _freeBytes = free;
      _measuring = false;
      _signature = _signatureOf(songs);
    });
  }

  String _signatureOf(List<SongModel> songs) =>
      songs.map((s) => '${s.id}:${s.audioPath}:${s.artworkPath}').join('|');

  /// Songs downloaded to the shared Music folder are owned by Android, not by
  /// the app's private storage.
  bool _livesInPhoneFolder(SongModel song) {
    final path = song.audioPath.toLowerCase();
    return path.startsWith('content://') || path.contains('/music/soundwave/');
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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

  Future<void> _delete(List<SongModel> songs, {required int bytes}) async {
    if (songs.isEmpty || _working) return;
    final confirmed = await _confirm(
      title: songs.length == 1
          ? 'Delete this download?'
          : 'Delete ${songs.length} downloads?',
      message: 'This frees ${_formatBytes(bytes)} on your phone.',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    await ref.read(downloadProvider.notifier).removeDownloads(songs);
    if (!mounted) return;
    setState(() {
      _working = false;
      _selectedIds.clear();
      _selecting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Freed ${_formatBytes(bytes)} — '
          '${songs.length} ${songs.length == 1 ? 'download' : 'downloads'} removed',
        ),
        backgroundColor: AppColors.secondaryBackground,
      ),
    );
    await _measure(ref.read(libraryProvider).downloadedSongs);
  }

  void _toggleSelecting() {
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = !_selecting;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(SongModel song) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.remove(song.id)) _selectedIds.add(song.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final downloaded = ref.watch(libraryProvider).downloadedSongs;

    // A download added or removed elsewhere refreshes the numbers.
    final signature = _signatureOf(downloaded);
    if (signature != _signature && !_selecting) {
      _signature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measure(downloaded);
      });
    }

    final sorted = [...downloaded]..sort(
      (a, b) => (_sizes[b.id] ?? 0).compareTo(_sizes[a.id] ?? 0),
    );
    final selectedSongs = downloaded
        .where((s) => _selectedIds.contains(s.id))
        .toList(growable: false);
    final selectedBytes = selectedSongs.fold<int>(
      0,
      (sum, song) => sum + (_sizes[song.id] ?? 0),
    );

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
                  padding: EdgeInsets.only(bottom: _selecting ? 140 : 32),
                  children: [
                    _buildTotalCard(activeTheme, downloaded),
                    if (downloaded.isEmpty)
                      _buildEmpty(activeTheme)
                    else ...[
                      _buildSectionHeader('Clean up'),
                      _buildCleanupCard(activeTheme, downloaded),
                      _buildSectionHeader(
                        'Songs by size',
                        trailing: _selecting ? 'Done' : 'Select',
                        onTrailingTap: _toggleSelecting,
                      ),
                      ...sorted.map(
                        (song) => _buildSongTile(activeTheme, song),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _selecting && downloaded.isNotEmpty
          ? _buildSelectionBar(activeTheme, selectedSongs, selectedBytes)
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
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 24,
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
                    'Storage Manager',
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
                  '${downloaded.length} '
                  '${downloaded.length == 1 ? 'song' : 'songs'} saved offline',
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
        ],
      ),
    );
  }

  Widget _buildTotalCard(AppThemeType activeTheme, List<SongModel> downloaded) {
    final total = _audioBytes;
    final free = _freeBytes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: GlassCard(
        borderRadius: 26,
        blur: 14,
        color: AppColors.glassWhiteMedium,
        borderColor: activeTheme.primaryAccent.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: activeTheme.accentGradient,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
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
                        _measuring && downloaded.isNotEmpty
                            ? 'Checking…'
                            : _formatBytes(total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.songTitle.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Used by SoundWave downloads',
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (downloaded.isNotEmpty) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    if (_phoneBytes > 0)
                      Expanded(
                        flex: (_phoneBytes * 1000 ~/ total).clamp(1, 1000),
                        child: Container(
                          height: 8,
                          color: activeTheme.primaryAccent,
                        ),
                      ),
                    if (_inAppBytes > 0)
                      Expanded(
                        flex: (_inAppBytes * 1000 ~/ total).clamp(1, 1000),
                        child: Container(
                          height: 8,
                          color: activeTheme.secondaryAccent.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildLegendRow(
                activeTheme.primaryAccent,
                'Music/SoundWave (phone folder)',
                _formatBytes(_phoneBytes),
              ),
              const SizedBox(height: 6),
              _buildLegendRow(
                activeTheme.secondaryAccent.withValues(alpha: 0.75),
                'Inside SoundWave (private)',
                _formatBytes(_inAppBytes),
              ),
            ],
            if (free != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sd_storage_rounded,
                      size: 16,
                      color: activeTheme.highlightColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_formatBytes(free)} free on this phone',
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.artistName.copyWith(fontSize: 11.5),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.artistName.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCleanupCard(AppThemeType activeTheme, List<SongModel> downloaded) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        borderRadius: 20,
        blur: 0,
        color: AppColors.glassWhiteMedium,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cleaning_services_rounded,
                  size: 18,
                  color: activeTheme.primaryAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Free ${_formatBytes(_audioBytes)} by removing all downloads',
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GradientButton.pill(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.deepOrangeAccent],
                    ),
                    onPressed: _working
                        ? null
                        : () => _delete(downloaded, bytes: _audioBytes),
                    text: 'Delete all',
                    icon: Icons.delete_sweep_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GradientButton.pill(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    gradient: activeTheme.accentGradient,
                    onPressed: _toggleSelecting,
                    text: 'Pick songs',
                    icon: Icons.checklist_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongTile(AppThemeType activeTheme, SongModel song) {
    final bytes = _sizes[song.id] ?? 0;
    final isSelected = _selectedIds.contains(song.id);
    final inPhone = _livesInPhoneFolder(song);

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
            _toggleSelection(song);
            return;
          }
          HapticFeedback.selectionClick();
          ref.read(playerProvider.notifier).playTrack(song, queue: [song]);
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (inPhone
                                  ? activeTheme.primaryAccent
                                  : activeTheme.secondaryAccent)
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          inPhone ? 'Music folder' : 'In app',
                          style: AppTextStyles.artistName.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: inPhone
                                ? activeTheme.primaryAccent
                                : activeTheme.secondaryAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.artistName.copyWith(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              bytes > 0 ? _formatBytes(bytes) : '—',
              style: AppTextStyles.artistName.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: activeTheme.highlightColor,
              ),
            ),
            IconButton(
              tooltip: 'Delete download',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.textMuted,
                size: 19,
              ),
              onPressed: _working ? null : () => _delete([song], bytes: bytes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppThemeType activeTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: GlassCard(
        borderRadius: 20,
        blur: 0,
        color: AppColors.glassWhiteMedium,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Column(
          children: [
            Icon(
              Icons.folder_open_rounded,
              color: activeTheme.primaryAccent.withValues(alpha: 0.85),
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing takes up space yet',
              style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Downloaded songs appear here with their size, so you can see '
              'what is using your phone and clear it any time.',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
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

  Widget _buildSelectionBar(
    AppThemeType activeTheme,
    List<SongModel> selectedSongs,
    int selectedBytes,
  ) {
    final count = selectedSongs.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 0
                    ? 'Pick songs to remove'
                    : '$count selected • ${_formatBytes(selectedBytes)}',
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
              onPressed: count == 0
                  ? null
                  : () => _delete(selectedSongs, bytes: selectedBytes),
              text: 'Delete',
              icon: Icons.delete_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
