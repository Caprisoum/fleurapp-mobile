enum CashRegisterDeviceType { receiptPrinter, paymentTerminal, cashDrawer }

class CashRegisterDevice {
  const CashRegisterDevice({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final CashRegisterDeviceType type;
}

/// Port Bluetooth commun aux futures imprimantes, TPE et tiroirs-caisses.
/// Une implémentation par constructeur pourra être branchée sans modifier la
/// gestion du panier.
abstract class CashRegisterBluetoothService {
  Stream<List<CashRegisterDevice>> scan();

  Future<void> connect(CashRegisterDevice device);

  Future<void> disconnect();

  bool get isConnected;
}
