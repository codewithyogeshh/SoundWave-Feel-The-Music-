import 'package:soundwave/features/player/models/song_model.dart';

/// Day bucket used to split the listening history into readable sections.
enum HistoryBucket { today, yesterday, earlier }

extension HistoryBucketLabel on HistoryBucket {
  String get label => switch (this) {
        HistoryBucket.today => 'Today',
        HistoryBucket.yesterday => 'Yesterday',
        HistoryBucket.earlier => 'Earlier',
      };
}

class HistorySection {
  final HistoryBucket bucket;
  final List<SongModel> songs;

  const HistorySection(this.bucket, this.songs);
}

DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

/// Which day section a song belongs to. Songs without a saved time (played
/// before this feature existed) fall into [HistoryBucket.earlier].
HistoryBucket historyBucketFor(int? playedAtMillis, {DateTime? now}) {
  if (playedAtMillis == null) return HistoryBucket.earlier;
  final current = _dayOf(now ?? DateTime.now());
  final played = _dayOf(DateTime.fromMillisecondsSinceEpoch(playedAtMillis));
  final days = current.difference(played).inDays;
  if (days <= 0) return HistoryBucket.today;
  if (days == 1) return HistoryBucket.yesterday;
  return HistoryBucket.earlier;
}

/// Groups songs into Today / Yesterday / Earlier, keeping the incoming order
/// inside each section and dropping empty sections.
List<HistorySection> groupHistorySongs(
  List<SongModel> songs,
  Map<String, int> playedTimes, {
  DateTime? now,
}) {
  final buckets = <HistoryBucket, List<SongModel>>{};
  for (final song in songs) {
    final bucket = historyBucketFor(playedTimes[song.id], now: now);
    buckets.putIfAbsent(bucket, () => <SongModel>[]).add(song);
  }

  return [
    for (final bucket in HistoryBucket.values)
      if ((buckets[bucket] ?? const <SongModel>[]).isNotEmpty)
        HistorySection(bucket, buckets[bucket]!),
  ];
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

/// Short label shown on the right of every history row: the time for today and
/// yesterday, the date for older tracks. Empty when the time is unknown.
String formatPlayedTime(int? playedAtMillis, {DateTime? now}) {
  if (playedAtMillis == null) return '';
  final current = now ?? DateTime.now();
  final played = DateTime.fromMillisecondsSinceEpoch(playedAtMillis);
  final bucket = historyBucketFor(playedAtMillis, now: current);

  if (bucket == HistoryBucket.earlier) {
    final date = '${played.day} ${_months[played.month - 1]}';
    return played.year == current.year ? date : '$date ${played.year}';
  }
  return _clockTime(played);
}
