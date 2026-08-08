# FleurApp Mobile

Application Flutter de caisse et de gestion pour Android/iOS, connectée au
backend Express/PostgreSQL FleurApp déployé sur Render.

## Modules livrés

- caisse responsive : catalogue, catégories, recherche, panier, contrôle de
  stock, vente immédiate ou différée, client, acompte et moyens de paiement ;
- encaissement idempotent : une clé `Idempotency-Key` est conservée après une
  coupure tant que la vente n’est pas modifiée ;
- ticket : lignes et montants autoritatifs du serveur, acompte, reste, statut,
  empreinte et copie ;
- administration JWT/PIN avec jeton dans le Keychain/Keystore via
  `flutter_secure_storage` ;
- catalogue : création, modification, suppression, catégories, fraîcheur,
  conditionnements et remise anti-gaspi ;
- stocks : niveaux réels, réceptions converties, pertes/rebuts et historiques ;
- activité : clôture Z définitive, totaux/TVA/modes de paiement, historique,
  clients en lecture, ventes de la session et export FEC consultable/copiable ;
- réglages : URL d’API persistante, test de santé, déconnexion et thème
  système/clair/sombre ;
- ports séparés pour Stripe Tap to Pay, Bluetooth et impression de tickets.

Tous les montants sont manipulés en centimes entiers. Aucune donnée fictive
n’est affichée lorsque Render ou PostgreSQL ne répond pas.

Le rapport [AUDIT_COMPARATIF_MOBILE.md](AUDIT_COMPARATIF_MOBILE.md) décrit la
correspondance Web/mobile et les fonctions demandées qui nécessitent encore de
nouvelles routes backend.

## Architecture

```text
lib/
├── core/                 # Configuration, argent, formatage et thèmes
├── features/
│   ├── admin/            # Catalogue, stocks, clients, activité, clôtures, FEC
│   ├── home/             # Navigation responsive et transitions
│   ├── pos/              # Caisse, panier, paiement et tickets
│   ├── settings/         # URL Render, santé, session et apparence
│   └── shared/           # Garde PIN/JWT et retours d’erreur
├── integrations/         # Ports Tap to Pay, Bluetooth et impression
├── models/               # Contrats API typés, montants en centimes
├── services/             # HTTP, stockage sécurisé et préférences
├── state/                # AppController, PosController et AdminController
├── app.dart
└── main.dart
```

## 1. Préparer Fedora Workstation

```bash
sudo dnf install git curl unzip xz zip android-tools mesa-libGLU java-17-openjdk-devel
```

Android Studio peut être installé depuis Flathub :

```bash
flatpak install flathub com.google.AndroidStudio
flatpak run com.google.AndroidStudio
```

Dans Android Studio, installer Android SDK Platform, Build-Tools et Command-line
Tools, puis configurer Flutter :

```bash
flutter config --android-sdk /home/ipsoum/Android/Sdk
flutter doctor --android-licenses
flutter doctor -v
```

Ce dépôt force Gradle à utiliser Java 17 dans `android/gradle.properties` :

```properties
org.gradle.java.home=/home/ipsoum/.sdkman/candidates/java/current
```

Ne supprimez pas cette ligne tant que le Java système Fedora est incompatible
avec Gradle 8.7.

## 2. Installer les dépendances

```bash
cd /home/ipsoum/fleurapp_project/fleurapp-mobile
flutter pub get
```

Sur cette installation Flutter 3.24/Dart 3.5, Dart peut ne pas détecter seul le
bundle de certificats Fedora. La commande équivalente et vérifiée est :

```bash
/home/ipsoum/development/flutter/bin/cache/dart-sdk/bin/dart \
  --root-certs-file=/etc/ssl/certs/ca-certificates.crt pub get
flutter pub get --offline
```

## 3. Configurer Render

Deux méthodes sont possibles :

1. lancer/compiler avec une valeur initiale :

```bash
flutter run \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

2. ouvrir **Réglages** dans l’application, saisir l’URL HTTPS sans `/api`, la
   tester puis l’enregistrer. Cette valeur locale prend ensuite priorité sur le
   `dart-define`.

Ne placez jamais `JWT_SECRET`, `ADMIN_PIN_HASH`, `DATABASE_URL` ou un autre
secret serveur dans l’APK. Seul le JWT obtenu après saisie du PIN est stocké
dans le stockage sécurisé du téléphone.

## 4. Tester sur un Poco F7 ou autre Android

Activez les options développeur et le débogage USB, puis :

```bash
adb devices
flutter devices
flutter run \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

Le téléphone communique directement avec Render en HTTPS. Pour un backend
local depuis l’émulateur Android, seule l’adresse `http://10.0.2.2:PORT` est
autorisée en développement ; utilisez HTTPS en dehors de localhost.

## 5. Qualité et APK de test

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release --no-pub \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

APK universel :

```text
build/app/outputs/flutter-apk/app-release.apk
```

Installation USB :

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

APK séparés par architecture :

```bash
flutter build apk --release --split-per-abi --no-pub \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

La configuration actuelle utilise la clé de développement pour le build de
test. Créez une clé de signature privée et protégez-la hors Git avant toute
publication Play Store.

## iOS

Le projet prépare le Keychain, le Bluetooth et le NFC. La compilation et la
signature nécessitent macOS, Xcode et un compte Apple Developer :

```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

## Paiement et matériels

- `ContactlessPaymentGateway` reçoit déjà des centimes entiers et accueillera
  Stripe Terminal/Tap to Pay avec les routes backend du PaymentIntent ;
- `CashRegisterBluetoothService` isole découverte et connexion ;
- `ReceiptPrinter` reçoit un ticket en centimes et reste indépendant du
  protocole ESC/POS, Wi-Fi ou USB.

Aucun paiement NFC réel ni impression fictive n’est déclenché tant que le SDK,
les comptes et le matériel ne sont pas configurés.
