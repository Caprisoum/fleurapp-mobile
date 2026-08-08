import 'money.dart';

String formatEuro(int cents) => formatEuroCents(cents);

String formatDateTime(DateTime? value) {
  if (value == null) return 'Date inconnue';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
