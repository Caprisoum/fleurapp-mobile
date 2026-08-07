import 'product.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get totalTtc => product.priceTtc * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(product: product, quantity: quantity ?? this.quantity);
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': product.id,
      'name': product.name,
      'price_ttc': product.priceTtc,
      'vat_rate': product.vatRate,
      'quantity': quantity,
    };
  }
}
