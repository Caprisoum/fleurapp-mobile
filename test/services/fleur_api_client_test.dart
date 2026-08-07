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
    final httpClient = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode([
          {
            'id': 7,
            'name': 'Pivoine',
            'price_ttc': '6.50',
            'vat_rate': '20',
            'category_name': 'Fleurs',
          }
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com/',
      httpClient: httpClient,
    );

    final products = await api.fetchProducts();

    expect(
      requestedUri,
      Uri.parse('https://fleurapp-test.onrender.com/api/produits'),
    );
    expect(products.single.name, 'Pivoine');
    api.close();
  });

  test('envoie uniquement le contrat de commande accepté par le backend',
      () async {
    late Map<String, dynamic> sentBody;
    final httpClient = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'orderId': 91,
          'totalTTC': 13,
          'hash': 'hash-test',
          'statut': 'TERMINÉE',
        }),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: httpClient,
    );

    final receipt = await api.createOrder(
      items: const [
        CartItem(
          product: Product(
            id: 7,
            name: 'Pivoine',
            priceTtc: 6.5,
            vatRate: 20,
            category: 'Fleurs',
          ),
          quantity: 2,
        ),
      ],
      paymentMethod: PaymentMethod.card,
    );

    expect(sentBody['mode_paiement'], 'Carte bancaire');
    expect((sentBody['cartItems'] as List).single['id'], 7);
    expect((sentBody['cartItems'] as List).single['quantity'], 2);
    expect(receipt.orderId, 91);
    api.close();
  });

  test('signale clairement une URL non configurée', () async {
    final api = RenderApiClient(
        baseUrl: '',
        httpClient: MockClient((_) async {
          throw StateError('La requête ne doit pas partir.');
        }));

    expect(api.fetchProducts(), throwsA(isA<ApiConfigurationException>()));
    api.close();
  });
}
