import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/features/online/services/download_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';

class DownloadState {
  final Map<String, double> progressMap; // songId -> progress (0.0 to 1.0)
  final Set<String> activeDownloads; // songIds currently downloading
  final String? lastError;

  const DownloadState({
    this.progressMap = const {},
    this.activeDownloads = const {},
    this.lastError,
  });

  bool isDownloading(String songId) => activeDownloads.contains(songId);

  double getProgress(String songId) => progressMap[songId] ?? 0.0;

  DownloadState copyWith({
    Map<String, double>? progressMap,
    Set<String>? activeDownloads,
    String? lastError,
  }) {
    return DownloadState(
      progressMap: progressMap ?? this.progressMap,
      activeDownloads: activeDownloads ?? this.activeDownloads,
      lastError: lastError,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() {
    return const DownloadState();
  }

  Future<DownloadResult> downloadSong(
    SongModel song, {
    DownloadDestination destination = DownloadDestination.inApp,
  }) async {
    final songId = song.id;

    // Mark as downloading
    final active = Set<String>.from(state.activeDownloads)..add(songId);
    final progress = Map<String, double>.from(state.progressMap)..[songId] = 0.05;
    state = state.copyWith(activeDownloads: active, progressMap: progress, lastError: null);

    final result = await DownloadService.downloadSong(
      song,
      destination: destination,
      onProgress: (p) {
        final updatedProgress = Map<String, double>.from(state.progressMap)..[songId] = p;
        state = state.copyWith(progressMap: updatedProgress);
      },
    );

    // Remove from active downloads
    final updatedActive = Set<String>.from(state.activeDownloads)..remove(songId);
    final finalProgress = Map<String, double>.from(state.progressMap);
    if (result.success) {
      finalProgress[songId] = 1.0;
      if (result.downloadedSong != null) {
        // Save to library state & storage
        await ref.read(libraryProvider.notifier).addDownloadedSong(result.downloadedSong!);
      }
    } else {
      finalProgress.remove(songId);
    }

    state = state.copyWith(
      activeDownloads: updatedActive,
      progressMap: finalProgress,
      lastError: result.error,
    );

    return result;
  }

  Future<void> removeDownload(SongModel song) async {
    await DownloadService.deleteDownload(song);
    await ref.read(libraryProvider.notifier).removeDownloadedSong(song.id);
    final finalProgress = Map<String, double>.from(state.progressMap)..remove(song.id);
    state = state.copyWith(progressMap: finalProgress);
  }
}

final downloadProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);

