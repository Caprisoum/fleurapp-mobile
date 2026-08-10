import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/models/bug_report.dart';
import 'package:fleurapp_mobile/models/payment_method.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/services/checkout_device_token_store.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';

import 'support/fake_fleur_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FleurApp sur appareil Android', () {
    testWidgets('réseau : erreur catalogue claire puis reprise par Réessayer',
        (tester) async {
      await _launch(tester, productFailures: 1);

      expect(find.text('Catalogue indisponible'), findsOneWidget);
      expect(
          find.text('Catalogue temporairement indisponible.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Signaler un problème'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Rose rouge'), findsOneWidget);
      expect(find.text('Catalogue indisponible'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'caisse : recherche, panier, conflit de stock et encaissement protégé',
        (tester) async {
      final harness = await _launch(tester, orderFailure: 409);

      expect(find.text('Rose rouge'), findsOneWidget);
      expect(find.text('Orchidée épuisée'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'rose');
      await tester.pumpAndSettle();
      expect(find.text('Rose rouge'), findsOneWidget);
      expect(find.text('Bouquet champêtre'), findsNothing);
      await _dismissKeyboard(tester);

      await tester.tap(find.text('Rose rouge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panier'));
      await tester.pumpAndSettle();
      expect(find.text('Commande en cours'), findsOneWidget);
      expect(find.text('4,50 €'), findsAtLeastNWidgets(2));

      await tester.ensureVisible(find.text('Encaisser'));
      await tester.tap(find.text('Encaisser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Espèces'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer l’encaissement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stock insuffisant'), findsOneWidget);
      expect(find.textContaining('panier a été conservé'), findsOneWidget);
      expect(find.text('Commande en cours'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.text('Commande en cours')))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Encaisser'));
      await tester.tap(find.text('Encaisser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Espèces'));
      await tester.tap(find.text('Confirmer l’encaissement'));
      await tester.pumpAndSettle();

      expect(find.text('Ticket #501'), findsOneWidget);
      expect(harness.backend.orderRequests, hasLength(2));
      final successful = harness.backend.orderRequests.last;
      expect(_header(successful.headers, 'idempotency-key'),
          startsWith('mobile_'));
      expect(
        _header(successful.headers, 'x-checkout-token'),
        FakeFleurBackend.checkoutToken,
      );
      final body = jsonDecode(successful.body) as Map<String, dynamic>;
      expect(body['cartItems'], [
        {'id': 1, 'quantity': 1}
      ]);
      expect(body['mode_paiement'], PaymentMethod.cash.apiValue);

      await tester.tap(find.text('Nouvelle vente'));
      await tester.pumpAndSettle();
      expect(find.text('Votre panier est vide'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('administration : PIN, JWT, catégories et fiche produit',
        (tester) async {
      final harness = await _launch(tester);
      await _openDestination(tester, Icons.local_florist_outlined);

      expect(find.text('Accès administrateur'), findsOneWidget);
      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, '1111');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Code PIN incorrect.'), findsOneWidget);

      await tester.enterText(pinField, '4827');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(find.text('Gestion du catalogue'), findsOneWidget);
      _expectNoLayoutError(tester, 'chargement de l’administration');
      expect(harness.tokens.token, 'test-jwt');
      expect(
        harness.backend.requests
            .where((request) => request.url.path == '/api/clients')
            .every((request) =>
                _header(request.headers, 'authorization') == 'Bearer test-jwt'),
        isTrue,
      );

      await tester.tap(find.byTooltip('Importer un catalogue CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Importer un catalogue CSV'), findsOneWidget);
      expect(find.text('Choisir un fichier CSV'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      _expectNoLayoutError(tester, 'dialogue d’import CSV');

      await tester.tap(find.text('Catégories'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Plantes vertes');
      await tester.tap(find.byTooltip('Créer'));
      await tester.pumpAndSettle();
      expect(find.text('Plantes vertes'), findsOneWidget);
      await tester.tap(find.text('Terminer'));
      await tester.pumpAndSettle();
      _expectNoLayoutError(tester, 'gestion des catégories');

      await tester.tap(find.text('Produit'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau produit'), findsOneWidget);
      _expectNoLayoutError(tester, 'ouverture de la fiche produit');
      await tester.enterText(_fieldWithLabel('Nom'), 'Monstera QA');
      await tester.enterText(_fieldWithLabel('Prix TTC'), '19,90');
      await tester.enterText(_fieldWithLabel('Stock actuel'), '6');
      await _dismissKeyboard(tester);
      final saveProduct = find.widgetWithText(FilledButton, 'Enregistrer');
      await tester.ensureVisible(saveProduct);
      await tester.tap(saveProduct);
      await tester.pumpAndSettle();

      expect(
          harness.controller.admin.products.any((p) => p.name == 'Monstera QA'),
          isTrue);
      expect(find.text('Produit créé.'), findsOneWidget);
      _expectNoLayoutError(tester, 'enregistrement de la fiche produit');
      final createRequest = harness.backend.requests.lastWhere(
        (request) =>
            request.method == 'POST' && request.url.path == '/api/produits',
      );
      expect(
          _header(createRequest.headers, 'authorization'), 'Bearer test-jwt');
      expect(tester.takeException(), isNull);
    });

    testWidgets('stocks : réception, perte, historiques et nomenclatures',
        (tester) async {
      final harness = await _launch(tester, authenticated: true);
      await _openDestination(tester, Icons.inventory_2_outlined);
      await tester.pumpAndSettle();
      expect(find.text('Rose rouge'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réceptionner'));
      await tester.pumpAndSettle();
      expect(find.text('Réception — Rose rouge'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '2');
      await _dismissKeyboard(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Réception enregistrée.'), findsOneWidget);
      expect(harness.backend.products.first['stock_actuel'], 32);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Déclarer une perte'));
      await tester.pumpAndSettle();
      await tester.enterText(_fieldWithLabel('Quantité'), '2');
      await tester.enterText(_fieldWithLabel('Motif'), 'Tige cassée');
      await _dismissKeyboard(tester);
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Perte enregistrée.'), findsOneWidget);
      expect(harness.backend.products.first['stock_actuel'], 30);

      await tester.tap(find.text('Réceptions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 botte'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Pertes'));
      await tester.pumpAndSettle();
      expect(find.text('2 × Rose rouge'), findsOneWidget);
      await tester.tap(find.text('BOM'));
      await tester.pumpAndSettle();
      expect(find.text('Nomenclatures protégées côté serveur'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('activité : Ticket Z, FEC, clients, bugs et alertes J-1',
        (tester) async {
      final harness = await _launch(tester, authenticated: true);
      await _openDestination(tester, Icons.assessment_outlined);
      await tester.pumpAndSettle();

      expect(find.text('Clôturer la caisse'), findsOneWidget);
      await tester.tap(find.text('Clôturer la caisse'));
      await tester.pumpAndSettle();
      expect(find.text('Clôturer la journée ?'), findsOneWidget);
      await tester.tap(find.text('Clôturer'));
      await tester.pumpAndSettle();
      expect(find.text('Ticket Z #8'), findsOneWidget);
      expect(find.text('4,50 €'), findsWidgets);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clients'));
      await tester.pumpAndSettle();
      expect(find.text('Martin Alice'), findsOneWidget);

      await tester.drag(find.byType(TabBar), const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FEC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Générer et consulter le FEC'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('JournalCode'), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bugs'));
      await tester.pumpAndSettle();
      expect(find.text('Contraste du catalogue'), findsOneWidget);
      final bugStatus = find.byType(DropdownButtonFormField<BugReportStatus>);
      await tester.ensureVisible(bugStatus);
      await tester.tap(bugStatus);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Résolu').last);
      await tester.pumpAndSettle();
      expect(find.text('Rapport #31 : Résolu.'), findsOneWidget);
      expect(harness.backend.bugs.first['statut'], 'RESOLU');

      await tester.tap(find.byTooltip('Alertes à venir'));
      await tester.pumpAndSettle();
      expect(find.text('Alertes à venir'), findsOneWidget);
      expect(find.text('Arrivage à venir — Rose rouge'), findsOneWidget);
      expect(find.text('Commande Alice Martin'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(find.text('Composant BOM insuffisant'), findsOneWidget);
      expect(find.text('Rappels J-1 actifs'), findsOneWidget);
      expect(harness.scheduler.initialized, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('réglages : santé API, thèmes, rapport de bug et déconnexion',
        (tester) async {
      final harness = await _launch(
        tester,
        authenticated: true,
        checkoutActive: false,
      );
      await _openDestination(tester, Icons.settings_outlined);

      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();
      expect(
        find.text('Backend joignable et base PostgreSQL disponible.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('checkout-device-card')));
      await tester.tap(find.text('Activer'));
      await tester.pumpAndSettle();
      expect(find.text('Caisse activée'), findsOneWidget);
      expect(harness.controller.checkoutDeviceActive, isTrue);
      final activation = harness.backend.requests.lastWhere(
        (request) => request.url.path == '/api/admin/devices',
      );
      expect(_header(activation.headers, 'authorization'), 'Bearer test-jwt');

      await tester.ensureVisible(find.byKey(const Key('theme-mode-selector')));
      await tester.tap(find.text('Sombre'));
      await tester.pumpAndSettle();
      expect(harness.controller.themeMode, ThemeMode.dark);
      expect(harness.settings.themeMode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byKey(const Key('theme-mode-selector'))))
            .brightness,
        Brightness.dark,
      );

      await tester.drag(find.byType(ListView).first, const Offset(0, 450));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Signaler un problème'));
      await tester.tap(find.text('Signaler un problème'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _fieldWithHint('Ex. Impossible de valider le panier'),
        'Erreur écran stocks',
      );
      await tester.enterText(
        _fieldWithHint(
          'Étapes réalisées, résultat attendu et message affiché…',
        ),
        'Le stock ne se rafraîchit pas après une réception de test.',
      );
      await _dismissKeyboard(tester);
      await tester.ensureVisible(find.text('Envoyer le rapport'));
      await tester.tap(find.text('Envoyer le rapport'));
      await tester.pumpAndSettle();
      expect(find.text('Rapport #32 envoyé. Merci !'), findsOneWidget);
      final bugRequest = harness.backend.requests.lastWhere(
        (request) => request.url.path == '/api/bugs',
      );
      final bugBody = jsonDecode(bugRequest.body) as Map<String, dynamic>;
      expect(bugBody['appareil_info'], {
        'os': 'Android 16 (SDK 36)',
        'modele': 'Poco F7',
      });
      expect(bugBody['version_app'], '1.0.0+1');

      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Déconnexion'));
      await tester.tap(find.text('Déconnexion'));
      await tester.pumpAndSettle();
      expect(harness.controller.adminAuthenticated, isFalse);
      expect(harness.tokens.token, isNull);
      expect(harness.scheduler.cleared, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<_Harness> _launch(
  WidgetTester tester, {
  bool authenticated = false,
  int? orderFailure,
  int productFailures = 0,
  bool checkoutActive = true,
}) async {
  final backend = FakeFleurBackend(
    orderFailure: orderFailure,
    productFailures: productFailures,
  );
  final settings = MemorySettingsStore();
  final tokens = MemoryTokenStore(authenticated ? 'test-jwt' : null);
  final scheduler = FakeAlertScheduler();
  final checkoutTokens = EphemeralCheckoutDeviceTokenStore(
    checkoutActive ? FakeFleurBackend.checkoutToken : null,
  );
  final controller = AppController(
    apiClient: RenderApiClient(
      baseUrl: 'https://fleurapp-qa.invalid',
      httpClient: backend.client,
      timeout: const Duration(seconds: 2),
    ),
    settingsStore: settings,
    tokenStore: tokens,
    checkoutTokenStore: checkoutTokens,
    alertScheduler: scheduler,
    deviceMetadataService: const FakeDeviceMetadataService(),
  );
  addTearDown(controller.dispose);
  await controller.initialize();
  await tester.pumpWidget(FleurApp(controller: controller));
  await tester.pumpAndSettle();
  return _Harness(
    backend: backend,
    controller: controller,
    settings: settings,
    tokens: tokens,
    scheduler: scheduler,
  );
}

Future<void> _openDestination(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).last);
  await tester.pumpAndSettle();
}

Future<void> _dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Finder _fieldWithLabel(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );

Finder _fieldWithHint(String hint) => find.ancestor(
      of: find.text(hint),
      matching: find.byType(TextFormField),
    );

String? _header(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

void _expectNoLayoutError(WidgetTester tester, String phase) {
  expect(tester.takeException(), isNull, reason: phase);
}

class _Harness {
  const _Harness({
    required this.backend,
    required this.controller,
    required this.settings,
    required this.tokens,
    required this.scheduler,
  });

  final FakeFleurBackend backend;
  final AppController controller;
  final MemorySettingsStore settings;
  final MemoryTokenStore tokens;
  final FakeAlertScheduler scheduler;
}
