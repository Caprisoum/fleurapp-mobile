# Audit comparatif Web → Flutter — FleurApp Mobile

Date : 8 août 2026

Périmètre modifié : dépôt `fleurapp-mobile` uniquement. Le dépôt
`fleurapp_backend_ui` a été lu comme source de vérité, sans modification.

## Synthèse

L’application initiale ne couvrait que le catalogue, le panier et un
encaissement immédiat. Elle envoyait encore les prix depuis Flutter, utilisait
des `double`, n’ajoutait aucune clé d’idempotence, ne gérait ni JWT ni URL
persistante et ne comportait aucun écran d’administration.

La version mise à niveau couvre toutes les fonctions réellement exposées par la
PWA et son backend sécurisé : caisse immédiate/différée, reçus, catalogue et
catégories, fraîcheur/remises, stock, réceptions, pertes, clients en lecture,
clôtures Z, FEC et réglages. Les écritures administratives portent un Bearer JWT
stocké dans le Keystore/Keychain et les valeurs monétaires restent en centimes
entiers de l’API jusqu’à l’affichage.

Mise à jour du 11 août 2026 : le backend publie désormais la création de clients
ainsi que la liste et le détail des commandes. L’application mobile permet donc
d’ajouter une fiche client et de consulter l’historique persistant, y compris
après redémarrage ou depuis un autre téléphone autorisé.

Deux demandes supplémentaires nécessitent encore un contrat backend dédié :
l’annulation compensatoire et l’administration des nomenclatures. Des écrans
explicatifs remplacent volontairement les boutons qui modifieraient une vente
clôturée ou appelleraient une route inexistante.

## Inventaire comparatif

| Module Web/API | Mobile avant | Mobile après |
|---|---|---|
| Catalogue, recherche, catégories | Lecture et filtres simples | Parité caisse + gestion complète |
| Panier et stock disponible | Oui, montants `double` | Centimes, contrôle de stock, ergonomie 48 px |
| Vente immédiate | Sans idempotence | `Idempotency-Key`, rejeu sûr après coupure |
| Vente différée/client/acompte | Absent | Client, date, acompte en centimes |
| Moyens de paiement | Carte/espèces/chèque | Valeurs strictement alignées au backend |
| Ticket/reçu | Total et hash | Lignes serveur, total, acompte, reste, statut, hash, copie |
| PIN/JWT administrateur | Absent | Login serveur, Bearer, stockage sécurisé, déconnexion |
| Produits CRUD | Absent | Création, édition, suppression et validation mobile |
| Catégories CRUD | Absent | Création, liste et suppression |
| Fraîcheur/anti-gaspi | Badge partiel | État, dates et remise serveur de 30 % |
| Réceptions de stock | Absent | Conversion achat→vente et historique |
| Pertes/rebuts | Absent | Déclaration et historique du jour |
| Clôture Z | Absent | Confirmation irréversible, ticket et historique |
| Export FEC | Absent | Génération, consultation monospace et copie |
| URL API | `dart-define` uniquement | `dart-define` + réglage local et test `/api/health` |
| Thème/navigation | Clair, caisse seulement | Système/clair/sombre, rail/barre et transitions |
| Tap to Pay/Bluetooth | Interfaces vides | Interfaces conservées, montants en centimes, UI d’état |

## Alignement des routes

| Route backend | Auth | Usage mobile |
|---|---:|---|
| `GET /api/health` | Non | Test de l’URL Render |
| `POST /api/auth/login` | Non | PIN → JWT |
| `GET /api/produits` | Non | Caisse, catalogue, stock et fraîcheur |
| `GET /api/categories` | Non | Filtres et formulaires |
| `POST /api/commandes` | Non | Vente avec `Idempotency-Key` obligatoire côté mobile |
| `GET /api/clients` | JWT | Sélection client et consultation |
| `POST/DELETE /api/categories` | JWT | Gestion des catégories |
| `POST/PUT/DELETE /api/produits` | JWT | Gestion des produits |
| `POST /api/produits/:id/remise-anti-gaspi` | JWT | Remise autoritative |
| `POST /api/stock/reception` | JWT | Réapprovisionnement converti |
| `GET /api/stock/receptions` | JWT | Historique des arrivages |
| `POST/GET /api/pertes` | JWT | Perte et historique |
| `POST /api/cloture-jour` | JWT | Ticket Z définitif |
| `GET /api/clotures` | JWT | Historique Z |
| `GET /api/export/fec` | JWT | Export annuel |

`DELETE /api/clotures/:id` n’est volontairement pas appelé : le serveur répond
`405` et PostgreSQL protège l’inaltérabilité.

## Architecture et sécurité appliquées

- `AppController` orchestre URL, thème, session, caisse et administration.
- `RenderApiClient` centralise timeouts, erreurs génériques, request ID,
  authentification Bearer et contrats JSON.
- `SecureAdminTokenStore` utilise `flutter_secure_storage`; le PIN n’est jamais
  persisté et aucun secret serveur n’est compilé dans l’application.
- le changement d’URL supprime le JWT actuel pour empêcher son rejeu vers une
  autre origine ; seules les URL HTTPS sont acceptées, avec exceptions locales
  explicites pour le développement ;
- `moneyToCents`, `centsToApiDecimal` et `decimalToBasisPoints` interdisent
  exposants, négatifs et fractions de centime ;
- le panier n’envoie au serveur que `id` et `quantity`; prix, TVA et remise sont
  toujours recalculés par PostgreSQL ;
- après timeout/coupure d’un POST, la clé et le panier sont conservés. Une
  modification du panier crée une nouvelle clé ;
- Android interdit la sauvegarde système du stockage chiffré et iOS déclare le
  groupe Keychain de l’application ;
- les réponses 409 expliquent le conflit de stock, les 401 ferment la session
  expirée et les erreurs incluent le `requestId` lorsqu’il est fourni ;
- les cibles globales ont un minimum de 48 px, les listes/dialogues sont
  scrollables et les transitions respectent `disableAnimations`.

## Écarts backend empêchant les fonctions supplémentaires

Les routes suivantes restent à concevoir après la mise à jour du 11 août 2026 :

1. une annulation comptable compensatoire, par exemple
   `POST /api/commandes/:id/annulations`, qui crée une écriture inverse et
   réintègre le stock sans modifier une vente clôturée ;
2. `GET/POST/PUT/DELETE /api/produits/:id/bom` pour administrer
   `produits_bom` sous transaction.

Une annulation par `DELETE` ou `UPDATE` serait incompatible avec les triggers
d’inaltérabilité décrits dans l’audit backend. Ces contrats doivent donc être
conçus et sécurisés côté serveur avant activation mobile.

## Vérifications

- formatage Dart de `lib/` et `test/` ;
- `flutter analyze` sans constat ;
- 15 tests unitaires/API/widget : parsing produit, centimes, stock, panier,
  idempotence/rejeu, Bearer JWT, contrat JSON, URL et navigation caisse ;
- configuration Gradle 8.7 et Java 17 préservée ;
- chaîne Android alignée sur AGP 8.5.1, Kotlin 1.9.22, NDK 26.1,
  Gradle 8.7 et Java 17 ;
- build APK release propre réussi : `23 379 983` octets, SHA-256
  `2aa5a74d2944e50ac491ddc933940edd82876d6a342b2e4ae7449ffeaee925e9` ;
- archive APK testée sans erreur et signature de développement vérifiée en
  schémas Android v1 et v2.

## Prochain lot backend recommandé

Ajouter ensuite les contrats d’annulation compensatoire et de gestion BOM avec
validation, JWT, transactions, verrous et tests PostgreSQL concurrents. Le
mobile pourra alors remplacer le dernier encart BOM sans compromettre
l’inaltérabilité fiscale.
