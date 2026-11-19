# SoundWave

A modern, offline-first Flutter music player with 320 kbps online streaming, high-resolution offline cover banner caching, background playback controls, and 5 dynamic OLED & neon themes.

## Live Demo

Try it in the browser: **[getsoundwave.vercel.app](https://getsoundwave.vercel.app)**

**Android app:** [Download the latest APK](https://github.com/codewithyogeshh/SoundWave-Feel-The-Music-/releases/latest) and install it on your phone to get offline downloads and local library scanning.

> The web build supports online streaming, search and playback. Downloads and local-device music scanning are mobile-only features, since browsers can't write to device storage or read the phone's music library.

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

Release APKs are built automatically by GitHub Actions: pushing a `v*` tag (or running the **Build APK** workflow manually) builds the APK and attaches it to a GitHub release.

## Author

Designed & built by **Yogesh Chavan** ([@codewithyogeshh](https://github.com/codewithyogeshh)).
