# Apple App Store — Guia de Publicacion

## 1. Prerrequisitos

- Cuenta Apple Developer ($99 USD/ano): https://developer.apple.com/programs/
- Mac con Xcode instalado (ultima version estable)
- Apple ID con autenticacion de dos factores
- Icono de app (1024x1024 PNG, sin transparencia, sin esquinas redondeadas)
- Screenshots por dispositivo (minimo 2, recomendado 5-8)
- URL de politica de privacidad

## 2. Configuracion de Xcode

### Bundle Identifier
En `ios/Runner.xcodeproj` → Runner target → General:
```
Bundle Identifier: cl.chilepuzzle.chilePuzzle
```

### Signing
1. Abrir `ios/Runner.xcworkspace` en Xcode
2. Runner target → Signing & Capabilities
3. Seleccionar tu Team (Apple Developer account)
4. Habilitar "Automatically manage signing"
5. Xcode generara los provisioning profiles necesarios

### Version
En `pubspec.yaml`:
```yaml
version: 1.0.0+1   # CFBundleShortVersionString + CFBundleVersion
```

Incrementar build number (+1) en cada release.

### App name
Editar `ios/Runner/Info.plist`:
```xml
<key>CFBundleDisplayName</key>
<string>Chile Puzzle</string>
```

### Icons
Opcion recomendada — usar `flutter_launcher_icons`:

```yaml
# pubspec.yaml dev_dependencies:
flutter_launcher_icons: ^0.14.3

# flutter_launcher_icons.yaml:
flutter_launcher_icons:
  ios: true
  image_path: "assets/icon/app_icon.png"
  remove_alpha_ios: true
```

```bash
flutter pub run flutter_launcher_icons
```

O reemplazar manualmente en `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

## 3. Permisos y Capabilities

### Info.plist
Agregar descripciones de uso requeridas en `ios/Runner/Info.plist`:

```xml
<!-- Google Maps -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to show your location on the map</string>

<!-- Si se usa Game Center -->
<key>GKGameCenterIdentifier</key>
<string>cl.chilepuzzle.chilePuzzle</string>
```

### Google Maps API Key
En `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
```

Restringir la key en Google Cloud Console:
1. APIs & Services → Credentials
2. Restricciones de aplicacion → iOS apps
3. Agregar Bundle ID: `cl.chilepuzzle.chilePuzzle`

### AdMob
En `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXX~YYYYY</string>
```

Reemplazar test IDs en `lib/features/ads/ad_service.dart`:
- iOS interstitial: `ca-app-pub-3940256099942544/4411468910` → tu ID real

### App Transport Security
Si el backend usa HTTP (no HTTPS), agregar excepcion en Info.plist:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```
**Nota:** Para produccion, usar HTTPS y remover esta excepcion.

## 4. Build del IPA

```bash
# Limpiar builds anteriores
flutter clean

# Build para release
flutter build ipa --release
```

Output: `build/ios/ipa/chile_puzzle.ipa`

Si hay errores de signing, abrir en Xcode y resolver:
```bash
open ios/Runner.xcworkspace
```

### Archive desde Xcode (alternativa)
1. Product → Archive
2. Esperar compilacion
3. Window → Organizer → seleccionar archive

## 5. App Store Connect

### Crear app
1. Ir a https://appstoreconnect.apple.com
2. My Apps → "+" → New App
3. Llenar: nombre, idioma primario, Bundle ID, SKU

### Store listing
- **Nombre**: Chile Puzzle Explorer (max 30 chars)
- **Subtitulo** (30 chars): "Descubre Chile con puzzles"
- **Descripcion**: gameplay, features, contenido educativo
- **Palabras clave**: puzzle, chile, geography, travel, jigsaw
- **Screenshots**: obligatorios para iPhone 6.7" y 6.5"
  - Capturar desde simulador o dispositivo
  - Formatos: 1290x2796 (6.7"), 1242x2688 (6.5")
- **App Preview** (opcional): video de 15-30s mostrando gameplay

### Categorias
- Primary: Games → Puzzle
- Secondary: Education

### Clasificacion de contenido (Age Rating)
- Llenar cuestionario
- Sin violencia, sin compras in-app
- Resultado esperado: 4+

### Privacidad
- Crear politica de privacidad (requerida)
- Subirla a URL publico
- App Privacy: declarar datos recolectados
  - Advertising: Device ID (AdMob)
  - Analytics: ninguno (local storage only)

### Precio
- Gratis (monetizacion via ads)

## 6. Subir build

### Desde command line
```bash
# Instalar Transporter o usar xcrun
xcrun altool --upload-app -f build/ios/ipa/chile_puzzle.ipa -t ios \
  -u tu@email.com -p @keychain:AC_PASSWORD
```

### Desde Xcode
1. Window → Organizer
2. Seleccionar archive → "Distribute App"
3. Seleccionar "App Store Connect"
4. Upload

### Desde Transporter
1. Descargar Transporter de Mac App Store
2. Arrastrar el .ipa
3. Click "Deliver"

## 7. TestFlight (testing)

1. En App Store Connect → TestFlight
2. El build aparece despues de procesamiento (~10-30 min)
3. Agregar testers internos (tu email)
4. Instalar TestFlight en dispositivo iOS
5. Probar la app

## 8. Enviar a revision

1. App Store Connect → App Store → seleccionar build
2. Completar toda la metadata
3. "Submit for Review"
4. Revision toma 1-3 dias (primera vez puede ser mas)

## 9. Checklist pre-publicacion

- [ ] Bundle ID correcto
- [ ] Signing con cuenta de produccion
- [ ] Icons de produccion generados (1024x1024)
- [ ] Ad IDs de produccion (no test)
- [ ] Google Maps API key restringida a Bundle ID
- [ ] Version y build number incrementados
- [ ] Politica de privacidad publicada
- [ ] Screenshots para todos los tamanos requeridos
- [ ] Probado en dispositivo real iOS
- [ ] Info.plist con descripciones de permisos
- [ ] `flutter build ipa --release` compila sin errores
- [ ] NSAppTransportSecurity removido o restringido a dominios especificos

## 10. Diferencias clave vs Google Play

| Aspecto | Google Play | App Store |
|---------|-------------|-----------|
| Costo cuenta | $25 unico | $99/ano |
| Formato build | AAB | IPA |
| Revision | 1-7 dias | 1-3 dias |
| Testing | Internal testing | TestFlight |
| Screenshots | Minimo 2 | Obligatorios por tamano |
| Signing | Keystore JKS | Apple Certificates (auto) |
| Subir build | Play Console | Xcode/Transporter |

## 11. Post-publicacion

- Monitorear crashes en Xcode Organizer → Crashes
- Responder reviews en App Store Connect
- Planificar actualizaciones via admin panel
- Renovar cuenta Apple Developer anualmente
