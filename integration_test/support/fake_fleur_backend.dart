import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fleurapp_mobile/models/bug_report.dart';
import 'package:fleurapp_mobile/models/upcoming_alert.dart';
import 'package:fleurapp_mobile/services/admin_token_store.dart';
import 'package:fleurapp_mobile/services/device_metadata_service.dart';
import 'package:fleurapp_mobile/services/local_alert_scheduler.dart';
import 'package:fleurapp_mobile/services/local_settings_store.dart';

class FakeFleurBackend {
  FakeFleurBackend({this.orderFailure, this.productFailures = 0});

  int? orderFailure;
  int productFailures;
  int nextOrderId = 501;
  int nextProductId = 10;
  int nextCategoryId = 10;
  int nextCustomerId = 5;
  int nextBugId = 32;
  final requests = <http.Request>[];
  final orderRequests = <http.Request>[];
  static const checkoutToken =
      'fdev_ccccccccccccccccccccccccccccccccccccccccccc';

  final categories = <Map<String, dynamic>>[
    {'id': 1, 'nom': 'Fleurs'},
    {'id': 2, 'nom': 'Bouquets'},
  ];

  final products = <Map<String, dynamic>>[
    {
      'id': 1,
      'name': 'Rose rouge',
      'price_ttc': '4.50',
      'base_price_ttc': '4.50',
      'vat_rate': '20.00',
      'categorie_id': 1,
      'category_name': 'Fleurs',
      'stock_actuel': 12,
      'unite_achat': 'botte',
      'unite_vente': 'tige',
      'ratio_conversion': 10,
      'date_arrivage': '2026-08-10',
      'duree_de_vie_jours': 5,
      'fraicheur_statut': 'frais',
      'jours_restants': 4,
    },
    {
      'id': 2,
      'name': 'Bouquet champêtre',
      'price_ttc': '25.00',
      'base_price_ttc': '25.00',
      'vat_rate': '20.00',
      'categorie_id': 2,
      'category_name': 'Bouquets',
      'stock_actuel': 3,
      'date_arrivage': '2026-08-08',
      'duree_de_vie_jours': 5,
      'fraicheur_statut': 'urgent',
      'jours_restants': 2,
    },
    {
      'id': 3,
      'name': 'Orchidée épuisée',
      'price_ttc': '18.00',
      'vat_rate': '20.00',
      'categorie_id': 1,
      'category_name': 'Fleurs',
      'stock_actuel': 0,
    },
  ];

  final receptions = <Map<String, dynamic>>[
    {
      'id': 1,
      'produit_nom': 'Rose rouge',
      'quantite_recue': 2,
      'unite_achat': 'botte',
      'quantite_vente_ajoutee': 20,
      'unite_vente': 'tige',
      'stock_avant': 10,
      'stock_apres': 30,
      'date_reception': '2026-08-10T08:00:00.000Z',
    },
  ];

  final wastes = <Map<String, dynamic>>[
    {
      'id': 1,
      'produit_nom': 'Rose rouge',
      'quantite': 1,
      'motif': 'Fané',
      'date_perte': '2026-08-10T09:00:00.000Z',
    },
  ];

  final closures = <Map<String, dynamic>>[
    {
      'id': 7,
      'total_ca_ttc': '129.50',
      'total_tva': '21.58',
      'nombre_transactions': 8,
      'nombre_annulations': 0,
      'hash_cloture': _hashB,
      'date_cloture': '2026-08-09T19:00:00.000Z',
    },
  ];

  final bugs = <Map<String, dynamic>>[
    {
      'id': 31,
      'titre': 'Contraste du catalogue',
      'description': 'Le nom des fleurs est difficile à lire en mode sombre.',
      'categorie': 'UI',
      'appareil_info': {'os': 'Android 16', 'modele': 'Poco F7'},
      'version_app': '1.0.0+1',
      'statut': 'NOUVEAU',
      'created_at': '2026-08-10T10:00:00.000Z',
    },
  ];

  final customers = <Map<String, dynamic>>[
    {
      'id': 4,
      'nom': 'Martin',
      'prenom': 'Alice',
      'telephone': '0612345678',
      'email': 'alice@example.fr',
      'allergies': 'Lys',
      'preferences': 'Bouquets colorés',
    }
  ];

  final orders = <Map<String, dynamic>>[
    {
      'id': 500,
      'client_id': 4,
      'client_nom': 'Martin',
      'client_prenom': 'Alice',
      'client_telephone': '0612345678',
      'date_commande': '2026-08-10T09:00:00.000Z',
      'date_livraison': '2026-08-11T10:00:00.000Z',
      'total_ttc': '25.00',
      'acompte_paye': '10.00',
      'reste_a_payer': '15.00',
      'statut': 'À PRÉPARER',
      'mode_paiement': 'Espèces',
      'type_commande': 'DIFFÉRÉE',
      'hash_transaction': _hashA,
      'stock_snapshot_version': 1,
      'nombre_lignes': 1,
      'cloture_id': null,
    }
  ];

  final bomRecipes = <Map<String, dynamic>>[
    {
      'parent_id': 2,
      'parent_name': 'Bouquet champêtre',
      'parent_stock': 3,
      'available_quantity': 2,
      'components': [
        {
          'product_id': 1,
          'product_name': 'Rose rouge',
          'stock': 12,
          'quantity': 5,
          'possible_quantity': 2,
        }
      ],
    }
  ];

  MockClient get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    final method = request.method;

    if (method == 'GET' && path == '/api/health') {
      return _json({'status': 'ok', 'database': 'connected'});
    }
    if (method == 'POST' && path == '/api/auth/login') {
      final body = _body(request);
      if (body['pin'] != '4827') {
        return _json({'error': 'Code PIN incorrect.'}, status: 401);
      }
      return _json({'token': 'test-jwt', 'expiresIn': '15m'});
    }
    if (path == '/api/devices/me') {
      String? token;
      for (final entry in request.headers.entries) {
        if (entry.key.toLowerCase() == 'x-checkout-token') {
          token = entry.value;
          break;
        }
      }
      if (token != checkoutToken) {
        return _json({'error': 'Caisse non activée ou révoquée.'}, status: 401);
      }
      return _json({
        'success': true,
        'device': {'id': 9, 'nom': 'Poco F7'}
      });
    }
    if (method == 'GET' && path == '/api/produits') {
      if (productFailures > 0) {
        productFailures--;
        return _json(
          {'error': 'Catalogue temporairement indisponible.'},
          status: 503,
        );
      }
      return _json(products);
    }
    if (method == 'GET' && path == '/api/categories') {
      return _json(categories);
    }
    if (method == 'POST' && path == '/api/bugs') {
      final body = _body(request);
      final report = <String, dynamic>{
        'id': nextBugId++,
        ...body,
        'statut': 'NOUVEAU',
        'created_at': '2026-08-10T20:00:00.000Z',
      };
      bugs.insert(0, report);
      return _json({'success': true, 'bug': report}, status: 201);
    }
    if (method == 'POST' && path == '/api/commandes') {
      orderRequests.add(request);
      final failure = orderFailure;
      if (failure != null) {
        orderFailure = null;
        return _json(
          {
            'error': failure == 409
                ? 'Stock insuffisant pour Rose rouge.'
                : 'Erreur de test.',
            'requestId': 'qa-device-409',
          },
          status: failure,
        );
      }
      final body = _body(request);
      final rawItems = body['cartItems'] as List<dynamic>? ?? const [];
      var totalCents = 0;
      final items = <Map<String, dynamic>>[];
      for (final raw in rawItems) {
        final line = Map<String, dynamic>.from(raw as Map);
        if (line['type'] == 'custom') {
          final quantity = line['quantity'] as int;
          final cents = _moneyToCents(line['price_ttc']);
          totalCents += cents * quantity;
          items.add({
            'id': null,
            'name': line['name'],
            'quantity': quantity,
            'price_ttc': line['price_ttc'],
          });
          continue;
        }
        final product = products.firstWhere(
          (item) => item['id'] == line['id'],
        );
        final quantity = line['quantity'] as int;
        final cents = _moneyToCents(product['price_ttc']);
        totalCents += cents * quantity;
        product['stock_actuel'] = (product['stock_actuel'] as int) - quantity;
        items.add({
          'id': product['id'],
          'name': product['name'],
          'quantity': quantity,
          'price_ttc': product['price_ttc'],
        });
      }
      final deposit = body['acompte']?.toString();
      final depositCents = deposit == null ? null : _moneyToCents(deposit);
      return _json(
        {
          'success': true,
          'orderId': nextOrderId++,
          'totalTTC': _cents(totalCents),
          if (deposit != null) 'acomptePaye': deposit,
          if (depositCents != null)
            'resteAPayer': _cents(totalCents - depositCents),
          'statut': body['isFutureOrder'] == true ? 'EN_ATTENTE' : 'PAYEE',
          'hash': _hashA,
          'items': items,
        },
        status: 201,
      );
    }

    if (_requiresAdmin(request) && !_authorized(request)) {
      return _json({'error': 'Connexion administrateur requise.'}, status: 401);
    }
    if (method == 'POST' && path == '/api/admin/devices') {
      return _json({
        'success': true,
        'device': {'id': 9, 'nom': _body(request)['nom']},
        'token': checkoutToken,
      }, status: 201);
    }
    if (method == 'GET' && path == '/api/clients') {
      return _json(customers);
    }
    if (method == 'POST' && path == '/api/clients') {
      final client = <String, dynamic>{
        'id': nextCustomerId++,
        ..._body(request),
      };
      customers.add(client);
      return _json({'success': true, 'client': client}, status: 201);
    }
    if (method == 'GET' && path == '/api/commandes') {
      return _json(orders);
    }
    if (method == 'POST' &&
        RegExp(r'^/api/commandes/\d+/annulations$').hasMatch(path)) {
      final id = int.parse(path.split('/')[3]);
      final order = orders.firstWhere((item) => item['id'] == id);
      if (order['annulation_id'] != null || order['cloture_id'] != null) {
        return _json({'error': 'Commande non annulable.'}, status: 409);
      }
      final body = _body(request);
      order
        ..['annulation_id'] = 700
        ..['date_annulation'] = '2026-08-10T10:00:00.000Z'
        ..['annulation_motif'] = body['motif']
        ..['mode_remboursement'] = order['mode_paiement']
        ..['montant_rembourse'] = order['acompte_paye']
        ..['hash_annulation'] = _hashB;
      return _json({
        'success': true,
        'cancellationId': 700,
        'orderId': id,
        'cancelledAt': order['date_annulation'],
        'refundedAmount': order['montant_rembourse'],
        'reason': body['motif'],
        'hash': _hashB,
      }, status: 201);
    }
    if (method == 'GET' && path.startsWith('/api/commandes/')) {
      final id = int.parse(path.split('/').last);
      final order = orders.firstWhere((item) => item['id'] == id);
      return _json({
        ...order,
        'client_email': 'alice@example.fr',
        'lignes': [
          {
            'id': 1,
            'produit_id': 2,
            'nom': 'Bouquet champêtre',
            'quantite': 1,
            'prix_unitaire_ttc': '25.00',
            'taux_tva': '20.00',
          }
        ],
      });
    }
    if (method == 'GET' && path == '/api/stock/receptions') {
      return _json(receptions);
    }
    if (method == 'GET' && path == '/api/bom') return _json(bomRecipes);
    if (method == 'PUT' && path.startsWith('/api/bom/')) {
      final parentId = int.parse(path.split('/').last);
      final parent = products.firstWhere((item) => item['id'] == parentId);
      final rawComponents = _body(request)['components'] as List<dynamic>;
      final components = rawComponents.map((raw) {
        final component = Map<String, dynamic>.from(raw as Map);
        final product = products.firstWhere(
          (item) => item['id'] == component['productId'],
        );
        final stock = product['stock_actuel'] as int;
        final quantity = component['quantity'] as int;
        return <String, dynamic>{
          'product_id': product['id'],
          'product_name': product['name'],
          'stock': stock,
          'quantity': quantity,
          'possible_quantity': stock ~/ quantity,
        };
      }).toList(growable: false);
      final available = components.fold<int>(
        parent['stock_actuel'] as int,
        (value, component) => value < (component['possible_quantity'] as int)
            ? value
            : component['possible_quantity'] as int,
      );
      final recipe = <String, dynamic>{
        'parent_id': parentId,
        'parent_name': parent['name'],
        'parent_stock': parent['stock_actuel'],
        'available_quantity': available,
        'components': components,
      };
      bomRecipes.removeWhere((item) => item['parent_id'] == parentId);
      bomRecipes.add(recipe);
      return _json({'success': true, 'recipe': recipe});
    }
    if (method == 'DELETE' && path.startsWith('/api/bom/')) {
      final parentId = int.parse(path.split('/').last);
      bomRecipes.removeWhere((item) => item['parent_id'] == parentId);
      return _json({'success': true});
    }
    if (method == 'GET' && path == '/api/pertes') return _json(wastes);
    if (method == 'GET' && path == '/api/clotures') return _json(closures);
    if (method == 'GET' && path == '/api/admin/bugs') return _json(bugs);
    if (method == 'GET' && path == '/api/notifications/a-venir') {
      return _json(_alertsPayload);
    }
    if (method == 'GET' && path == '/api/export/fec') {
      return http.Response(
        'JournalCode\tEcritureNum\tEcritureDate\nVE\t501\t20260810',
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }
    if (method == 'POST' && path == '/api/categories') {
      final body = _body(request);
      categories.add({'id': nextCategoryId++, 'nom': body['nom']});
      return _json({'success': true}, status: 201);
    }
    if (method == 'DELETE' && path.startsWith('/api/categories/')) {
      final id = int.parse(path.split('/').last);
      categories.removeWhere((item) => item['id'] == id);
      return _json({'success': true});
    }
    if (method == 'POST' && path == '/api/produits') {
      final body = _body(request);
      products.add(_productFromBody(nextProductId++, body));
      return _json({'success': true}, status: 201);
    }
    if (method == 'PUT' && path.startsWith('/api/produits/')) {
      final id = int.parse(path.split('/').last);
      final index = products.indexWhere((item) => item['id'] == id);
      products[index] = _productFromBody(id, _body(request));
      return _json({'success': true});
    }
    if (method == 'DELETE' && path.startsWith('/api/produits/')) {
      final id = int.parse(path.split('/').last);
      products.removeWhere((item) => item['id'] == id);
      return _json({'success': true});
    }
    if (method == 'POST' && path.endsWith('/remise-anti-gaspi')) {
      final id = int.parse(path.split('/')[3]);
      final product = products.firstWhere((item) => item['id'] == id);
      product['remise_anti_gaspi_pct'] = '30.00';
      product['price_ttc'] =
          _cents((_moneyToCents(product['price_ttc']) * 7) ~/ 10);
      return _json({'success': true, 'product': product});
    }
    if (method == 'POST' && path == '/api/stock/reception') {
      final body = _body(request);
      final product = products.firstWhere(
        (item) => item['id'] == body['produit_id'],
      );
      final received = body['quantite_recue'] as int;
      final ratio = product['ratio_conversion'] as int;
      final before = product['stock_actuel'] as int;
      product['stock_actuel'] = before + received * ratio;
      receptions.insert(0, {
        'id': receptions.length + 1,
        'produit_nom': product['name'],
        'quantite_recue': received,
        'unite_achat': product['unite_achat'],
        'quantite_vente_ajoutee': received * ratio,
        'unite_vente': product['unite_vente'],
        'stock_avant': before,
        'stock_apres': product['stock_actuel'],
        'date_reception': '2026-08-10T20:10:00.000Z',
      });
      return _json({'success': true}, status: 201);
    }
    if (method == 'POST' && path == '/api/pertes') {
      final body = _body(request);
      final product = products.firstWhere(
        (item) => item['id'] == body['productId'],
      );
      product['stock_actuel'] =
          (product['stock_actuel'] as int) - (body['quantity'] as int);
      wastes.insert(0, {
        'id': wastes.length + 1,
        'produit_nom': product['name'],
        'quantite': body['quantity'],
        'motif': body['reason'],
        'date_perte': '2026-08-10T20:15:00.000Z',
      });
      return _json({'success': true});
    }
    if (method == 'POST' && path == '/api/cloture-jour') {
      closures.insert(0, {
        'id': 8,
        'total_ca_ttc': '4.50',
        'total_tva': '0.75',
        'nombre_transactions': 1,
        'nombre_annulations': 1,
        'hash_cloture': _hashA,
        'date_cloture': '2026-08-10T20:20:00.000Z',
      });
      return _json({
        'clotureId': 8,
        'totalCA': '4.50',
        'totalTVA': '0.75',
        'nombre_transactions': 1,
        'nombre_annulations': 1,
        'hashZ': _hashA,
        'caParMode': {'Espèces': '4.50'},
      });
    }
    if (method == 'PATCH' && path.startsWith('/api/admin/bugs/')) {
      final id = int.parse(path.split('/').last);
      final report = bugs.firstWhere((item) => item['id'] == id);
      report['statut'] = _body(request)['statut'];
      return _json({'success': true, 'bug': report});
    }
    return _json({'error': 'Route de test absente : $method $path'},
        status: 404);
  }

  bool _requiresAdmin(http.Request request) {
    final path = request.url.path;
    return path == '/api/clients' ||
        path.startsWith('/api/commandes') ||
        path == '/api/pertes' ||
        path == '/api/clotures' ||
        path == '/api/cloture-jour' ||
        path == '/api/stock/reception' ||
        path.startsWith('/api/stock/receptions') ||
        path.startsWith('/api/bom') ||
        path.startsWith('/api/admin/') ||
        path.startsWith('/api/notifications/') ||
        path.startsWith('/api/export/') ||
        path.startsWith('/api/categories') ||
        path.startsWith('/api/produits/') ||
        (path == '/api/produits' && request.method != 'GET');
  }

  bool _authorized(http.Request request) =>
      request.headers.entries.any((entry) =>
          entry.key.toLowerCase() == 'authorization' &&
          entry.value == 'Bearer test-jwt');

  Map<String, dynamic> _productFromBody(int id, Map<String, dynamic> body) {
    final category = categories.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id'] == body['categorie_id'],
          orElse: () => null,
        );
    return {
      'id': id,
      'name': body['nom'],
      'price_ttc': body['prix_ttc'],
      'base_price_ttc': body['prix_ttc'],
      'vat_rate': body['taux_tva'],
      'categorie_id': body['categorie_id'],
      'category_name': category?['nom'] ?? 'Sans catégorie',
      'stock_actuel': body['stock_actuel'],
      'date_arrivage': body['date_arrivage'],
      'duree_de_vie_jours': body['duree_de_vie_jours'],
      'unite_achat': body['unite_achat'],
      'unite_vente': body['unite_vente'],
      'ratio_conversion': body['ratio_conversion'],
    };
  }

  Map<String, dynamic> _body(http.Request request) =>
      Map<String, dynamic>.from(jsonDecode(request.body) as Map);

  http.Response _json(Object body, {int status = 200}) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  int _moneyToCents(Object? value) {
    final parts = value.toString().split('.');
    return int.parse(parts.first) * 100 +
        int.parse((parts.length == 1 ? '' : parts[1]).padRight(2, '0'));
  }

  String _cents(int value) =>
      '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
}

class MemorySettingsStore implements LocalSettingsStore {
  MemorySettingsStore({
    this.apiBaseUrl = 'https://fleurapp-qa.invalid',
    this.themeMode = ThemeMode.light,
  });

  String apiBaseUrl;
  ThemeMode themeMode;

  @override
  Future<LocalSettings> read() async => LocalSettings(
        apiBaseUrl: apiBaseUrl,
        themeMode: themeMode,
      );

  @override
  Future<void> writeApiBaseUrl(String value) async => apiBaseUrl = value;

  @override
  Future<void> writeThemeMode(ThemeMode value) async => themeMode = value;
}

class MemoryTokenStore implements AdminTokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

class FakeDeviceMetadataService implements DeviceMetadataService {
  const FakeDeviceMetadataService();

  @override
  Future<BugDeviceMetadata> load() async => const BugDeviceMetadata(
        os: 'Android 16 (SDK 36)',
        model: 'Poco F7',
        appVersion: '1.0.0+1',
      );
}

class FakeAlertScheduler implements LocalAlertScheduler {
  bool initialized = false;
  bool cleared = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<LocalAlertSyncResult> sync(UpcomingAlertsPayload payload) async =>
      LocalAlertSyncResult(
        enabled: true,
        scheduled: payload.alerts.length,
        shownNow: 0,
      );

  @override
  Future<void> clear() async => cleared = true;
}

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const _alertsPayload = {
  'generatedAt': '2026-08-10T08:00:00.000Z',
  'window': {
    'to': '2026-08-12T08:00:00.000Z',
    'timeZone': 'Europe/Paris',
  },
  'summary': {
    'total': 3,
    'arrivals': 1,
    'orders': 1,
    'bomAlerts': 1,
    'critical': 1,
  },
  'notifications': [
    {
      'id': 'arrival:1:2026-08-11T06:00:00.000Z',
      'type': 'arrival',
      'severity': 'info',
      'title': 'Arrivage à venir — Rose rouge',
      'message': 'Deux bottes sont attendues demain matin.',
      'eventAt': '2026-08-11T06:00:00.000Z',
      'remindAt': '2026-08-10T06:00:00.000Z',
      'hoursUntil': 22,
      'data': {'productId': 1},
    },
    {
      'id': 'order:81:2026-08-11T12:00:00.000Z',
      'type': 'order',
      'severity': 'warning',
      'title': 'Commande Alice Martin',
      'message': 'Bouquet à préparer pour demain.',
      'eventAt': '2026-08-11T12:00:00.000Z',
      'remindAt': '2026-08-10T12:00:00.000Z',
      'hoursUntil': 28,
      'data': {'orderId': 81},
    },
    {
      'id': 'bom:2:2026-08-11T14:00:00.000Z',
      'type': 'bom',
      'severity': 'critical',
      'title': 'Composant BOM insuffisant',
      'message': 'Le stock de feuillage est insuffisant.',
      'eventAt': '2026-08-11T14:00:00.000Z',
      'remindAt': '2026-08-10T14:00:00.000Z',
      'hoursUntil': 30,
      'data': {'productId': 2},
    },
  ],
};
