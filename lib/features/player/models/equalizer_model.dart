class EqualizerModel {
  static const List<String> bandLabels = [
    '60 Hz',
    '230 Hz',
    '910 Hz',
    '3.6 kHz',
    '14 kHz',
  ];

  static const List<String> bandDescriptions = [
    'Sub-Bass',
    'Bass',
    'Midrange',
    'Presence',
    'Brilliance',
  ];

  static const Map<String, List<double>> standardPresets = {
    'Flat / Studio Reference': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Vibrant Bass Boost': [5.5, 4.0, -1.0, 2.0, 3.5],
    'Vocal Clarity': [-2.0, 1.0, 5.0, 4.0, 2.0],
    'Treble Booster': [-2.0, -1.0, 1.5, 4.5, 6.0],
    'Electronic & EDM': [5.0, 3.5, 0.0, 3.0, 5.0],
    'Acoustic Warmth': [3.0, 2.5, 1.0, 2.0, 1.0],
    'Rock & Metal': [4.5, 2.5, -2.0, 3.5, 4.5],
    'Lo-Fi Chill': [4.0, 3.0, 0.0, -2.0, -3.5],
  };

  final bool isEnabled;
  final String presetName;
  final List<double> bandGains; // 5 values from -12.0 to +12.0 dB
  final double bassBoost; // 0.0 to 1.0
  final double virtualizer; // 0.0 to 1.0

  const EqualizerModel({
    this.isEnabled = true,
    this.presetName = 'Vibrant Bass Boost',
    this.bandGains = const [5.5, 4.0, -1.0, 2.0, 3.5],
    this.bassBoost = 0.65,
    this.virtualizer = 0.30,
  });

  EqualizerModel copyWith({
    bool? isEnabled,
    String? presetName,
    List<double>? bandGains,
    double? bassBoost,
    double? virtualizer,
  }) {
    return EqualizerModel(
      isEnabled: isEnabled ?? this.isEnabled,
      presetName: presetName ?? this.presetName,
      bandGains: bandGains ?? List<double>.from(this.bandGains),
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'presetName': presetName,
      'bandGains': bandGains,
      'bassBoost': bassBoost,
      'virtualizer': virtualizer,
    };
  }

  factory EqualizerModel.fromMap(Map<String, dynamic> map) {
    final rawGains = map['bandGains'] as List<dynamic>?;
    final gains = rawGains != null
        ? rawGains.map((e) => (e as num).toDouble()).toList()
        : const [5.5, 4.0, -1.0, 2.0, 3.5];

    return EqualizerModel(
      isEnabled: map['isEnabled'] as bool? ?? true,
      presetName: map['presetName'] as String? ?? 'Vibrant Bass Boost',
      bandGains: gains.length == 5 ? gains : const [5.5, 4.0, -1.0, 2.0, 3.5],
      bassBoost: (map['bassBoost'] as num?)?.toDouble() ?? 0.65,
      virtualizer: (map['virtualizer'] as num?)?.toDouble() ?? 0.30,
    );
  }
}
