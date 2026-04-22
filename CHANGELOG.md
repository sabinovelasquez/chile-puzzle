# Zoom-In Chile — Changelog

Release notes for the Zoom-In Chile mobile app. Each version matches
`pubspec.yaml` (`<semver>+<build>`) and is the source of truth that
the admin backend reads to auto-populate release notes when sending
emails to testers.

New releases go on top. Each entry has an `**ES**` and `**EN**`
sub-block with one bullet per line.

## 1.12.0+20 — 2026-04-22

**ES**
- Ahora podés compartir tus puzzles: al terminar un puzzle o al abrir "Ver completados" aparece un botón Compartir. Encuadra tu foto en 1:1, escuchá el clic de la cámara, y mirá tu polaroid deslizarse al centro — con la silueta de Xime y gato en la esquina y el tip del nivel debajo.
- La vista para encuadrar trae un tono sepia y una viñeta suaves; la foto que compartís sale en color completo y nítida.
- Pellizcá para acercarte (hasta 10x) y arrastrá para encuadrar. La foto queda pegada a los bordes — no se sale del marco.
- Se comparte el dato del nivel actual (si abrís la foto desde un nivel Fácil, va el tip de Fácil; no siempre el de Experto).

**EN**
- You can now share your puzzles: when you finish one or open "Ver completados", a Share button shows up. Frame your photo in 1:1, hear the shutter, and watch your polaroid slide into place — Xime-and-cat silhouette in the corner, level tip underneath.
- The framing view has a soft sepia tint and a gentle vignette; the image you share comes out full-colour and sharp.
- Pinch to zoom in (up to 10×) and drag to frame. The photo stays locked to its edges — it can't drift past the frame.
- The shared tip matches the level you're viewing (open an Easy photo, you share the Easy tip; no more defaulting to Expert).

## 1.11.2+19 — 2026-04-22

**ES**
- Integración real de AdMob: los anuncios ya no son de prueba.

**EN**
- Real AdMob integration: ads are no longer test placeholders.

## 1.11.1+18 — 2026-04-18

**ES**
- Foto de referencia y foto final ahora llenan la pantalla de borde a borde, sin franjas negras en teléfonos altos.
- Nuevo control en el tip: desliza para ajustar el tamaño del texto a tu gusto; la preferencia se recuerda.
- Toggle de brillo del tip movido al mismo panel del tamaño de texto.
- Botones del puzzle completado rediseñados: contornos suaves en pastel y menos espacio vertical.
- Pequeño ajuste de copy en "Acerca de" ("viajes" → "aventuras").

**EN**
- Reference and completion photos now fill the screen edge-to-edge, no black bars on tall phones.
- New tip control: slide to adjust text size to your liking; your preference is remembered.
- Tip shine toggle moved into the same panel as the text-size slider.
- Completion buttons redesigned: soft pastel outlines with tighter vertical spacing.
- Small "About" copy tweak ("travels" → "adventures").

## 1.11.0+17 — 2026-04-15

**ES**
- Nueva opción en Ajustes: "Ranking global" (apagada por defecto). Al activarla, tus puntajes se envían automáticamente al ranking. Tus iniciales aparecen subrayadas — un toque las cambia.
- Al terminar un puzzle con el ranking automático activo, el botón "Ver ranking" sólo aparece si entraste al Top 10 de ese nivel.
- Nuevo botón "Ver ranking" en el selector de dificultad de cada ubicación.
- La foto de referencia se cierra sola después de 5 segundos; un anillo alrededor del ícono de cerrar muestra la cuenta regresiva.
- El botón de ayuda es transparente mientras se recarga y se vuelve blanco con destello cuando está listo.
- Ícono "ranking" unificado en Ajustes, Perfil y todos los botones de ver/ingresar al ranking.

**EN**
- New Settings option: "Global ranking" (off by default). When on, your scores are sent to the ranking silently. Your initials show underlined — tap to change them.
- With auto-ranking on, the "View ranking" button at puzzle completion appears only if you reach the Top 10 for that level.
- New "View ranking" button in each location's difficulty picker.
- The reference photo now auto-closes after 5 seconds; a ring around the close icon shows the countdown.
- The help button is transparent while charging and turns white with a flash when ready.
- Unified "ranking" icon across Settings, Profile and every view/enter ranking button.

## 1.10.1+16 — 2026-04-15

**ES**
- La cuadrícula de ubicaciones ahora carga todo de una vez y mantiene un orden estable: primero las nuevas, luego las que están en progreso, después las completadas, y al final las bloqueadas. Antes, al bajar por la lista podían aparecer ubicaciones faltantes y otras saltaban de posición.
- El zoom en la foto de referencia a pantalla completa ahora se desbloquea correctamente solo al completar el nivel Experto, no al terminar cualquier dificultad.
- La pantalla de carga del puzzle ya no muestra el footer antes de que la imagen esté lista.
- El footer oculto durante la carga ya no desplaza las piezas al reaparecer: las piezas permanecen en su lugar.

**EN**
- The location grid now loads everything at once and keeps a stable order: new unlocks first, then in-progress, completed, and locked at the bottom. Previously, scrolling down could show missing locations or cause others to jump positions.
- Zoom on the fullscreen reference photo now correctly unlocks only after completing the Expert difficulty, not after any difficulty.
- The puzzle loading screen no longer shows the footer before the image is ready.
- The footer hidden during loading no longer shifts pieces when it reappears: pieces stay in place.

## 1.10.0+15 — 2026-04-15

**ES**
- Nueva ayuda en el puzzle: un botón en el footer anima una pieza fantasma hacia la pieza más alejada de su lugar. Se recarga en 2 minutos con una barra de progreso visible.
- Preferencia de destello en Ajustes: elige entre Shimmer, Flash o Apagado, con vista previa del efecto en el botón. El modo Flash es la nueva opción por defecto.
- Modal de dificultad rediseñado: cuadrícula 2×2 con ícono, nombre y puntos en cada nivel, marcas de completado por color, y la opción de ayudas visuales ahora vive aquí (no en el perfil).
- La imagen de referencia tiene un límite de 3 usos por partida; cuando se agota, ver un anuncio otorga 3 usos más.
- Icono pulsante de inicio en las fichas desbloqueadas para jugadores nuevos (desaparece al completar el primer puzzle).
- El ícono del tip cambia a la silueta de fotógrafa solo al superar el nivel Experto o completar todos los niveles disponibles; antes siempre mostraba la silueta.
- Los trofeos ganados se destacan con un fondo dorado brillante y texto en verde oscuro para mejor legibilidad.
- Los puntos por partida no pueden ser negativos, aunque se usen todas las ayudas.

**EN**
- New in-puzzle help: a footer button animates a ghost piece toward the most misplaced piece. Recharges in 2 minutes with a visible progress bar.
- Shimmer preference in Settings: choose Shimmer, Flash, or Off, with a live preview on the button. Flash is the new default.
- Difficulty modal redesigned: 2×2 grid with icon, name and points per level, color-coded completion badges, and the visual hints option now lives here instead of in Profile.
- Reference image limited to 3 peeks per session; when depleted, watching an ad grants 3 more.
- Pulsing play icon on unlocked cards for brand-new players (disappears after the first completion).
- The tip icon switches to the photographer silhouette only after beating Expert or completing every available difficulty; previously it always showed the silhouette.
- Earned trophies are highlighted with a bright gold background and dark-teal text for better readability.
- Puzzle score can no longer go negative, even with all hints active.

## 1.9.2+14 — 2026-04-12

**ES**
- Al completar un puzzle, la foto ahora se muestra en pantalla completa (sin footer ni espacios).
- Nuevo loader animado personalizado en lugar del spinner genérico.
- Tips y silueta se ocultan mientras carga la imagen y se muestran al terminar.
- Tip centrado verticalmente cuando no hay silueta visible.
- El carrusel de tips siempre parte desde el nivel más fácil.
- Texto actualizado en la sección "Acerca de".

**EN**
- Completed puzzle photo now displays truly fullscreen (no footer or gaps).
- Custom animated loader replaces the generic spinner.
- Tips and silhouette hidden while the image loads, shown once ready.
- Tip card centered vertically when no silhouette is present.
- Tip carousel always starts from the easiest difficulty.
- Updated "About" section text.

## 1.9.1+13 — 2026-04-11

**ES**
- Nueva ilustración de la fotógrafa y el gato en el encabezado del perfil.

**EN**
- New photographer-and-cat illustration in the profile header.

## 1.9.0+12 — 2026-04-11

**ES**
- Al terminar un puzzle y al ver la foto desde el mapa, ahora aparece un tip contextual con el nivel completado como pill de color.
- Nueva silueta de la fotógrafa y el gato como referencia visual cuando el nivel lo permite.
- Carrusel deslizable de tips por dificultad en la vista de foto completa.
- Transiciones más suaves al mostrar y ocultar los tips.

**EN**
- Finishing a puzzle and viewing the photo from the map now show a contextual tip with a colored "level completed" pill.
- New photographer-and-cat silhouette as a visual cue on supported levels.
- Swipeable per-difficulty tip carousel on the full photo view.
- Smoother fade when tips appear and disappear.

## 1.8.0+11 — 2026-04-11

**ES**
- Respaldo y restauración de progreso con un código corto: guarda tus puntos, trofeos y puzzles completados, y recupéralos en otro teléfono.
- Opción para enviarte el código por correo.
- Pequeños ajustes visuales en la pantalla de puzzle completado.

**EN**
- Backup and restore your progress with a short code: save your points, trophies and completed puzzles, and recover them on another phone.
- Option to email the code to yourself.
- Small visual tweaks on the puzzle completion screen.

## 1.7.1+10 — 2026-04-11

**ES**
- Nuevo: ranking por ubicación y tu mejor marca personal.
- Fotos más nítidas (hasta 3× más resolución).
- Penalizaciones por ayudas: -10 ref, -15 fijar, -20 multi-selección.
- Trofeos nuevos: Lobo Solitario y Voluntad de Hierro.
- Ajustes movidos a un diálogo más limpio con íconos.
- Piezas fijas vibran y destellan al intentar moverlas.
- Tips distintos por dificultad.
- Imagen de referencia sólo al cargar.
- Encabezado más limpio.
- Brillo al encajar activado por defecto.

**EN**
- New: per-location ranking and your personal best.
- Sharper photos (up to 3× resolution).
- Help penalties: -10 reference, -15 lock pieces, -20 multi-select.
- New trophies: Lone Wolf and Iron Will.
- Settings moved to a cleaner dialog with icons.
- Locked pieces now shake and flash when you try to move them.
- Per-difficulty tips.
- Reference image shows only on load.
- Cleaner header.
- Snap shine now on by default.

## 1.7.0+9 — 2026-04-10

**ES**
- Fotos de puzzle pre-recortadas por dificultad: imágenes más nítidas y carga más rápida.
- Imagen de referencia siempre coincide exactamente con lo que estás armando.

**EN**
- Puzzle photos pre-cropped per difficulty: sharper images and faster loading.
- Reference image now matches exactly what you are solving.
