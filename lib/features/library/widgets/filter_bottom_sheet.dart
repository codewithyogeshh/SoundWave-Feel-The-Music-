import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/app/theme/text_styles.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/widgets/gradient_button.dart';
import 'package:soundwave/core/widgets/premium_sheet.dart';
import 'package:soundwave/features/library/models/song_filter_state.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  final SongFilterState currentState;
  final List<SongModel> songs;

  const FilterBottomSheet({
    super.key,
    required this.currentState,
    required this.songs,
  });

  static Future<SongFilterState?> show(
    BuildContext context, {
    required SongFilterState currentState,
    required List<SongModel> songs,
  }) {
    return showModalBottomSheet<SongFilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        currentState: currentState,
        songs: songs,
      ),
    );
  }

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late SongFilterState _state;
  late List<String> _artists;
  late List<String> _albums;
  late List<String> _genres;

  @override
  void initState() {
    super.initState();
    _state = widget.currentState;
    _artists = SongFilterHelper.getUniqueArtists(widget.songs);
    _albums = SongFilterHelper.getUniqueAlbums(widget.songs);
    _genres = SongFilterHelper.getUniqueGenres(widget.songs);
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    return Container(
      decoration: premiumSheetDecoration(activeTheme, radius: 28),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.only(bottom: 18),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumSheetHandle(theme: activeTheme),

            // Header Row: Title & Reset Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PremiumSheetHeader(
                theme: activeTheme,
                icon: Icons.tune_rounded,
                title: 'Filter Tracks',
                subtitle: _state.hasActiveFilters
                    ? '${_state.activeFilterCount} filter'
                          '${_state.activeFilterCount == 1 ? '' : 's'} on'
                          ' • ${widget.songs.length} tracks'
                    : '${widget.songs.length} tracks in your library',
                trailing: _state.hasActiveFilters
                    ? PremiumSheetPill(
                        label: 'Reset',
                        icon: Icons.refresh_rounded,
                        color: activeTheme.highlightColor,
                        onTap: () {
                          setState(() {
                            _state = _state.reset();
                          });
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            _buildHairline(activeTheme),

            // Scrollable Filter Sections
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Quick Category / Unknown songs
                    _buildSectionHeader('Song Category & Source', Icons.category_outlined),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SongCategoryFilter.values.map((cat) {
                        final isSelected = _state.category == cat;
                        return _buildFilterChip(
                          label: cat.label,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _state = _state.copyWith(category: cat);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Duration Filter
                    _buildSectionHeader('Track Duration', Icons.timer_outlined),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: DurationFilter.values.map((d) {
                        final isSelected = _state.duration == d;
                        return _buildFilterChip(
                          label: d.label,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _state = _state.copyWith(duration: d);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: File Size Filter
                    _buildSectionHeader('Audio File Size', Icons.data_usage_rounded),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SongSizeFilter.values.map((sz) {
                        final isSelected = _state.size == sz;
                        return _buildFilterChip(
                          label: sz.label,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _state = _state.copyWith(size: sz);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 4: Singer / Artist Selector
                    if (_artists.isNotEmpty) ...[
                      _buildSectionHeader('Singer / Artist', Icons.person_outline_rounded),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _artists.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            if (idx == 0) {
                              final isSelected = _state.selectedArtist == null;
                              return _buildFilterChip(
                                label: 'All Singers',
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _state = _state.copyWith(clearArtist: true);
                                  });
                                },
                              );
                            }
                            final artist = _artists[idx - 1];
                            final isSelected = _state.selectedArtist == artist;
                            return _buildFilterChip(
                              label: artist,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _state = isSelected
                                      ? _state.copyWith(clearArtist: true)
                                      : _state.copyWith(selectedArtist: artist);
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section 5: Album Selector
                    if (_albums.isNotEmpty) ...[
                      _buildSectionHeader('Album', Icons.album_outlined),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _albums.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            if (idx == 0) {
                              final isSelected = _state.selectedAlbum == null;
                              return _buildFilterChip(
                                label: 'All Albums',
                                isSelected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _state = _state.copyWith(clearAlbum: true);
                                  });
                                },
                              );
                            }
                            final album = _albums[idx - 1];
                            final isSelected = _state.selectedAlbum == album;
                            return _buildFilterChip(
                              label: album,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _state = isSelected
                                      ? _state.copyWith(clearAlbum: true)
                                      : _state.copyWith(selectedAlbum: album);
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Section 6: Genre Selector
                    if (_genres.isNotEmpty) ...[
                      _buildSectionHeader('Genre', Icons.music_note_outlined),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            label: 'All Genres',
                            isSelected: _state.selectedGenre == null,
                            onTap: () {
                              setState(() {
                                _state = _state.copyWith(clearGenre: true);
                              });
                            },
                          ),
                          ..._genres.map((g) {
                            final isSelected = _state.selectedGenre == g;
                            return _buildFilterChip(
                              label: g,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _state = isSelected
                                      ? _state.copyWith(clearGenre: true)
                                      : _state.copyWith(selectedGenre: g);
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            _buildHairline(activeTheme),
            const SizedBox(height: 14),

            // Bottom Actions: Apply Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.glassWhite.withValues(
                          alpha: 0.05,
                        ),
                        side: BorderSide(
                          color: activeTheme.highlightColor.withValues(
                            alpha: 0.28,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context, const SongFilterState());
                      },
                      child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: GradientButton(
                      onPressed: () {
                        Navigator.pop(context, _state);
                      },
                      text: _state.hasActiveFilters
                          ? 'Apply Filters (${_state.activeFilterCount})'
                          : 'Show All Tracks',
                      icon: Icons.check_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHairline(AppThemeType activeTheme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            activeTheme.highlightColor.withValues(alpha: 0.45),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final activeTheme = ref.watch(themeProvider);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: activeTheme.primaryAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: activeTheme.highlightColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeTheme = ref.watch(themeProvider);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? activeTheme.primaryGradient : null,
          color: isSelected ? null : AppColors.glassWhiteMedium,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeTheme.highlightColor.withValues(alpha: 0.55)
                : AppColors.glassBorderSubtle,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeTheme.primaryAccent.withValues(alpha: 0.34),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? activeTheme.onPrimaryGradient
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
