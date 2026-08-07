import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/models/product.dart';

void main() {
  group('Product.fromJson', () {
    test('convertit le format renvoyé par le backend', () {
      final product = Product.fromJson({
        'id': 12,
        'name': 'Rose rouge',
        'price_ttc': '4.50',
        'vat_rate': '20.00',
        'stock_actuel': 7,
        'category_name': 'Fleurs coupées',
        'remise_anti_gaspi_pct': '30',
      });

      expect(product.id, 12);
      expect(product.priceTtc, 4.5);
      expect(product.stock, 7);
      expect(product.category, 'Fleurs coupées');
      expect(product.discountPercent, 30);
      expect(product.isAvailable, isTrue);
    });

    test('refuse un identifiant produit non numérique', () {
      expect(
        () => Product.fromJson({
          'id': 'custom',
          'name': 'Prix libre',
          'price_ttc': 10,
        }),
        throwsFormatException,
      );
    });
  });
}
