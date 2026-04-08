# Zoom-In Chile

Juego móvil de puzzles fotográficos de lugares reales de Chile. Los jugadores resuelven rompecabezas, descubren datos culturales y exploran Chile desde el celular.

## Stack

- **App:** Flutter/Dart, Android-only (package: `cl.depointless.zoominchile`)
- **Admin:** Node.js/Express, vanilla HTML/JS, SQLite
- **Server:** DigitalOcean droplet, nginx reverse proxy, PM2, SSL
- **i18n:** ES/EN via `.arb` files

## Gameplay

1. Grid con ubicaciones organizadas por dificultad (Fácil → Locura)
2. Seleccionar ubicación → elegir dificultad (3 a 6 piezas)
3. Resolver puzzle arrastrando piezas a su posición correcta
4. Al completar: confetti + sonido + puntos (base + bonus tiempo + bonus eficiencia)
5. Acumular puntos desbloquea nuevas ubicaciones
6. Modal con tip cultural, link a Google Maps, agregar a favoritos

## Features

- **27 trofeos** en 5 categorías: completados, puntos, velocidad, zonas, especiales
- **Ranking:** Leaderboard global con iniciales estilo arcade
- **5 zonas de dificultad:** Fácil, Normal, Difícil, Experto, Locura
- **Filtros:** Todos, Nuevos, En progreso, Completados, Favoritos + por zona
- **Perfil:** Stats, trofeos en modal dedicado, progreso total
- **i18n:** ES/EN, toggle desde perfil
- **Ads:** Interstitial ad al completar puzzle (AdMob)
- **Sonidos:** Pieza correcta + puzzle completado, mute persistente
- **Admin:** Panel web para gestionar ubicaciones, zonas, trofeos y scoring

## Setup

### Requisitos

- Flutter SDK
- Node.js
- Android Studio o dispositivo físico
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

## Estructura

```
lib/
  main.dart                              # Entry, theme, localization
  core/
    models/                              # Location, GameConfig, PlayerProgress, Trophy, Scoring
    services/                            # MockBackend (HTTP), GameProgressService, AudioService
    theme/app_theme.dart                 # Colors, theme constants
  features/
    ads/ad_service.dart                  # AdMob interstitial
    auth/auth_service.dart               # Silent auth (Play Games)
    map/map_screen.dart                  # Location grid, filters, difficulty dialog
    profile/profile_screen.dart          # Stats, trophies modal, about
    puzzle/                              # Engine, screen, completion drawer
    leaderboard/                         # Ranking screen, initials input
  l10n/                                  # ARB files + generated localizations

admin-backend/
  server.js                              # Express API + CRUD
  db.js                                  # SQLite schema
  data/database.sqlite                   # Production data
  public/                                # Admin UI + uploads
```

## Licencia

Proyecto privado.
