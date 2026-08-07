String formatEuro(double value) {
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
}
