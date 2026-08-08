import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order_receipt.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../services/api_exception.dart';
import '../services/fleur_api_client.dart';

enum CatalogStatus { initial, loading, ready, error }

class CheckoutOptions {
  const CheckoutOptions({
    required this.paymentMethod,
    this.customerId,
    this.isFutureOrder = false,
    this.deliveryDate,
    this.depositCents,
  });

  final PaymentMethod paymentMethod;
  final int? customerId;
  final bool isFutureOrder;
  final DateTime? deliveryDate;
  final int? depositCents;
}

class PosController extends ChangeNotifier {
  PosController({required FleurApiClient apiClient}) : _apiClient = apiClient;

  final FleurApiClient _apiClient;
  final Map<int, CartItem> _cart = <int, CartItem>{};
  final List<OrderReceipt> _sessionReceipts = [];
  List<Product> _products = const [];
  CatalogStatus _catalogStatus = CatalogStatus.initial;
  String? _catalogError;
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isSubmitting = false;
  _PendingCheckout? _pendingCheckout;
  bool _disposed = false;

  List<Product> get products => List.unmodifiable(_products);
  CatalogStatus get catalogStatus => _catalogStatus;
  String? get catalogError => _catalogError;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool get isSubmitting => _isSubmitting;
  bool get hasUncertainCheckout => _pendingCheckout != null;
  UnmodifiableListView<OrderReceipt> get sessionReceipts =>
      UnmodifiableListView(_sessionReceipts.reversed);

  List<String> get categories {
    final values = _products.map((product) => product.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<Product> get filteredProducts {
    final normalizedSearch = _searchQuery.trim().toLowerCase();
    return _products.where((product) {
      final matchesCategory =
          _selectedCategory == null || product.category == _selectedCategory;
      final matchesSearch = normalizedSearch.isEmpty ||
          product.name.toLowerCase().contains(normalizedSearch) ||
          product.category.toLowerCase().contains(normalizedSearch);
      return matchesCategory && matchesSearch;
    }).toList(growable: false);
  }

  List<CartItem> get cartItems => List.unmodifiable(_cart.values);
  bool get isCartEmpty => _cart.isEmpty;
  int get cartQuantity =>
      _cart.values.fold(0, (total, item) => total + item.quantity);
  int get cartTotalCents =>
      _cart.values.fold(0, (total, item) => total + item.totalCents);

  Future<void> loadProducts() async {
    _catalogStatus = CatalogStatus.loading;
    _catalogError = null;
    _notify();
    try {
      _products = await _apiClient.fetchProducts();
      if (_selectedCategory != null &&
          !_products.any((product) => product.category == _selectedCategory)) {
        _selectedCategory = null;
      }
      _catalogStatus = CatalogStatus.ready;
    } on ApiException catch (error) {
      _catalogStatus = CatalogStatus.error;
      _catalogError = error.message;
    } catch (_) {
      _catalogStatus = CatalogStatus.error;
      _catalogError = 'Impossible de charger le catalogue.';
    }
    _notify();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    _notify();
  }

  void selectCategory(String? value) {
    if (_selectedCategory == value) return;
    _selectedCategory = value;
    _notify();
  }

  bool addProduct(Product product) {
    if (!product.isAvailable) return false;
    final current = _cart[product.id];
    final nextQuantity = (current?.quantity ?? 0) + 1;
    if (product.stock != null && nextQuantity > product.stock!) return false;
    _cart[product.id] = CartItem(product: product, quantity: nextQuantity);
    _invalidatePendingCheckout();
    _notify();
    return true;
  }

  void increment(Product product) => addProduct(product);

  void decrement(Product product) {
    final current = _cart[product.id];
    if (current == null) return;
    if (current.quantity <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = current.copyWith(quantity: current.quantity - 1);
    }
    _invalidatePendingCheckout();
    _notify();
  }

  void remove(Product product) {
    if (_cart.remove(product.id) != null) {
      _invalidatePendingCheckout();
      _notify();
    }
  }

  void clearCart() {
    if (_cart.isEmpty) return;
    _cart.clear();
    _invalidatePendingCheckout();
    _notify();
  }

  Future<OrderReceipt> checkout(CheckoutOptions options) async {
    if (_cart.isEmpty) throw const ApiException('Le panier est vide.');
    if (_isSubmitting) {
      throw const ApiException('Un encaissement est déjà en cours.');
    }
    if (options.isFutureOrder) {
      if (options.customerId == null || options.deliveryDate == null) {
        throw const ApiException(
          'Sélectionnez un client et une date de livraison.',
        );
      }
      final deposit = options.depositCents ?? 0;
      if (deposit < 0 || deposit > cartTotalCents) {
        throw const ApiException('L’acompte doit être compris dans le total.');
      }
    }

    final signature = _checkoutSignature(options);
    final pending = _pendingCheckout;
    final idempotencyKey = pending != null && pending.signature == signature
        ? pending.key
        : _newIdempotencyKey();
    _pendingCheckout = _PendingCheckout(idempotencyKey, signature);
    _isSubmitting = true;
    _notify();
    try {
      final receipt = await _apiClient.createOrder(
        items: List<CartItem>.unmodifiable(_cart.values),
        paymentMethod: options.paymentMethod,
        idempotencyKey: idempotencyKey,
        customerId: options.customerId,
        isFutureOrder: options.isFutureOrder,
        deliveryDate: options.deliveryDate,
        depositCents: options.depositCents,
      );
      _cart.clear();
      _pendingCheckout = null;
      _sessionReceipts.add(receipt);
      return receipt;
    } on ApiException catch (error) {
      if (!error.outcomeUnknown) _pendingCheckout = null;
      rethrow;
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  String _checkoutSignature(CheckoutOptions options) {
    final items = _cart.values.toList()
      ..sort((a, b) => a.product.id.compareTo(b.product.id));
    return [
      items.map((item) => '${item.product.id}:${item.quantity}').join(','),
      options.paymentMethod.apiValue,
      options.customerId ?? '',
      options.isFutureOrder,
      options.deliveryDate?.toUtc().toIso8601String() ?? '',
      options.depositCents ?? '',
    ].join('|');
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final encoded =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    return 'mobile_${encoded.join()}';
  }

  void _invalidatePendingCheckout() => _pendingCheckout = null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _PendingCheckout {
  const _PendingCheckout(this.key, this.signature);
  final String key;
  final String signature;
}
