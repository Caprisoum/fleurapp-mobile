import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';

import '../integration_test/support/fake_fleur_backend.dart';

void main() {
  testWidgets('fiche produit sans overflow sur la largeur du Poco F7',
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

    await tester.tap(find.byIcon(Icons.local_florist_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Gestion du catalogue'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'catalogue');

    await tester.tap(find.byTooltip('Importer un catalogue CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Importer un catalogue CSV'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'import CSV');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Plantes vertes');
    await tester.tap(find.byTooltip('Créer'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'catégories');
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produit'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau produit'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'fiche produit vide');

    await tester.enterText(_fieldWithLabel('Nom'), 'Monstera QA');
    await tester.enterText(_fieldWithLabel('Prix TTC'), '19,90');
    await tester.enterText(_fieldWithLabel('Stock actuel'), '6');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'fiche produit remplie');

    final save = find.widgetWithText(FilledButton, 'Enregistrer');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Nouveau produit'), findsNothing);
    expect(backend.products.last['name'], 'Monstera QA');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Monstera QA'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'produit enregistré');
  });

  testWidgets('crée une nomenclature sans overflow sur la largeur du Poco F7',
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

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('BOM'));
    await tester.tap(find.text('BOM'));
    await tester.pumpAndSettle();

    expect(find.text('Bouquet champêtre'), findsOneWidget);
    expect(find.textContaining('2 disponible(s)'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'liste BOM');

    await tester.tap(find.byKey(const Key('create-bom-button')));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle nomenclature'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orchidée épuisée').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rose rouge').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer').last);
    await tester.pumpAndSettle();

    expect(backend.bomRecipes.length, 2);
    expect(
      backend.bomRecipes.any((recipe) => recipe['parent_id'] == 3),
      isTrue,
    );
    expect(tester.takeException(), isNull, reason: 'création BOM');
  });
}

Finder _fieldWithLabel(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
