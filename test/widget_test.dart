import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundwave/app/app.dart';
import 'package:soundwave/app/theme/app_theme.dart';
import 'package:soundwave/app/theme/theme_model.dart';
import 'package:soundwave/core/utils/duration_formatter.dart';
import 'package:soundwave/core/widgets/album_artwork.dart';
import 'package:soundwave/core/widgets/song_track_tile.dart';
import 'package:soundwave/features/library/models/playlist_model.dart';
import 'package:soundwave/features/library/models/song_filter_state.dart';
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/online/services/download_service.dart';
import 'package:soundwave/features/player/models/equalizer_model.dart';
import 'package:soundwave/features/player/models/lyrics_model.dart';
import 'package:soundwave/features/player/models/song_model.dart';
import 'package:soundwave/features/player/presentation/now_playing_screen.dart';
import 'package:soundwave/features/player/services/audio_handler.dart';
import 'package:soundwave/features/player/services/sleep_timer_service.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/online_music_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/search_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';

class _RecordingAudioHandler extends SoundWaveAudioHandler {
  final List<String> loadedSongIds = [];
  int pauseCount = 0;
  int playCount = 0;
  double recordedVolume = 1.0;
  double recordedSpeed = 1.0;

  @override
  Future<void> loadQueue(List<SongModel> songs, {int initialIndex = 0}) async {
    if (songs.isNotEmpty) {
      loadedSongIds.add(songs[initialIndex.clamp(0, songs.length - 1)].id);
      await super.updateSongQueue(songs, newIndex: initialIndex);
    }
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> setPlaybackVolume(double volume) async {
    recordedVolume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    recordedSpeed = speed;
  }

  @override
  Future<void> updateSongQueue(List<SongModel> newQueue, {int? newIndex}) async {
    await super.updateSongQueue(newQueue, newIndex: newIndex);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    await super.removeFromQueue(index);
  }

  @override
  Future<void> clearUpcomingQueue() async {
    await super.clearUpcomingQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pngBytes = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  group('Unit Tests: SoundWave Models & Utilities', () {
    test('DurationFormatter formats standard minutes and seconds correctly', () {
      expect(DurationFormatter.format(const Duration(minutes: 3, seconds: 56)), '3:56');
      expect(DurationFormatter.format(const Duration(seconds: 9)), '0:09');
      expect(DurationFormatter.format(const Duration(minutes: 12, seconds: 4)), '12:04');
    });

    test('DurationFormatter formatLong formats hours and minutes', () {
      expect(DurationFormatter.formatLong(const Duration(hours: 1, minutes: 25)), '1h 25m');
      expect(DurationFormatter.formatLong(const Duration(minutes: 45)), '45m');
    });

    test('SongModel serialization and deserialization integrity', () {
      const song = SongModel(
        id: 'test_1',
        title: 'Dreams Tonight',
        artist: 'Arijit Singh',
        album: 'Midnight Echoes',
        duration: Duration(minutes: 3, seconds: 56),
        audioPath: 'assets/audio/dreams_tonight.wav',
        sourceType: AudioSourceType.asset,
        genre: 'Pop',
        isHd: true,
      );

      final map = song.toMap();
      final revived = SongModel.fromMap(map);

      expect(revived.id, song.id);
      expect(revived.title, song.title);
      expect(revived.artist, song.artist);
      expect(revived.duration, song.duration);
      expect(revived.isHd, true);
    });

    test('PlaylistModel calculates song count and total duration accurately', () {
      const song1 = SongModel(
        id: 'test_s1',
        title: 'Song One',
        artist: 'Artist One',
        duration: Duration(minutes: 3, seconds: 30),
        audioPath: '/storage/song1.mp3',
      );
      const song2 = SongModel(
        id: 'test_s2',
        title: 'Song Two',
        artist: 'Artist Two',
        duration: Duration(minutes: 4, seconds: 15),
        audioPath: '/storage/song2.mp3',
      );
      final songs = [song1, song2];
      final playlist = PlaylistModel(
        id: 'pl_test',
        name: 'My Test Playlist',
        songs: songs,
        createdAt: DateTime.now(),
      );

      expect(playlist.songCount, 2);
      expect(
        playlist.totalDuration,
        songs[0].duration + songs[1].duration,
      );
    });

    test('SongFilterHelper filters by search query and category correctly', () {
      const s1 = SongModel(
        id: 's1',
        title: 'Midnight Echoes',
        artist: 'The Weeknd',
        album: 'Dawn FM',
        duration: Duration(minutes: 3, seconds: 20),
        audioPath: '/s1.mp3',
        genre: 'Synthpop',
        isLocal: true,
      );
      const s2 = SongModel(
        id: 's2',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: Duration(minutes: 3, seconds: 50),
        audioPath: '/s2.mp3',
        genre: 'Pop',
        isLocal: false,
      );
      const s3 = SongModel(
        id: 's3',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: Duration(minutes: 4, seconds: 22),
        audioPath: '/s3.mp3',
        genre: 'Romantic',
        isLocal: true,
      );

      final songs = [s1, s2, s3];
      final favIds = {'s1', 's3'};
      final recentIds = ['s2', 's1'];

      // Test 1: Category - Favorites
      final favResult = SongFilterHelper.filterAndSort(
        songs: songs,
        filterState: const SongFilterState(category: SongCategoryFilter.favorites),
        favoriteIds: favIds,
        recentlyPlayedIds: recentIds,
      );
      expect(favResult.length, 2);
      expect(favResult.map((s) => s.id), containsAll(['s1', 's3']));

      // Test 2: Category - Downloads (Local Only)
      final localResult = SongFilterHelper.filterAndSort(
        songs: songs,
        filterState: const SongFilterState(category: SongCategoryFilter.downloads),
        favoriteIds: favIds,
        recentlyPlayedIds: recentIds,
      );
      expect(localResult.length, 2);
      expect(localResult.map((s) => s.id), containsAll(['s1', 's3']));

      // Test 3: Search Query
      final searchResult = SongFilterHelper.filterAndSort(
        songs: songs,
        filterState: const SongFilterState(searchQuery: 'arijit'),
        favoriteIds: favIds,
        recentlyPlayedIds: recentIds,
      );
      expect(searchResult.length, 1);
      expect(searchResult.first.title, 'Tum Hi Ho');

      // Test 4: Duration Filter (< 3:30 vs > 4:00)
      final under3MinResult = SongFilterHelper.filterAndSort(
        songs: songs,
        filterState: const SongFilterState(duration: DurationFilter.under3Min),
        favoriteIds: favIds,
        recentlyPlayedIds: recentIds,
      );
      expect(under3MinResult.length, 0); // 200s, 230s, 262s are all >= 180s

      final threeToFiveMin = SongFilterHelper.filterAndSort(
        songs: songs,
        filterState: const SongFilterState(duration: DurationFilter.threeToFiveMin),
        favoriteIds: favIds,
        recentlyPlayedIds: recentIds,
      );
      expect(threeToFiveMin.length, 3);

      // Test 5: Sorting Name Z-A
      final sortResult = SongFilterHelper.filterAndSort(
        songs: songs,
        filterState: const SongFilterState(sortBy: SongSortOption.nameDesc),
        favoriteIds: favIds,
        recentlyPlayedIds: recentIds,
      );
      expect(sortResult.first.title, 'Tum Hi Ho');
      expect(sortResult.last.title, 'Midnight Echoes');
    });

    test('DownloadService helpers normalize artwork URLs and save/delete local banners', () async {
      expect(
        DownloadService.normalizeArtworkUrl('https://c.saavncdn.com/123/img-150x150.jpg'),
        'https://c.saavncdn.com/123/img-500x500.jpg',
      );
      expect(
        DownloadService.normalizeArtworkUrl('https://c.saavncdn.com/123/img-50x50.jpg'),
        'https://c.saavncdn.com/123/img-500x500.jpg',
      );
      expect(DownloadService.sanitizeIdForFile('online_a:b/c'), 'online_a_b_c');

      final tempDir = await Directory.systemTemp.createTemp('sw_dl_test_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        return tempDir.path;
      });

      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final audioFile = File('${tempDir.path}/online_track_9_320k.m4a');
      await audioFile.writeAsBytes([1, 2, 3, 4]);

      final onlineSong = SongModel(
        id: 'online_track_9',
        title: 'Test Track',
        artist: 'Test Artist',
        duration: const Duration(minutes: 3),
        audioPath: audioFile.path,
        artworkPath: 'https://c.saavncdn.com/9/cover-150x150.jpg',
      );

      final requestedUrls = <String>[];
      final mockClient = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return http.Response.bytes(pngBytes, 200);
      });

      final localArtPath = await DownloadService.ensureLocalArtworkForSong(
        onlineSong,
        client: mockClient,
      );
      expect(localArtPath, isNotNull);
      expect(requestedUrls.single, 'https://c.saavncdn.com/9/cover-500x500.jpg');
      expect(File(localArtPath!).existsSync(), isTrue);

      final downloadedModel = onlineSong.copyWith(
        sourceType: AudioSourceType.file,
        artworkPath: localArtPath,
        isLocal: true,
      );
      expect(SoundWaveAudioHandler.resolveArtUri(localArtPath), Uri.file(localArtPath));

      final deleted = await DownloadService.deleteDownload(downloadedModel);
      expect(deleted, isTrue);
      expect(audioFile.existsSync(), isFalse);
      expect(File(localArtPath).existsSync(), isFalse);
    });

    test('SoundWaveAudioHandler.resolveArtUri handles local files, HTTP URLs, and missing files', () async {
      final tempDir = await Directory.systemTemp.createTemp('sw_art_uri_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final existingFile = File('${tempDir.path}/banner.jpg');
      await existingFile.writeAsBytes(pngBytes);

      expect(SoundWaveAudioHandler.resolveArtUri(existingFile.path), Uri.file(existingFile.path));
      expect(
        SoundWaveAudioHandler.resolveArtUri(Uri.file(existingFile.path).toString()),
        Uri.file(existingFile.path),
      );
      expect(SoundWaveAudioHandler.resolveArtUri('${tempDir.path}/missing.jpg'), isNull);
      expect(SoundWaveAudioHandler.resolveArtUri('assets/images/logo.png'), isNull);
      expect(
        SoundWaveAudioHandler.resolveArtUri('https://c.saavncdn.com/1/art-500x500.jpg'),
        Uri.parse('https://c.saavncdn.com/1/art-500x500.jpg'),
      );
    });

    test('PlayerNotifier prefers downloaded offline files and cancels stale async requests', () async {
      final tempDir = await Directory.systemTemp.createTemp('sw_player_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final offlineAudio = File('${tempDir.path}/offline_1.m4a');
      final offlineBanner = File('${tempDir.path}/offline_1_art.jpg');
      await offlineAudio.writeAsBytes([10, 20, 30]);
      await offlineBanner.writeAsBytes(pngBytes);

      final offlineSong = SongModel(
        id: 'online_saved_1',
        title: 'Offline Hit',
        artist: 'Artist One',
        duration: const Duration(minutes: 4),
        audioPath: offlineAudio.path,
        sourceType: AudioSourceType.file,
        artworkPath: offlineBanner.path,
        isLocal: true,
      );

      final remoteCopy = offlineSong.copyWith(
        audioPath: 'https://example.com/stream.mp3',
        sourceType: AudioSourceType.network,
        artworkPath: 'https://example.com/remote.jpg',
        isLocal: false,
      );

      SharedPreferences.setMockInitialValues({
        'sw_downloaded_songs': [json.encode(offlineSong.toMap())],
        'sw_local_songs_cache': [json.encode(offlineSong.toMap())],
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LibraryStorageService(prefs);
      final handler = _RecordingAudioHandler();

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          storageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      // Tapping remote card should automatically play the downloaded file + offline banner
      await container.read(playerProvider.notifier).playTrack(remoteCopy);
      final current = container.read(playerProvider).currentSong;
      expect(current?.sourceType, AudioSourceType.file);
      expect(current?.audioPath, offlineAudio.path);
      expect(current?.artworkPath, offlineBanner.path);
      expect(handler.loadedSongIds, ['online_saved_1']);

      // Explicit pause cancels any in-flight playTrack before completion
      final unresolvedOnline = const SongModel(
        id: 'online_slow_2',
        title: 'Slow Track',
        artist: 'Artist Two',
        duration: Duration(minutes: 3),
        audioPath: '',
        sourceType: AudioSourceType.network,
      );
      final pendingPlay = container.read(playerProvider.notifier).playTrack(unresolvedOnline);
      await container.read(playerProvider.notifier).pause();
      await pendingPlay;
      expect(handler.loadedSongIds, ['online_saved_1']);
      expect(handler.pauseCount, greaterThanOrEqualTo(1));
    });

    test('LibraryNotifier preserves downloaded songs across add and remove operations', () async {
      const dummyLocal = SongModel(
        id: 'local_dummy_1',
        title: 'Local Cached',
        artist: 'Local Artist',
        duration: Duration(minutes: 2),
        audioPath: '/tmp/local_cached.mp3',
        sourceType: AudioSourceType.file,
        isLocal: true,
      );
      SharedPreferences.setMockInitialValues({
        'sw_local_songs_cache': [json.encode(dummyLocal.toMap())],
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LibraryStorageService(prefs);

      const downloaded = SongModel(
        id: 'online_dl_1',
        title: 'Downloaded Banner Song',
        artist: 'Artist A',
        duration: Duration(minutes: 3),
        audioPath: '/tmp/dl.m4a',
        sourceType: AudioSourceType.file,
        artworkPath: '/tmp/dl_art.jpg',
        isLocal: true,
      );

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      await container.read(libraryProvider.notifier).addDownloadedSong(downloaded);
      expect(container.read(libraryProvider).downloadedSongs.length, 1);
      expect(container.read(libraryProvider).allSongs.any((s) => s.id == downloaded.id), isTrue);

      await container.read(libraryProvider.notifier).removeDownloadedSong(downloaded.id);
      expect(container.read(libraryProvider).downloadedSongs, isEmpty);
      expect(container.read(libraryProvider).allSongs.any((s) => s.id == downloaded.id), isFalse);
    });

    test('ThemeNotifier persists selected theme and AppTheme.fromType syncs ColorScheme', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LibraryStorageService(prefs);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeProvider), AppThemeType.midnightOled);
      await container.read(themeProvider.notifier).setTheme(AppThemeType.cyberNeon);
      expect(container.read(themeProvider), AppThemeType.cyberNeon);

      final themeData = AppTheme.fromType(AppThemeType.midnightOled);
      expect(themeData.colorScheme.primary, AppThemeType.midnightOled.primaryAccent);
      expect(themeData.scaffoldBackgroundColor, AppThemeType.midnightOled.primaryBackground);
    });

    test('SearchNotifier filters local library safely and disposes cleanly', () async {
      const s1 = SongModel(
        id: 'local_1',
        title: 'Kesariya Acoustic',
        artist: 'Arijit Singh',
        album: 'Brahmastra',
        duration: Duration(minutes: 4),
        audioPath: '/tmp/kesariya.mp3',
        sourceType: AudioSourceType.file,
        isLocal: true,
      );
      SharedPreferences.setMockInitialValues({
        'sw_local_songs_cache': [json.encode(s1.toMap())],
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = LibraryStorageService(prefs);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
      );

      container.read(searchProvider.notifier).onQueryChanged('kesariya');
      expect(container.read(searchProvider).results.length, 1);
      expect(container.read(searchProvider).results.first.title, 'Kesariya Acoustic');

      // Disposing while debounce timer is pending must not throw
      container.dispose();
    });

    test('SleepTimerNotifier starts and cancels cleanly', () async {
      final handler = _RecordingAudioHandler();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
        ],
      );
      addTearDown(container.dispose);

      container.read(sleepTimerProvider.notifier).startTimer(15);
      expect(container.read(sleepTimerProvider).isActive, isTrue);
      expect(container.read(sleepTimerProvider).totalMinutes, 15);

      container.read(sleepTimerProvider.notifier).cancelTimer();
      expect(container.read(sleepTimerProvider).isActive, isFalse);
    });
  });

  group('Widget Tests: SoundWave App Navigation & UI', () {
    testWidgets('AlbumArtwork renders local offline cover banner file', (WidgetTester tester) async {
      final tempDir = Directory.systemTemp.createTempSync('sw_widget_art_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final localArt = File('${tempDir.path}/offline_banner.png');
      localArt.writeAsBytesSync(pngBytes);

      expect(AlbumArtwork.extractLocalFilePath(localArt.path), localArt.path);
      expect(AlbumArtwork.extractLocalFilePath('https://example.com/a.jpg'), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AlbumArtwork(
                size: 100,
                artworkUrl: localArt.path,
                songTitle: 'Offline Song',
                songArtist: 'Offline Artist',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('SoundWave launches, handles offline catalog gracefully, and navigates all tabs', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storageService = LibraryStorageService(prefs);
      final audioHandler = _RecordingAudioHandler();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(audioHandler),
            storageServiceProvider.overrideWithValue(storageService),
            onlineTrendingProvider.overrideWith((ref) async => const <SongModel>[]),
          ],
          child: const SoundWaveApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Brand Title and Tagline on Home
      expect(find.text('SoundWave'), findsWidgets);
      expect(find.text('Feel the music, live the moment.'), findsOneWidget);
      // Orphaned Trending header hidden when offline; graceful retry card shown instead
      expect(find.text('Trending Online Hits'), findsNothing);
      expect(find.text('Hot Online Tracks'), findsOneWidget);
      expect(find.text('Online catalog unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Persistent Bottom Navigation Destinations
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
      expect(find.byIcon(Icons.library_music_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsWidgets);
      expect(find.byIcon(Icons.person_rounded), findsWidgets);

      // Switch to Explore Tab
      await tester.tap(find.byIcon(Icons.explore_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Explore'), findsWidgets);
      expect(find.text('Discover new music everyday'), findsOneWidget);
      expect(find.text('Trending Now'), findsOneWidget);

      // Switch to Library Tab
      await tester.tap(find.byIcon(Icons.library_music_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Your Library'), findsOneWidget);

      // Switch to Profile Tab (tap bottom navigation item)
      await tester.tap(find.byIcon(Icons.person_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Listening Statistics'), findsOneWidget);
    });

    testWidgets('Home displays Trending Online Hits when online songs load', (WidgetTester tester) async {
      const sampleOnline = SongModel(
        id: 'online_hit_1',
        title: 'Midnight Melody',
        artist: 'Arijit Singh',
        album: 'SoundWave Sessions',
        duration: Duration(minutes: 4, seconds: 10),
        audioPath: 'https://example.com/track.mp4',
        sourceType: AudioSourceType.network,
        isLocal: false,
      );

      SharedPreferences.setMockInitialValues({
        'sw_local_songs_cache': [json.encode(sampleOnline.toMap())],
      });
      final prefs = await SharedPreferences.getInstance();
      final storageService = LibraryStorageService(prefs);
      final audioHandler = _RecordingAudioHandler();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(audioHandler),
            storageServiceProvider.overrideWithValue(storageService),
            onlineTrendingProvider.overrideWith((ref) async => [sampleOnline]),
          ],
          child: const SoundWaveApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The home header, quick-access dock and hero banner sit above the
      // trending rail, so scroll down to it before asserting.
      await tester.dragUntilVisible(
        find.text('Trending Online Hits'),
        find.byType(CustomScrollView).first,
        const Offset(0, -120),
      );
      await tester.pump();

      expect(find.text('Trending Online Hits'), findsOneWidget);
      expect(find.text('Midnight Melody'), findsWidgets);
    });

    testWidgets('SongTrackTile toggles favorite icon reactively on tap', (WidgetTester tester) async {
      const sampleSong = SongModel(
        id: 'local_fav_1',
        title: 'Midnight Melody',
        artist: 'Arijit Singh',
        album: 'SoundWave Sessions',
        duration: Duration(minutes: 4, seconds: 10),
        audioPath: '/tmp/track.mp3',
        sourceType: AudioSourceType.file,
        isLocal: true,
      );

      SharedPreferences.setMockInitialValues({
        'sw_local_songs_cache': [json.encode(sampleSong.toMap())],
      });
      final prefs = await SharedPreferences.getInstance();
      final storageService = LibraryStorageService(prefs);
      final audioHandler = _RecordingAudioHandler();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(audioHandler),
            storageServiceProvider.overrideWithValue(storageService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SongTrackTile(
                song: sampleSong,
                playlist: [sampleSong],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('NowPlayingScreen More Options opens Sleep Timer and activates live countdown', (WidgetTester tester) async {
      const track = SongModel(
        id: 'local_np_1',
        title: 'Starlight Drive',
        artist: 'SoundWave',
        album: 'Offline Hits',
        duration: Duration(minutes: 3, seconds: 45),
        audioPath: '/tmp/starlight.mp3',
        sourceType: AudioSourceType.file,
        isLocal: true,
      );

      SharedPreferences.setMockInitialValues({
        'sw_local_songs_cache': [json.encode(track.toMap())],
      });
      final prefs = await SharedPreferences.getInstance();
      final storageService = LibraryStorageService(prefs);
      final audioHandler = _RecordingAudioHandler();

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(audioHandler),
          storageServiceProvider.overrideWithValue(storageService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(playerProvider.notifier).playTrack(track);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: NowPlayingScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('Starlight Drive'), findsOneWidget);

      // Open More Options sheet
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sleep Timer & Fade-Out'), findsOneWidget);
      expect(find.text('Audio Equalizer Studio'), findsOneWidget);
      expect(find.text('Playback Speed'), findsOneWidget);
      expect(find.text('Track Details & Audio Specs'), findsOneWidget);

      // Open Sleep Timer sheet and select 15 min
      await tester.tap(find.text('Sleep Timer & Fade-Out'));
      await tester.pumpAndSettle();
      expect(find.text('15 min'), findsOneWidget);
      await tester.tap(find.text('15 min'));
      await tester.pumpAndSettle();

      // Countdown chip appears in TopBar
      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);

      // Clean up active timer before test completes
      container.read(sleepTimerProvider.notifier).cancelTimer();
    });

    test('EqualizerModel serialization and preset integrity', () {
      const eq = EqualizerModel();
      expect(eq.isEnabled, true);
      expect(eq.bandGains.length, 5);
      expect(eq.presetName, 'Vibrant Bass Boost');

      final flatGains = EqualizerModel.standardPresets['Flat / Studio Reference']!;
      final updated = eq.copyWith(
        presetName: 'Flat / Studio Reference',
        bandGains: flatGains,
        bassBoost: 0.0,
      );
      expect(updated.bandGains, [0.0, 0.0, 0.0, 0.0, 0.0]);
      expect(updated.bassBoost, 0.0);

      final map = updated.toMap();
      final revived = EqualizerModel.fromMap(map);
      expect(revived.presetName, 'Flat / Studio Reference');
      expect(revived.bandGains, [0.0, 0.0, 0.0, 0.0, 0.0]);
    });

    test('LyricsData parses synchronized LRC timestamps and lines accurately', () {
      const sampleLrc = '''
[00:02.50] First line of the melody
[00:08.00] Second line rolling in
[00:15.30] Chorus starts here
''';
      final lyrics = LyricsData.parseLrc(sampleLrc);
      expect(lyrics.isSynced, true);
      expect(lyrics.lines.length, 3);
      expect(lyrics.lines[0].text, 'First line of the melody');
      expect(lyrics.lines[0].timestamp, const Duration(seconds: 2, milliseconds: 500));
      expect(lyrics.lines[1].timestamp, const Duration(seconds: 8));

      // Test active line index detection
      expect(lyrics.getActiveLineIndex(const Duration(seconds: 1)), 0);
      expect(lyrics.getActiveLineIndex(const Duration(seconds: 4)), 0);
      expect(lyrics.getActiveLineIndex(const Duration(seconds: 10)), 1);
      expect(lyrics.getActiveLineIndex(const Duration(seconds: 20)), 2);
    });

    test('PlayerNotifier reorders queue and removes tracks correctly', () async {
      final mockHandler = _RecordingAudioHandler();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(mockHandler),
        ],
      );
      addTearDown(container.dispose);

      const songA = SongModel(id: 's_a', title: 'Song A', artist: 'Artist A', duration: Duration(minutes: 3), audioPath: '/a.mp3');
      const songB = SongModel(id: 's_b', title: 'Song B', artist: 'Artist B', duration: Duration(minutes: 3), audioPath: '/b.mp3');
      const songC = SongModel(id: 's_c', title: 'Song C', artist: 'Artist C', duration: Duration(minutes: 3), audioPath: '/c.mp3');

      final notifier = container.read(playerProvider.notifier);
      await notifier.playTrack(songA, queue: [songA, songB, songC]);

      expect(container.read(playerProvider).queue.map((s) => s.id).toList(), ['s_a', 's_b', 's_c']);

      // Reorder: move songC (index 2) to index 0
      await notifier.reorderQueue(2, 0);
      expect(container.read(playerProvider).queue.map((s) => s.id).toList(), ['s_c', 's_a', 's_b']);
      expect(container.read(playerProvider).currentIndex, 1); // Song A is still current

      // Remove songB (index 2)
      await notifier.removeFromQueue(2);
      expect(container.read(playerProvider).queue.map((s) => s.id).toList(), ['s_c', 's_a']);

      // Clear upcoming
      await notifier.clearUpcomingQueue();
      expect(container.read(playerProvider).queue.length, 1);
      expect(container.read(playerProvider).queue.first.id, 's_a');
    });

    test('PlayerNotifier plays a song next and appends to the queue', () async {
      final mockHandler = _RecordingAudioHandler();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(mockHandler),
        ],
      );
      addTearDown(container.dispose);

      const songA = SongModel(id: 's_a', title: 'Song A', artist: 'Artist A', duration: Duration(minutes: 3), audioPath: '/a.mp3');
      const songB = SongModel(id: 's_b', title: 'Song B', artist: 'Artist B', duration: Duration(minutes: 3), audioPath: '/b.mp3');
      const songC = SongModel(id: 's_c', title: 'Song C', artist: 'Artist C', duration: Duration(minutes: 3), audioPath: '/c.mp3');
      const songD = SongModel(id: 's_d', title: 'Song D', artist: 'Artist D', duration: Duration(minutes: 3), audioPath: '/d.mp3');
      const songE = SongModel(id: 's_e', title: 'Song E', artist: 'Artist E', duration: Duration(minutes: 3), audioPath: '/e.mp3');

      final notifier = container.read(playerProvider.notifier);
      await notifier.playTrack(songA, queue: [songA, songB, songC]);
      List<String> ids() =>
          container.read(playerProvider).queue.map((s) => s.id).toList();

      await notifier.playNextInQueue(songD);
      expect(ids(), ['s_a', 's_d', 's_b', 's_c']);
      expect(container.read(playerProvider).currentSong?.id, 's_a');
      expect(container.read(playerProvider).currentIndex, 0);

      // Tapping play-next twice must not queue two copies.
      await notifier.playNextInQueue(songD);
      expect(ids(), ['s_a', 's_d', 's_b', 's_c']);

      // A song already waiting later is not added twice.
      await notifier.addToQueue(songB);
      expect(ids(), ['s_a', 's_d', 's_b', 's_c']);

      await notifier.addToQueue(songE);
      expect(ids(), ['s_a', 's_d', 's_b', 's_c', 's_e']);
      expect(container.read(playerProvider).currentSong?.id, 's_a');
    });

    test('SleepTimerNotifier supports adding minutes and cancelling cleanly', () {
      final mockHandler = _RecordingAudioHandler();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(mockHandler),
        ],
      );
      addTearDown(container.dispose);

      final timerNotifier = container.read(sleepTimerProvider.notifier);
      timerNotifier.startTimer(10);

      var state = container.read(sleepTimerProvider);
      expect(state.isActive, true);
      expect(state.totalMinutes, 10);
      expect(state.remaining.inMinutes, 10);

      // Add 5 minutes
      timerNotifier.addMinutes(5);
      state = container.read(sleepTimerProvider);
      expect(state.totalMinutes, 15);
      expect(state.remaining.inMinutes, 15);

      // Cancel
      timerNotifier.cancelTimer();
      state = container.read(sleepTimerProvider);
      expect(state.isActive, false);
      expect(mockHandler.recordedVolume, 1.0);
    });
  });
}
