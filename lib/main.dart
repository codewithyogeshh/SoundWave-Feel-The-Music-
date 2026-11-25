import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/app/app.dart';
import 'package:soundwave/features/library/services/library_storage_service.dart';
import 'package:soundwave/features/player/services/audio_handler.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait orientation is locked declaratively in AndroidManifest.xml
  // Avoiding runtime setPreferredOrientations prevents MIUI from altering system auto-rotate settings

  // Dispose any lingering native ExoPlayer instances left behind by a prior engine session
  await SoundWaveAudioHandler.disposeOrphanedNativePlayers();

  // Initialize background Audio Service
  SoundWaveAudioHandler? audioHandler;
  try {
    audioHandler = await initAudioService();
  } catch (e) {
    debugPrint('AudioService init fallback: $e');
    audioHandler = SoundWaveAudioHandler();
  }

  // Initialize Local Storage Service (SharedPreferences)
  final storageService = await LibraryStorageService.create();

  // Apply saved playback/battery preferences before the first track loads.
  audioHandler.pauseOnHeadphoneUnplug =
      storageService.getPauseOnHeadphoneUnplug();
  audioHandler.setBatterySaver(storageService.getBatterySaver());

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const SoundWaveApp(),
    ),
  );
}
