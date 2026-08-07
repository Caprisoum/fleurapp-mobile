enum PaymentMethod {
  card('Carte bancaire'),
  cash('Espèces'),
  cheque('Chèque');

  const PaymentMethod(this.apiValue);

  final String apiValue;
}
