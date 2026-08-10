import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/services/admin_token_store.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/services/local_settings_store.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parcours mobile catalogue, panier et encaissement idempotent',
      (tester) async {
    http.Request? orderRequest;
    var productLoads = 0;
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-qa.invalid',
      httpClient: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/produits') {
          productLoads++;
          return _jsonResponse([
            {
              'id': 1,
              'name': 'Rose rouge',
              'price_ttc': '4.50',
              'base_price_ttc': '4.50',
              'vat_rate': '20.00',
              'category_name': 'Fleurs',
              'stock_actuel': productLoads == 1 ? 12 : 11,
            }
          ]);
        }
        if (request.method == 'POST' && request.url.path == '/api/commandes') {
          orderRequest = request;
          return _jsonResponse(
            {
              'success': true,
              'orderId': 501,
              'totalTTC': '4.50',
              'statut': 'PAYEE',
              'hash': List.filled(64, 'a').join(),
              'items': [
                {
                  'id': 1,
                  'name': 'Rose rouge',
                  'quantity': 1,
                  'price_ttc': '4.50',
                }
              ],
            },
            statusCode: 201,
          );
        }
        return _jsonResponse(<Object>[]);
      }),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: const _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Rose rouge'), findsOneWidget);
    await tester.tap(find.text('Rose rouge'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();
    expect(find.text('4,50 €'), findsWidgets);

    await tester.tap(find.text('Encaisser'));
    await tester.pumpAndSettle();
    expect(find.text('Encaisser 4,50 €'), findsOneWidget);

    await tester.tap(find.text('Confirmer l’encaissement'));
    await tester.pumpAndSettle();

    expect(find.text('Ticket #501'), findsOneWidget);
    expect(orderRequest, isNotNull);
    expect(
      orderRequest!.headers.entries
          .firstWhere((entry) => entry.key.toLowerCase() == 'idempotency-key')
          .value,
      startsWith('mobile_'),
    );
    final body = jsonDecode(orderRequest!.body) as Map<String, dynamic>;
    expect(body['cartItems'], [
      {'id': 1, 'quantity': 1}
    ]);
    expect(body['mode_paiement'], 'Carte Bancaire');
    expect(productLoads, 2);
    expect(tester.takeException(), isNull);
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class _MemorySettingsStore implements LocalSettingsStore {
  const _MemorySettingsStore();

  @override
  Future<LocalSettings> read() async => const LocalSettings(
        apiBaseUrl: 'https://fleurapp-qa.invalid',
        themeMode: ThemeMode.light,
      );

  @override
  Future<void> writeApiBaseUrl(String value) async {}

  @override
  Future<void> writeThemeMode(ThemeMode value) async {}
}

class _MemoryTokenStore implements AdminTokenStore {
  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}
