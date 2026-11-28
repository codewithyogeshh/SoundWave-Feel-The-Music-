import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart' as oaq;
import 'package:soundwave/features/permissions/services/permission_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';

enum SongSortCriteria { title, artist, duration, dateAdded }

class LocalAudioScanner {
  final oaq.OnAudioQuery _audioQuery = oaq.OnAudioQuery();

  Future<List<SongModel>> scanLocalAudio({
    SongSortCriteria sortCriteria = SongSortCriteria.title,
  }) async {
    final results = <SongModel>[];
    final seenPaths = <String>{};

    try {
      final hasPermission = await PermissionService.requestAudioPermission();
      if (!hasPermission) {
        debugPrint('Media permission not granted for local scanning.');
      }

      // Also trigger on_audio_query internal permission handshake
      try {
        await _audioQuery.checkAndRequest(retryRequest: true);
      } catch (e) {
        debugPrint('OnAudioQuery checkAndRequest note: $e');
      }

      oaq.SongSortType sortType = oaq.SongSortType.TITLE;
      switch (sortCriteria) {
        case SongSortCriteria.title:
          sortType = oaq.SongSortType.TITLE;
          break;
        case SongSortCriteria.artist:
          sortType = oaq.SongSortType.ARTIST;
          break;
        case SongSortCriteria.duration:
          sortType = oaq.SongSortType.DURATION;
          break;
        case SongSortCriteria.dateAdded:
          sortType = oaq.SongSortType.DATE_ADDED;
          break;
      }

      // 1. Query external media store
      try {
        final songs = await _audioQuery.querySongs(
          sortType: sortType,
          orderType: oaq.OrderType.ASC_OR_SMALLER,
          uriType: oaq.UriType.EXTERNAL,
          ignoreCase: true,
        );

        for (final s in songs) {
          final path = s.data.trim();
          if (path.isEmpty || seenPaths.contains(path)) continue;
          // Songs SoundWave downloaded to phone storage already appear in the
          // Downloads tab; listing them as device music too would duplicate.
          if (path.contains('/Music/SoundWave/')) continue;

          final rawTitle = s.title.trim();
          final displayTitle = rawTitle.isNotEmpty ? rawTitle : 'Track ${s.id}';
          final rawArtist = s.artist?.trim();
          final displayArtist = (rawArtist != null && rawArtist != '<unknown>' && rawArtist.isNotEmpty)
              ? rawArtist
              : 'Unknown Artist';
          final rawAlbum = s.album?.trim();
          final displayAlbum = (rawAlbum != null && rawAlbum != '<unknown>' && rawAlbum.isNotEmpty)
              ? rawAlbum
              : 'Downloaded Music';

          // Duration fallback
          final ms = s.duration ?? 0;
          final duration = ms > 0 ? Duration(milliseconds: ms) : const Duration(minutes: 3, seconds: 20);

          DateTime? dateAdded;
          if (s.dateAdded != null && s.dateAdded! > 0) {
            dateAdded = DateTime.fromMillisecondsSinceEpoch(s.dateAdded! * 1000);
          }

          seenPaths.add(path);
          results.add(
            SongModel(
              id: 'local_${s.id}',
              title: displayTitle,
              artist: displayArtist,
              album: displayAlbum,
              duration: duration,
              audioPath: path,
              sourceType: AudioSourceType.file,
              albumId: s.albumId,
              rawId: s.id,
              dateAdded: dateAdded,
              fileSize: s.size,
              isLocal: true,
              genre: s.genre ?? 'Downloaded',
              isHd: true,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error querying MediaStore songs: $e');
      }

      // 2. Direct Storage Directory Fallback & Deep Scan for Downloaded Music
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final directoriesToScan = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Music',
          '/sdcard/Download',
          '/sdcard/Music',
          '/storage/emulated/0/Audio',
          '/storage/emulated/0/snaptube/download',
        ];

        final supportedExts = {'.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.opus'};

        for (final dirPath in directoriesToScan) {
          try {
            final dir = Directory(dirPath);
            if (await dir.exists()) {
              final entities = dir.listSync(recursive: true, followLinks: false);
              for (final entity in entities) {
                if (entity is File) {
                  final filePath = entity.path;
                  final lower = filePath.toLowerCase();
                  final isAudio = supportedExts.any((ext) => lower.endsWith(ext));
                  if (!isAudio) continue;

                  if (seenPaths.contains(filePath)) continue;

                  // Extract filename as title
                  final rawName = filePath.split(Platform.pathSeparator).last;
                  final dotIndex = rawName.lastIndexOf('.');
                  final nameWithoutExt = dotIndex > 0 ? rawName.substring(0, dotIndex) : rawName;
                  final cleanTitle = nameWithoutExt
                      .replaceAll('_', ' ')
                      .replaceAll('-', ' ')
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim();

                  DateTime? dateAdded;
                  int? fileSize;
                  try {
                    dateAdded = entity.lastModifiedSync();
                    fileSize = entity.lengthSync();
                  } catch (_) {}

                  seenPaths.add(filePath);
                  results.add(
                    SongModel(
                      id: 'local_file_${filePath.hashCode.abs()}',
                      title: cleanTitle.isNotEmpty ? cleanTitle : 'Downloaded Song',
                      artist: 'Device Storage',
                      album: 'Downloads',
                      duration: const Duration(minutes: 3, seconds: 30),
                      audioPath: filePath,
                      sourceType: AudioSourceType.file,
                      dateAdded: dateAdded,
                      fileSize: fileSize,
                      isLocal: true,
                      genre: 'Downloaded',
                      isHd: true,
                    ),
                  );

                  // Inform MediaScanner in background
                  try {
                    _audioQuery.scanMedia(filePath);
                  } catch (_) {}
                }
              }
            }
          } catch (e) {
            debugPrint('Note scanning dir $dirPath: $e');
          }
        }
      }

      // Sort results
      switch (sortCriteria) {
        case SongSortCriteria.title:
          results.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
        case SongSortCriteria.artist:
          results.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
          break;
        case SongSortCriteria.duration:
          results.sort((a, b) => b.duration.compareTo(a.duration));
          break;
        case SongSortCriteria.dateAdded:
          break;
      }

      return results;
    } catch (e) {
      debugPrint('Error scanning local audio: $e');
      return results;
    }
  }
}

