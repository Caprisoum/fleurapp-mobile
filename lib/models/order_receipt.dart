class OrderReceipt {
  const OrderReceipt({
    required this.orderId,
    required this.totalTtc,
    required this.hash,
    this.status,
  });

  final int orderId;
  final double totalTtc;
  final String hash;
  final String? status;

  factory OrderReceipt.fromJson(Map<String, dynamic> json) {
    final idValue = json['orderId'] ?? json['order_id'];
    final totalValue = json['totalTTC'] ?? json['total_ttc'];
    final orderId = idValue is num ? idValue.toInt() : int.tryParse('$idValue');
    final totalTtc = totalValue is num
        ? totalValue.toDouble()
        : double.tryParse('$totalValue');

    if (orderId == null || totalTtc == null) {
      throw const FormatException('Réponse de commande incomplète.');
    }

    return OrderReceipt(
      orderId: orderId,
      totalTtc: totalTtc,
      hash: (json['hash'] ?? '').toString(),
      status: json['statut']?.toString(),
    );
  }
}
