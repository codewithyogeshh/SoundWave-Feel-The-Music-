import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/features/player/models/equalizer_model.dart';
import 'package:soundwave/shared/providers/library_provider.dart';
import 'package:soundwave/shared/providers/player_provider.dart';

class EqualizerNotifier extends Notifier<EqualizerModel> {
  static const String _storageKey = 'soundwave_equalizer_v1';

  @override
  EqualizerModel build() {
    return _loadPersistedState();
  }

  EqualizerModel _loadPersistedState() {
    try {
      final storage = ref.read(storageServiceProvider);
      final raw = storage.prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        return EqualizerModel.fromMap(decoded);
      }
    } catch (_) {
      // Return defaults if parsing fails
    }
    return const EqualizerModel();
  }

  Future<void> _persist() async {
    try {
      final storage = ref.read(storageServiceProvider);
      await storage.prefs.setString(_storageKey, json.encode(state.toMap()));
    } catch (_) {
      // Silent error in test environments
    }
  }

  /// Pushes the current equalizer state to the live audio engine so changes are
  /// heard immediately. Never throws — the engine simply stays idle when no
  /// real player is available (e.g. tests or non-Android platforms).
  void _applyToEngine() {
    try {
      final handler = ref.read(audioHandlerProvider);
      handler.updateEqualizer(
        enabled: state.isEnabled,
        bandGains: state.bandGains,
        bassBoost: state.bassBoost,
        virtualizer: state.virtualizer,
      );
    } catch (_) {
      // No audio handler override (tests / startup) — ignore.
    }
  }

  void toggleEnabled() {
    HapticFeedback.lightImpact();
    state = state.copyWith(isEnabled: !state.isEnabled);
    _persist();
    _applyToEngine();
  }

  void applyPreset(String presetName) {
    HapticFeedback.selectionClick();
    final gains = EqualizerModel.standardPresets[presetName];
    if (gains != null) {
      double boost = state.bassBoost;
      double virt = state.virtualizer;
      if (presetName == 'Flat / Studio Reference') {
        boost = 0.0;
        virt = 0.0;
      } else if (presetName == 'Vibrant Bass Boost') {
        boost = 0.70;
        virt = 0.25;
      } else if (presetName == 'Electronic & EDM') {
        boost = 0.65;
        virt = 0.40;
      } else if (presetName == 'Vocal Clarity') {
        boost = 0.15;
        virt = 0.35;
      }

      state = state.copyWith(
        presetName: presetName,
        bandGains: List<double>.from(gains),
        bassBoost: boost,
        virtualizer: virt,
      );
      _persist();
      _applyToEngine();
    }
  }

  void updateBandGain(int bandIndex, double gainDb) {
    if (bandIndex < 0 || bandIndex >= state.bandGains.length) return;
    final clamped = gainDb.clamp(-12.0, 12.0);
    final updatedGains = List<double>.from(state.bandGains);
    updatedGains[bandIndex] = clamped;

    state = state.copyWith(
      bandGains: updatedGains,
      presetName: 'Custom Profile',
    );
    _persist();
    _applyToEngine();
  }

  void updateBassBoost(double value) {
    state = state.copyWith(
      bassBoost: value.clamp(0.0, 1.0),
      presetName: 'Custom Profile',
    );
    _persist();
    _applyToEngine();
  }

  void updateVirtualizer(double value) {
    state = state.copyWith(
      virtualizer: value.clamp(0.0, 1.0),
      presetName: 'Custom Profile',
    );
    _persist();
    _applyToEngine();
  }

  void resetToFlat() {
    HapticFeedback.mediumImpact();
    applyPreset('Flat / Studio Reference');
  }
}

final equalizerProvider =
    NotifierProvider<EqualizerNotifier, EqualizerModel>(
  EqualizerNotifier.new,
);
