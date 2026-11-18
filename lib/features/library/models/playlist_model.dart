import 'dart:convert';
import 'package:soundwave/features/player/models/song_model.dart';

class PlaylistModel {
  final String id;
  final String name;
  final String description;
  final String? coverImage;
  final List<SongModel> songs;
  final DateTime createdAt;
  final bool isCustom;

  const PlaylistModel({
    required this.id,
    required this.name,
    this.description = '',
    this.coverImage,
    this.songs = const [],
    required this.createdAt,
    this.isCustom = true,
  });

  int get songCount => songs.length;

  Duration get totalDuration => songs.fold(
        Duration.zero,
        (prev, song) => prev + song.duration,
      );

  PlaylistModel copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImage,
    List<SongModel>? songs,
    DateTime? createdAt,
    bool? isCustom,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImage': coverImage,
      'songs': songs.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isCustom': isCustom,
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> map) {
    return PlaylistModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      coverImage: map['coverImage'] as String?,
      songs: (map['songs'] as List<dynamic>?)
              ?.map((s) => SongModel.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isCustom: (map['isCustom'] as bool?) ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaylistModel.fromJson(String source) =>
      PlaylistModel.fromMap(json.decode(source) as Map<String, dynamic>);
}

