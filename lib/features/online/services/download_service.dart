import 'dart:io';
import 'package:flutter/foundation.dart';
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

      // 2. Request permissions if downloading to Phone Storage
      if (destination == DownloadDestination.phoneStorage && Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          // Check audio permission for Android 13+
          final audioStatus = await Permission.audio.request();
          if (audioStatus.isDenied) {
            debugPrint('Storage permission denied, falling back or attempting public path');
          }
        }
      }

      // 3. Determine target directory and file name
      Directory? targetDir;
      String fileName;
      final cleanTitle = _sanitizeFileName(sourceSong.title);
      final cleanArtist = _sanitizeFileName(sourceSong.artist);
      final cleanId = sanitizeIdForFile(sourceSong.id);

      if (destination == DownloadDestination.inApp) {
        targetDir = await getInAppDirectory();
        fileName = '${cleanId}_320k.m4a';
      } else {
        targetDir = await getPublicStorageDirectory();
        targetDir ??= await getInAppDirectory();
        fileName = '$cleanTitle - $cleanArtist.mp3';
      }

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

      // 6. Build offline SongModel pointing to local audio & local banner file
      final downloadedSong = sourceSong.copyWith(
        id: sourceSong.id,
        audioPath: targetFile.path,
        sourceType: AudioSourceType.file,
        artworkPath: localArtPath ?? sourceSong.artworkPath,
        isLocal: true,
        fileSize: receivedBytes,
      );

      return DownloadResult(
        success: true,
        savedPath: targetFile.path,
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
      if (song.audioPath.isNotEmpty && File(song.audioPath).existsSync()) {
        await File(song.audioPath).delete();
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

  /// Sanitize filename by stripping illegal characters
  static String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll('&', 'and')
        .trim();
  }
}

