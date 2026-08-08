import '../core/money.dart';

class ReceiptLine {
  const ReceiptLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
  });

  final int productId;
  final String name;
  final int quantity;
  final int unitPriceCents;
  int get totalCents => unitPriceCents * quantity;

  factory ReceiptLine.fromJson(Map<String, dynamic> json) => ReceiptLine(
        productId: _int(json['id']),
        name: '${json['name'] ?? 'Produit'}',
        quantity: _int(json['quantity']),
        unitPriceCents:
            moneyToCents(json['price_ttc'], field: 'Prix du ticket'),
      );
}

class OrderReceipt {
  const OrderReceipt({
    required this.orderId,
    required this.totalCents,
    required this.hash,
    this.depositCents,
    this.remainingCents,
    this.status,
    this.lines = const [],
    this.createdAt,
  });

  final int orderId;
  final int totalCents;
  final int? depositCents;
  final int? remainingCents;
  final String hash;
  final String? status;
  final List<ReceiptLine> lines;
  final DateTime? createdAt;

  factory OrderReceipt.fromJson(Map<String, dynamic> json) {
    final idValue = json['orderId'] ?? json['order_id'];
    final orderId = idValue is num ? idValue.toInt() : int.tryParse('$idValue');
    if (orderId == null) {
      throw const FormatException('Réponse de commande incomplète.');
    }
    final rawItems = json['items'];
    return OrderReceipt(
      orderId: orderId,
      totalCents: moneyToCents(
        json['totalTTC'] ?? json['total_ttc'],
        field: 'Total commande',
      ),
      depositCents: _nullableMoney(json['acomptePaye']),
      remainingCents: _nullableMoney(json['resteAPayer']),
      hash: (json['hash'] ?? '').toString(),
      status: json['statut']?.toString(),
      lines: rawItems is List
          ? rawItems
              .map((item) =>
                  ReceiptLine.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList(growable: false)
          : const [],
      createdAt: DateTime.now(),
    );
  }
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
int? _nullableMoney(Object? value) =>
    value == null ? null : moneyToCents(value, field: 'Montant du ticket');
