import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:soundwave/features/online/services/online_music_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';

enum DownloadDestination {
  inApp,
  phoneStorage,
}

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class DownloadResult {
  final bool success;
  final String? savedPath;
  final String? error;
  final SongModel? downloadedSong;

  const DownloadResult({
    required this.success,
    this.savedPath,
    this.error,
    this.downloadedSong,
  });
}

class DownloadService {
  static const String inAppSubdir = 'soundwave_downloads';
  static const Map<String, String> _downloadHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  /// Upgrade thumbnail artwork URLs (50x50 / 150x150) to crisp 500x500 banners.
  static String normalizeArtworkUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.contains('150x150')) {
      return trimmed.replaceAll('150x150', '500x500');
    }
    if (trimmed.contains('50x50')) {
      return trimmed.replaceAll('50x50', '500x500');
    }
    return trimmed;
  }

  /// Sanitize a song ID for safe local filenames.
  static String sanitizeIdForFile(String id) {
    return id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Build the deterministic local banner file path inside in-app offline storage.
  static Future<File> getArtworkFileForId(String songId) async {
    final inAppDir = await getInAppDirectory();
    return File('${inAppDir.path}/${sanitizeIdForFile(songId)}_art.jpg');
  }

  /// Ensure a cover banner image exists locally for offline display & notifications.
  /// Returns the local file path if already on disk or successfully fetched.
  static Future<String?> ensureLocalArtworkForSong(
    SongModel song, {
    http.Client? client,
  }) async {
    try {
      final existingArtPath = song.artworkPath?.trim();
      if (existingArtPath != null &&
          existingArtPath.isNotEmpty &&
          !existingArtPath.startsWith('http') &&
          !existingArtPath.startsWith('assets/')) {
        final normalizedPath = existingArtPath.startsWith('file://')
            ? (Uri.tryParse(existingArtPath)?.toFilePath() ??
                existingArtPath.substring(7))
            : existingArtPath;
        final existingFile = File(normalizedPath);
        if (await existingFile.exists() && await existingFile.length() > 0) {
          return existingFile.path;
        }
      }

      final artFile = await getArtworkFileForId(song.id);
      if (await artFile.exists() && await artFile.length() > 0) {
        return artFile.path;
      }

      String? remoteUrl =
          (existingArtPath != null && existingArtPath.startsWith('http'))
              ? existingArtPath
              : null;

      // Backfill remote banner URL for online tracks missing an artwork URL.
      if ((remoteUrl == null || remoteUrl.isEmpty) &&
          song.id.startsWith('online_')) {
        final resolved = await OnlineMusicService.resolveFullTrack(song);
        if (resolved?.artworkPath != null &&
            resolved!.artworkPath!.startsWith('http')) {
          remoteUrl = resolved.artworkPath;
        }
      }

      if (remoteUrl == null || !remoteUrl.startsWith('http')) {
        return null;
      }

      final normalizedUrl = normalizeArtworkUrl(remoteUrl);
      final ownClient = client == null;
      final httpClient = client ?? http.Client();
      try {
        final artRes = await httpClient
            .get(Uri.parse(normalizedUrl), headers: _downloadHeaders)
            .timeout(const Duration(seconds: 12));
        if (artRes.statusCode == 200 && artRes.bodyBytes.isNotEmpty) {
          await artFile.writeAsBytes(artRes.bodyBytes, flush: true);
          return artFile.path;
        }
      } finally {
        if (ownClient) {
          httpClient.close();
        }
      }
    } catch (e) {
      debugPrint('Artwork download skipped/failed for ${song.id}: $e');
    }
    return null;
  }

  /// Get or create the In-App offline storage directory
  static Future<Directory> getInAppDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${docDir.path}/$inAppSubdir');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// Get or create the Public Phone Storage directory (/Music/SoundWave or /Download/SoundWave)
  static Future<Directory?> getPublicStorageDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Try standard Android Music directory
        final musicDir = Directory('/storage/emulated/0/Music/SoundWave');
        if (await musicDir.exists()) return musicDir;
        try {
          await musicDir.create(recursive: true);
          return musicDir;
        } catch (_) {}

        // Fallback to Download directory
        final downloadDir = Directory('/storage/emulated/0/Download/SoundWave');
        if (await downloadDir.exists()) return downloadDir;
        try {
          await downloadDir.create(recursive: true);
          return downloadDir;
        } catch (_) {}

        // Fallback to external storage
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final target = Directory('${extDir.path}/SoundWave');
          if (!await target.exists()) {
            await target.create(recursive: true);
          }
          return target;
        }
      }
    } catch (e) {
      debugPrint('Error getting public storage dir: $e');
    }
    return null;
  }

  /// Bridge to Android's MediaStore, which owns the shared Music folder.
  static const MethodChannel _mediaChannel = MethodChannel(
    'soundwave/media_store',
  );

  /// File extension that matches the audio the CDN actually serves.
  static String _audioExtension(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp3')) return 'mp3';
    return 'm4a';
  }

  static Future<Map<Object?, Object?>?> _callSaveToMusic(
    File file,
    String displayName,
    String mime,
  ) {
    return _mediaChannel.invokeMethod<Map<Object?, Object?>>('saveToMusic', {
      'path': file.path,
      'name': displayName,
      'mime': mime,
    });
  }

  /// Adds [file] to the phone's shared Music/SoundWave folder without asking
  /// for "All files access": Android 10+ lets the app hand the song to
  /// MediaStore, which is how the folder is meant to be written nowadays.
  ///
  /// Returns the location SoundWave should use to play it back later — a
  /// MediaStore URI on Android 10+, a plain file path on older releases.
  static Future<String?> _importToMusic(
    File file, {
    required String displayName,
    required String mime,
  }) async {
    if (!Platform.isAndroid) return file.path;
    try {
      Map<Object?, Object?>? saved;
      try {
        saved = await _callSaveToMusic(file, displayName, mime);
      } on PlatformException catch (error) {
        // Android 9 and older still need the classic storage permission.
        if (error.code != 'permission_denied') rethrow;
        final granted = (await Permission.storage.request()).isGranted;
        if (!granted) return null;
        saved = await _callSaveToMusic(file, displayName, mime);
      }
      final uri = saved?['uri'] as String?;
      if (uri != null && uri.isNotEmpty) return uri;
      final path = saved?['path'] as String?;
      if (path != null && path.isNotEmpty) return path;
      return null;
    } catch (error) {
      debugPrint('Saving to Music/SoundWave failed: $error');
      return null;
    }
  }

  /// Download an online track (plus its cover banner) to In-App or Public storage
  static Future<DownloadResult> downloadSong(
    SongModel song, {
    required DownloadDestination destination,
    void Function(double progress)? onProgress,
  }) async {
    File? targetFile;
    final client = http.Client();
    try {
      // 1. Resolve full 320kbps CDN stream URL and high-res artwork metadata
      SongModel sourceSong = song;
      String streamUrl = song.audioPath;
      final needsTrackResolve =
          streamUrl.isEmpty ||
          streamUrl.contains('jiotunepreview.jio.com') ||
          song.artworkPath == null ||
          song.artworkPath!.isEmpty;

      if (needsTrackResolve && song.id.startsWith('online_')) {
        final resolvedTrack = await OnlineMusicService.resolveFullTrack(song);
        if (resolvedTrack != null) {
          sourceSong = song.copyWith(
            title: resolvedTrack.title.isNotEmpty ? resolvedTrack.title : song.title,
            artist: resolvedTrack.artist.isNotEmpty ? resolvedTrack.artist : song.artist,
            album: resolvedTrack.album.isNotEmpty ? resolvedTrack.album : song.album,
            duration: resolvedTrack.duration.inSeconds > 0
                ? resolvedTrack.duration
                : song.duration,
            artworkPath: (resolvedTrack.artworkPath != null &&
                    resolvedTrack.artworkPath!.isNotEmpty)
                ? resolvedTrack.artworkPath
                : song.artworkPath,
          );
          if (resolvedTrack.audioPath.isNotEmpty &&
              (streamUrl.isEmpty || streamUrl.contains('jiotunepreview.jio.com'))) {
            streamUrl = resolvedTrack.audioPath;
          }
        } else if (streamUrl.isEmpty || streamUrl.contains('jiotunepreview.jio.com')) {
          final resolved = await OnlineMusicService.resolveStreamUrl(song.id);
          if (resolved != null && resolved.isNotEmpty) {
            streamUrl = resolved;
          }
        }
      }

      if (streamUrl.isEmpty) {
        return const DownloadResult(
          success: false,
          error: 'Could not resolve full track stream URL',
        );
      }

      // 2. Decide where the finished song should end up.
      final bool toPhone = destination == DownloadDestination.phoneStorage;
      final cleanTitle = _sanitizeFileName(sourceSong.title);
      final cleanArtist = _sanitizeFileName(sourceSong.artist);
      final cleanId = sanitizeIdForFile(sourceSong.id);
      final safeTitle = cleanTitle.isEmpty ? cleanId : cleanTitle;
      final safeArtist = cleanArtist.isEmpty ? 'SoundWave' : cleanArtist;
      final String extension = _audioExtension(streamUrl);
      final String displayName = '$safeTitle - $safeArtist.$extension';
      final String mime = extension == 'mp3' ? 'audio/mpeg' : 'audio/mp4';

      // 3. Phone storage downloads are written to a temporary file first and
      // then handed to MediaStore, so the song shows up in Music/SoundWave
      // without the heavy "All files access" permission.
      final Directory targetDir = toPhone
          ? await getTemporaryDirectory()
          : await getInAppDirectory();
      final String fileName = toPhone
          ? 'sw_import_$cleanId.$extension'
          : '${cleanId}_320k.m4a';

      targetFile = File('${targetDir.path}/$fileName');

      // 4. Download audio with progress tracking (0.0 -> 0.90)
      final request = http.Request('GET', Uri.parse(streamUrl));
      request.headers.addAll(_downloadHeaders);
      final response = await client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return DownloadResult(
          success: false,
          error: 'Download server responded with status ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = targetFile.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (contentLength > 0 && onProgress != null) {
            final audioProgress = (receivedBytes / contentLength).clamp(0.0, 1.0);
            onProgress(audioProgress * 0.90);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (receivedBytes == 0) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        return const DownloadResult(
          success: false,
          error: 'Downloaded audio stream was empty',
        );
      }

      onProgress?.call(0.92);

      // 5. Download high-res cover banner alongside the song for offline UI & notifications
      final localArtPath = await ensureLocalArtworkForSong(
        sourceSong,
        client: client,
      );

      onProgress?.call(1.0);

      // 6. Hand phone-storage downloads to the shared Music folder.
      String savedPath = targetFile.path;
      if (toPhone) {
        final imported = await _importToMusic(
          targetFile,
          displayName: displayName,
          mime: mime,
        );
        if (imported == null) {
          return const DownloadResult(
            success: false,
            error: 'Could not add the song to Music/SoundWave',
          );
        }
        savedPath = imported;
        try {
          await targetFile.delete();
        } catch (_) {}
      }

      // 7. Build offline SongModel pointing to local audio & local banner file
      final downloadedSong = sourceSong.copyWith(
        id: sourceSong.id,
        audioPath: savedPath,
        sourceType: AudioSourceType.file,
        artworkPath: localArtPath ?? sourceSong.artworkPath,
        isLocal: true,
        fileSize: receivedBytes,
      );

      return DownloadResult(
        success: true,
        savedPath: savedPath,
        downloadedSong: downloadedSong,
      );
    } catch (e) {
      debugPrint('Download error: $e');
      if (targetFile != null && await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      return DownloadResult(
        success: false,
        error: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  /// Remove downloaded song file and its cached offline cover banner from storage
  static Future<bool> deleteDownload(SongModel song) async {
    try {
      final audioPath = song.audioPath.trim();
      if (audioPath.startsWith('content://')) {
        // Song lives in the shared Music folder; Android owns the file.
        try {
          await _mediaChannel.invokeMethod<bool>('deleteSaved', {
            'uri': audioPath,
          });
        } catch (e) {
          debugPrint('Could not remove the Music folder copy: $e');
        }
      } else if (audioPath.isNotEmpty && File(audioPath).existsSync()) {
        await File(audioPath).delete();
      }

      final artPath = song.artworkPath?.trim();
      if (artPath != null &&
          artPath.isNotEmpty &&
          !artPath.startsWith('http') &&
          !artPath.startsWith('assets/')) {
        final normalizedPath = artPath.startsWith('file://')
            ? (Uri.tryParse(artPath)?.toFilePath() ?? artPath.substring(7))
            : artPath;
        final artFile = File(normalizedPath);
        if (await artFile.exists()) {
          await artFile.delete();
        }
      }

      final defaultArtFile = await getArtworkFileForId(song.id);
      if (await defaultArtFile.exists()) {
        await defaultArtFile.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting download: $e');
      return false;
    }
  }

  /// Bytes one download occupies on the device: its audio file plus the
  /// cached cover banner. Falls back to the stored metadata size when the
  /// files cannot be read (e.g. downloads moved to public storage).
  static Future<int> downloadedBytes(SongModel song) async {
    if (kIsWeb) return song.fileSize ?? 0;
    final counted = <String>{};
    var total = 0;

    Future<void> addPath(String? path) async {
      if (path == null) return;
      final trimmed = path.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('http') ||
          trimmed.startsWith('assets/') ||
          trimmed.startsWith('asset://')) {
        return;
      }
      final normalized = trimmed.startsWith('file://')
          ? (Uri.tryParse(trimmed)?.toFilePath() ?? trimmed.substring(7))
          : trimmed;
      if (!counted.add(normalized)) return;
      try {
        final file = File(normalized);
        if (await file.exists()) total += await file.length();
      } catch (_) {}
    }

    await addPath(song.audioPath);
    await addPath(song.artworkPath);
    try {
      final artFile = await getArtworkFileForId(song.id);
      await addPath(artFile.path);
    } catch (_) {}

    if (total == 0 && song.fileSize != null) return song.fileSize!;
    return total;
  }

  /// Combined on-device size of [songs], for the Downloads storage summary.
  static Future<int> totalDownloadedBytes(Iterable<SongModel> songs) async {
    var total = 0;
    for (final song in songs) {
      total += await downloadedBytes(song);
    }
    return total;
  }

  /// Sanitize filename by stripping illegal characters
  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll('&', 'and')
        .trim();
  }
}

