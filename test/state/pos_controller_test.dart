import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/models/admin_models.dart';
import 'package:fleurapp_mobile/models/cart_item.dart';
import 'package:fleurapp_mobile/models/bug_report.dart';
import 'package:fleurapp_mobile/models/order_receipt.dart';
import 'package:fleurapp_mobile/models/payment_method.dart';
import 'package:fleurapp_mobile/models/product.dart';
import 'package:fleurapp_mobile/services/api_exception.dart';
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
    expect(controller.categories, ['Bouquets', 'Plantes']);
    controller.selectCategory('Plantes');
    expect(controller.filteredProducts.single.name, 'Monstera');
    controller.selectCategory(null);
    controller.setSearchQuery('champ');
    expect(controller.filteredProducts.single.name, 'Bouquet champêtre');
  });

  test('respecte le stock et calcule exclusivement en centimes', () async {
    await controller.loadProducts();
    final bouquet = controller.products.first;
    expect(controller.addProduct(bouquet), isTrue);
    expect(controller.addProduct(bouquet), isTrue);
    expect(controller.addProduct(bouquet), isFalse);
    expect(controller.cartQuantity, 2);
    expect(controller.cartTotalCents, 5000);
  });

  test('envoie la commande avec une clé puis vide le panier', () async {
    await controller.loadProducts();
    controller.addProduct(controller.products.first);
    final receipt = await controller.checkout(
      const CheckoutOptions(paymentMethod: PaymentMethod.card),
    );
    expect(receipt.orderId, 42);
    expect(api.lastPaymentMethod, PaymentMethod.card);
    expect(api.lastIdempotencyKey, startsWith('mobile_'));
    expect(api.lastIdempotencyKey, hasLength(55));
    expect(controller.isCartEmpty, isTrue);
  });

  test('ajoute et transmet une vente sur mesure sans toucher au catalogue',
      () async {
    controller.addCustomSale(
      name: 'Bouquet création client',
      priceCents: 1750,
      vatBasisPoints: 1000,
      quantity: 2,
    );

    expect(controller.cartQuantity, 2);
    expect(controller.cartTotalCents, 3500);
    expect(controller.cartItems.single.product.isCustomSale, isTrue);

    await controller.checkout(
      const CheckoutOptions(paymentMethod: PaymentMethod.card),
    );

    expect(api.lastItems.single.toApiJson(), {
      'type': 'custom',
      'name': 'Bouquet création client',
      'price_ttc': '17.50',
      'vat_rate': '10.00',
      'quantity': 2,
    });
    expect(controller.isCartEmpty, isTrue);
  });

  test('transmet le client choisi lors d’un encaissement immédiat', () async {
    await controller.loadProducts();
    controller.addProduct(controller.products.first);

    await controller.checkout(
      const CheckoutOptions(
        paymentMethod: PaymentMethod.card,
        customerId: 17,
      ),
    );

    expect(api.lastCustomerId, 17);
  });

  test('réutilise la clé après une coupure au résultat inconnu', () async {
    await controller.loadProducts();
    controller.addProduct(controller.products.first);
    api.failUnknown = true;
    const options = CheckoutOptions(paymentMethod: PaymentMethod.cash);
    await expectLater(
        controller.checkout(options), throwsA(isA<ApiException>()));
    final firstKey = api.lastIdempotencyKey;
    api.failUnknown = false;
    await controller.checkout(options);
    expect(api.lastIdempotencyKey, firstKey);
  });
}

class _FakeApi implements FleurApiClient {
  List<CartItem> lastItems = const [];
  PaymentMethod? lastPaymentMethod;
  String? lastIdempotencyKey;
  int? lastCustomerId;
  bool failUnknown = false;

  @override
  Future<void> checkHealth() async {}

  @override
  Future<BugReport> submitBugReport(BugReportDraft report) =>
      throw UnimplementedError();

  @override
  Future<List<ProductCategory>> fetchCategories() async => const [];

  @override
  Future<List<Product>> fetchProducts() async => const [
        Product(
          id: 1,
          name: 'Bouquet champêtre',
          priceCents: 2500,
          vatBasisPoints: 2000,
          category: 'Bouquets',
          stock: 2,
        ),
        Product(
          id: 2,
          name: 'Monstera',
          priceCents: 3990,
          vatBasisPoints: 1000,
          category: 'Plantes',
          stock: 3,
        ),
      ];

  @override
  Future<OrderReceipt> createOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    required String idempotencyKey,
    int? customerId,
    bool isFutureOrder = false,
    DateTime? deliveryDate,
    int? depositCents,
  }) async {
    lastItems = items;
    lastPaymentMethod = paymentMethod;
    lastIdempotencyKey = idempotencyKey;
    lastCustomerId = customerId;
    if (failUnknown) {
      throw const ApiException('Connexion interrompue.', outcomeUnknown: true);
    }
    return const OrderReceipt(
      orderId: 42,
      totalCents: 2500,
      hash: 'abc123',
      status: 'TERMINÉE',
    );
  }

  @override
  void close() {}
}
