# 30 trofeos nuevos — propuesta

Pensados para escalar al milestone de 60 ubicaciones, llenar huecos en
la economía de puntos recalibrada (Easy → Locura, 0 → 30.000 pts), y
darle al jugador comprometido razones para volver. Diseñados leyendo:

- Trofeos existentes (29) — para no duplicar y mantener escalonado.
- `BACKLOG.md` — items que pueden quedar como semillas de trofeo.
- `CHANGELOG.md` — comportamientos que ya rastreamos pero no premiamos
  (compartir, favoritos, replays, zonas).
- `lib/core/models/player_progress.dart` — datos que tenemos guardados.

---

## Trofeos existentes hoy (29)

Ya cubierto:

| Categoría | Trofeos | Thresholds |
|---|---|---|
| `totalCompleted` | first, sharp_eye, five, ten, pathfinder, twenty, twentyfive, forty, fifty, seventyfive, hundred | 1, 3, 5, 10, 15, 20, 25, 40, 50, 75, 100 |
| `totalPoints` | century, two_fifty, five_hundred, thousand, two_thousand, three_thousand, five_thousand | 100, 250, 500, 1.000, 2.000, 3.000, 5.000 |
| `fastestTime` | quick_solver, speed_demon, lightning_fast, condor | ≤45, ≤30, ≤15, ≤10 s |
| `zoneAllCompleted` | zone_easy, zone_normal, zone_hard, zone_expert, zone_insane | una por zona |
| `noHelpCompleted` | lone_wolf, iron_will | 10, 20 |

Huecos identificados:
- `totalCompleted` techo en 100 (con 60 ubicaciones × 4 grillas = 240 max).
- `totalPoints` techo en 5.000, pero la economía nueva llega a ~30.000.
- `fastestTime` no tiene tiempos bajo 10 s (jugadores expertos los logran en 3×3).
- `noHelpCompleted` techo en 20.
- **Cero trofeos** para sharedLocationIds, favoriteLocationIds, ni grillas específicas (ej. completar 50 6×6).

---

## Plan: 30 trofeos nuevos

Divididos en dos grupos según viabilidad:

- **🟢 Sin release** (17): usan métricas que `checkNewTrophies()` ya soporta. Se agregan desde el admin y aparecen al próximo arranque del juego.
- **🟡 Con release** (13): requieren agregar 4 nuevas métricas al switch en `lib/core/services/game_progress_service.dart`. Sin nuevos campos en `PlayerProgress` — todo derivable de los datos existentes.

---

### 🟢 Sin release — 17 trofeos

#### Milestones de cantidad (`totalCompleted`)

Llenan el rango 100 → 240 (techo realista con 60 ubicaciones × 4 grillas).

| ID | Nombre ES | Nombre EN | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|
| `thirty_puzzles` | Andariego | Wanderer | 30 | `path` | Completa 30 puzzles |
| `sixty_puzzles` | Viajero del Sur | Voyager | 60 | `map_trifold` | Completa 60 puzzles |
| `ninety_puzzles` | Cartógrafo | Cartographer | 90 | `compass` | Completa 90 puzzles |
| `onefifty_puzzles` | Maestro Explorador | Master Explorer | 150 | `crown` | Completa 150 puzzles |
| `twohundred_puzzles` | Enciclopedia Viviente | Living Encyclopedia | 200 | `globe` | Completa 200 puzzles |
| `living_legend` | Leyenda Andina | Living Legend | 240 | `medal` | Completa todas las grillas de todas las ubicaciones |

#### Milestones de puntos (`totalPoints`)

Cubren el rango 5.000 → 30.000 con la economía recalibrada.

| ID | Nombre ES | Nombre EN | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|
| `seventyfive_hundred` | Aprendiz | Apprentice | 7.500 | `star` | Llega a 7.500 puntos |
| `ten_thousand` | Adepto | Adept | 10.000 | `diamond` | Llega a 10.000 puntos |
| `fifteen_thousand` | Conocedor | Connoisseur | 15.000 | `heart` | Llega a 15.000 puntos |
| `twenty_thousand` | Cofre Lleno | Treasure Vault | 20.000 | `shield` | Llega a 20.000 puntos |
| `twentyfive_thousand` | Realeza | Royal | 25.000 | `crown` | Llega a 25.000 puntos |
| `thirty_thousand` | Mítico | Mythical | 30.000 | `sun` | Llega a 30.000 puntos |

#### Velocidad (`fastestTime`)

Bajo 10 s solo es alcanzable en 3×3. Para hardcore.

| ID | Nombre ES | Nombre EN | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|
| `blink_of_eye` | Parpadeo | Blink | 7 | `lightning` | Termina un puzzle en menos de 7 segundos |
| `phantom` | Fantasma | Phantom | 5 | `rocket` | Termina un puzzle en menos de 5 segundos |

#### Sin ayuda (`noHelpCompleted`)

Techo actual 20 → escalamos a 100.

| ID | Nombre ES | Nombre EN | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|
| `purist` | Purista | Purist | 30 | `eye` | Completa 30 puzzles sin usar ayudas |
| `ascetic` | Asceta | Ascetic | 50 | `skull` | Completa 50 puzzles sin usar ayudas |
| `untouchable` | Intocable | Untouchable | 100 | `spiral` | Completa 100 puzzles sin usar ayudas |

---

### 🟡 Con release — 13 trofeos

Los 4 cases nuevos para `checkNewTrophies()` son derivaciones puras
(no agregan campos a `PlayerProgress`):

```dart
// 1. sharedCount — uses existing _progress.sharedLocationIds.length
case 'sharedCount':
  earned = _progress.sharedLocationIds.length >= (cond['threshold'] as int);

// 2. favoritesCount — uses existing _progress.favoriteLocationIds.length
case 'favoritesCount':
  earned = _progress.favoriteLocationIds.length >= (cond['threshold'] as int);

// 3. gridsCompletedAt — count puzzles whose key endsWith "_<difficulty>"
case 'gridsCompletedAt':
  final d = cond['difficulty'] as int;
  final n = _progress.completedPuzzles.keys.where((k) => k.endsWith('_$d')).length;
  earned = n >= (cond['threshold'] as int);

// 4. zonesCompletedCount — count zones where every location is completed
case 'zonesCompletedCount':
  final completed = _progress.completedLocationIds();
  final byZone = <String, Set<String>>{};
  for (final l in allLocations) {
    byZone.putIfAbsent(l.region, () => <String>{}).add(l.id);
  }
  int count = 0;
  for (final ids in byZone.values) {
    if (ids.isNotEmpty && ids.every(completed.contains)) count++;
  }
  earned = count >= (cond['threshold'] as int);
```

#### Compartir (`sharedCount`)

Toca el loop social que abrimos en 1.12.0 y refinamos en 1.12.5.

| ID | Nombre ES | Nombre EN | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|
| `first_postcard` | Primera Postal | First Postcard | 1 | `camera` | Comparte tu primera ubicación |
| `postcard_collector` | Coleccionista | Postcard Collector | 5 | `map_pin` | Comparte 5 ubicaciones distintas |
| `storyteller` | Cuentahistorias | Storyteller | 15 | `heart` | Comparte 15 ubicaciones distintas |
| `chile_ambassador` | Embajador de Chile | Chile Ambassador | 30 | `globe` | Comparte 30 ubicaciones distintas |

#### Favoritos (`favoritesCount`)

Premia construir tu mapa personal.

| ID | Nombre ES | Nombre EN | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|
| `curator` | Curador | Curator | 5 | `star` | Marca 5 ubicaciones como favoritas |
| `heart_map` | Mapa del Corazón | Heart Map | 15 | `heart` | Marca 15 ubicaciones como favoritas |

#### Maestría de grilla (`gridsCompletedAt`)

Trofeos por completar puzzles en una dificultad específica. Los
parámetros ahora incluyen `difficulty` además del `threshold`.

| ID | Nombre ES | Nombre EN | Difficulty | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|---|
| `gentle_walker` | Paseo Tranquilo | Gentle Walker | 3 | 60 | `plant` | Completa el nivel Fácil de las 60 ubicaciones |
| `eagle_eye` | Vista de Águila | Eagle Eye | 6 | 10 | `eye` | Completa 10 puzzles en grilla Experto (6×6) |
| `expert_hunter` | Cazador Experto | Expert Hunter | 6 | 25 | `target` | Completa 25 puzzles en grilla Experto |
| `master_of_six` | Maestro de las 36 piezas | Master of 36 | 6 | 50 | `skull` | Completa 50 puzzles en grilla Experto |

#### Zonas (`zonesCompletedCount`)

Zonas terminadas (suma de `zone_*` ya existentes, expresada como hito agregado).

| ID | Nombre ES | Nombre EN | Threshold | Icono | Descripción ES |
|---|---|---|---|---|---|
| `tri_zone` | Tres Frentes | Three Fronts | 3 | `flag` | Completa todas las ubicaciones de 3 zonas |
| `pentahedron` | Pentaedro | Pentahedron | 5 | `crown` | Completa todas las ubicaciones de las 5 zonas |

---

## Mapeo a fields del admin

Para cada trofeo, en la tab **Trophies** del admin:

```yaml
id: <id>
name: { en: ..., es: ... }
description: { en: ..., es: ... }
icon: <icon name>
type: milestone | speed | zone_complete
condition:
  metric: <metric>            # totalCompleted | totalPoints | fastestTime | noHelpCompleted | sharedCount | favoritesCount | gridsCompletedAt | zonesCompletedCount
  threshold: <int>
  difficulty: <int>           # solo para gridsCompletedAt
  zoneId: <string>            # solo para zone_complete
```

---

## Rollout sugerido

1. **Hoy mismo (sin release):** crear los 17 🟢 desde admin. Con eso ya cubres milestones hasta 240 puzzles, 30.000 pts, sub-5 s y 100 sin ayuda.
2. **Próximo release menor (~v1.13):** agregar los 4 cases nuevos en `checkNewTrophies()` + crear los 13 🟡 desde admin. Test rápido en closed testing antes de prod.
3. **Verificar `_trophyIcon()` en `lib/features/profile/profile_screen.dart`** — los iconos de esta propuesta ya están todos mapeados (verificado contra el switch existente). Sin ajustes necesarios.

---

## Resumen de viabilidad

| Categoría | Cantidad | Métrica usada | ¿Requiere release? |
|---|---|---|---|
| totalCompleted (milestones) | 6 | existente | ❌ No |
| totalPoints (milestones) | 6 | existente | ❌ No |
| fastestTime (velocidad) | 2 | existente | ❌ No |
| noHelpCompleted | 3 | existente | ❌ No |
| sharedCount | 4 | **nueva** | ✅ Sí |
| favoritesCount | 2 | **nueva** | ✅ Sí |
| gridsCompletedAt | 4 | **nueva** | ✅ Sí |
| zonesCompletedCount | 2 | **nueva** | ✅ Sí |
| **Total** | **30** | | 17 sin release / 13 con release |

Cero campos nuevos en `PlayerProgress`. Cero migraciones de datos. Solo
4 ramas nuevas en un switch.
