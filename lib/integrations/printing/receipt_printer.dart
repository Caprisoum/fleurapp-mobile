class ReceiptPrintData {
  const ReceiptPrintData({
    required this.orderId,
    required this.totalTtc,
    required this.lines,
  });

  final int orderId;
  final double totalTtc;
  final List<String> lines;
}

/// Contrat indépendant du protocole (ESC/POS Bluetooth, Wi-Fi, USB…).
abstract class ReceiptPrinter {
  bool get isReady;

  Future<void> printReceipt(ReceiptPrintData receipt);
}
