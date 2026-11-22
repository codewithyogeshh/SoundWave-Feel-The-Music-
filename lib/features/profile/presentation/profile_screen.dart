import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/developer_spotlight_card.dart';
import 'package:soundwave/core/widgets/glass_card.dart';
import 'package:soundwave/core/widgets/song_track_tile.dart';
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _customUsername;
  String _audioQuality = 'HD Lossless (320 kbps)';
  bool _gapless = true;
  bool _normalize = true;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final storage = ref.read(storageServiceProvider);
      final profile = storage.getUserProfile();
      _audioQuality = (profile['audioQuality'] as String?) ?? 'HD Lossless (320 kbps)';
      _gapless = (profile['gaplessPlayback'] as bool?) ?? true;
      _normalize = (profile['normalizeVolume'] as bool?) ?? true;
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final storage = ref.watch(storageServiceProvider);
    final currentTheme = ref.watch(themeProvider);
    final profile = storage.getUserProfile();
    final username = _customUsername ?? (profile['username'] as String? ?? 'Yogesh Chavan');
    final totalPlayed = storage.getTotalSongsPlayed();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 175),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile & Settings', style: AppTextStyles.screenTitle),
              const SizedBox(height: 18),

              // Developer Spotlight Card (Front and Center)
              const DeveloperSpotlightCard(),
              const SizedBox(height: 18),

              // User Profile Card
              GlassCard(
                borderRadius: 24,
                blur: 0,
                padding: const EdgeInsets.all(18),
                color: currentTheme.secondaryBackground.withValues(alpha: 0.86),
                borderColor: currentTheme.primaryAccent.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: currentTheme.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: currentTheme.highlightColor,
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showEditNameDialog(context, storage, profile, username),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: currentTheme.primaryAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _showEditNameDialog(context, storage, profile, username),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    username,
                                    style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SoundWave VIP Music Engine',
                            style: AppTextStyles.artistName.copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: currentTheme.accentGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Offline Music Player Active',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Listening Stats Section
              Text('Listening Statistics', style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.play_circle_fill_rounded,
                      value: '$totalPlayed',
                      label: 'Tracks Played',
                      gradient: currentTheme.primaryGradient,
                      onTap: () => _showSongListSheet(
                        context,
                        title: 'Recently Played Tracks',
                        icon: Icons.play_circle_fill_rounded,
                        songs: libState.recentlyPlayedSongs,
                        theme: currentTheme,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.favorite_rounded,
                      value: '${libState.favoriteIds.length}',
                      label: 'Favorites',
                      gradient: currentTheme.accentGradient,
                      onTap: () => _showSongListSheet(
                        context,
                        title: 'Favorite & Liked Songs',
                        icon: Icons.favorite_rounded,
                        songs: libState.favoriteSongs,
                        theme: currentTheme,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.library_music_rounded,
                      value: '${libState.allSongs.length}',
                      label: 'Offline Songs',
                      gradient: currentTheme.primaryGradient,
                      onTap: () => _showSongListSheet(
                        context,
                        title: 'Downloaded & Offline Songs',
                        icon: Icons.library_music_rounded,
                        songs: libState.allSongs,
                        theme: currentTheme,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.queue_music_rounded,
                      value: '${libState.playlists.length}',
                      label: 'Playlists',
                      gradient: currentTheme.accentGradient,
                      onTap: () => _showPlaylistsSheet(
                        context,
                        libState,
                        currentTheme,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // Theme Selector Section
              Text('App Theme & Appearance', style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'Select from 5 luxury neon and OLED themes',
                style: AppTextStyles.subtitle.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: AppThemeType.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final theme = AppThemeType.values[index];
                    final isSelected = theme == currentTheme;

                    return GestureDetector(
                      onTap: () {
                        ref.read(themeProvider.notifier).setTheme(theme);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to ${theme.label} theme'),
                            duration: const Duration(seconds: 1),
                            backgroundColor: theme.secondaryBackground,
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 160,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? theme.highlightColor : AppColors.glassBorderSubtle,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: theme.primaryAccent.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    theme.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.check_circle_rounded, color: theme.highlightColor, size: 16),
                                ],
                              ],
                            ),
                            // Swatch Dots
                            Row(
                              children: theme.swatches.map((c) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 0.8),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 26),

              // Audio & Playback Settings
              Text('Audio & Playback Engine', style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.high_quality_rounded,
                title: 'Audio Output Quality',
                subtitle: _audioQuality,
                iconColor: currentTheme.primaryAccent,
                onTap: () => _showQualityPicker(context, storage, profile),
              ),
              const SizedBox(height: 10),

              _buildSettingsTile(
                icon: Icons.equalizer_rounded,
                title: 'Audio Equalizer Studio',
                subtitle: '5-band frequency console, curve & bass boost',
                iconColor: currentTheme.secondaryAccent,
                onTap: () => context.push('/equalizer'),
              ),
              const SizedBox(height: 10),

              // Gapless Toggle
              _buildSwitchTile(
                icon: Icons.all_inclusive_rounded,
                title: 'Gapless Playback',
                subtitle: 'Zero delay between queued tracks',
                iconColor: currentTheme.primaryAccent,
                value: _gapless,
                onChanged: (val) {
                  setState(() => _gapless = val);
                  final updated = Map<String, dynamic>.from(profile);
                  updated['gaplessPlayback'] = val;
                  storage.saveUserProfile(updated);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'Gapless playback enabled' : 'Gapless playback disabled'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Volume Normalization Toggle
              _buildSwitchTile(
                icon: Icons.volume_up_rounded,
                title: 'Volume Normalization',
                subtitle: 'Equalize volume levels across different albums',
                iconColor: currentTheme.highlightColor,
                value: _normalize,
                onChanged: (val) {
                  setState(() => _normalize = val);
                  final updated = Map<String, dynamic>.from(profile);
                  updated['normalizeVolume'] = val;
                  storage.saveUserProfile(updated);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'Volume normalization enabled' : 'Volume normalization disabled'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 26),

              // Storage & Scanning
              Text('Storage & Maintenance', style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.refresh_rounded,
                title: 'Rescan Device Audio',
                subtitle: 'Detect newly downloaded songs and update metadata',
                iconColor: currentTheme.primaryAccent,
                onTap: () {
                  ref.read(libraryProvider.notifier).scanLocalMusic();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scanning device storage for music...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildSettingsTile(
                icon: Icons.cleaning_services_rounded,
                title: 'Clear Cache & Temp Artwork',
                subtitle: 'Free memory and refresh decoded album art',
                iconColor: currentTheme.highlightColor,
                onTap: () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Memory and artwork cache cleared successfully!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              const SizedBox(height: 26),

              // About & Legal
              Text('About SoundWave', style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About App & Version',
                subtitle: 'SoundWave v1.2.0 • Designed by Yogesh Chavan',
                iconColor: currentTheme.secondaryAccent,
                onTap: () => _showAboutDialog(context),
              ),
              const SizedBox(height: 10),

              _buildSettingsTile(
                icon: Icons.security_rounded,
                title: 'Privacy & Storage Policy',
                subtitle: '100% offline-first • Zero tracking policy',
                iconColor: currentTheme.primaryAccent,
                onTap: () => _showPrivacyDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Gradient gradient,
    VoidCallback? onTap,
  }) {
    return GlassCard(
      borderRadius: 18,
      blur: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      color: AppColors.glassWhiteMedium,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                ),
                Text(
                  label,
                  style: AppTextStyles.timeLabel.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
        ],
      ),
    );
  }

  void _showSongListSheet(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<SongModel> songs,
    required AppThemeType theme,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: theme.primaryAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: theme.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
                                Text(
                                  '${songs.length} tracks available',
                                  style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (songs.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              ref.read(playerProvider.notifier).playTrack(songs.first, queue: songs);
                              Navigator.of(ctx).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: theme.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Play All',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white10),
                  Expanded(
                    child: songs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 48, color: Colors.white24),
                                const SizedBox(height: 12),
                                Text(
                                  'No songs in this list yet',
                                  style: AppTextStyles.subtitle.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              return SongTrackTile(
                                song: song,
                                playlist: songs,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPlaylistsSheet(
    BuildContext context,
    LibraryState libState,
    AppThemeType theme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: theme.primaryAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: theme.accentGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Playlists', style: AppTextStyles.cardTitle.copyWith(fontSize: 16)),
                        Text(
                          '${libState.playlists.length} playlists created',
                          style: AppTextStyles.subtitle.copyWith(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white10),
              Expanded(
                child: libState.playlists.isEmpty
                    ? Center(
                        child: Text(
                          'No playlists created yet',
                          style: AppTextStyles.subtitle.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: libState.playlists.length,
                        itemBuilder: (context, index) {
                          final pl = libState.playlists[index];
                          return GlassCard(
                            borderRadius: 16,
                            blur: 0,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            color: AppColors.glassWhiteMedium,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              context.push('/playlist/${pl.id}');
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: theme.primaryGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pl.name, style: AppTextStyles.songTitle.copyWith(fontSize: 15)),
                                      Text(
                                        '${pl.songCount} songs',
                                        style: AppTextStyles.subtitle.copyWith(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.neonBlue,
  }) {
    return GlassCard(
      borderRadius: 18,
      blur: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: AppColors.glassWhiteMedium,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassWhiteMedium,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorderSubtle),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.songTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.subtitle.copyWith(fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = AppColors.purple,
  }) {
    final activeTheme = ref.watch(themeProvider);
    return GlassCard(
      borderRadius: 18,
      blur: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.glassWhiteMedium,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassWhiteMedium,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorderSubtle),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.songTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.subtitle.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeTheme.highlightColor,
            activeTrackColor: activeTheme.secondaryAccent.withValues(alpha: 0.45),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showQualityPicker(
    BuildContext context,
    LibraryStorageService storage,
    Map<String, dynamic> profile,
  ) {
    final options = [
      'Standard (128 kbps MP3)',
      'High Quality (256 kbps AAC)',
      'HD Lossless (320 kbps)',
      'Ultra Hi-Res (24-bit / 96kHz FLAC)',
    ];

    final activeTheme = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: activeTheme.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Audio Quality', style: AppTextStyles.cardTitle),
                const SizedBox(height: 12),
                ...options.map((opt) {
                  final isSelected = opt == _audioQuality;
                  return ListTile(
                    title: Text(
                      opt,
                      style: TextStyle(
                        color: isSelected ? activeTheme.primaryAccent : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: activeTheme.primaryAccent)
                        : null,
                    onTap: () {
                      setState(() => _audioQuality = opt);
                      final updated = Map<String, dynamic>.from(profile);
                      updated['audioQuality'] = opt;
                      storage.saveUserProfile(updated);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Audio quality updated to: $opt')),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final activeTheme = ref.read(themeProvider);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: activeTheme.secondaryBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: activeTheme.primaryAccent),
              const SizedBox(width: 8),
              Text('SoundWave', style: AppTextStyles.cardTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feel the music, live the moment.',
                style: AppTextStyles.subtitle.copyWith(color: activeTheme.primaryAccent),
              ),
              const SizedBox(height: 12),
              Text(
                'SoundWave v1.2.0 is an offline-first music player crafted with Flutter. Built by Yogesh Chavan (@codewithyogeshh).',
                style: AppTextStyles.subtitle,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    final activeTheme = ref.read(themeProvider);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: activeTheme.secondaryBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Privacy & Media Access', style: TextStyle(color: Colors.white)),
          content: Text(
            'SoundWave respects your privacy. Media permissions are requested only to read audio tracks on your device. Your local songs and personal playlists remain on your device and are never uploaded or tracked.',
            style: AppTextStyles.subtitle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Understood', style: TextStyle(color: activeTheme.primaryAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    LibraryStorageService storage,
    Map<String, dynamic> profile,
    String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    final activeTheme = ref.read(themeProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: activeTheme.secondaryBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Edit Profile Name', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: activeTheme.primaryAccent),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: activeTheme.highlightColor, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  setState(() {
                    _customUsername = trimmed;
                  });
                  final updated = Map<String, dynamic>.from(profile);
                  updated['username'] = trimmed;
                  storage.saveUserProfile(updated);
                }
                Navigator.pop(ctx);
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: activeTheme.primaryAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }
}
