import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundwave/app/theme/app_colors.dart';
import 'package:soundwave/features/player/utils/voice_command_parser.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';
import 'package:soundwave/shared/providers/theme_provider.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Bottom sheet that listens for one spoken playback command ("पुढचं गाणं",
/// "थांबव", "पुन्हा लाव" …) and acts on the player straight away.
class VoiceControlSheet extends ConsumerStatefulWidget {
  const VoiceControlSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceControlSheet(),
    );
  }

  @override
  ConsumerState<VoiceControlSheet> createState() => _VoiceControlSheetState();
}

class _VoiceControlSheetState extends ConsumerState<VoiceControlSheet> {
  static const String _voiceLangKey = 'sw_voice_search_lang';

  final SpeechToText _speech = SpeechToText();
  String _voiceLang = 'auto';
  bool _isListening = false;
  String? _heard;
  String? _result;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadVoiceLang();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _loadVoiceLang() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_voiceLangKey);
      if (saved != null && mounted) setState(() => _voiceLang = saved);
    } catch (_) {
      // Stay with the phone's own language.
    }
  }

  String? _matchLocale(List<LocaleName> locales, String prefix) {
    for (final locale in locales) {
      final id = locale.localeId.toLowerCase().replaceAll('-', '_');
      if (id == prefix || id.startsWith('${prefix}_')) return locale.localeId;
    }
    return null;
  }

  /// Uses the language picked for voice search, otherwise the phone's own
  /// Marathi / Hindi / English model.
  Future<String?> _localeId() async {
    try {
      final locales = await _speech.locales();
      if (_voiceLang != 'auto') {
        final chosen = _matchLocale(locales, _voiceLang);
        if (chosen != null) return chosen;
      }
      for (final prefix in const ['mr', 'hi', 'en_in', 'en']) {
        final match = _matchLocale(locales, prefix);
        if (match != null) return match;
      }
    } catch (_) {
      // Fall back to the phone's default language.
    }
    return null;
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _failed = false;
      _result = null;
      _heard = null;
    });

    var handled = false;

    void handleHeard(String words) {
      if (handled || words.trim().isEmpty) return;
      handled = true;
      if (mounted) setState(() => _isListening = false);
      _runSpoken(words.trim());
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            final last = _heard;
            if (last != null && last.trim().isNotEmpty) handleHeard(last);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _failed = true;
            _result = _errorMessage(error.errorMsg);
          });
        },
      );

      if (!available) {
        setState(() {
          _failed = true;
          _result =
              'या फोनवर आवाज ओळख उपलब्ध नाही. फोनच्या सेटिंग्जमध्ये Google आवाज सेवा चालू करा.';
        });
        return;
      }

      final localeId = await _localeId();
      if (!mounted) return;
      setState(() => _isListening = true);

      await _speech.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 2),
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty || !mounted) return;
          setState(() => _heard = words);
          if (result.finalResult) handleHeard(words);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _failed = true;
        _result = 'आवाज ऐकता आला नाही. पुन्हा प्रयत्न करा.';
      });
    }
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'काहीच ऐकलं नाही. माइकजवळ बोला.';
      case 'error_permission':
        return 'माइकची परवानगी दिली नाही. फोनच्या सेटिंग्जमध्ये SoundWave ला माइक परवानगी द्या.';
      case 'error_network':
      case 'error_network_timeout':
        return 'इंटरनेट नाही. एकदा इंटरनेट लागल्यावर पुन्हा बोला.';
      case 'error_busy':
        return 'माइक आधीच वापरात आहे. थोड्या वेळाने पुन्हा बोला.';
      default:
        return 'आवाज ओळखता आला नाही. पुन्हा बोला.';
    }
  }

  Future<void> _runSpoken(String words) async {
    final command = parseVoiceCommand(words);
    if (command == null) {
      setState(() {
        _failed = true;
        _result =
            '"$words" ही आज्ञा समजली नाही. खाली दिलेल्या आज्ञा बोलून बघा.';
      });
      return;
    }

    final message = await _execute(command);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _failed = false;
      _result = message;
    });
  }

  Future<String> _execute(VoiceCommand command) async {
    final player = ref.read(playerProvider.notifier);
    final playerState = ref.read(playerProvider);
    final song = playerState.currentSong;

    switch (command) {
      case VoiceCommand.next:
        if (song == null) return 'आधी एक गाणं लावा, मग "पुढचं गाणं" म्हणा.';
        await player.skipToNext();
        return 'पुढचं गाणं लावलं.';
      case VoiceCommand.previous:
        if (song == null) return 'आधी एक गाणं लावा, मग "मागचं गाणं" म्हणा.';
        await player.skipToPrevious();
        return 'मागचं गाणं लावलं.';
      case VoiceCommand.pause:
        if (song == null) return 'सध्या काहीच वाजत नाही.';
        if (playerState.isPlaying) {
          await player.pause();
          return 'गाणं थांबवलं.';
        }
        return 'गाणं आधीच थांबलं आहे.';
      case VoiceCommand.resume:
        if (song == null) return 'लावायला गाणं नाही. आधी यादीतून गाणं निवडा.';
        if (!playerState.isPlaying) {
          await player.togglePlayPause();
          return 'गाणं पुन्हा सुरू केलं.';
        }
        return 'गाणं आधीच वाजतंय.';
      case VoiceCommand.restart:
        if (song == null) return 'सध्या काहीच वाजत नाही.';
        await player.seek(Duration.zero);
        return 'गाणं सुरुवातीपासून लावलं.';
      case VoiceCommand.shuffle:
        if (!playerState.isShuffle) {
          await player.toggleShuffle();
          return 'शफल चालू केलं.';
        }
        await player.toggleShuffle();
        return 'शफल बंद केलं.';
      case VoiceCommand.repeat:
        await player.cycleRepeatMode();
        final mode = ref.read(playerProvider).repeatMode;
        return mode == AudioServiceRepeatMode.one
            ? 'हेच गाणं पुन्हा पुन्हा लागेल.'
            : 'पुन्हा पुन्हा चालू केलं.';
      case VoiceCommand.favorite:
        if (song == null) return 'आधी एक गाणं लावा, मग "आवडतं" म्हणा.';
        await ref.read(libraryProvider.notifier).toggleFavorite(song);
        final isFav = ref.read(libraryProvider).isFavorite(song.id);
        return isFav
            ? '"${song.title}" आवडत्या गाण्यांत टाकलं.'
            : '"${song.title}" आवडत्या गाण्यांतून काढलं.';
      case VoiceCommand.volumeUp:
        await player.volumeUp();
        final louder = (ref.read(playerProvider).volume * 100).round();
        return louder >= 100
            ? 'आवाज पूर्ण वाढवला (100%).'
            : 'आवाज वाढवला — आता $louder%.';
      case VoiceCommand.volumeDown:
        await player.volumeDown();
        final quieter = (ref.read(playerProvider).volume * 100).round();
        return quieter <= 0
            ? 'आवाज पूर्ण कमी केला (म्यूट).'
            : 'आवाज कमी केला — आता $quieter%.';
      case VoiceCommand.mute:
        final muted = await player.toggleMute();
        return muted ? 'आवाज बंद केला (म्यूट).' : 'म्यूट काढलं — आवाज पुन्हा सुरू.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = ref.watch(themeProvider);
    final song = ref.watch(playerProvider).currentSong;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded, color: activeTheme.primaryAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Voice control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          Text(
            song == null
                ? 'आवाजाने गाणं लावा, थांबवा, पुढे करा किंवा आवाज वाढवा-कमी करा.'
                : 'सध्या: ${song.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: activeTheme.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: activeTheme.highlightColor.withValues(
                        alpha: _isListening ? 0.65 : 0.3,
                      ),
                      blurRadius: _isListening ? 34 : 18,
                      spreadRadius: _isListening ? 4 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: activeTheme.onAccentGradient,
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _isListening
                  ? 'ऐकतोय… आज्ञा बोला'
                  : (_heard ?? 'माइक दाबा आणि आज्ञा बोला'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isListening
                    ? activeTheme.primaryAccent
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _failed
                    ? Colors.redAccent.withValues(alpha: 0.12)
                    : AppColors.glassWhiteMedium,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _failed
                      ? Colors.redAccent.withValues(alpha: 0.4)
                      : AppColors.glassBorderSubtle,
                ),
              ),
              child: Text(
                _result!,
                style: TextStyle(
                  color: _failed ? Colors.redAccent : Colors.white,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'अशा आज्ञा बोलता येतील',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final example in voiceCommandExamples)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glassWhiteMedium,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.glassBorderSubtle),
                  ),
                  child: Text(
                    example,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
