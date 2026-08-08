class MoneyFormatException implements FormatException {
  const MoneyFormatException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => message;
}

int moneyToCents(Object? value, {String field = 'Montant'}) {
  if (value == null) throw MoneyFormatException('$field manquant.');
  final normalized = value.toString().trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) throw MoneyFormatException('$field invalide.');

  final euros = int.tryParse(match.group(1)!);
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  final cents = int.tryParse(decimals.isEmpty ? '0' : decimals);
  if (euros == null || cents == null) {
    throw MoneyFormatException('$field invalide.');
  }
  final total = euros * 100 + cents;
  if (!total.isFinite || total > 100000000) {
    throw MoneyFormatException('$field hors limites.');
  }
  return total;
}

int decimalToBasisPoints(Object? value, {String field = 'Taux'}) {
  final normalized = value?.toString().trim().replaceAll(',', '.');
  final match =
      RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$').firstMatch(normalized ?? '');
  if (match == null) throw MoneyFormatException('$field invalide.');
  final whole = int.parse(match.group(1)!);
  final decimals = int.parse((match.group(2) ?? '').padRight(2, '0'));
  final result = whole * 100 + decimals;
  if (result > 10000) throw MoneyFormatException('$field hors limites.');
  return result;
}

String centsToApiDecimal(int cents) {
  if (cents < 0) throw const MoneyFormatException('Montant négatif interdit.');
  final euros = cents ~/ 100;
  final decimals = (cents % 100).toString().padLeft(2, '0');
  return '$euros.$decimals';
}

String basisPointsToApiDecimal(int basisPoints) {
  if (basisPoints < 0 || basisPoints > 10000) {
    throw const MoneyFormatException('Taux hors limites.');
  }
  final whole = basisPoints ~/ 100;
  final decimals = (basisPoints % 100).toString().padLeft(2, '0');
  return '$whole.$decimals';
}

String formatEuroCents(int cents) {
  final sign = cents < 0 ? '−' : '';
  final absolute = cents.abs();
  final euros = absolute ~/ 100;
  final decimals = (absolute % 100).toString().padLeft(2, '0');
  return '$sign$euros,$decimals\u00a0€';
}
