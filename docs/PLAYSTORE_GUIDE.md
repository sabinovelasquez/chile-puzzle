# Google Play Store — Guía de Publicación

## 1. Prerrequisitos

- Cuenta de Google Play Developer ($25 USD, pago único): https://play.google.com/console
- Java/JDK instalado para generar keystore
- Icono de app (512x512 PNG)
- Screenshots del app (mínimo 2, recomendado 4-8)
- Feature graphic (1024x500 PNG)
- URL de política de privacidad (requerido por Google)

## 2. Keystore para firma

Generar el keystore (una sola vez, guardarlo seguro):

```bash
keytool -genkey -v \
  -keystore ~/chile-puzzle-upload.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias upload
```

Crear archivo `android/key.properties` (NO commitear a git):

```properties
storePassword=<tu_password>
keyPassword=<tu_password>
keyAlias=upload
storeFile=/Users/sabino/chile-puzzle-upload.jks
```

Agregar a `.gitignore`:
```
android/key.properties
*.jks
```

## 3. Configurar firma en Gradle

Editar `android/app/build.gradle.kts`:

```kotlin
// Antes de android { ... }
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // ...
        }
    }
}
```

## 4. Metadata del app

### App name
Editar `android/app/src/main/AndroidManifest.xml`:
```xml
android:label="Chile Puzzle Explorer"
```

### Icons
Opción recomendada — usar `flutter_launcher_icons`:

```bash
# Agregar a dev_dependencies en pubspec.yaml:
# flutter_launcher_icons: ^0.14.3

# Crear flutter_launcher_icons.yaml:
# flutter_launcher_icons:
#   android: true
#   image_path: "assets/icon/app_icon.png"
#   min_sdk_android: 21

flutter pub run flutter_launcher_icons
```

O reemplazar manualmente los archivos en `android/app/src/main/res/mipmap-*`.

### Version
En `pubspec.yaml`:
```yaml
version: 1.0.0+1   # versionName+versionCode
```

Incrementar `versionCode` (+1) en cada release.

## 5. Reemplazar IDs de prueba

### AdMob
En `lib/features/ads/ad_service.dart`, reemplazar los test IDs:
- Android interstitial: `ca-app-pub-3940256099942544/1033173712` → tu ID real
- iOS interstitial: `ca-app-pub-3940256099942544/4411468910` → tu ID real

En `android/app/src/main/AndroidManifest.xml`, reemplazar el APPLICATION_ID de AdMob:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXX~YYYYY"/>  <!-- Tu app ID real -->
```

### Google Maps API Key
En Google Cloud Console:
1. Ir a APIs & Services → Credentials
2. Seleccionar la API key usada
3. Restricciones de aplicación → Android apps
4. Agregar: package name `cl.chilepuzzle.chile_puzzle` + SHA-1 fingerprint

Para obtener SHA-1 del keystore:
```bash
keytool -list -v -keystore ~/chile-puzzle-upload.jks -alias upload
```

## 6. Build del AAB

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Verificar que el AAB se generó correctamente:
```bash
ls -la build/app/outputs/bundle/release/app-release.aab
```

## 7. Google Play Console

### Crear app
1. Ir a https://play.google.com/console
2. "Create app" → llenar nombre, idioma, tipo (app), categoría (puzzle/games)

### Store listing
- **Título**: Chile Puzzle Explorer (máx 30 chars)
- **Descripción corta** (80 chars): "Descubre Chile resolviendo puzzles de sus lugares más icónicos"
- **Descripción completa** (4000 chars): describir gameplay, features, contenido educativo
- **Screenshots**: mínimo 2 por dispositivo (phone, tablet opcional)
  - Capturar con: `flutter screenshot` o desde el emulador
- **Feature graphic**: 1024x500 PNG
- **App icon**: 512x512 PNG (se sube automáticamente desde el AAB)

### Content rating
- Llenar el cuestionario IARC (toma ~5 minutos)
- El app no tiene contenido violento ni compras in-app
- Categoría esperada: Everyone / PEGI 3

### Privacy policy
- Crear una política de privacidad básica
- Subirla a un URL público (GitHub Pages funciona)
- Requerida por Google para apps con ads y auth

### Target audience
- Seleccionar rango de edad (13+)
- No es app para niños (evita requisitos COPPA adicionales)

### Pricing
- Free (monetización via ads)

### Upload AAB
1. Ir a Testing → Internal testing
2. Crear nuevo release
3. Subir el `.aab`
4. Agregar testers (tu email)
5. Publicar internal testing
6. Testear en dispositivo real
7. Cuando listo → promover a Production

## 8. Checklist pre-publicación

- [ ] App name correcto en AndroidManifest.xml
- [ ] Icons de producción generados
- [ ] Ad IDs de producción (no test)
- [ ] Google Maps API key restringida
- [ ] Version code incrementado
- [ ] Keystore guardado en lugar seguro (si lo pierdes, no puedes actualizar la app)
- [ ] Política de privacidad publicada
- [ ] Screenshots y feature graphic listos
- [ ] Probado en dispositivo real (no solo emulador)
- [ ] ProGuard/R8 no rompe nada en release mode
- [ ] `flutter build appbundle --release` compila sin errores

## 9. Post-publicación

- La revisión de Google toma 1-7 días (primera vez puede ser más)
- Monitorear crashes en Play Console → Android vitals
- Responder reviews de usuarios
- Planificar actualizaciones de contenido via admin panel
