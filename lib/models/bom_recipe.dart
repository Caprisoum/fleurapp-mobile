class BomComponent {
  const BomComponent({
    required this.productId,
    required this.productName,
    required this.stock,
    required this.quantity,
    required this.possibleQuantity,
  });

  final int productId;
  final String productName;
  final int stock;
  final int quantity;
  final int possibleQuantity;

  factory BomComponent.fromJson(Map<String, dynamic> json) => BomComponent(
        productId: _positiveInt(json['product_id'], 'Produit composant'),
        productName: '${json['product_name'] ?? ''}',
        stock: _nonNegativeInt(json['stock'], 'Stock composant'),
        quantity: _positiveInt(json['quantity'], 'Quantité composant'),
        possibleQuantity:
            _nonNegativeInt(json['possible_quantity'], 'Capacité composant'),
      );
}

class BomRecipe {
  const BomRecipe({
    required this.parentId,
    required this.parentName,
    required this.parentStock,
    required this.availableQuantity,
    required this.components,
  });

  final int parentId;
  final String parentName;
  final int parentStock;
  final int availableQuantity;
  final List<BomComponent> components;

  factory BomRecipe.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'];
    if (rawComponents is! List || rawComponents.isEmpty) {
      throw const FormatException('Composants de nomenclature absents.');
    }
    return BomRecipe(
      parentId: _positiveInt(json['parent_id'], 'Produit parent'),
      parentName: '${json['parent_name'] ?? ''}',
      parentStock: _nonNegativeInt(json['parent_stock'], 'Stock parent'),
      availableQuantity:
          _nonNegativeInt(json['available_quantity'], 'Stock disponible'),
      components: rawComponents
          .map((item) => BomComponent.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
    );
  }
}

class BomComponentDraft {
  const BomComponentDraft({required this.productId, required this.quantity});

  final int productId;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
      };
}

class BomRecipeDraft {
  const BomRecipeDraft({required this.parentId, required this.components});

  final int parentId;
  final List<BomComponentDraft> components;

  Map<String, dynamic> toJson() => {
        'components': components.map((item) => item.toJson()).toList(),
      };
}

int _positiveInt(Object? value, String field) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 1) throw FormatException('$field invalide.');
  return parsed;
}

int _nonNegativeInt(Object? value, String field) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 0) throw FormatException('$field invalide.');
  return parsed;
}
