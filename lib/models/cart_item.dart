import '../core/money.dart';
import 'product.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  int get totalCents => product.priceCents * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);

  Map<String, dynamic> toApiJson() => product.isCustomSale
      ? {
          'type': 'custom',
          'name': product.name,
          'price_ttc': centsToApiDecimal(product.priceCents),
          'vat_rate': basisPointsToApiDecimal(product.vatBasisPoints),
          'quantity': quantity,
        }
      : {
          'id': product.id,
          'quantity': quantity,
        };
}
