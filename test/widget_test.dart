import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/services/admin_token_store.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/services/local_settings_store.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('affiche le catalogue et ajoute un produit au panier',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async => http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'Bouquet champêtre',
                'price_ttc': '25.00',
                'vat_rate': '20.00',
                'category_name': 'Bouquets',
                'stock_actuel': 4,
              }
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(
      controller.pos.products,
      isNotEmpty,
      reason: controller.pos.catalogError,
    );
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Bouquet champêtre'), findsOneWidget);
    await tester.tap(find.text('Bouquet champêtre'));
    await tester.pump();
    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();

    expect(find.text('Commande en cours'), findsOneWidget);
    expect(find.text('25,00\u00a0€'), findsAtLeastNWidgets(2));
    expect(find.text('Encaisser'), findsOneWidget);
  });

  testWidgets('navigue sans overflow sur les modules Poco F7', (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async {
        final Object payload = switch (request.url.path) {
          '/api/produits' => [
              {
                'id': 1,
                'name': 'Rose rouge',
                'price_ttc': '4.50',
                'base_price_ttc': '4.50',
                'vat_rate': '20.00',
                'category_name': 'Fleurs',
                'stock_actuel': 12,
              }
            ],
          _ => <Object>[],
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore('jwt-test'),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.local_florist_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Gestion du catalogue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Stocks'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.assessment_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Clôtures'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Serveur Render'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemorySettingsStore implements LocalSettingsStore {
  @override
  Future<LocalSettings> read() async => const LocalSettings(
        apiBaseUrl: 'https://fleurapp-test.onrender.com',
        themeMode: ThemeMode.light,
      );

  @override
  Future<void> writeApiBaseUrl(String value) async {}

  @override
  Future<void> writeThemeMode(ThemeMode value) async {}
}

class _MemoryTokenStore implements AdminTokenStore {
  _MemoryTokenStore([this.token]);
  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}
