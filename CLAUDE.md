# Chile Puzzle Explorer

Mobile puzzle game (Flutter) with Node.js admin panel. Players solve jigsaw puzzles of Chilean locations on a map.

## Stack

- **App:** Flutter/Dart (Android & iOS target, web stub exists)
- **Admin:** Node.js/Express, vanilla HTML/JS, file-based JSON storage
- **i18n:** ES/EN via `.arb` files, no hardcoded strings

## Project Layout

```
lib/
  main.dart                          # Entry point, theme, localization config
  core/models/location_model.dart    # Location data model + JSON parsing
  core/services/mock_backend.dart    # HTTP client → localhost:3000/api/locations
  features/ads/ad_service.dart       # AdMob interstitial ads
  features/auth/auth_service.dart    # Silent auth (Play Games / Game Center)
  features/map/map_screen.dart       # Google Maps with location markers
  features/puzzle/puzzle_engine.dart # Drag & drop puzzle engine (snap=20px)
  features/puzzle/puzzle_piece.dart  # Piece model (position, grid cell, state)
  features/puzzle/puzzle_screen.dart # Wrapper screen hosting PuzzleEngine
  l10n/*.arb                         # Translation source files
  l10n/generated/                    # Auto-generated (flutter gen-l10n)

admin-backend/
  server.js          # Express: GET/POST /api/locations, POST /api/upload
  data/locations.json # All location data (bilingual)
  public/            # Admin UI (index.html, app.js, style.css)
  public/uploads/    # Uploaded images
```

## App Flow

Map → tap marker → PuzzleScreen → complete puzzle → tip dialog → interstitial ad → back to map

## Commands

```bash
# Flutter (binary not in PATH)
/Users/sabino/development/flutter/bin/flutter run          # Run on connected device/emulator
/Users/sabino/development/flutter/bin/flutter gen-l10n      # Regenerate l10n after .arb changes

# Admin backend
cd admin-backend && node server.js                          # Serves on http://localhost:3000
```

## Key Details

- Flutter SDK: `/Users/sabino/development/flutter/` (not in PATH)
- Android emulator connects to admin via `http://10.0.2.2:3000`, web/iOS via `http://127.0.0.1:3000`
- l10n output goes to `lib/l10n/generated/` (not synthetic package)
- Import localizations as `package:chile_puzzle/l10n/generated/app_localizations.dart`
- Location data model: `{ id, name:{en,es}, region, latitude, longitude, image, thumbnail, tip:{en,es}, difficulty:[int] }`
- Puzzle grid size driven by `difficulty` array from admin
- Ad test IDs used currently (replace for production)
- PRD in `puzzle.PRD`

## Conventions

- Language: code in English, user-facing strings via l10n only
- Keep admin KISS: vanilla JS, no build tools
- `generate: true` in pubspec.yaml enables auto l10n generation
