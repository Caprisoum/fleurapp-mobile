import '../core/money.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.vatBasisPoints,
    required this.category,
    this.categoryId,
    this.stock,
    this.discountBasisPoints = 0,
    this.basePriceCents,
    this.purchaseUnit,
    this.saleUnit,
    this.conversionRatio,
    this.arrivalDate,
    this.shelfLifeDays,
    this.freshnessStatus,
    this.remainingDays,
  });

  final int id;
  final String name;
  final int priceCents;
  final int vatBasisPoints;
  final String category;
  final int? categoryId;
  final int? stock;
  final int discountBasisPoints;
  final int? basePriceCents;
  final String? purchaseUnit;
  final String? saleUnit;
  final int? conversionRatio;
  final DateTime? arrivalDate;
  final int? shelfLifeDays;
  final String? freshnessStatus;
  final int? remainingDays;

  bool get isAvailable => stock == null || stock! > 0;
  bool get hasUnitConversion =>
      purchaseUnit != null && saleUnit != null && conversionRatio != null;
  bool get canApplyAntiWaste =>
      remainingDays != null && remainingDays! <= 2 && discountBasisPoints == 0;
  int get discountPercent => discountBasisPoints ~/ 100;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: _requiredInt(json['id'], 'id'),
        name: (json['name'] ?? json['nom'] ?? 'Produit sans nom').toString(),
        priceCents: moneyToCents(
          json['price_ttc'] ?? json['prix_ttc'],
          field: 'Prix produit',
        ),
        vatBasisPoints: decimalToBasisPoints(
          json['vat_rate'] ?? json['taux_tva'] ?? 20,
          field: 'TVA produit',
        ),
        category:
            (json['category_name'] ?? json['categorie'] ?? 'Sans catégorie')
                .toString(),
        categoryId: _nullableInt(json['categorie_id'] ?? json['category_id']),
        stock: _nullableInt(json['stock_actuel'] ?? json['stock']),
        discountBasisPoints: decimalToBasisPoints(
          json['remise_anti_gaspi_pct'] ?? 0,
          field: 'Remise anti-gaspi',
        ),
        basePriceCents: _nullableMoney(json['base_price_ttc']),
        purchaseUnit: _nullableString(json['unite_achat']),
        saleUnit: _nullableString(json['unite_vente']),
        conversionRatio: _nullableInt(json['ratio_conversion']),
        arrivalDate: DateTime.tryParse('${json['date_arrivage'] ?? ''}'),
        shelfLifeDays: _nullableInt(json['duree_de_vie_jours']),
        freshnessStatus: _nullableString(json['fraicheur_statut']),
        remainingDays: _nullableInt(json['jours_restants']),
      );

  static int _requiredInt(Object? value, String field) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null) {
      throw FormatException('Champ produit invalide : $field');
    }
    return parsed;
  }

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  static int? _nullableMoney(Object? value) =>
      value == null ? null : moneyToCents(value, field: 'Prix catalogue');

  static String? _nullableString(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString().trim();
  }
}
