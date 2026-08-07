# FleurApp Mobile

Application de caisse Flutter pour Android et iOS, connectée directement à
l'API Node.js/PostgreSQL de FleurApp hébergée sur Render.

## Fonctionnalités disponibles

- chargement du catalogue depuis `GET /api/produits` ;
- recherche et filtrage par catégorie ;
- contrôle du stock disponible dans le panier ;
- panier responsive pour téléphone et tablette ;
- encaissement par carte, espèces ou chèque via `POST /api/commandes` ;
- affichage du numéro, du total et de la signature de la commande ;
- gestion explicite des erreurs réseau et de configuration ;
- contrats prêts pour Tap to Pay, le Bluetooth et l'impression de tickets.

L'application n'utilise pas de catalogue fictif en cas de panne. Une erreur
réseau reste visible afin d'éviter une vente déconnectée du stock réel.

## Architecture

```text
lib/
├── core/                 # Configuration, thème et formatage
├── features/pos/         # Écran de caisse et widgets
├── integrations/         # Ports Tap to Pay, Bluetooth et impression
├── models/               # Produit, panier, paiement et reçu
├── services/             # Client HTTP de l'API Render
├── state/                # Gestion d'état ChangeNotifier
├── app.dart
└── main.dart
```

`PosController` centralise l'état du catalogue et du panier. Les interfaces du
dossier `integrations/` permettront d'ajouter les SDK constructeurs sans les
coupler à l'interface de caisse.

## 1. Préparer Fedora Workstation

Installer les outils système :

```bash
sudo dnf install git curl unzip xz zip android-tools mesa-libGLU
```

Télécharger le SDK Flutter stable depuis le site Flutter, puis l'extraire par
exemple dans `~/development/flutter`. Ajouter ensuite Flutter au `PATH` :

```bash
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
flutter --version
```

### Installer Android Studio

La solution la plus simple sous Fedora est Flatpak :

```bash
flatpak install flathub com.google.AndroidStudio
flatpak run com.google.AndroidStudio
```

Dans l'assistant Android Studio, installer :

1. Android SDK Platform ;
2. Android SDK Build-Tools ;
3. Android SDK Command-line Tools ;
4. Android Emulator si un téléphone physique n'est pas utilisé.

Puis indiquer à Flutter le chemin affiché dans Android Studio, par exemple :

```bash
flutter config --android-sdk "$HOME/Android/Sdk"
flutter doctor --android-licenses
flutter doctor -v
```

Sur cette machine, `flutter doctor` signale actuellement que le SDK Android et
Android Studio ne sont pas encore détectés. La compilation APK nécessitera donc
cette étape.

## 2. Installer les dépendances

```bash
cd /home/ipsoum/fleurapp_project/fleurapp-mobile
flutter pub get
```

## 3. Configurer l'API Render

L'URL n'est pas enregistrée en dur. Elle est injectée avec `API_BASE_URL` et ne
doit pas contenir `/api` à la fin :

```bash
flutter run \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

Le client appellera automatiquement :

- `https://VOTRE-SERVICE.onrender.com/api/produits`
- `https://VOTRE-SERVICE.onrender.com/api/commandes`

Tester d'abord le backend depuis Fedora :

```bash
curl -i https://VOTRE-SERVICE.onrender.com/api/produits
```

## 4. Tester sur un téléphone Android

Activer les options développeur et le débogage USB sur le téléphone, le
brancher, puis accepter son empreinte RSA :

```bash
adb devices
flutter devices
flutter run \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

Le téléphone et le backend Render communiquent directement en HTTPS : aucune
adresse spéciale d'émulateur ou redirection vers `localhost` n'est nécessaire.

## 5. Générer l'APK de test

APK universel installable manuellement :

```bash
flutter clean
flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

Le fichier produit se trouve ici :

```text
build/app/outputs/flutter-apk/app-release.apk
```

Installation par USB :

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Pour obtenir des APK plus petits, séparés par architecture :

```bash
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

La configuration actuelle signe l'APK de test avec la clé de développement.
Une clé privée de production devra être configurée avant publication sur le
Play Store.

## iOS

Le code iOS est présent, mais la compilation et la signature nécessitent macOS,
Xcode et un compte Apple Developer :

```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

## Qualité

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Paiement sans contact et matériels

- `ContactlessPaymentGateway` accueillera l'adaptateur Stripe Terminal/Tap to
  Pay et son flux d'autorisation côté backend.
- `CashRegisterBluetoothService` accueillera la découverte et la connexion des
  imprimantes ou TPE.
- `ReceiptPrinter` isole le rendu et l'envoi des tickets (par exemple ESC/POS).

Les permissions Android/iOS pour NFC et Bluetooth sont préparées. Leur demande
à l'exécution et les capacités de signature propres aux SDK seront ajoutées avec
les plugins choisis. Aucun paiement NFC réel n'est simulé dans cette version.
