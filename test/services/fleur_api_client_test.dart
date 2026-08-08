import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/models/cart_item.dart';
import 'package:fleurapp_mobile/models/payment_method.dart';
import 'package:fleurapp_mobile/models/product.dart';
import 'package:fleurapp_mobile/services/api_exception.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('charge le catalogue depuis la route Render attendue', () async {
    late Uri requestedUri;
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com/',
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return _jsonResponse([
          {
            'id': 7,
            'name': 'Pivoine',
            'price_ttc': '6.50',
            'vat_rate': '20',
            'category_name': 'Fleurs',
          }
        ]);
      }),
    );
    final products = await api.fetchProducts();
    expect(requestedUri,
        Uri.parse('https://fleurapp-test.onrender.com/api/produits'));
    expect(products.single.priceCents, 650);
    api.close();
  });

  test('envoie le contrat minimal et la clé d’idempotence', () async {
    late http.Request sentRequest;
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        sentRequest = request;
        return _jsonResponse({
          'orderId': 91,
          'totalTTC': 13,
          'hash': 'hash-test',
          'statut': 'TERMINÉE',
          'items': [
            {'id': 7, 'name': 'Pivoine', 'quantity': 2, 'price_ttc': 6.5}
          ],
        }, statusCode: 201);
      }),
    );
    final receipt = await api.createOrder(
      items: const [
        CartItem(
          product: Product(
            id: 7,
            name: 'Pivoine',
            priceCents: 650,
            vatBasisPoints: 2000,
            category: 'Fleurs',
          ),
          quantity: 2,
        ),
      ],
      paymentMethod: PaymentMethod.card,
      idempotencyKey: 'mobile_0123456789abcdef0123456789abcdef',
    );
    final sentBody = jsonDecode(sentRequest.body) as Map<String, dynamic>;
    expect(sentRequest.headers['Idempotency-Key'],
        'mobile_0123456789abcdef0123456789abcdef');
    expect(sentBody['mode_paiement'], 'Carte Bancaire - TPE');
    expect((sentBody['cartItems'] as List).single, {'id': 7, 'quantity': 2});
    expect(receipt.totalCents, 1300);
    expect(receipt.lines.single.totalCents, 1300);
    api.close();
  });

  test('ajoute le Bearer JWT uniquement sur les routes admin', () async {
    late http.Request sentRequest;
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        sentRequest = request;
        return _jsonResponse([]);
      }),
    )..updateAdminToken('jwt-secret-test');
    await api.fetchCustomers();
    expect(sentRequest.headers['Authorization'], 'Bearer jwt-secret-test');
    api.close();
  });

  test('charge et valide le centre d’alertes avec le JWT admin', () async {
    late http.Request sentRequest;
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.ngrok-free.app',
      httpClient: MockClient((request) async {
        sentRequest = request;
        return _jsonResponse({
          'generatedAt': '2026-08-08T08:00:00.000Z',
          'window': {
            'to': '2026-08-10T08:00:00.000Z',
            'timeZone': 'Europe/Paris',
          },
          'summary': {
            'total': 1,
            'arrivals': 0,
            'orders': 1,
            'bomAlerts': 0,
            'critical': 0,
          },
          'notifications': [
            {
              'id': 'order:42:2026-08-09T10:00:00.000Z',
              'type': 'order',
              'severity': 'warning',
              'title': 'Commande #42 à préparer',
              'message': 'Livraison demain.',
              'eventAt': '2026-08-09T10:00:00.000Z',
              'remindAt': '2026-08-08T10:00:00.000Z',
              'hoursUntil': 26,
              'data': {'orderId': 42},
            }
          ],
        });
      }),
    )..updateAdminToken('jwt-notifications');

    final payload = await api.fetchUpcomingAlerts();
    expect(sentRequest.url.path, '/api/notifications/a-venir');
    expect(sentRequest.headers['Authorization'], 'Bearer jwt-notifications');
    expect(sentRequest.headers['Bypass-Tunnel-Reminder'], 'FleurApp-Mobile');
    expect(payload.summary.orders, 1);
    expect(payload.alerts.single.hoursUntil, 26);
    api.close();
  });

  test('signale clairement une URL non configurée', () async {
    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((_) async => throw StateError('inatteignable')),
    );
    expect(api.fetchProducts(), throwsA(isA<ApiConfigurationException>()));
    api.close();
  });

  test('refuse une URL avec chemin, identifiants ou paramètres', () {
    expect(
      () => RenderApiClient.normalizeBaseUrl('https://example.com/api'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => RenderApiClient.normalizeBaseUrl('https://user@example.com?x=1'),
      throwsA(isA<ApiException>()),
    );
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
