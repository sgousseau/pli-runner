# Pli Runner — Instructions pour Claude sur Mac

## Contexte

App Flutter pour coursier. Le dispatch envoie des photos contenant des adresses via un bot Telegram. L'app extrait automatiquement le numéro client et l'adresse par OCR, géolocalise, affiche sur une carte, et envoie un message automatique au dispatch quand le coursier approche du client.

## Setup complet sur Mac (iPhone physique)

### 1. Prérequis

Vérifie que tout est installé :

```bash
flutter doctor
# Doit afficher : Flutter, Xcode, iOS toolchain OK
# Si Xcode manque : xcode-select --install
# Si CocoaPods manque : sudo gem install cocoapods
```

### 2. Installer les dépendances

```bash
cd pli-runner
flutter pub get
cd ios && pod install && cd ..
```

### 3. Clé API Google Maps (obligatoire pour la carte)

1. Va sur https://console.cloud.google.com/apis/credentials
2. Crée une clé API avec "Maps SDK for iOS" activé
3. Ajoute la clé dans `ios/Runner/AppDelegate.swift` :

```swift
import UIKit
import Flutter
import GoogleMaps  // Ajouter cet import

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("COLLE_TA_CLE_ICI")  // Ajouter cette ligne
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 4. Configurer le signing iOS

Ouvre le projet dans Xcode :

```bash
open ios/Runner.xcworkspace
```

Dans Xcode :
- Sélectionne le target "Runner"
- Onglet "Signing & Capabilities"
- Coche "Automatically manage signing"
- Sélectionne ton Team (Apple Developer account ou Personal Team)
- Le Bundle Identifier est `com.sgousseau.pliRunner`
- Ajoute la capability "Background Modes" avec "Location updates" coché (normalement déjà dans Info.plist)

### 5. Lancer sur iPhone

Branche l'iPhone en USB, déverrouille-le, et fais confiance à l'ordinateur si demandé.

```bash
flutter run
# Ou pour une version optimisée :
flutter run --release
```

Si c'est la première fois, sur l'iPhone : Réglages → Général → VPN et gestion des appareils → fais confiance au certificat développeur.

### 6. Créer le bot Telegram

L'utilisateur doit faire ça manuellement dans Telegram :
1. Ouvrir Telegram, chercher `@BotFather`
2. Envoyer `/newbot`
3. Donner un nom (ex: "Pli Runner Bot")
4. Donner un username (ex: "pli_runner_bot")
5. Copier le token fourni
6. Dans l'app Pli Runner → Paramètres → coller le token
7. Le dispatch doit envoyer `/start` au bot puis envoyer les photos

## Architecture

```
lib/
├── core/
│   ├── models/pli.dart              # Modèle Pli (id, clientNumber, address, lat/lng, status)
│   └── providers.dart               # Providers Riverpod + orchestration polling/OCR/geofencing
├── features/
│   ├── plis/
│   │   ├── data/pli_repository.dart       # Persistence JSON locale
│   │   ├── domain/
│   │   │   ├── ocr_service.dart           # OCR ML Kit + parsing adresses françaises
│   │   │   ├── geocoding_service.dart     # Adresse → GPS
│   │   │   └── geofencing_service.dart    # Tracking GPS + détection proximité
│   │   └── presentation/
│   │       ├── pli_list_screen.dart       # Liste des plis avec statuts
│   │       └── pli_map_screen.dart        # Carte Google Maps
│   ├── telegram/
│   │   └── data/telegram_service.dart     # API Telegram Bot (poll, download, send)
│   └── settings/
│       ├── data/settings_repository.dart  # SharedPreferences
│       └── presentation/settings_screen.dart
└── main.dart
```

## Flow de données

```
Dispatch envoie photo au bot Telegram
  → App poll toutes les 10s via API Telegram Bot
  → Télécharge la photo
  → OCR (google_mlkit_text_recognition) extrait n° client + adresse
  → Geocoding convertit adresse en lat/lng
  → Pli ajouté à la liste
  → Geofencing surveille position du coursier
  → À ~500m du client → message auto envoyé au dispatch via le bot
```

## Stack technique

- **State management** : flutter_riverpod
- **HTTP** : dio (API Telegram Bot)
- **OCR** : google_mlkit_text_recognition (on-device, gratuit)
- **Localisation** : geolocator + geocoding
- **Carte** : google_maps_flutter
- **Storage** : shared_preferences + JSON file
- **Notifications** : flutter_local_notifications

## Commandes utiles

```bash
flutter pub get          # Installer dépendances
flutter analyze          # Vérifier erreurs
flutter test             # Tests
flutter run              # Lancer en debug
flutter run --release    # Lancer en release
flutter build ios        # Build iOS
```

## Permissions iOS (déjà configurées dans Info.plist)

- `NSLocationWhenInUseUsageDescription` — localisation active
- `NSLocationAlwaysAndWhenInUseUsageDescription` — localisation arrière-plan
- `UIBackgroundModes` : location, fetch

## Points d'attention

- Le bot Telegram doit recevoir au moins un message du dispatch pour que le `chatId` soit enregistré (c'est fait automatiquement au premier message reçu)
- L'OCR est optimisé pour les adresses françaises (rue, avenue, boulevard, code postal, etc.)
- Le numéro client est cherché en haut de l'image (patterns: #XXX, N°XXX, Ref XXX, Client XXX)
- Le geofencing utilise un rayon de 500m par défaut (configurable dans les paramètres)
- Google Maps nécessite une clé API, mais la liste des plis fonctionne sans
