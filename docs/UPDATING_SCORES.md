# Cómo actualizar puntajes y niveles — Zoom-In Chile

Guía para mantener coherente el sistema de puntos al subir nuevas
ubicaciones, agregar trofeos o recalibrar la economía del juego.
Pensada para Xime y Sabino. Sin tecnicismos, paso a paso.

---

## 1. Conceptos rápidos

| Concepto | Qué es | Dónde se cambia |
|---|---|---|
| **Grilla** (3/4/5/6) | La dificultad del rompecabezas: 3 columnas (fácil) hasta 6 (experto). El jugador la elige al jugar. | No se configura. Se aplica a todas las ubicaciones por igual. |
| **Zona** (Fácil → Locura) | Etiqueta visual de cada ubicación. Solo recomienda el puntaje de desbloqueo. **No** bloquea grillas. | Editor de ubicación → "Zona". |
| **Puntos para desbloquear** (`requiredPoints`) | El puntaje total que el jugador debe acumular para que una ubicación aparezca disponible. | Editor de ubicación → "Puntos para desbloquear". |
| **Puntos base por grilla** | Cuántos puntos otorga completar una grilla. Hoy: 50/100/200/350 para 3/4/5/6. | Tab Scoring del admin. |
| **Time bonus** | +50 si terminas en menos de 60 s. | Tab Scoring. |
| **Efficiency bonus** | +20% del base si haces el puzzle con pocos movimientos. | Tab Scoring. |

---

## 2. Subir una ubicación nueva

1. **Mira la foto.** ¿Qué tan obvia es la silueta del lugar? ¿Tiene mucha textura repetida (cielo, árboles, mar)? ¿Colores planos o variados?
2. **Elige la zona** según la dificultad visual:

| Zona | Para qué fotos | Rango sugerido | Hoy | Meta 60 |
|---|---|---|---|---|
| 🟢 **Fácil** | Edificios reconocibles, fachadas con contraste, símbolos claros. | 0 – 250 | 6 | 12 |
| 🟡 **Normal** | Paisajes con un punto focal, calles con detalles únicos. | 400 – 1.500 | 7 | 18 |
| 🔵 **Difícil** | Texturas repetitivas, vegetación densa, planos cerrados. | 2.000 – 5.000 | 6 | 12 |
| 🟣 **Experto** | Patrones casi uniformes, fotos abstractas, colores muy similares. | 6.000 – 11.000 | 9 | 12 |
| 🔴 **Locura** | Casi imposibles a simple vista. Reservada para 2-3 ubicaciones especiales. | 13.000 – 20.000 | 2 | 6 |
| **Total** | | | **30** | **60** |

3. **Asigna "Puntos para desbloquear"** dentro del rango sugerido.
   - Por defecto, el editor te muestra valores tipo (datalist) cuando seleccionas la zona. Puedes elegir uno o tipear cualquier número.
   - Si pones un valor fuera del rango, el sistema te avisa con una pregunta de confirmación. **No** te bloquea — solo se asegura de que sea intencional.
4. **No te confundas con la grilla.** La zona NO restringe grillas. El jugador siempre puede jugar 3×3, 4×4, 5×5 o 6×6 en cualquier ubicación.

**Regla de oro:** si dudas entre dos zonas vecinas, elige la más baja. Es mejor que el jugador descubra un lugar fácil de lo que pensabas a quedar trabado pidiendo demasiados puntos.

### Milestones a largo plazo

A un ritmo de **3–5 ubicaciones nuevas por semana** (≈16/mes), la distribución sugerida por zona en cada milestone:

| Milestone | Cuándo | 🟢 Fácil | 🟡 Normal | 🔵 Difícil | 🟣 Experto | 🔴 Locura | **Total** |
|---|---|---|---|---|---|---|---|
| Hoy | 2026-04 | 6 | 7 | 6 | 9 | 2 | **30** |
| **M60** | ~2 meses | 12 | 18 | 12 | 12 | 6 | **60** |
| **M90** | ~4 meses | 16 | 26 | 18 | 22 | 8 | **90** |
| **M120** | ~6 meses | 20 | 34 | 26 | 30 | 10 | **120** |
| **M180** | ~9 meses | 24 | 50 | 38 | 50 | 18 | **180** |
| **M240** | ~12 meses | 28 | 64 | 54 | 70 | 24 | **240** |

Lectura rápida:
- **Easy** crece poco a poco — el onboarding es finito; con 28 lugares fáciles ya hay sobra para que cualquier jugador nuevo se enganche.
- **Normal** es el caballo de tiro: la mayoría de fotos cae acá y el jugador pasa la mayor parte del tiempo en esta zona.
- **Hard** crece proporcionalmente, sirve de puente al Experto.
- **Experto** es el escalón de prestigio — debe ser denso (28-70) para que el techo del juego se sienta real.
- **Locura** se mantiene escasa: 6 al M60, 24 al M240. Demasiados rompen la sensación de "imposible".

Si la cadencia real cae a 3/semana, todos los hitos se recorren ≈25% más tarde; si sube a 5/semana, llegan ≈25% antes.

---

## 3. Cómo recalibrar puntajes existentes

Si decides cambiar la escala (ej. el primer Locura debería costar más, o las nuevas Experto deberían arrancar más alto), sigue este orden:

1. **Confirma la nueva escala con Sabino.** Cambiar gates puede sacar ubicaciones que jugadores ya tenían "abiertas" (les desaparecen de la vista hasta volver a alcanzar el puntaje). Eso afecta a usuarios reales.
2. **Documenta los nuevos rangos** acá en este archivo — actualiza la tabla de la sección 2.
3. **Revisa los trofeos por puntos** (Tab Trophies → filtra por type=milestone, metric=totalPoints):
   - Si subes el techo de Locura de 20.000 a 30.000, agrega trofeos intermedios para que la escalera siga sintiéndose densa.
   - Si bajas los gates, los trofeos viejos se vuelven triviales — considera retirarlos (cambiar `active=false`) o subir sus thresholds.
4. **Actualiza ubicaciones una por una** desde el admin (Tab Locations). El editor te muestra el rango sugerido al cambiar zona, así que es manual pero rápido.

> ⚠️ **Importante:** los puntos de las ubicaciones (`requiredPoints`) se editan ubicación por ubicación. No hay un botón "recalibrar todo". Para 60 ubicaciones tomará ~30 minutos en una sentada.

---

## 4. Cómo agregar trofeos (sin app release)

Ya hay 5 métricas que la app sabe leer **sin necesidad de un nuevo build**:

| Métrica | Qué cuenta | Ejemplo |
|---|---|---|
| `totalCompleted` | Cantidad total de puzzles completados (cada combinación ubicación + grilla cuenta una vez). | "Completa 100 puzzles" → threshold=100 |
| `totalPoints` | Puntos acumulados. | "Llega a 10.000 pts" → threshold=10000 |
| `fastestTime` | Tu tiempo más rápido (en segundos). El trofeo se desbloquea cuando bajas de ese tiempo. | "Termina algún puzzle en menos de 10 s" → threshold=10 |
| `zoneAllCompleted` | Completar todas las ubicaciones de una zona específica. | Trofeo "zone_easy" cuando terminas todas las Fácil. |
| `noHelpCompleted` | Cuántos puzzles terminaste sin usar ninguna ayuda (ni "fijar piezas", ni "selección múltiple", ni "ver foto referencia"). | "20 puzzles sin ayuda" → threshold=20 |

**Para agregar un trofeo nuevo con estas métricas:**

1. Admin → tab **Trophies** → "Add new".
2. Llena:
   - `id` (sin espacios, en inglés, ej. `master_explorer`).
   - Nombre EN/ES.
   - Descripción EN/ES.
   - Icono (ver lista en sección 5).
   - Tipo: `milestone`, `speed`, o `zone_complete`.
   - Métrica + threshold (o zoneId si es `zone_complete`).
3. Save. **Aparece automáticamente en el siguiente arranque de la app** del jugador.

**Para agregar un trofeo con métrica nueva** (ej. "comparte 10 ubicaciones"):
- Requiere release de app. Sabino debe modificar `lib/core/services/game_progress_service.dart` → función `checkNewTrophies()` → agregar el case en el switch.
- Buenas candidatas (datos que ya tracking pero sin trofeos hoy):
  - `sharedCount` — número de ubicaciones compartidas.
  - `favoritesCount` — número de favoritos.
  - `expertGridsCompleted` — puzzles 6×6 completados.
  - `zonesCompletedCount` — cantidad de zonas terminadas (1-5).

---

## 5. Iconos disponibles para trofeos

Cualquier nombre de la columna izquierda funciona como icono al crear/editar un trofeo. Los íconos son de [Phosphor](https://phosphoricons.com/), estilo "Fill". Para agregar uno nuevo a esta lista hay que tocar `lib/features/profile/profile_screen.dart` (función `_trophyIcon`) y hacer release.

| Nombre | Mejor para | Nombre | Mejor para |
|---|---|---|---|
| `trophy` | Logros generales | `crown` | Top tier, completista |
| `star` | Hitos cualquiera | `medal` | Reconocimiento |
| `lightning` (o `bolt`) | Velocidad | `diamond` | Logro raro/valioso |
| `timer` | Tiempo récord | `flame` / `fire` | Racha caliente |
| `flag` | Hito alcanzado | `rocket` | Velocidad extrema |
| `puzzle_piece` | Cantidad de puzzles | `eye` | Observación, sin ayuda |
| `mountains` (o `hiking`/`landscape`) | Aventurero | `globe` | Llegar lejos, mundial |
| `compass` (o `explore`) | Explorador | `map_pin` | Lugar específico |
| `path` | Camino recorrido | `camera` | Foto / compartir |
| `binoculars` | Observador, descubrir | `heart` | Favoritos |
| `sun` | Luminoso, alto puntaje | `shield` | Defensor, completista |
| `map_trifold` | Cartógrafo | `target` | Precisión |
| `hand_pointing` | Interacción/click | `plant` | Inicio, fácil |
| `skull` | Experto extremo | `spiral` | Locura, infinito |

---

## 6. Errores comunes y cómo evitarlos

| Síntoma | Causa probable | Solución |
|---|---|---|
| Una ubicación nueva no aparece en el juego. | Marcaste estado "Borrador" o "Programar para…" con fecha futura. | Cambia a "Publicar ahora". |
| Dos ubicaciones de la misma zona tienen el mismo `requiredPoints`. | Default por defecto (la primera opción del bucket). | Distribuye los puntos dentro del rango. Si una es más linda o más representativa, dale un puntaje más bajo (aparece antes). |
| Un trofeo nuevo no se desbloquea. | El threshold es muy alto, o la métrica no coincide con lo que el jugador hace. | Reduce el threshold para probar. Verifica que la métrica esté en la lista de la sección 4. |
| Cambié los puntos y un jugador me reportó que "perdió" una ubicación. | Subiste el `requiredPoints` por encima de lo que el jugador acumuló. | Decide: revierte el cambio, o avisa que es esperado. Coordina con Sabino antes de cambios masivos. |
| El jugador ve "Puntos para desbloquear" pero ya tiene los puntos. | Caché en su teléfono. La app sincroniza al abrir el mapa. | Que cierre y abra la app. |

---

## 7. Cuando algo amerita avisar a Sabino

- Quieres recalibrar más de 5 ubicaciones a la vez.
- Cambias el `basePoints` o cualquier valor en Tab Scoring.
- Quieres agregar un trofeo que necesita una métrica nueva (sección 4).
- Algo no se está mostrando como esperabas en la app.

Para todo lo demás (subir ubicaciones, ajustar puntos individuales, programar publicaciones, agregar trofeos con métricas existentes): adelante.
