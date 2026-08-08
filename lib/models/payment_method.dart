enum PaymentMethod {
  card('Carte bancaire', 'Carte Bancaire - TPE'),
  cash('Espèces', 'Espèces'),
  cheque('Chèque', 'Chèque');

  const PaymentMethod(this.label, this.apiValue);

  final String label;
  final String apiValue;
}
