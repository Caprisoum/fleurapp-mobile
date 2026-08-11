import '../core/money.dart';

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.totalCents,
    required this.depositCents,
    required this.remainingCents,
    required this.status,
    required this.paymentMethod,
    required this.orderType,
    required this.hash,
    required this.lineCount,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.createdAt,
    this.deliveryAt,
    this.closureId,
  });

  final int id;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final DateTime? createdAt;
  final DateTime? deliveryAt;
  final int totalCents;
  final int depositCents;
  final int remainingCents;
  final String status;
  final String paymentMethod;
  final String orderType;
  final String hash;
  final int lineCount;
  final int? closureId;

  bool get isClosed => closureId != null;

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: _int(json['id'], 'Commande'),
        customerId: _nullableInt(json['client_id']),
        customerName: _customerName(json),
        customerPhone: _string(json['client_telephone']),
        createdAt: _date(json['date_commande']),
        deliveryAt: _date(json['date_livraison']),
        totalCents: moneyToCents(json['total_ttc'], field: 'Total commande'),
        depositCents:
            moneyToCents(json['acompte_paye'], field: 'Acompte commande'),
        remainingCents:
            moneyToCents(json['reste_a_payer'], field: 'Reste commande'),
        status: '${json['statut'] ?? ''}',
        paymentMethod: '${json['mode_paiement'] ?? ''}',
        orderType: '${json['type_commande'] ?? ''}',
        hash: '${json['hash_transaction'] ?? ''}',
        lineCount: _nullableInt(json['nombre_lignes']) ?? 0,
        closureId: _nullableInt(json['cloture_id']),
      );
}

class OrderHistoryLine {
  const OrderHistoryLine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatBasisPoints,
    this.productId,
  });

  final int id;
  final int? productId;
  final String name;
  final int quantity;
  final int unitPriceCents;
  final int vatBasisPoints;

  int get totalCents => unitPriceCents * quantity;

  factory OrderHistoryLine.fromJson(Map<String, dynamic> json) =>
      OrderHistoryLine(
        id: _int(json['id'], 'Ligne'),
        productId: _nullableInt(json['produit_id']),
        name: '${json['nom'] ?? ''}',
        quantity: _int(json['quantite'], 'Quantité'),
        unitPriceCents:
            moneyToCents(json['prix_unitaire_ttc'], field: 'Prix de ligne'),
        vatBasisPoints:
            decimalToBasisPoints(json['taux_tva'], field: 'TVA de ligne'),
      );
}

class OrderDetail {
  const OrderDetail({
    required this.summary,
    required this.lines,
    this.customerEmail,
  });

  final OrderSummary summary;
  final List<OrderHistoryLine> lines;
  final String? customerEmail;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lignes'];
    if (rawLines is! List) {
      throw const FormatException('Lignes de commande absentes.');
    }
    final summaryJson = Map<String, dynamic>.from(json)
      ..['nombre_lignes'] = rawLines.length;
    return OrderDetail(
      summary: OrderSummary.fromJson(summaryJson),
      customerEmail: _string(json['client_email']),
      lines: rawLines
          .map((item) =>
              OrderHistoryLine.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
    );
  }
}

int _int(Object? value, String field) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 1) throw FormatException('$field invalide.');
  return parsed;
}

int? _nullableInt(Object? value) {
  if (value == null || '$value'.isEmpty) return null;
  return value is num ? value.toInt() : int.tryParse('$value');
}

String? _string(Object? value) {
  if (value == null || value.toString().trim().isEmpty) return null;
  return value.toString().trim();
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

String? _customerName(Map<String, dynamic> json) {
  final values = [
    _string(json['client_nom']),
    _string(json['client_prenom']),
  ].whereType<String>().toList(growable: false);
  return values.isEmpty ? null : values.join(' ');
}
