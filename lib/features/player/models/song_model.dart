import 'dart:convert';

enum AudioSourceType { asset, file, network }

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String audioPath;
  final AudioSourceType sourceType;
  final String? artworkPath;
  final int? albumId; // For Android on_audio_query native artwork
  final int? rawId; // Song ID in MediaStore for OnAudioQuery Audio artwork
  final bool isLocal;
  final bool isFavorite;
  final String genre;
  final bool isHd;
  final DateTime? dateAdded;
  final int? fileSize; // in bytes

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    this.album = 'SoundWave Originals',
    required this.duration,
    required this.audioPath,
    this.sourceType = AudioSourceType.asset,
    this.artworkPath,
    this.albumId,
    this.rawId,
    this.isLocal = false,
    this.isFavorite = false,
    this.genre = 'Pop',
    this.isHd = true,
    this.dateAdded,
    this.fileSize,
  });

  String get fileSizeFormatted {
    if (fileSize == null || fileSize! <= 0) return '';
    final mb = fileSize! / (1024 * 1024);
    if (mb >= 1.0) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = fileSize! / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  bool get isUnknownArtist {
    final clean = artist.trim().toLowerCase();
    return clean.isEmpty ||
        clean == 'unknown' ||
        clean == 'unknown artist' ||
        clean == '<unknown>' ||
        clean == 'device storage';
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? audioPath,
    AudioSourceType? sourceType,
    String? artworkPath,
    int? albumId,
    int? rawId,
    bool? isLocal,
    bool? isFavorite,
    String? genre,
    bool? isHd,
    DateTime? dateAdded,
    int? fileSize,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      audioPath: audioPath ?? this.audioPath,
      sourceType: sourceType ?? this.sourceType,
      artworkPath: artworkPath ?? this.artworkPath,
      albumId: albumId ?? this.albumId,
      rawId: rawId ?? this.rawId,
      isLocal: isLocal ?? this.isLocal,
      isFavorite: isFavorite ?? this.isFavorite,
      genre: genre ?? this.genre,
      isHd: isHd ?? this.isHd,
      dateAdded: dateAdded ?? this.dateAdded,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': duration.inMilliseconds,
      'audioPath': audioPath,
      'sourceType': sourceType.index,
      'artworkPath': artworkPath,
      'albumId': albumId,
      'rawId': rawId,
      'isLocal': isLocal,
      'isFavorite': isFavorite,
      'genre': genre,
      'isHd': isHd,
      'dateAddedMs': dateAdded?.millisecondsSinceEpoch,
      'fileSize': fileSize,
    };
  }

  factory SongModel.fromMap(Map<String, dynamic> map) {
    return SongModel(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: (map['album'] as String?) ?? 'SoundWave Originals',
      duration: Duration(milliseconds: (map['durationMs'] as int?) ?? 0),
      audioPath: map['audioPath'] as String,
      sourceType: AudioSourceType.values[(map['sourceType'] as int?) ?? 0],
      artworkPath: map['artworkPath'] as String?,
      albumId: map['albumId'] as int?,
      rawId: map['rawId'] as int?,
      isLocal: (map['isLocal'] as bool?) ?? false,
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      genre: (map['genre'] as String?) ?? 'Pop',
      isHd: (map['isHd'] as bool?) ?? true,
      dateAdded: map['dateAddedMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateAddedMs'] as int)
          : null,
      fileSize: map['fileSize'] as int?,
    );
  }

  String toJson() => json.encode(toMap());

  factory SongModel.fromJson(String source) =>
      SongModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
