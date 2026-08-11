import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/models/admin_models.dart';
import 'package:fleurapp_mobile/models/bom_recipe.dart';
import 'package:fleurapp_mobile/models/cart_item.dart';
import 'package:fleurapp_mobile/models/catalog_import.dart';
import 'package:fleurapp_mobile/models/bug_report.dart';
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
    )..updateCheckoutToken('fdev_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
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
      customerId: 17,
    );
    final sentBody = jsonDecode(sentRequest.body) as Map<String, dynamic>;
    expect(sentRequest.headers['Idempotency-Key'],
        'mobile_0123456789abcdef0123456789abcdef');
    expect(sentRequest.headers['X-Checkout-Token'],
        'fdev_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    expect(sentBody['mode_paiement'], 'Carte Bancaire - TPE');
    expect(sentBody['clientId'], 17);
    expect((sentBody['cartItems'] as List).single, {'id': 7, 'quantity': 2});
    expect(receipt.totalCents, 1300);
    expect(receipt.lines.single.totalCents, 1300);
    api.close();
  });

  test('active, vérifie et révoque une identité de caisse sécurisée', () async {
    const deviceToken = 'fdev_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final requests = <http.Request>[];
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/admin/devices') {
          return _jsonResponse({
            'success': true,
            'device': {'id': 4, 'nom': 'Poco F7'},
            'token': deviceToken,
          }, statusCode: 201);
        }
        return _jsonResponse({
          'success': true,
          'device': {'id': 4}
        });
      }),
    )..updateAdminToken('jwt-device-admin');

    final token = await api.registerCheckoutDevice('Poco F7');
    expect(token, deviceToken);
    api.updateCheckoutToken(token);
    await api.checkCheckoutDevice();
    await api.revokeCheckoutDevice();

    expect(requests.first.headers['Authorization'], 'Bearer jwt-device-admin');
    expect(jsonDecode(requests.first.body), {'nom': 'Poco F7'});
    expect(requests[1].headers['X-Checkout-Token'], deviceToken);
    expect(requests[2].method, 'DELETE');
    expect(requests[2].headers['X-Checkout-Token'], deviceToken);
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

  test('crée un client et consulte une commande persistée', () async {
    final requests = <http.Request>[];
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return _jsonResponse({
            'success': true,
            'client': {
              'id': 8,
              'nom': 'Durand',
              'prenom': 'Zoé',
              'telephone': '0611223344',
              'email': 'zoe@example.fr',
            },
          }, statusCode: 201);
        }
        final baseOrder = {
          'id': 42,
          'client_id': 8,
          'client_nom': 'Durand',
          'client_prenom': 'Zoé',
          'date_commande': '2026-08-11T08:00:00.000Z',
          'total_ttc': '30.00',
          'acompte_paye': '10.00',
          'reste_a_payer': '20.00',
          'statut': 'À PRÉPARER',
          'mode_paiement': 'Espèces',
          'type_commande': 'DIFFÉRÉE',
          'hash_transaction': 'hash-42',
          'cloture_id': null,
        };
        if (request.url.path == '/api/commandes/42') {
          return _jsonResponse({
            ...baseOrder,
            'lignes': [
              {
                'id': 3,
                'produit_id': 7,
                'nom': 'Bouquet pastel',
                'quantite': 2,
                'prix_unitaire_ttc': '15.00',
                'taux_tva': '20.00',
              }
            ],
          });
        }
        return _jsonResponse([
          {...baseOrder, 'nombre_lignes': 1}
        ]);
      }),
    )..updateAdminToken('jwt-client-history');

    final customer = await api.createCustomer(const CustomerDraft(
      lastName: 'Durand',
      firstName: 'Zoé',
      phone: '0611223344',
      email: 'zoe@example.fr',
    ));
    final orders = await api.fetchOrders();
    final detail = await api.fetchOrderDetail(orders.single.id);

    expect(customer.displayName, 'Durand Zoé');
    expect(orders.single.totalCents, 3000);
    expect(detail.lines.single.totalCents, 3000);
    expect(detail.lines.single.vatBasisPoints, 2000);
    expect(
        requests.every((request) =>
            request.headers['Authorization'] == 'Bearer jwt-client-history'),
        isTrue);
    expect(requests.first.body, contains('zoe@example.fr'));
    api.close();
  });

  test('liste, remplace et supprime une nomenclature avec le JWT admin',
      () async {
    final requests = <http.Request>[];
    final recipe = {
      'parent_id': 7,
      'parent_name': 'Bouquet pastel',
      'parent_stock': 5,
      'available_quantity': 3,
      'components': [
        {
          'product_id': 2,
          'product_name': 'Rose',
          'stock': 10,
          'quantity': 3,
          'possible_quantity': 3,
        }
      ],
    };
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') return _jsonResponse([recipe]);
        if (request.method == 'PUT') {
          return _jsonResponse({'success': true, 'recipe': recipe});
        }
        return _jsonResponse({'success': true});
      }),
    )..updateAdminToken('jwt-bom');

    final recipes = await api.fetchBomRecipes();
    final saved = await api.saveBomRecipe(const BomRecipeDraft(
      parentId: 7,
      components: [BomComponentDraft(productId: 2, quantity: 3)],
    ));
    await api.deleteBomRecipe(7);

    expect(recipes.single.availableQuantity, 3);
    expect(saved.components.single.productName, 'Rose');
    expect(requests.map((request) => request.method), ['GET', 'PUT', 'DELETE']);
    expect(requests[1].url.path, '/api/bom/7');
    expect(jsonDecode(requests[1].body), {
      'components': [
        {'productId': 2, 'quantity': 3}
      ],
    });
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer jwt-bom',
      ),
      isTrue,
    );
    api.close();
  });

  test('prévisualise puis importe un CSV avec JWT et idempotence', () async {
    final requests = <http.Request>[];
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/preview')) {
          return _jsonResponse({
            'summary': {'create': 1, 'update': 0, 'skip': 0, 'error': 0},
            'categoriesToCreate': ['Fleurs'],
            'rows': [
              {
                'row': 2,
                'status': 'create',
                'name': 'Rose',
                'category': 'Fleurs',
                'price': '2.50',
              }
            ],
          });
        }
        return _jsonResponse({
          'success': true,
          'created': 1,
          'updated': 0,
          'skipped': 0,
        }, statusCode: 201);
      }),
    )..updateAdminToken('jwt-import');
    const rows = [
      CatalogImportRow({
        'nom': 'Rose',
        'categorie': 'Fleurs',
        'prix_ttc': '2,50',
        'taux_tva': '20',
        'stock_actuel': '10',
      })
    ];

    final preview =
        await api.previewCatalogImport(rows, CatalogDuplicateMode.skip);
    final result = await api.importCatalog(
      rows,
      CatalogDuplicateMode.skip,
      'catalog_mobile_0123456789abcdef',
    );

    expect(preview.canImport, isTrue);
    expect(result.created, 1);
    expect(requests.first.headers['Authorization'], 'Bearer jwt-import');
    expect(requests.last.headers['Idempotency-Key'],
        'catalog_mobile_0123456789abcdef');
    expect(requests.last.url.path, '/api/admin/catalogue/import');
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

  test('envoie un rapport public avec les métadonnées sans JWT', () async {
    late http.Request sentRequest;
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        sentRequest = request;
        return _jsonResponse({
          'success': true,
          'bug': {
            'id': 12,
            'titre': 'Écran de paiement bloqué',
            'description': 'Le bouton de validation ne répond plus.',
            'categorie': 'Paiement',
            'appareil_info': {
              'os': 'Android 15 (SDK 35)',
              'modele': 'Xiaomi POCO F7',
            },
            'version_app': '1.2.0+3',
            'statut': 'NOUVEAU',
            'created_at': '2026-08-08T20:00:00.000Z',
          },
        }, statusCode: 201);
      }),
    )..updateAdminToken('jwt-qui-ne-doit-pas-partir');

    final report = await api.submitBugReport(const BugReportDraft(
      title: 'Écran de paiement bloqué',
      description: 'Le bouton de validation ne répond plus.',
      category: BugCategory.payment,
      device: BugDeviceMetadata(
        os: 'Android 15 (SDK 35)',
        model: 'Xiaomi POCO F7',
        appVersion: '1.2.0+3',
      ),
    ));
    final body = jsonDecode(sentRequest.body) as Map<String, dynamic>;
    expect(sentRequest.method, 'POST');
    expect(sentRequest.url.path, '/api/bugs');
    expect(sentRequest.headers.containsKey('Authorization'), isFalse);
    expect(body['categorie'], 'Paiement');
    expect((body['appareil_info'] as Map)['modele'], 'Xiaomi POCO F7');
    expect(report.id, 12);
    expect(report.status, BugReportStatus.newReport);
    api.close();
  });

  test('liste et traite les rapports avec le JWT admin', () async {
    final requests = <http.Request>[];
    final stored = {
      'id': 22,
      'titre': 'Décalage visuel',
      'description': 'Le texte dépasse sur un petit écran Android.',
      'categorie': 'UI',
      'appareil_info': {'os': 'Android 15', 'modele': 'POCO F7'},
      'version_app': '1.2.0+3',
      'statut': 'RESOLU',
      'created_at': '2026-08-08T20:00:00.000Z',
    };
    final api = RenderApiClient(
      baseUrl: 'https://fleurapp-test.onrender.com',
      httpClient: MockClient((request) async {
        requests.add(request);
        return request.method == 'GET'
            ? _jsonResponse([stored])
            : _jsonResponse({'success': true, 'bug': stored});
      }),
    )..updateAdminToken('jwt-bugs');

    final reports = await api.fetchBugReports(status: BugReportStatus.resolved);
    final updated = await api.updateBugReportStatus(
      reports.single.id,
      BugReportStatus.resolved,
    );
    expect(requests.first.url.queryParameters, {
      'limit': '200',
      'statut': 'RESOLU',
    });
    expect(requests.first.headers['Authorization'], 'Bearer jwt-bugs');
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, '/api/admin/bugs/22');
    expect(jsonDecode(requests.last.body), {'statut': 'RESOLU'});
    expect(updated.status, BugReportStatus.resolved);
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
