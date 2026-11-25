import 'package:soundwave/features/online/services/online_music_service.dart';
import 'package:soundwave/features/player/models/song_model.dart';

/// Keeps the play queue from turning into the same song played ten times.
///
/// Online searches return the original track plus jhankar, lo-fi, remix and
/// re-upload versions of it. Starting the queue from such a list makes "Up
/// Next" repeat one song, so this helper groups those versions into one family,
/// keeps at most a couple of them and lets the player top the queue up with
/// songs of a similar vibe (same artist, same genre, trending).
class QueueVariety {
  QueueVariety._();

  /// Words that describe a *version* of a song, not the song itself.
  static const Set<String> _noiseWords = {
    'jhankar',
    'jankar',
    'lofi',
    'lo',
    'fi',
    'slowed',
    'reverb',
    'remix',
    'mix',
    'version',
    'cover',
    'female',
    'male',
    'duet',
    'sad',
    'happy',
    'unplugged',
    'acoustic',
    'instrumental',
    'karaoke',
    'extended',
    'edit',
    'edited',
    'original',
    'audio',
    'video',
    'lyrical',
    'lyrics',
    'official',
    'full',
    'hd',
    'dj',
    'beat',
    'beats',
    'from',
    'movie',
    'film',
    'soundtrack',
    'ft',
    'feat',
    'song',
    'songs',
    'hindi',
    'bollywood',
    'trap',
    'reprise',
    'new',
    'old',
  };

  /// Normalised song name, ignoring bracketed text and version suffixes.
  static String familyKey(String title) {
    var text = title.toLowerCase();

    text = text.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), ' ');
    for (final separator in const [' - ', ' – ', ' — ', ' | ', '|']) {
      final index = text.indexOf(separator);
      if (index > 0) text = text.substring(0, index);
    }
    text = text.replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F]+'), ' ');
    final words = text
        .split(' ')
        .where((w) => w.isNotEmpty && !_noiseWords.contains(w))
        .toList();
    if (words.isEmpty) {
      // The title was nothing but version words: keep the raw title.
      return title.toLowerCase().trim();
    }
    return words.join(' ');
  }

  /// True when both songs are really the same track (original, remix, cover…).
  /// Titles are compared word by word so "Dil Mera Tod Diya" and "Dil Mera
  /// Tod Ke" are treated as one song instead of two.
  static bool sameFamily(SongModel a, SongModel b) {
    final left = familyKey(a.title);
    final right = familyKey(b.title);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;

    final shorter = left.length <= right.length ? left : right;
    final longer = left.length <= right.length ? right : left;
    if (shorter.length >= 14 && longer.contains(shorter)) return true;

    final leftWords = left.split(' ').where((w) => w.isNotEmpty).toSet();
    final rightWords = right.split(' ').where((w) => w.isNotEmpty).toSet();
    // Short titles ("Tum Hi Ho") must match exactly; fuzzy matching is only
    // safe once there are enough words to be meaningful.
    if (leftWords.length < 3 || rightWords.length < 3) return false;

    final common = leftWords.intersection(rightWords).length;
    final union = leftWords.union(rightWords).length;
    if (common < 3) return false;
    return common / union >= 0.6;
  }

  /// Drops extra versions of songs that are already queued, keeping only
  /// [maxPerFamily] of each. The song that is playing right now is always kept.
  static List<SongModel> trimRepeats(
    List<SongModel> songs, {
    String? currentId,
    int maxPerFamily = 1,
  }) {
    final kept = <SongModel>[];
    SongModel? current;
    if (currentId != null) {
      for (final song in songs) {
        if (song.id == currentId) {
          current = song;
          break;
        }
      }
    }

    for (final song in songs) {
      final isCurrent = currentId != null && song.id == currentId;
      // Only the version that is playing right now is kept for the current
      // song; its other versions (jhankar, lo-fi, covers) are dropped.
      if (!isCurrent && current != null && sameFamily(current, song)) continue;

      final inFamily = kept.where((k) => sameFamily(k, song)).length;
      if (!isCurrent && inFamily >= maxPerFamily) continue;
      kept.add(song);
    }
    return kept;
  }

  /// Songs that feel like [seed]: same artist first, then its genre, then
  /// trending tracks. Returns only distinct songs, never another version of
  /// the seed itself and never more than three songs by one artist.
  static Future<List<SongModel>> similarVibeSongs(
    SongModel seed, {
    int limit = 12,
  }) async {
    final candidates = <SongModel>[];

    if (!seed.isUnknownArtist) {
      final artist = seed.artist.split(',').first.split('&').first.trim();
      if (artist.isNotEmpty) {
        try {
          candidates.addAll(await OnlineMusicService.searchSongs(artist));
        } catch (_) {
          // Offline or the online library is unreachable: try the next source.
        }
      }
    }

    if (seed.genre.isNotEmpty && seed.genre.toUpperCase() != 'ONLINE') {
      try {
        candidates.addAll(await OnlineMusicService.getGenreSongs(seed.genre));
      } catch (_) {}
    }

    if (candidates.length < limit) {
      try {
        candidates.addAll(await OnlineMusicService.getTrendingSongs());
      } catch (_) {}
    }

    final picked = <SongModel>[];
    final usedIds = <String>{seed.id};

    for (final candidate in candidates) {
      if (picked.length >= limit) break;
      if (candidate.id.isEmpty || usedIds.contains(candidate.id)) continue;
      if (sameFamily(candidate, seed)) continue;
      if (picked.any((p) => sameFamily(p, candidate))) continue;

      final artistKey = _artistKey(candidate.artist);
      if (artistKey.isNotEmpty &&
          picked.where((p) => _artistKey(p.artist) == artistKey).length >= 3) {
        continue;
      }

      picked.add(candidate);
      usedIds.add(candidate.id);
    }

    return picked;
  }

  static String _artistKey(String artist) {
    return artist.split(',').first.split('&').first.trim().toLowerCase();
  }
}
