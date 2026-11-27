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
import 'package:soundwave/features/profile/services/app_share_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/update/services/update_service.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/playback_prefs_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _customUsername;

  /// Version label taken from the build itself (`--dart-define=SOUNDWAVE_VERSION`),
  /// so the About screen shows the version that was actually shipped even when
  /// the release version is chosen automatically by the build workflow.
  String get _versionLabel {
    final version = UpdateService.installedVersion;
    return version == null ? '' : ' v$version';
  }

  @override
  Widget build(BuildContext context) {
    final libState = ref.watch(libraryProvider);
    final storage = ref.watch(storageServiceProvider);
    final currentTheme = ref.watch(themeProvider);
    final profile = storage.getUserProfile();
    final username = _customUsername ?? (profile['username'] as String? ?? 'Yogesh Chavan');
    final totalPlayed = storage.getTotalSongsPlayed();
    final batterySaver = ref.watch(batterySaverProvider);
    final pauseOnUnplug = ref.watch(pauseOnHeadphoneUnplugProvider);
    final pauseOnLowBattery = ref.watch(pauseOnLowBatteryProvider);
    final stopWhenClosed = ref.watch(stopWhenAppClosedProvider);
    final highQualityStreams = ref.watch(highQualityStreamProvider);
    final lyricsCacheCount = storage.getCachedLyricsCount();
    final lyricsCacheBytes = storage.getCachedLyricsBytes();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 175),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero header — big gradient title matching the player screens
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: currentTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: currentTheme.primaryAccent.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: currentTheme.onPrimaryGradient,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (rect) => currentTheme.primaryGradient.createShader(rect),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'Profile & Settings',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.screenTitle.copyWith(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your music, your rules',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: currentTheme.highlightColor.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Developer Spotlight Card (Front and Center)
              const DeveloperSpotlightCard(),
              const SizedBox(height: 18),

              // User Profile Card
              GlassCard(
                borderRadius: 26,
                blur: 0,
                padding: const EdgeInsets.all(18),
                color: currentTheme.secondaryBackground.withValues(alpha: 0.9),
                borderColor: currentTheme.highlightColor.withValues(alpha: 0.45),
                shadows: [
                  BoxShadow(
                    color: currentTheme.primaryAccent.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            gradient: currentTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: currentTheme.highlightColor.withValues(alpha: 0.5),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: currentTheme.primaryAccent.withValues(alpha: 0.35),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: currentTheme.secondaryBackground,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 38,
                                color: Colors.white,
                              ),
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
                                    style: AppTextStyles.cardTitle.copyWith(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
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
                            style: AppTextStyles.artistName.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: currentTheme.accentGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: currentTheme.highlightColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              'Offline Music Player Active',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: currentTheme.onAccentGradient,
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
              _sectionTitle(Icons.insights_rounded, 'Listening Statistics'),
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

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.timer_rounded,
                      value: _formatListeningTime(storage.getListenedSeconds()),
                      label: 'Listening Time',
                      gradient: currentTheme.accentGradient,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.star_rounded,
                      value: _topArtist(libState.recentlyPlayedSongs),
                      label: 'Top Artist',
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
                ],
              ),

              const SizedBox(height: 26),

              // Theme Selector Section
              _sectionTitle(Icons.palette_rounded, 'App Theme & Appearance'),
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
              _sectionTitle(Icons.graphic_eq_rounded, 'Audio & Playback Engine'),
              const SizedBox(height: 12),

              // Stream quality is real: JioSaavn's CDN serves the same track
              // as 320 kbps or 160 kbps AAC, and this switch picks which one
              // every newly resolved online track (stream or download) uses.
              _buildSwitchTile(
                icon: Icons.high_quality_rounded,
                title: 'High-Quality Streaming',
                subtitle: highQualityStreams
                    ? 'Stream and download at 320 kbps'
                    : 'Data saver: 160 kbps, uses less mobile data',
                iconColor: currentTheme.primaryAccent,
                value: highQualityStreams,
                onChanged: (val) {
                  ref.read(highQualityStreamProvider.notifier).setEnabled(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Streaming in 320 kbps'
                            : 'Data saver on — streaming in 160 kbps',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
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

              _buildSettingsTile(
                icon: Icons.lyrics_rounded,
                title: 'Offline Lyrics Cache',
                subtitle: lyricsCacheCount == 0
                    ? 'No saved lyrics yet'
                    : '$lyricsCacheCount '
                          '${lyricsCacheCount == 1 ? 'song' : 'songs'} • '
                          '${_formatBytes(lyricsCacheBytes)}',
                iconColor: currentTheme.highlightColor,
                onTap: () => _confirmClearLyrics(storage),
              ),
              const SizedBox(height: 10),

              _buildSettingsTile(
                icon: Icons.download_for_offline_rounded,
                title: 'Downloads & Storage',
                subtitle: 'Offline audio, storage used, batch delete',
                iconColor: currentTheme.secondaryAccent,
                onTap: () => context.push('/downloads'),
              ),
              const SizedBox(height: 10),

              const SizedBox(height: 26),

              // Battery & Device
              _sectionTitle(Icons.battery_charging_full_rounded, 'Battery & Device'),
              const SizedBox(height: 12),

              _buildSwitchTile(
                icon: Icons.battery_saver_rounded,
                title: 'Battery Saver Mode',
                subtitle: 'Turns off background glow and equalizer DSP to save battery',
                iconColor: currentTheme.primaryAccent,
                value: batterySaver,
                onChanged: (val) {
                  ref.read(batterySaverProvider.notifier).setEnabled(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'Battery saver on — glow and equalizer effects paused' : 'Battery saver off'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildSwitchTile(
                icon: Icons.headphones_rounded,
                title: 'Pause When Headphones Unplug',
                subtitle: 'Stops the music when your earphones or Bluetooth headset disconnect',
                iconColor: currentTheme.secondaryAccent,
                value: pauseOnUnplug,
                onChanged: (val) {
                  ref.read(pauseOnHeadphoneUnplugProvider.notifier).setEnabled(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'Music will pause when headphones disconnect' : 'Music will keep playing without headphones'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildSwitchTile(
                icon: Icons.battery_alert_rounded,
                title: 'Pause on Low Battery',
                subtitle: 'Stops the music at 15% battery when the phone is not charging',
                iconColor: currentTheme.highlightColor,
                value: pauseOnLowBattery,
                onChanged: (val) {
                  ref.read(pauseOnLowBatteryProvider.notifier).setEnabled(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'Music will pause at 15% battery' : 'Music will keep playing on low battery'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildSwitchTile(
                icon: Icons.layers_clear_rounded,
                title: 'Stop When App Is Closed',
                subtitle: 'Ends playback when you swipe SoundWave away from recent apps',
                iconColor: currentTheme.primaryAccent,
                value: stopWhenClosed,
                onChanged: (val) {
                  ref.read(stopWhenAppClosedProvider.notifier).setEnabled(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'Swiping the app away will stop the music' : 'Music keeps playing after the app is swiped away'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(height: 26),

              // Storage & Scanning
              _sectionTitle(Icons.storage_rounded, 'Storage & Maintenance'),
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
              _sectionTitle(Icons.info_rounded, 'About SoundWave'),
              const SizedBox(height: 12),

              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About App & Version',
                subtitle: 'SoundWave$_versionLabel • Designed by Yogesh Chavan',
                iconColor: currentTheme.secondaryAccent,
                onTap: () => _showAboutDialog(context),
              ),
              const SizedBox(height: 10),

              _buildSettingsTile(
                icon: Icons.share_rounded,
                title: 'Share SoundWave',
                subtitle: 'Sends the APK as SoundWave.apk, never base.apk',
                iconColor: currentTheme.primaryAccent,
                onTap: () => _shareApp(context),
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

  /// 42s → "42s", 12m → "12m", 3h 07m → "3h 7m".
  String _formatListeningTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// Artist that appears most often in the listening history.
  String _topArtist(List<SongModel> songs) {
    if (songs.isEmpty) return '—';
    final counts = <String, int>{};
    for (final song in songs) {
      final artist = song.artist.trim();
      if (artist.isEmpty) continue;
      counts[artist] = (counts[artist] ?? 0) + 1;
    }
    if (counts.isEmpty) return '—';
    return counts.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
  }

  /// Loud section heading: gradient bar, glowing icon and bold type.
  Widget _sectionTitle(IconData icon, String title) {
    final theme = ref.watch(themeProvider);
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: theme.accentGradient,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: theme.highlightColor.withValues(alpha: 0.55),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Icon(icon, size: 18, color: theme.highlightColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Gradient gradient,
    VoidCallback? onTap,
  }) {
    final accent = gradient.colors.first;
    return GlassCard(
      borderRadius: 20,
      blur: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      color: AppColors.glassWhiteMedium,
      borderColor: accent.withValues(alpha: 0.32),
      shadows: [
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppThemeType.readableOn(gradient.colors),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  label,
                  style: AppTextStyles.timeLabel.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: accent.withValues(alpha: 0.7),
              size: 12,
            ),
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
      borderRadius: 20,
      blur: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      color: AppColors.glassWhiteMedium,
      borderColor: iconColor.withValues(alpha: 0.3),
      shadows: [
        BoxShadow(
          color: iconColor.withValues(alpha: 0.16),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor, iconColor.withValues(alpha: 0.55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.42),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppThemeType.readableOn([iconColor]),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.songTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_right_rounded, color: iconColor, size: 18),
          ),
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
    final accent = value ? activeTheme.primaryAccent : iconColor;
    return GlassCard(
      borderRadius: 20,
      blur: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: AppColors.glassWhiteMedium,
      borderColor: accent.withValues(alpha: value ? 0.42 : 0.24),
      shadows: [
        BoxShadow(
          color: accent.withValues(alpha: value ? 0.22 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [iconColor, iconColor.withValues(alpha: 0.55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppThemeType.readableOn([iconColor]),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.songTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 11.5,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeTheme.highlightColor,
            activeTrackColor: activeTheme.primaryAccent.withValues(alpha: 0.6),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.7),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearLyrics(LibraryStorageService storage) async {
    final count = storage.getCachedLyricsCount();
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved lyrics to clear')),
      );
      return;
    }

    final activeTheme = ref.read(themeProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: activeTheme.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text('Clear offline lyrics?'),
        content: Text(
          'This removes $count saved '
          '${count == 1 ? 'song' : 'songs'} of lyrics from this device. '
          'They download again the next time you open a song online.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Clear',
              style: TextStyle(color: activeTheme.highlightColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await storage.clearCachedLyrics();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved lyrics cleared')),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      await AppShareService.share();
    } catch (error) {
      debugPrint('ProfileScreen: sharing the app failed: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not share the app on this device.')),
      );
    }
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
                'SoundWave$_versionLabel is an offline-first music player crafted with Flutter. Built by Yogesh Chavan (@codewithyogeshh).',
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
