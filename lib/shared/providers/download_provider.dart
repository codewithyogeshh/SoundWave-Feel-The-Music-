import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/features/online/services/download_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/playback_prefs_provider.dart';

class DownloadState {
  final Map<String, double> progressMap; // songId -> progress (0.0 to 1.0)
  final Set<String> activeDownloads; // songIds currently downloading
  final Map<String, SongModel> activeSongs; // songId -> song being downloaded
  final Map<String, String> failedDownloads; // songId -> error message
  final Map<String, SongModel> failedSongs; // songId -> song to retry
  final String? lastError;

  const DownloadState({
    this.progressMap = const {},
    this.activeDownloads = const {},
    this.activeSongs = const {},
    this.failedDownloads = const {},
    this.failedSongs = const {},
    this.lastError,
  });

  bool isDownloading(String songId) => activeDownloads.contains(songId);

  double getProgress(String songId) => progressMap[songId] ?? 0.0;

  /// Songs that finished with an error and can be retried.
  List<SongModel> get retryableSongs => failedSongs.values.toList();

  DownloadState copyWith({
    Map<String, double>? progressMap,
    Set<String>? activeDownloads,
    Map<String, SongModel>? activeSongs,
    Map<String, String>? failedDownloads,
    Map<String, SongModel>? failedSongs,
    String? lastError,
  }) {
    return DownloadState(
      progressMap: progressMap ?? this.progressMap,
      activeDownloads: activeDownloads ?? this.activeDownloads,
      activeSongs: activeSongs ?? this.activeSongs,
      failedDownloads: failedDownloads ?? this.failedDownloads,
      failedSongs: failedSongs ?? this.failedSongs,
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
    required DownloadDestination destination,
  }) async {
    final songId = song.id;

    // Mark as downloading and clear any previous failure for this track.
    final active = Set<String>.from(state.activeDownloads)..add(songId);
    final progress = Map<String, double>.from(state.progressMap)..[songId] = 0.05;
    final activeSongs = Map<String, SongModel>.from(state.activeSongs)
      ..[songId] = song;
    final failed = Map<String, String>.from(state.failedDownloads)
      ..remove(songId);
    final failedSongs = Map<String, SongModel>.from(state.failedSongs)
      ..remove(songId);

    state = state.copyWith(
      activeDownloads: active,
      progressMap: progress,
      activeSongs: activeSongs,
      failedDownloads: failed,
      failedSongs: failedSongs,
      lastError: null,
    );

    final result = await DownloadService.downloadSong(
      song,
      destination: destination,
      onProgress: (p) {
        final updatedProgress = Map<String, double>.from(state.progressMap)
          ..[songId] = p;
        state = state.copyWith(progressMap: updatedProgress);
      },
    );

    // Remove from active downloads
    final updatedActive = Set<String>.from(state.activeDownloads)..remove(songId);
    final remainingSongs = Map<String, SongModel>.from(state.activeSongs)
      ..remove(songId);
    final finalProgress = Map<String, double>.from(state.progressMap);

    Map<String, String> updatedFailed =
        Map<String, String>.from(state.failedDownloads);
    Map<String, SongModel> updatedFailedSongs =
        Map<String, SongModel>.from(state.failedSongs);

    if (result.success) {
      finalProgress[songId] = 1.0;
      if (result.downloadedSong != null) {
        // Save to library state & storage
        await ref
            .read(libraryProvider.notifier)
            .addDownloadedSong(result.downloadedSong!);
      }
    } else {
      finalProgress.remove(songId);
      updatedFailed[songId] = result.error ?? 'Download failed';
      updatedFailedSongs[songId] = song;
    }

    state = state.copyWith(
      activeDownloads: updatedActive,
      progressMap: finalProgress,
      activeSongs: remainingSongs,
      failedDownloads: updatedFailed,
      failedSongs: updatedFailedSongs,
      lastError: result.error,
    );

    return result;
  }

  /// Downloads [songs] one after another and returns how many succeeded.
  ///
  /// Sequential on purpose: parallel downloads on a phone connection mostly
  /// make every track slower and the progress bars jump around.
  Future<int> downloadMany(
    Iterable<SongModel> songs, {
    DownloadDestination? destination,
  }) async {
    final DownloadDestination target =
        destination ?? ref.read(downloadDestinationProvider);
    var succeeded = 0;
    for (final song in songs) {
      if (state.isDownloading(song.id)) continue;
      final result = await downloadSong(song, destination: target);
      if (result.success) succeeded++;
    }
    return succeeded;
  }

  Future<void> retry(SongModel song) async {
    await downloadSong(song, destination: ref.read(downloadDestinationProvider));
  }

  Future<void> retryAll() async {
    // Retries must land where the user chose, not always in app storage.
    final destination = ref.read(downloadDestinationProvider);
    for (final song in state.retryableSongs) {
      await downloadSong(song, destination: destination);
    }
  }

  Future<void> dismissFailure(String songId) async {
    final failed = Map<String, String>.from(state.failedDownloads)
      ..remove(songId);
    final failedSongs = Map<String, SongModel>.from(state.failedSongs)
      ..remove(songId);
    state = state.copyWith(failedDownloads: failed, failedSongs: failedSongs);
  }

  Future<void> removeDownload(SongModel song) async {
    await DownloadService.deleteDownload(song);
    await ref.read(libraryProvider.notifier).removeDownloadedSong(song.id);
    final finalProgress = Map<String, double>.from(state.progressMap)
      ..remove(song.id);
    final failed = Map<String, String>.from(state.failedDownloads)
      ..remove(song.id);
    final failedSongs = Map<String, SongModel>.from(state.failedSongs)
      ..remove(song.id);
    state = state.copyWith(
      progressMap: finalProgress,
      failedDownloads: failed,
      failedSongs: failedSongs,
    );
  }

  /// Removes several downloads in one pass, used by the batch action in the
  /// Downloads screen.
  Future<void> removeDownloads(Iterable<SongModel> songs) async {
    for (final song in songs) {
      await removeDownload(song);
    }
  }
}

final downloadProvider = NotifierProvider<DownloadNotifier, DownloadState>(
  DownloadNotifier.new,
);
