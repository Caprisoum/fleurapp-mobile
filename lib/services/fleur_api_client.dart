import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cart_item.dart';
import '../models/order_receipt.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import 'api_exception.dart';

abstract class FleurApiClient {
  Future<List<Product>> fetchProducts();

  Future<OrderReceipt> createOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
  });

  void close();
}

class RenderApiClient implements FleurApiClient {
  RenderApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 25),
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  @override
  Future<List<Product>> fetchProducts() async {
    final response = await _request(
      () => _httpClient.get(_uri('/api/produits')),
    );
    final payload = _decodeJson(response);
    if (payload is! List) {
      throw const ApiException('Format du catalogue inattendu.');
    }

    try {
      return payload
          .map((item) =>
              Product.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    } on TypeError {
      throw const ApiException('Un produit reçu est illisible.');
    }
  }

  @override
  Future<OrderReceipt> createOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
  }) async {
    final response = await _request(
      () => _httpClient.post(
        _uri('/api/commandes'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'cartItems': items.map((item) => item.toApiJson()).toList(),
          'mode_paiement': paymentMethod.apiValue,
        }),
      ),
      acceptedStatusCodes: const {200, 201},
    );

    final payload = _decodeJson(response);
    if (payload is! Map) {
      throw const ApiException('Réponse de commande inattendue.');
    }

    try {
      return OrderReceipt.fromJson(Map<String, dynamic>.from(payload));
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) throw const ApiConfigurationException();
    return Uri.parse('$_baseUrl$path');
  }

  Future<http.Response> _request(
    Future<http.Response> Function() send, {
    Set<int> acceptedStatusCodes = const {200},
  }) async {
    try {
      final response = await send().timeout(timeout);
      if (!acceptedStatusCodes.contains(response.statusCode)) {
        throw ApiException(
          _extractError(response),
          statusCode: response.statusCode,
        );
      }
      return response;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Le serveur met trop de temps à répondre. Réessayez dans un instant.',
      );
    } on http.ClientException catch (error) {
      throw ApiException('Connexion au serveur impossible : ${error.message}');
    } on FormatException {
      throw const ApiException('Adresse du backend invalide.');
    } catch (_) {
      throw const ApiException('Connexion au serveur impossible.');
    }
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('Le serveur a renvoyé une réponse illisible.');
    }
  }

  String _extractError(http.Response response) {
    try {
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is Map && payload['error'] != null) {
        return payload['error'].toString();
      }
    } on FormatException {
      // Le corps HTML ou vide sera remplacé par un message stable ci-dessous.
    }
    return 'Erreur serveur (${response.statusCode}).';
  }

  @override
  void close() => _httpClient.close();

  static String _normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
