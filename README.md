# SoundWave

A modern, offline-first Flutter music player with 320 kbps online streaming, high-resolution offline cover banner caching, background playback controls, and 5 dynamic OLED & neon themes.

## Key Features

- **Single-Stream Audio Engine (`just_audio` + `audio_service`)**: Guaranteed single-track playback with monotonic generation tracking, audio focus handling, lockscreen / notification media controls, and zero overlapping playback.
- **Offline Downloads with Cover Banners**: Save tracks in-app or export to `/Music/SoundWave` alongside 500x500 cover banners cached locally for offline playback, UI rendering, and notification/lockscreen artwork.
- **5 Dynamic Luxury Themes**: Live theme switching across **Cyber Neon**, **Midnight Obsidian (OLED)**, **Royal Amethyst**, **Emerald Aurora**, and **Crimson Eclipse** with full Material 3 surface & accent synchronization.
- **Now Playing Studio**: Swipeable MiniPlayer (swipe left/right to skip), interactive Up Next queue, working Sleep Timer with live countdown, Equalizer presets, and Track Audio Specs.
- **Smart Library & Discovery**: Local device audio scanning (`on_audio_query`), multi-criteria filtering & sorting, custom playlists, favorites, and pull-to-refresh online feeds with offline fallback.

## Tech Stack

- **Framework**: Flutter (Material 3)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Audio & Media**: `just_audio`, `audio_service`, `audio_session`, `on_audio_query`
- **Storage & Caching**: `shared_preferences`, `path_provider`, `cached_network_image`

## Getting Started

```bash
# 1. Install dependencies
flutter pub get

# 2. Run static analysis
flutter analyze

# 3. Run unit & widget tests
flutter test

# 4. Run on a connected device
flutter run

# 5. Build release APK
flutter build apk --release
```

## Author

Designed & built by **Yogesh Chavan** ([@codewithyogeshh](https://github.com/codewithyogeshh)).
