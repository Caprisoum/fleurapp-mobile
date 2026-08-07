/// Port applicatif prévu pour Stripe Terminal / Tap to Pay.
///
/// L'implémentation native sera ajoutée ici sans coupler l'écran de caisse au
/// SDK du prestataire de paiement.
abstract class ContactlessPaymentGateway {
  bool get isAvailable;

  Future<PaymentAuthorization> authorize({
    required int amountInCents,
    required String currency,
    required String orderReference,
  });
}

class PaymentAuthorization {
  const PaymentAuthorization({
    required this.transactionId,
    required this.authorizedAt,
  });

  final String transactionId;
  final DateTime authorizedAt;
}

class UnavailableContactlessPaymentGateway
    implements ContactlessPaymentGateway {
  const UnavailableContactlessPaymentGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<PaymentAuthorization> authorize({
    required int amountInCents,
    required String currency,
    required String orderReference,
  }) {
    throw UnsupportedError('Tap to Pay n’est pas encore configuré.');
  }
}
