class Product {
  const Product({
    required this.id,
    required this.name,
    required this.priceTtc,
    required this.vatRate,
    required this.category,
    this.stock,
    this.discountPercent = 0,
  });

  final int id;
  final String name;
  final double priceTtc;
  final double vatRate;
  final String category;
  final int? stock;
  final double discountPercent;

  bool get isAvailable => stock == null || stock! > 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _asInt(json['id'], field: 'id'),
      name: (json['name'] ?? json['nom'] ?? 'Produit sans nom').toString(),
      priceTtc: _asDouble(
        json['price_ttc'] ?? json['prix_ttc'],
        field: 'price_ttc',
      ),
      vatRate: _asDouble(
        json['vat_rate'] ?? json['taux_tva'] ?? 20,
        field: 'vat_rate',
      ),
      category:
          (json['category_name'] ?? json['categorie'] ?? 'Autres').toString(),
      stock: _asNullableInt(json['stock_actuel'] ?? json['stock']),
      discountPercent: _asDouble(
        json['remise_anti_gaspi_pct'] ?? 0,
        field: 'remise_anti_gaspi_pct',
      ),
    );
  }

  static int _asInt(Object? value, {required String field}) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null) {
      throw FormatException('Champ produit invalide : $field');
    }
    return parsed;
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  static double _asDouble(Object? value, {required String field}) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null) {
      throw FormatException('Champ produit invalide : $field');
    }
    return parsed;
  }
}
