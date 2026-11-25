import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/player/models/lyrics_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/player/services/lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<LibraryStorageService> newStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryStorageService(prefs);
  }

  group('Offline lyrics cache', () {
    test('cached lyrics survive a fresh storage instance', () async {
      final storage = await newStorage();
      expect(storage.getCachedLyrics('online_1'), isNull);

      await storage.putCachedLyrics('online_1', '[00:01.00] Hello\n[00:02.00] World');
      expect(storage.getCachedLyricsCount(), 1);

      final reopened = await newStorage();
      expect(
        reopened.getCachedLyrics('online_1'),
        '[00:01.00] Hello\n[00:02.00] World',
      );

      await reopened.clearCachedLyrics();
      expect(reopened.getCachedLyrics('online_1'), isNull);
      expect(reopened.getCachedLyricsCount(), 0);
    });

    test('empty payloads are not cached', () async {
      final storage = await newStorage();
      await storage.putCachedLyrics('online_2', '   ');
      expect(storage.getCachedLyrics('online_2'), isNull);
    });

    test('cache evicts the oldest entry once it is full', () async {
      final storage = await newStorage();
      for (var i = 0; i < 155; i++) {
        await storage.putCachedLyrics('song_$i', '[00:00.00] line $i');
      }
      expect(storage.getCachedLyricsCount(), 150);
      expect(storage.getCachedLyrics('song_0'), isNull);
      expect(storage.getCachedLyrics('song_154'), isNotNull);
    });

    test('service serves cached lyrics without touching the network', () async {
      final storage = await newStorage();
      const songId = 'online_cached_test_77';
      const song = SongModel(
        id: songId,
        title: 'A Track That Does Not Exist Online',
        artist: 'Nobody',
        duration: Duration(minutes: 3),
        audioPath: 'https://example.com/never.mp3',
        sourceType: AudioSourceType.network,
      );

      await storage.putCachedLyrics(
        LyricsService.cacheKeyFor(song),
        '[00:03.00] Cached line one\n[00:07.50] Cached line two',
      );

      final lyrics = await LyricsService.getLyricsForSong(song, storage: storage);
      expect(lyrics.fromCache, isTrue);
      expect(lyrics.isSynced, isTrue);
      expect(lyrics.lines.length, 2);
      expect(lyrics.lines.first.text, 'Cached line one');
      expect(
        lyrics.lines.first.timestamp,
        const Duration(seconds: 3),
      );
    });
  });

  group('Lyrics sync offset', () {
    test('offsets persist per song and default to zero', () async {
      final storage = await newStorage();
      expect(storage.getLyricsOffsetMs('song_a'), 0);

      await storage.setLyricsOffsetMs('song_a', 500);
      await storage.setLyricsOffsetMs('song_b', -750);

      final reopened = await newStorage();
      expect(reopened.getLyricsOffsetMs('song_a'), 500);
      expect(reopened.getLyricsOffsetMs('song_b'), -750);

      // Zero means "no offset", so the entry is dropped entirely.
      await reopened.setLyricsOffsetMs('song_a', 0);
      expect((await newStorage()).getLyricsOffsetMs('song_a'), 0);
    });

    test('offsets are clamped to a sane range', () async {
      final storage = await newStorage();
      await storage.setLyricsOffsetMs('song_c', 999999);
      expect(storage.getLyricsOffsetMs('song_c'), 10000);

      await storage.setLyricsOffsetMs('song_c', -999999);
      expect(storage.getLyricsOffsetMs('song_c'), -10000);
    });

    test('LyricsData.shifted moves lines and never goes negative', () {
      final lyrics = LyricsData.parseLrc(
        '[00:01.00] One\n[00:05.00] Two\n[00:09.00] Three',
        songId: 's1',
      );

      final later = lyrics.shifted(const Duration(milliseconds: 500));
      expect(later.lines[0].timestamp, const Duration(milliseconds: 1500));
      expect(later.songId, 's1');

      final earlier = lyrics.shifted(const Duration(milliseconds: -2000));
      expect(earlier.lines[0].timestamp, Duration.zero);
      expect(earlier.lines[1].timestamp, const Duration(seconds: 3));
      // Still sorted, so active-line lookup keeps working.
      for (var i = 1; i < earlier.lines.length; i++) {
        expect(
          earlier.lines[i].timestamp >= earlier.lines[i - 1].timestamp,
          isTrue,
        );
      }
      expect(earlier.getActiveLineIndex(const Duration(seconds: 4)), 1);
    });

    test('zero offset returns the same lyrics unchanged', () {
      final lyrics = LyricsData.parseLrc('[00:02.00] Only line');
      expect(identical(lyrics.shifted(Duration.zero), lyrics), isTrue);
    });
  });
}
