import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/app/widgets/bottom_navigation_bar.dart';
import 'package:soundwave/core/widgets/app_background.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/features/explore/presentation/explore_screen.dart';
import 'package:soundwave/features/home/presentation/home_screen.dart';
import 'package:soundwave/features/library/presentation/library_screen.dart';
import 'package:soundwave/features/permissions/services/permission_service.dart';
import 'package:soundwave/features/player/presentation/mini_player.dart';
import 'package:soundwave/features/profile/presentation/profile_screen.dart';
import 'package:soundwave/features/search/presentation/search_screen.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  /// Plays a short fade-through over the tab stack on every tab change. The
  /// stack itself stays mounted, so scroll positions and player state survive.
  late final AnimationController _tabTransition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowFirstTimePermissionDialog();
    });
  }

  Future<void> _checkAndShowFirstTimePermissionDialog() async {
    final storage = ref.read(storageServiceProvider);
    final hasPrompted = storage.hasPromptedAudioPermission();

    // Show popup strictly only once on first install
    if (!hasPrompted) {
      final isGranted = await PermissionService.isAudioPermissionGranted();
      if (!isGranted) {
        if (!mounted) return;
        _showPermissionSheet();
      } else {
        await storage.setPromptedAudioPermission(true);
      }
    }
  }

  void _showPermissionSheet() {
    final activeTheme = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: activeTheme.secondaryBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: activeTheme.primaryAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Music Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: activeTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: activeTheme.primaryAccent.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.audio_file_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'Add Your Phone Music',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'SoundWave needs audio permission to scan and play all downloaded songs stored on your device.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // Highlights Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildPermissionFeature(
                        Icons.folder_open_rounded,
                        'Scans Download and Music folders automatically',
                      ),
                      const SizedBox(height: 10),
                      _buildPermissionFeature(
                        Icons.offline_pin_rounded,
                        '100% offline playback with high-fidelity sound',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Action Button
                GradientButton.pill(
                  width: double.infinity,
                  height: 50,
                  gradient: AppColors.accentGradient,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final storage = ref.read(storageServiceProvider);
                    await storage.setPromptedAudioPermission(true);

                    final granted = await PermissionService.requestAudioPermission();
                    if (granted) {
                      await ref.read(libraryProvider.notifier).scanLocalMusic();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.secondaryBackground,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            content: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: AppColors.neonBlue, size: 20),
                                SizedBox(width: 10),
                                Text('Local songs synced to your library!'),
                              ],
                            ),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.secondaryBackground,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            content: const Text(
                              'Permission not granted. You can scan anytime from Library.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  text: 'Allow Permission & Add Songs',
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(height: 10),

                // Secondary Action Button
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final storage = ref.read(storageServiceProvider);
                    await storage.setPromptedAudioPermission(true);
                  },
                  child: Text(
                    'Maybe Later',
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPermissionFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neonBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabTransition.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      _tabTransition.forward(from: 0);
    }
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context, AppThemeType theme) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.primaryAccent.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: theme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryAccent.withValues(alpha: 0.4),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.power_settings_new_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Exit SoundWave?',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to exit the app?\nYour music playback will stop.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text(
                          'Keep Listening',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: theme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryAccent.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Exit App',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final playerState = ref.watch(playerProvider);
    final hasActiveSong = playerState.currentSong != null;

    final screens = [
      HomeScreen(
        onNavigateToExplore: () => _onTabSelected(1),
        onNavigateToLibrary: () => _onTabSelected(2),
        onNavigateToSearch: () => _onTabSelected(3),
        onNavigateToProfile: () => _onTabSelected(4),
      ),
      ExploreScreen(
        onSearchTap: () => _onTabSelected(3),
        onSeeAllPlaylists: () => _onTabSelected(2),
      ),
      const LibraryScreen(),
      const SearchScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final shouldExit = await _showExitConfirmationDialog(context, activeTheme);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: AppBackground(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _tabTransition,
              curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.014),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _tabTransition,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Persistent Mini Player above the bottom bar
              if (hasActiveSong) const MiniPlayer(),
              // Floating Bottom Navigation Bar
              FloatingBottomNavBar(
                currentIndex: _currentIndex,
                onTabSelected: _onTabSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

