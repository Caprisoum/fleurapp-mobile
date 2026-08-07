import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order_receipt.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../services/api_exception.dart';
import '../services/fleur_api_client.dart';

enum CatalogStatus { initial, loading, ready, error }

class PosController extends ChangeNotifier {
  PosController({required FleurApiClient apiClient}) : _apiClient = apiClient;

  final FleurApiClient _apiClient;
  final Map<int, CartItem> _cart = <int, CartItem>{};

  List<Product> _products = const [];
  CatalogStatus _catalogStatus = CatalogStatus.initial;
  String? _catalogError;
  String _searchQuery = '';
  String? _selectedCategory;
  bool _isSubmitting = false;
  bool _disposed = false;

  List<Product> get products => List.unmodifiable(_products);
  CatalogStatus get catalogStatus => _catalogStatus;
  String? get catalogError => _catalogError;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool get isSubmitting => _isSubmitting;
  UnmodifiableListView<CartItem> get cartItems =>
      UnmodifiableListView(_cart.values);
  bool get isCartEmpty => _cart.isEmpty;
  int get cartQuantity =>
      _cart.values.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotal =>
      _cart.values.fold(0, (sum, item) => sum + item.totalTtc);

  List<String> get categories {
    final values = _products.map((product) => product.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<Product> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((product) {
      final matchesCategory =
          _selectedCategory == null || product.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList(growable: false);
  }

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
    _notify();
  }

  void remove(Product product) {
    if (_cart.remove(product.id) != null) _notify();
  }

  Future<OrderReceipt> checkout(PaymentMethod paymentMethod) async {
    if (_cart.isEmpty) {
      throw const ApiException('Le panier est vide.');
    }
    if (_isSubmitting) {
      throw const ApiException('Un encaissement est déjà en cours.');
    }

    _isSubmitting = true;
    _notify();
    try {
      final receipt = await _apiClient.createOrder(
        items: List<CartItem>.unmodifiable(_cart.values),
        paymentMethod: paymentMethod,
      );
      _cart.clear();
      return receipt;
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _apiClient.close();
    super.dispose();
  }
}
