import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/library/utils/history_grouping.dart';
import 'package:soundwave/features/player/models/song_model.dart';

SongModel _song(String id) => SongModel(
      id: id,
      title: id,
      artist: 'Artist',
      duration: const Duration(seconds: 200),
      audioPath: 'audio/$id.mp3',
    );

void main() {
  final now = DateTime(2026, 11, 28, 20, 30);

  test('groups history into Today, Yesterday and Earlier', () {
    final times = <String, int>{
      'a': DateTime(2026, 11, 28, 9, 5).millisecondsSinceEpoch,
      'b': DateTime(2026, 11, 27, 23, 10).millisecondsSinceEpoch,
      'c': DateTime(2026, 11, 2, 18, 0).millisecondsSinceEpoch,
    };

    final sections = groupHistorySongs(
      [_song('a'), _song('b'), _song('c')],
      times,
      now: now,
    );

    expect(sections.map((s) => s.bucket).toList(), [
      HistoryBucket.today,
      HistoryBucket.yesterday,
      HistoryBucket.earlier,
    ]);
    expect(sections[0].songs.single.id, 'a');
    expect(sections[1].songs.single.id, 'b');
    expect(sections[2].songs.single.id, 'c');
  });

  test('songs without a saved time fall into Earlier', () {
    final sections = groupHistorySongs([_song('x')], const {}, now: now);
    expect(sections.single.bucket, HistoryBucket.earlier);
  });

  test('empty sections are dropped and order inside a section is kept', () {
    final times = <String, int>{
      'a': DateTime(2026, 11, 28, 10, 0).millisecondsSinceEpoch,
      'b': DateTime(2026, 11, 28, 11, 0).millisecondsSinceEpoch,
    };
    final sections = groupHistorySongs(
      [_song('a'), _song('b')],
      times,
      now: now,
    );
    expect(sections.length, 1);
    expect(sections.single.songs.map((s) => s.id).toList(), ['a', 'b']);
  });

  test('day boundary at midnight counts as yesterday', () {
    expect(
      historyBucketFor(
        DateTime(2026, 11, 27, 0, 0).millisecondsSinceEpoch,
        now: DateTime(2026, 11, 28, 0, 1),
      ),
      HistoryBucket.yesterday,
    );
  });

  test('formats the clock time for today and the date for older tracks', () {
    expect(
      formatPlayedTime(
        DateTime(2026, 11, 28, 21, 7).millisecondsSinceEpoch,
        now: now,
      ),
      '9:07 PM',
    );
    expect(
      formatPlayedTime(
        DateTime(2026, 11, 2, 8, 0).millisecondsSinceEpoch,
        now: now,
      ),
      '2 Nov',
    );
    expect(
      formatPlayedTime(
        DateTime(2025, 12, 31, 8, 0).millisecondsSinceEpoch,
        now: now,
      ),
      '31 Dec 2025',
    );
    expect(formatPlayedTime(null, now: now), '');
  });
}
