import 'package:flutter/material.dart';
import 'package:soundwave/core/widgets/song_track_tile.dart';
import 'package:soundwave/features/player/models/song_model.dart';

class RecommendedTrackTile extends StatelessWidget {
  final SongModel song;
  final List<SongModel> playlist;

  const RecommendedTrackTile({
    super.key,
    required this.song,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    return SongTrackTile(
      song: song,
      playlist: playlist,
    );
  }
}
