import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/models/cart_item.dart';
import 'package:fleurapp_mobile/models/order_receipt.dart';
import 'package:fleurapp_mobile/models/payment_method.dart';
import 'package:fleurapp_mobile/models/product.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/state/pos_controller.dart';

void main() {
  late _FakeApi api;
  late PosController controller;

  setUp(() {
    api = _FakeApi();
    controller = PosController(apiClient: api);
  });

  tearDown(() => controller.dispose());

  test('charge, filtre et classe le catalogue', () async {
    await controller.loadProducts();

    expect(controller.catalogStatus, CatalogStatus.ready);
    expect(controller.products, hasLength(2));
    expect(controller.categories, ['Bouquets', 'Plantes']);

    controller.selectCategory('Plantes');
    expect(controller.filteredProducts.single.name, 'Monstera');

    controller.selectCategory(null);
    controller.setSearchQuery('champ');
    expect(controller.filteredProducts.single.name, 'Bouquet champêtre');
  });

  test('respecte le stock et calcule le total', () async {
    await controller.loadProducts();
    final bouquet = controller.products.first;

    expect(controller.addProduct(bouquet), isTrue);
    expect(controller.addProduct(bouquet), isTrue);
    expect(controller.addProduct(bouquet), isFalse);
    expect(controller.cartQuantity, 2);
    expect(controller.cartTotal, 50);
  });

  test('envoie la commande puis vide le panier', () async {
    await controller.loadProducts();
    controller.addProduct(controller.products.first);

    final receipt = await controller.checkout(PaymentMethod.card);

    expect(receipt.orderId, 42);
    expect(api.lastPaymentMethod, PaymentMethod.card);
    expect(api.lastItems.single.quantity, 1);
    expect(controller.isCartEmpty, isTrue);
  });
}

class _FakeApi implements FleurApiClient {
  List<CartItem> lastItems = const [];
  PaymentMethod? lastPaymentMethod;

  @override
  Future<List<Product>> fetchProducts() async => const [
        Product(
          id: 1,
          name: 'Bouquet champêtre',
          priceTtc: 25,
          vatRate: 20,
          category: 'Bouquets',
          stock: 2,
        ),
        Product(
          id: 2,
          name: 'Monstera',
          priceTtc: 39.9,
          vatRate: 10,
          category: 'Plantes',
          stock: 3,
        ),
      ];

  @override
  Future<OrderReceipt> createOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
  }) async {
    lastItems = items;
    lastPaymentMethod = paymentMethod;
    return const OrderReceipt(
      orderId: 42,
      totalTtc: 25,
      hash: 'abc123',
      status: 'TERMINÉE',
    );
  }

  @override
  void close() {}
}
