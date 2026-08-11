import '../core/money.dart';

class ProductCategory {
  const ProductCategory({required this.id, required this.name});
  final int id;
  final String name;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(id: _int(json['id']), name: '${json['nom'] ?? ''}');
}

class Customer {
  const Customer({
    required this.id,
    required this.lastName,
    this.firstName,
    this.phone,
    this.email,
    this.allergies,
    this.preferences,
  });
  final int id;
  final String lastName;
  final String? firstName;
  final String? phone;
  final String? email;
  final String? allergies;
  final String? preferences;
  String get displayName => [lastName, firstName]
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .join(' ');

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: _int(json['id']),
        lastName: '${json['nom'] ?? ''}',
        firstName: _string(json['prenom']),
        phone: _string(json['telephone']),
        email: _string(json['email']),
        allergies: _string(json['allergies']),
        preferences: _string(json['preferences']),
      );
}

class CustomerDraft {
  const CustomerDraft({
    required this.lastName,
    this.firstName,
    this.phone,
    this.email,
    this.allergies,
    this.preferences,
  });

  final String lastName;
  final String? firstName;
  final String? phone;
  final String? email;
  final String? allergies;
  final String? preferences;

  Map<String, dynamic> toJson() => {
        'nom': lastName,
        'prenom': firstName,
        'telephone': phone,
        'email': email,
        'allergies': allergies,
        'preferences': preferences,
      };
}

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.priceCents,
    required this.vatBasisPoints,
    required this.stock,
    this.categoryId,
    this.arrivalDate,
    this.shelfLifeDays,
    this.purchaseUnit,
    this.saleUnit,
    this.conversionRatio,
  });
  final String name;
  final int? categoryId;
  final int priceCents;
  final int vatBasisPoints;
  final int stock;
  final DateTime? arrivalDate;
  final int? shelfLifeDays;
  final String? purchaseUnit;
  final String? saleUnit;
  final int? conversionRatio;

  Map<String, dynamic> toJson() => {
        'nom': name,
        'categorie_id': categoryId,
        'prix_ttc': centsToApiDecimal(priceCents),
        'taux_tva': basisPointsToApiDecimal(vatBasisPoints),
        'stock_actuel': stock,
        'date_arrivage': arrivalDate == null ? null : _date(arrivalDate!),
        'duree_de_vie_jours': shelfLifeDays,
        'unite_achat': purchaseUnit,
        'unite_vente': saleUnit,
        'ratio_conversion': conversionRatio,
      };
}

class StockReception {
  const StockReception({
    required this.id,
    required this.productName,
    required this.receivedQuantity,
    required this.purchaseUnit,
    required this.addedQuantity,
    required this.saleUnit,
    required this.stockBefore,
    required this.stockAfter,
    this.receivedAt,
  });
  final int id;
  final String productName;
  final int receivedQuantity;
  final String purchaseUnit;
  final int addedQuantity;
  final String saleUnit;
  final int stockBefore;
  final int stockAfter;
  final DateTime? receivedAt;

  factory StockReception.fromJson(Map<String, dynamic> json) => StockReception(
        id: _int(json['id']),
        productName: '${json['produit_nom'] ?? ''}',
        receivedQuantity: _int(json['quantite_recue']),
        purchaseUnit: '${json['unite_achat'] ?? ''}',
        addedQuantity: _int(json['quantite_vente_ajoutee']),
        saleUnit: '${json['unite_vente'] ?? ''}',
        stockBefore: _int(json['stock_avant']),
        stockAfter: _int(json['stock_apres']),
        receivedAt: DateTime.tryParse('${json['date_reception'] ?? ''}'),
      );
}

class WasteRecord {
  const WasteRecord({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.reason,
    this.date,
  });
  final int id;
  final String productName;
  final int quantity;
  final String reason;
  final DateTime? date;

  factory WasteRecord.fromJson(Map<String, dynamic> json) => WasteRecord(
        id: _int(json['id']),
        productName: '${json['produit_nom'] ?? 'Produit supprimé'}',
        quantity: _int(json['quantite']),
        reason: '${json['motif'] ?? ''}',
        date: DateTime.tryParse('${json['date_perte'] ?? ''}'),
      );
}

class ClosureRecord {
  const ClosureRecord({
    required this.id,
    required this.totalCents,
    required this.vatCents,
    required this.transactionCount,
    required this.hash,
    this.date,
  });
  final int id;
  final int totalCents;
  final int vatCents;
  final int transactionCount;
  final String hash;
  final DateTime? date;

  factory ClosureRecord.fromJson(Map<String, dynamic> json) => ClosureRecord(
        id: _int(json['id']),
        totalCents: moneyToCents(json['total_ca_ttc'], field: 'Total clôture'),
        vatCents: moneyToCents(json['total_tva'], field: 'TVA clôture'),
        transactionCount: _int(json['nombre_transactions']),
        hash: '${json['hash_cloture'] ?? ''}',
        date: DateTime.tryParse('${json['date_cloture'] ?? ''}'),
      );
}

class ClosureReceipt {
  const ClosureReceipt({
    required this.id,
    required this.totalCents,
    required this.vatCents,
    required this.transactionCount,
    required this.hash,
    required this.totalsByPayment,
  });
  final int id;
  final int totalCents;
  final int vatCents;
  final int transactionCount;
  final String hash;
  final Map<String, int> totalsByPayment;

  factory ClosureReceipt.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['caParMode'];
    return ClosureReceipt(
      id: _int(json['clotureId']),
      totalCents: moneyToCents(json['totalCA'], field: 'Total Z'),
      vatCents: moneyToCents(json['totalTVA'], field: 'TVA Z'),
      transactionCount: _int(json['nombre_transactions']),
      hash: '${json['hashZ'] ?? ''}',
      totalsByPayment: rawPayments is Map
          ? rawPayments.map(
              (key, value) => MapEntry(
                '$key',
                moneyToCents(value, field: 'Total par paiement'),
              ),
            )
          : const {},
    );
  }
}

class AdminLoginResult {
  const AdminLoginResult({required this.token, required this.expiresIn});
  final String token;
  final String expiresIn;
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String? _string(Object? value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return value.toString().trim();
}

String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
