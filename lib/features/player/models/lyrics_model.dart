class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '[${timestamp.inSeconds}s] $text';
}

class LyricsData {
  final List<LyricLine> lines;
  final bool isSynced;
  final String? songId;

  /// True when these lyrics were served from the on-device cache instead of a
  /// fresh network fetch.
  final bool fromCache;

  const LyricsData({
    required this.lines,
    this.isSynced = false,
    this.songId,
    this.fromCache = false,
  });

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  LyricsData copyWith({bool? fromCache}) => LyricsData(
        lines: lines,
        isSynced: isSynced,
        songId: songId,
        fromCache: fromCache ?? this.fromCache,
      );

  /// Moves every timestamp by [offset] so the user can re-sync lyrics that the
  /// provider timed slightly early or late. Lines never go below zero, and the
  /// result stays sorted so [getActiveLineIndex] keeps working.
  LyricsData shifted(Duration offset) {
    if (offset == Duration.zero || lines.isEmpty) return this;

    final shiftedLines = lines
        .map((line) {
          final timestamp = line.timestamp + offset;
          return LyricLine(
            timestamp: timestamp.isNegative ? Duration.zero : timestamp,
            text: line.text,
          );
        })
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return LyricsData(
      lines: shiftedLines,
      isSynced: isSynced,
      songId: songId,
      fromCache: fromCache,
    );
  }

  int getActiveLineIndex(Duration currentPosition) {
    if (lines.isEmpty) return -1;
    // If before first line
    if (currentPosition < lines.first.timestamp) return 0;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  static LyricsData parseLrc(String rawContent, {String? songId}) {
    if (rawContent.trim().isEmpty) {
      return LyricsData(lines: const [], isSynced: false, songId: songId);
    }

    final parsedLines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)');
    final rawLines = rawContent.split('\n');

    for (final raw in rawLines) {
      final match = regExp.firstMatch(raw.trim());
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final millisStr = match.group(3) ?? '0';
        final millis = int.tryParse(millisStr.padRight(3, '0').substring(0, 3)) ?? 0;

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          parsedLines.add(LyricLine(timestamp: duration, text: text));
        }
      }
    }

    if (parsedLines.isNotEmpty) {
      // Sort by timestamp just in case
      parsedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return LyricsData(lines: parsedLines, isSynced: true, songId: songId);
    }

    // Fallback: plain text without timestamps
    final plainLines = rawLines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('['))
        .map((l) => LyricLine(timestamp: Duration.zero, text: l))
        .toList();

    return LyricsData(lines: plainLines, isSynced: false, songId: songId);
  }
}
