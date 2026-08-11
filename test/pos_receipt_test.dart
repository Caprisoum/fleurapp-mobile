import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/services/checkout_device_token_store.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';

import '../integration_test/support/fake_fleur_backend.dart';

void main() {
  testWidgets('le ticket est structuré et se ferme en touchant l’arrière-plan',
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
      tokenStore: MemoryTokenStore(),
      checkoutTokenStore: EphemeralCheckoutDeviceTokenStore(
        FakeFleurBackend.checkoutToken,
      ),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rose rouge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encaisser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espèces'));
    await tester.tap(find.text('Confirmer l’encaissement'));
    await tester.pumpAndSettle();

    expect(find.text('Ticket #501'), findsOneWidget);
    expect(find.text('1 ×'), findsOneWidget);
    expect(find.text('Rose rouge'), findsOneWidget);
    expect(find.byKey(const Key('close-receipt-button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Ticket #501'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
