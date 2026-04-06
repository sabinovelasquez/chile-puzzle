# Zoom-In Chile

Mobile puzzle game (Flutter) with Node.js admin panel. Players solve jigsaw puzzles of real Chilean locations, earning points and trophies.

## Stack

- **App:** Flutter/Dart, Android-only (package: `cl.depointless.zoominchile`)
- **Admin:** Node.js/Express, vanilla HTML/JS, file-based JSON storage
- **Server:** DigitalOcean droplet, nginx reverse proxy, PM2, SSL
- **i18n:** ES/EN via `.arb` files, no hardcoded strings

## Project Layout

```
lib/
  main.dart                              # Entry, theme, localization, service init
  core/models/location_model.dart        # Location data model + JSON parsing
  core/models/player_progress.dart       # Progress model (points, puzzles, trophies)
  core/models/game_config.dart           # Config: zones, scoring, trophies
  core/models/trophy_model.dart          # Trophy model + conditions
  core/models/scoring_config.dart        # Scoring rules
  core/services/mock_backend.dart        # HTTP client → games.sabino.cl/zoominchile/api
  core/services/game_progress_service.dart # Progress persistence (SharedPreferences)
  core/services/audio_service.dart       # Sound effects + mute toggle
  core/theme/app_theme.dart              # Colors, theme constants
  features/ads/ad_service.dart           # AdMob interstitial ads
  features/auth/auth_service.dart        # Silent auth (Play Games / Game Center)
  features/map/map_screen.dart           # Location card grid, difficulty dialog
  features/puzzle/puzzle_engine.dart     # Drag & drop puzzle engine
  features/puzzle/puzzle_piece.dart      # Piece model (position, grid cell, state)
  features/puzzle/puzzle_screen.dart     # Fullscreen puzzle with timer, completion
  features/puzzle/completion_drawer.dart # Post-completion modal (points, tip, actions)
  features/profile/profile_screen.dart   # Stats, trophies, about, clear progress
  l10n/*.arb                             # Translation source files
  l10n/generated/                        # Auto-generated (flutter gen-l10n)

assets/
  sounds/place-piece.wav                 # SFX: piece snaps to correct position
  sounds/puzzle-finished-confetti.mp3    # SFX: puzzle completion celebration
  Zoom-In-Chile.png                      # App icon

admin-backend/
  server.js          # Express: CRUD APIs, image upload with HEIC→JPEG conversion
  data/              # JSON storage (locations, zones, trophies, scoring)
  public/            # Admin UI (index.html, app.js, style.css)
  public/uploads/    # Uploaded images
```

## App Flow

Grid → tap location card → difficulty dialog → PuzzleScreen → complete → confetti + sound → completion modal (points, tip, Google Maps link) → interstitial ad → back to grid

## Commands

```bash
# Flutter (binary not in PATH)
/Users/sabino/development/flutter/bin/flutter run              # Run on connected device/emulator
/Users/sabino/development/flutter/bin/flutter gen-l10n          # Regenerate l10n after .arb changes
/Users/sabino/development/flutter/bin/flutter build apk --release   # Release APK
/Users/sabino/development/flutter/bin/flutter build appbundle --release  # AAB for Google Play

# Admin backend (local dev)
cd admin-backend && node server.js                              # Serves on http://localhost:3000

# Deploy to server (CAUTION: patch port/bind/URL prefix after rsync)
scp admin-backend/server.js root@games.sabino.cl:/tmp/server.js.new
# Then SSH and sed: PORT→3001, bind→127.0.0.1, /uploads/→/zoominchile/uploads/
```

## Server / Production

- **Domain:** games.sabino.cl
- **App URLs:**
  - Admin: `https://games.sabino.cl/zoominchile/admin` (basic auth)
  - API: `https://games.sabino.cl/zoominchile/api/*` (no auth)
  - Uploads: `https://games.sabino.cl/zoominchile/uploads/*`
  - Downloads: `https://games.sabino.cl/zoominchile/downloads/zoominchile.apk`
  - Privacy: `https://games.sabino.cl/zoominchile/privacy`
  - Terms: `https://games.sabino.cl/zoominchile/terms`
- **Server config:** Port 3001, bind 127.0.0.1, PM2 process name `zoominchile`
- **Local dev:** Port 3000, bind 0.0.0.0 — NEVER rsync local server.js directly to production
- **HEIC conversion:** Uses `heif-convert` (libheif-examples) on server, NOT sharp
- **Node.js:** v20.20.2 on server

## Key Details

- Flutter SDK: `/Users/sabino/development/flutter/` (not in PATH)
- Android emulator: `http://10.0.2.2:3000` (dev), production: `https://games.sabino.cl/zoominchile`
- Release signing: keystore in `android/app/`, config in `android/key.properties` (not committed)
- l10n output: `lib/l10n/generated/` — import as `package:chile_puzzle/l10n/generated/app_localizations.dart`
- Timer starts after image loads (not on board init)
- Puzzle completion: confetti (flutter_confetti) + sound + completion modal
- Back button blocked after completion (forces exit through "Continue" button → ad)
- Location grid sorted: new unlocks → in progress → completed → locked
- Sound: piece placement (correct position only) + puzzle completion, mute persisted in SharedPreferences
- Ad test IDs used currently (replace for production)

## Google Play

- **Package:** cl.depointless.zoominchile
- **Developer:** Depointless
- **App name:** Zoom-In Chile
- **Category:** Game (Puzzle), Free
- **Privacy policy:** https://games.sabino.cl/zoominchile/privacy
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **App access:** All functionality available without restrictions (point-based unlocks are gameplay, not access restrictions)
- **Short description:** Discover Chile through puzzles. Real photos, real places. New locations weekly.
- **Content rating:** Everyone

## Conventions

- Language: code in English, user-facing strings via l10n only
- Keep admin KISS: vanilla JS, no build tools
- `generate: true` in pubspec.yaml enables auto l10n generation
- Credits: Photography by Sabino & Ximena, sounds by Vilkas Sound (CC BY 4.0)
