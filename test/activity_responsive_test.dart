import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';

import '../integration_test/support/fake_fleur_backend.dart';

void main() {
  testWidgets('activité, bugs et alertes sans overflow sur le Poco F7',
      (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = FakeFleurBackend();
    final controller = AppController(
      apiClient: RenderApiClient(
        baseUrl: 'https://fleurapp-qa.invalid',
        httpClient: backend.client,
      ),
      settingsStore: MemorySettingsStore(),
      tokenStore: MemoryTokenStore('test-jwt'),
      alertScheduler: FakeAlertScheduler(),
      deviceMetadataService: const FakeDeviceMetadataService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.assessment_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Clôturer la caisse'), findsOneWidget);

    await tester.tap(find.text('Clôturer la caisse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clôturer'));
    await tester.pumpAndSettle();
    expect(find.text('Ticket Z #8'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clients'));
    await tester.pumpAndSettle();
    expect(find.text('Martin Alice'), findsOneWidget);
    await tester.tap(find.text('Ajouter un client'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom *'),
      'Durand',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'durand@example.fr',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Durand'), findsOneWidget);

    await tester.tap(find.text('Ventes'));
    await tester.pumpAndSettle();
    expect(find.text('25,00\u00a0€'), findsOneWidget);
    await tester.tap(find.text('25,00\u00a0€'));
    await tester.pumpAndSettle();
    expect(find.text('Commande #500'), findsOneWidget);
    expect(find.textContaining('Bouquet champêtre'), findsOneWidget);
    await tester.tap(find.text('Annuler la vente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Motif obligatoire'),
      'Erreur de saisie pendant la recette',
    );
    await tester.tap(find.text('Créer l’annulation'));
    await tester.pumpAndSettle();
    expect(backend.orders.first['annulation_id'], 700);
    expect(find.textContaining('ANNULÉE'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();

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
    await tester.scrollUntilVisible(
      find.text('Suivi par le support FleurApp'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Suivi par le support FleurApp'), findsOneWidget);
    expect(find.text('Statut du rapport'), findsNothing);
    expect(backend.bugs.first['statut'], 'NOUVEAU');

    await tester.tap(find.byTooltip('Alertes à venir'));
    await tester.pumpAndSettle();
    expect(find.text('Arrivage à venir — Rose rouge'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Commande Alice Martin'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Commande Alice Martin'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Composant BOM insuffisant'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Composant BOM insuffisant'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Calendrier des arrivages'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Calendrier des arrivages'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
