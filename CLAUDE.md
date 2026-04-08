# Zoom-In Chile

Mobile puzzle game (Flutter) with Node.js admin panel. Players solve jigsaw puzzles of real Chilean locations, earning points and trophies.

## Stack

- **App:** Flutter/Dart, Android-only (package: `cl.depointless.zoominchile`)
- **Admin:** Node.js/Express, vanilla HTML/JS, SQLite storage
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
  features/profile/profile_screen.dart   # Stats, trophies modal, about, clear progress
  features/leaderboard/leaderboard_screen.dart  # Ranking with confetti
  features/leaderboard/initials_input.dart      # 3-letter initials input dialog
  l10n/*.arb                             # Translation source files
  l10n/generated/                        # Auto-generated (flutter gen-l10n)

assets/
  sounds/place-piece.wav                 # SFX: piece snaps to correct position
  sounds/puzzle-finished-confetti.mp3    # SFX: puzzle completion celebration
  Zoom-In-Chile.png                      # App icon

admin-backend/
  server.js          # Express: CRUD APIs, image upload with HEIC→JPEG conversion
  db.js              # SQLite schema + helpers
  migrate.js         # JSON → SQLite migration (safe to rerun)
  data/              # SQLite database (database.sqlite) + legacy JSON
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

# Deploy backend to server
./deploy.sh                                                     # git pull + npm install + pm2 restart
```

## Server / Production

- **Domain:** games.sabino.cl
- **App URLs:**
  - Admin: `https://games.sabino.cl/zoominchile/admin` (basic auth)
  - API: `https://games.sabino.cl/zoominchile/api/*` (GET public, POST/PUT/DELETE require basic auth — except leaderboard POST)
  - Uploads: `https://games.sabino.cl/zoominchile/uploads/*`
  - Downloads: `https://games.sabino.cl/zoominchile/downloads/zoominchile.apk`
  - Privacy: `https://games.sabino.cl/zoominchile/privacy`
  - Terms: `https://games.sabino.cl/zoominchile/terms`
- **Server config:** Port 3001, bind 127.0.0.1, PM2 process name `zoominchile`
- **Local dev:** Port 3000, bind 0.0.0.0 — NEVER rsync local server.js directly to production
- **HEIC conversion:** Uses `heif-convert` (libheif-examples) on server, NOT sharp
- **Node.js:** v20.20.2 on server

## Release Process

```bash
# 1. Bump version in pubspec.yaml (e.g., 1.3.0+5 → 1.4.0+6)
#    +N is the versionCode (must increment for every Play Console upload)

# 2. Update version string in profile about dialog
#    lib/features/profile/profile_screen.dart — search for 'v1.x.x'

# 3. Build release AAB
/Users/sabino/development/flutter/bin/flutter build appbundle --release

# 4. Output: build/app/outputs/bundle/release/app-release.aab

# 5. Upload to Play Console:
#    Testing → Internal testing → Create new release → Upload AAB
#    Add release notes (en-US, es-419, es-ES, es-US)
#    Internal testing opt-in: https://play.google.com/apps/internaltest/4700433915880246135

# 6. Commit & push
git add -A && git commit -m "chore: bump version to X.Y.Z+N"
git push
```

### Content updates (no release needed)
- Locations, zones, trophies, scoring → managed via admin panel or API
- Trophies with existing metrics (totalCompleted, totalPoints, fastestTime, zoneAllCompleted) can be added without app changes
- 27 available Phosphor icons mapped in profile_screen.dart `_trophyIcon()`

### What requires a new release
- New trophy condition metrics (code change in game_progress_service.dart)
- UI changes, new screens, dependency updates
- AdMob ID changes

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
- **Track:** Internal testing (not production yet)
- **Internal testing link:** https://play.google.com/apps/internaltest/4700433915880246135
- **Privacy policy:** https://games.sabino.cl/zoominchile/privacy
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **App access:** All functionality available without restrictions (point-based unlocks are gameplay, not access restrictions)
- **Short description:** Discover Chile through puzzles. Real photos, real places. New locations weekly.
- **Content rating:** Everyone
- **Release notes languages:** en-US, es-419, es-ES, es-US

## Conventions

- Language: code in English, user-facing strings via l10n only
- Keep admin KISS: vanilla JS, no build tools
- `generate: true` in pubspec.yaml enables auto l10n generation
- Credits: Photography by Sabino & Ximena, sounds by Vilkas Sound (CC BY 4.0)
