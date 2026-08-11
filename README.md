# FleurApp Mobile

Application Flutter de caisse et de gestion pour Android/iOS, connectée au
backend Express/PostgreSQL FleurApp déployé sur Render.

## Modules livrés

- caisse responsive : catalogue, catégories, recherche, panier, contrôle de
  stock, vente immédiate ou différée, client, acompte et moyens de paiement ;
- encaissement idempotent : une clé `Idempotency-Key` est conservée après une
  coupure tant que la vente n’est pas modifiée ;
- identité de caisse révocable : activation administrateur par téléphone,
  jeton propre à l’appareil dans le Keystore Android et révocation distante ;
- ticket : lignes et montants autoritatifs du serveur, acompte, reste, statut,
  empreinte et copie ;
- administration JWT/PIN avec jeton dans le Keychain/Keystore via
  `flutter_secure_storage` ;
- catalogue : création, modification, suppression, catégories, fraîcheur,
  conditionnements et remise anti-gaspi ;
- stocks : niveaux réels, réceptions converties, pertes/rebuts et historiques ;
- activité : clôture Z définitive, totaux/TVA/modes de paiement, historique,
  création et consultation des clients, historique serveur des commandes avec
  détail des lignes et export FEC consultable/copiable ;
- centre d’alertes administrateur : arrivages, commandes différées et besoins
  BOM sur 48 heures, badge dans l’en-tête et rappels locaux sonores à J-1 ;
- signalement de bugs public depuis Réglages, la connexion et les erreurs réseau,
  avec version/OS/modèle automatiques et suivi administrateur des statuts ;
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
│   ├── bugs/             # Formulaire public de signalement
│   ├── home/             # Navigation responsive et transitions
│   ├── notifications/    # Centre d’alertes et rappels J-1
│   ├── pos/              # Caisse, panier, paiement et tickets
│   ├── settings/         # URL Render, santé, session et apparence
│   └── shared/           # Garde PIN/JWT et retours d’erreur
├── integrations/         # Ports Tap to Pay, Bluetooth et impression
├── models/               # Contrats API typés, montants en centimes
├── services/             # HTTP, stockage sécurisé, préférences et rappels
├── state/                # État caisse, admin, application et alertes
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

### Activer ce téléphone pour encaisser

Après installation du nouvel APK :

1. ouvrez un module administrateur et connectez-vous avec le PIN ;
2. ouvrez **Réglages** ;
3. dans **Sécurité des encaissements**, touchez **Activer** ;
4. vérifiez l’état **Caisse activée** ;
5. réalisez une vente de test.

Le jeton généré n’est jamais affiché. Il est propre à ce téléphone et stocké
avec `flutter_secure_storage`. Un administrateur peut le révoquer depuis la PWA
dans **Activité > Téléphones et caisses autorisés**. Après une révocation, le
panier reste disponible mais le serveur refuse l’encaissement jusqu’à une
nouvelle activation.

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

### Tester avec un tunnel de développement

Dans le dépôt backend, démarrez le serveur sur le port 3000 :

```bash
cd /home/ipsoum/fleurapp_project/fleurapp_backend_ui
npm run dev:tunnel
```

Dans un second terminal, lancez l’une des commandes affichées :

```bash
npx localtunnel --port 3000
# ou, si ngrok est installé :
ngrok http 3000
```

Dans **Réglages > Serveur Render**, remplacez temporairement l’URL par l’URL
HTTPS du tunnel, testez-la puis enregistrez-la. Le client ajoute le header de
contournement de la page d’avertissement localtunnel ; aucun secret n’est placé
dans l’APK.

## Import CSV du catalogue

Après connexion administrateur, ouvrez **Catalogue** puis touchez l’icône de
fichier dans l’en-tête. L’application accepte un CSV FleurApp de 32 Kio et
100 produits maximum, affiche les créations, mises à jour, doublons et erreurs,
puis demande une confirmation avant toute écriture.

Le modèle CSV se télécharge depuis l’administration Web. Il est compatible avec
LibreOffice Calc et contient les colonnes de prix, TVA, stock, catégorie,
conditionnement et fraîcheur. Une relance réseau conserve la même clé
d’idempotence afin d’éviter les doubles imports.

## Rappels d’arrivages et de commandes

Après connexion avec le PIN administrateur, touchez la cloche en haut de
l’écran puis **Activer les rappels**. Android 13 ou plus récent affiche sa boîte
de dialogue d’autorisation. FleurApp synchronise ensuite les alertes au login,
à l’ouverture du centre et à chaque retour de l’application au premier plan.

Pour un test fonctionnel :

1. créez une commande différée avec une livraison dans les 24 à 48 heures ;
2. ou donnez à un produit suivi une date d’arrivage dans les deux prochains
   jours ;
3. ouvrez la cloche et tirez la liste vers le bas ;
4. vérifiez l’alerte visuelle et le nombre de rappels programmés.

Si l’événement commence dans moins de 24 heures, le rappel J-1 devenu imminent
est affiché immédiatement. Sinon Android le programme environ 24 heures avant,
avec son et vibration. Sur HyperOS/Poco, autorisez au besoin l’exécution en
arrière-plan et choisissez une batterie sans restriction pour FleurApp.

Ces alertes sont locales, pas des notifications push : l’application doit avoir
été ouverte et synchronisée au moins une fois pendant la fenêtre de 48 heures.

## Tester un signalement de bug

1. appliquez `setup_security.sql` sur la base du backend après sauvegarde ;
2. ouvrez **Réglages > Signaler un problème**, saisissez au moins cinq
   caractères dans le titre et dix dans la description, puis envoyez ;
3. vérifiez le SnackBar contenant l’identifiant du rapport ;
4. connectez-vous avec le PIN, ouvrez **Activité > Bugs**, filtrez sur
   **Nouveau**, puis passez le rapport à **En cours** ou **Résolu** ;
5. répétez le test depuis l’écran PIN ou depuis un écran d’erreur réseau.

L’application transmet seulement le nom du système, le modèle, la version de
FleurApp et les champs saisis. Elle ne lit ni numéro de série, ni IMEI, ni autre
identifiant unique.

## 5. Qualité et APK de test

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --no-pub \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

APK de recette à installer sur les téléphones de test :

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Installation USB :

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Gardez le téléphone déverrouillé et l’écran allumé pendant les scénarios
instrumentés : Flutter attend la prochaine image lorsque l’écran Android se met
en veille.

## 6. Créer la signature de production

Le build `release` refuse désormais de démarrer tant qu’une clé privée dédiée
n’est pas configurée ; il ne peut donc plus être signé accidentellement avec le
certificat Android Debug.

Créez une fois le dossier et la clé hors Git :

```bash
mkdir -p /home/ipsoum/.config/fleurapp
keytool -genkeypair -v \
  -keystore /home/ipsoum/.config/fleurapp/upload-keystore.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias fleurapp-upload
```

Choisissez des mots de passe longs et conservez-les dans un gestionnaire de
mots de passe. Copiez ensuite le modèle local :

```bash
cd /home/ipsoum/fleurapp_project/fleurapp-mobile
cp android/key.properties.example android/key.properties
```

Remplacez les valeurs de `android/key.properties`, notamment :

```properties
storeFile=/home/ipsoum/.config/fleurapp/upload-keystore.jks
```

Ce fichier et les keystores sont ignorés par Git. Sauvegardez la clé dans deux
emplacements chiffrés : sa perte empêcherait de mettre à jour l’application
signée avec cette identité.

Construisez et vérifiez ensuite l’APK :

```bash
flutter build apk --release --no-pub \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
/home/ipsoum/Android/Sdk/build-tools/35.0.0/apksigner verify --verbose \
  build/app/outputs/flutter-apk/app-release.apk
```

APK séparés par architecture :

```bash
flutter build apk --release --split-per-abi --no-pub \
  --dart-define=API_BASE_URL=https://VOTRE-SERVICE.onrender.com
```

Ne partagez jamais `android/key.properties`, le keystore ou ses mots de passe.

### Tests fonctionnels complets sur un vrai Android

La suite `integration_test/app_full_test.dart` démarre l’APK réel et exécute six
parcours sur le téléphone :

- panne du catalogue, message utilisateur et reprise avec « Réessayer » ;
- recherche, panier, paiement, conflit de stock 409 et clé d’idempotence ;
- PIN administrateur erroné puis valide, JWT, import CSV, catégories et produit ;
- réception, perte, historiques de stock et écran BOM ;
- clients, Ticket Z, FEC, traitement d’un bug et alertes J-1 ;
- test de santé du backend, thèmes clair/sombre, rapport de bug et déconnexion.

Un backend HTTP complet mais simulé répond à l’APK. Les scénarios contrôlent les
corps JSON et headers réellement émis sans toucher Render ni la base de
production. L’import via le sélecteur de fichiers Android, le paiement NFC et le
matériel Bluetooth restent des recettes matérielles manuelles tant que leurs SDK
ne sont pas connectés.

```bash
adb devices
flutter devices
./tool/qa.sh integration ID_DU_TELEPHONE
```

Sur HyperOS, gardez le téléphone déverrouillé et acceptez « Installer via USB ».
Une annulation produit `INSTALL_FAILED_USER_RESTRICTED` et il suffit alors de
relancer la même commande.

La commande locale complète (tests, Semgrep et APK debug) est :

```bash
./tool/qa.sh all
```

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
