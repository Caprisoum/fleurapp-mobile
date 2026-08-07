import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/models/cart_item.dart';
import 'package:fleurapp_mobile/models/order_receipt.dart';
import 'package:fleurapp_mobile/models/payment_method.dart';
import 'package:fleurapp_mobile/models/product.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/state/pos_controller.dart';

void main() {
  testWidgets('affiche le catalogue et ajoute un produit au panier',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosController(apiClient: _FakeApi());
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Bouquet champêtre'), findsOneWidget);
    await tester.tap(find.text('Bouquet champêtre'));
    await tester.pump();

    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();

    expect(find.text('Commande en cours'), findsOneWidget);
    expect(find.text('25,00 €'), findsAtLeastNWidgets(2));
    expect(find.text('Encaisser'), findsOneWidget);
  });
}

class _FakeApi implements FleurApiClient {
  @override
  Future<List<Product>> fetchProducts() async => const [
        Product(
          id: 1,
          name: 'Bouquet champêtre',
          priceTtc: 25,
          vatRate: 20,
          category: 'Bouquets',
          stock: 4,
        ),
      ];

  @override
  Future<OrderReceipt> createOrder({
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
  }) async {
    return const OrderReceipt(orderId: 1, totalTtc: 25, hash: 'test');
  }

  @override
  void close() {}
}
