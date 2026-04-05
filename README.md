# Chile Puzzle Explorer

Juego móvil de puzzles fotográficos de lugares chilenos. Los jugadores resuelven rompecabezas, descubren datos culturales y exploran Chile desde el celular.

## Stack

- **App:** Flutter/Dart (Android & iOS)
- **Admin:** Node.js/Express, vanilla HTML/JS, JSON file storage
- **i18n:** ES/EN via `.arb` files

## Gameplay

1. Mapa con locaciones agrupadas por zona (región)
2. Seleccionar locación → elegir dificultad (3×3, 4×4, etc.)
3. Resolver puzzle con mecánica de swap (arrastrar pieza → intercambia con la del destino)
4. Al completar: puntos + bonus por tiempo y eficiencia + trofeos
5. Acumular puntos desbloquea nuevas zonas
6. Drawer con mapa, tip cultural y botón de compartir

## Features

- **Scoring:** Puntos base por dificultad + bonus por tiempo + bonus por eficiencia
- **Zonas:** Regiones que se desbloquean al acumular puntos
- **Trofeos:** Hitos como "primer puzzle", "500 puntos", "zona completa"
- **Perfil:** Stats + grid de trofeos ganados
- **Compartir:** Resultados y trofeos via share sheet
- **i18n:** Toggle EN/ES en app bar
- **Ads:** Interstitial ad al completar puzzle (AdMob)
- **Auth:** Silent sign-in (Play Games / Game Center)
- **Admin:** Panel web para gestionar locaciones, zonas, trofeos y scoring

## Setup

### Requisitos

- Flutter SDK
- Node.js
- Android Studio (emulador) o dispositivo físico
- API keys: Google Maps, AdMob

### Correr el proyecto

```bash
# Admin backend
cd admin-backend && node server.js
# → http://localhost:3000

# App Flutter
flutter run
```

El emulador Android conecta al backend via `http://10.0.2.2:3000`.

### Estructura

```
lib/
  main.dart                            # Entry point, theme, locale
  core/
    models/                            # LocationModel, GameConfig, PlayerProgress, etc.
    services/                          # MockBackend (HTTP), GameProgressService (persistence)
    theme/app_theme.dart               # Montserrat + Material 3 theme
  features/
    ads/ad_service.dart                # AdMob interstitial
    auth/auth_service.dart             # Silent auth
    map/map_screen.dart                # Zona list, location cards, difficulty picker
    profile/profile_screen.dart        # Stats + trophies
    puzzle/
      puzzle_engine.dart               # Swap-based puzzle with grid fade-out
      puzzle_piece.dart                # Piece model
      puzzle_screen.dart               # Wrapper with completion handling
      completion_drawer.dart           # Points, map, tip, share, continue
      icon_mapping.dart                # String → IconData mapping
  l10n/                                # ARB files + generated localizations

admin-backend/
  server.js                            # Express API
  data/                                # locations.json, zones.json, trophies.json, scoring.json
  public/                              # Admin UI + uploaded images
```

## Publicación

- [Google Play Store](docs/PLAYSTORE_GUIDE.md)
- [Apple App Store](docs/APPSTORE_GUIDE.md)

## Licencia

Proyecto privado.
