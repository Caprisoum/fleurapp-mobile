import 'dart:convert';
import 'dart:typed_data';

enum CatalogDuplicateMode { skip, update }

extension CatalogDuplicateModeApi on CatalogDuplicateMode {
  String get apiValue => name;
  String get label => switch (this) {
        CatalogDuplicateMode.skip => 'Conserver les produits existants',
        CatalogDuplicateMode.update => 'Mettre à jour les produits existants',
      };
}

class CatalogImportRow {
  const CatalogImportRow(this.values);
  final Map<String, String> values;

  Map<String, dynamic> toJson() => values;
}

class CatalogImportPreviewRow {
  const CatalogImportPreviewRow({
    required this.row,
    required this.status,
    this.name,
    this.category,
    this.price,
    this.error,
  });

  final int row;
  final String status;
  final String? name;
  final String? category;
  final String? price;
  final String? error;

  factory CatalogImportPreviewRow.fromJson(Map<String, dynamic> json) =>
      CatalogImportPreviewRow(
        row: int.tryParse('${json['row']}') ?? 0,
        status: '${json['status'] ?? 'error'}',
        name: json['name']?.toString(),
        category: json['category']?.toString(),
        price: json['price']?.toString(),
        error: json['error']?.toString(),
      );
}

class CatalogImportPreview {
  const CatalogImportPreview({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
    required this.categoriesToCreate,
    required this.rows,
  });

  final int created;
  final int updated;
  final int skipped;
  final int errors;
  final List<String> categoriesToCreate;
  final List<CatalogImportPreviewRow> rows;

  bool get canImport => rows.isNotEmpty && errors == 0;

  factory CatalogImportPreview.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map? ?? {});
    return CatalogImportPreview(
      created: int.tryParse('${summary['create']}') ?? 0,
      updated: int.tryParse('${summary['update']}') ?? 0,
      skipped: int.tryParse('${summary['skip']}') ?? 0,
      errors: int.tryParse('${summary['error']}') ?? 0,
      categoriesToCreate: (json['categoriesToCreate'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      rows: (json['rows'] as List? ?? const [])
          .map((value) => CatalogImportPreviewRow.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .toList(growable: false),
    );
  }
}

class CatalogImportResult {
  const CatalogImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
  });

  final int created;
  final int updated;
  final int skipped;

  factory CatalogImportResult.fromJson(Map<String, dynamic> json) =>
      CatalogImportResult(
        created: int.tryParse('${json['created']}') ?? 0,
        updated: int.tryParse('${json['updated']}') ?? 0,
        skipped: int.tryParse('${json['skipped']}') ?? 0,
      );
}

class CatalogCsvParser {
  const CatalogCsvParser._();

  static const maxBytes = 32 * 1024;
  static const fields = <String>{
    'nom',
    'categorie',
    'prix_ttc',
    'taux_tva',
    'stock_actuel',
    'unite_achat',
    'unite_vente',
    'ratio_conversion',
    'date_arrivage',
    'duree_de_vie_jours',
  };

  static List<CatalogImportRow> parse(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('Le fichier CSV est vide.');
    if (bytes.length > maxBytes) {
      throw const FormatException('Le fichier dépasse la limite de 32 Kio.');
    }
    var source = utf8.decode(bytes);
    if (source.startsWith('\uFEFF')) source = source.substring(1);
    if (source.trim().isEmpty) {
      throw const FormatException('Le fichier CSV est vide.');
    }
    final firstLine = source.split(RegExp(r'\r?\n')).first;
    final delimiter =
        ';'.allMatches(firstLine).length >= ','.allMatches(firstLine).length
            ? ';'
            : ',';
    final records = _records(source, delimiter);
    if (records.length < 2) {
      throw const FormatException(
          'Le fichier doit contenir un en-tête et au moins un produit.');
    }
    final headers = records.first.map(_canonicalHeader).toList();
    final unknown = headers.where((header) => !fields.contains(header));
    if (unknown.isNotEmpty) {
      throw FormatException('Colonne CSV inconnue : ${unknown.first}.');
    }
    if (headers.toSet().length != headers.length) {
      throw const FormatException('Une colonne apparaît plusieurs fois.');
    }
    for (final required in ['nom', 'prix_ttc', 'taux_tva', 'stock_actuel']) {
      if (!headers.contains(required)) {
        throw FormatException('Colonne obligatoire absente : $required.');
      }
    }
    if (records.length - 1 > 100) {
      throw const FormatException('Un import est limité à 100 produits.');
    }
    return records.skip(1).toList().asMap().entries.map((entry) {
      final values = entry.value;
      if (values.length > headers.length &&
          values.skip(headers.length).any((value) => value.isNotEmpty)) {
        throw FormatException(
            'La ligne ${entry.key + 2} contient trop de colonnes.');
      }
      final row = {for (final field in fields) field: ''};
      for (var index = 0; index < headers.length; index += 1) {
        row[headers[index]] = index < values.length ? values[index] : '';
      }
      if (row['taux_tva']!.isEmpty) row['taux_tva'] = '20';
      if (row['stock_actuel']!.isEmpty) row['stock_actuel'] = '0';
      return CatalogImportRow(Map.unmodifiable(row));
    }).toList(growable: false);
  }

  static List<List<String>> _records(String source, String delimiter) {
    final records = <List<String>>[];
    var record = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var index = 0; index < source.length; index += 1) {
      final character = source[index];
      if (character == '"') {
        if (quoted && index + 1 < source.length && source[index + 1] == '"') {
          field.write('"');
          index += 1;
        } else {
          quoted = !quoted;
        }
      } else if (character == delimiter && !quoted) {
        record.add(field.toString().trim());
        field = StringBuffer();
      } else if ((character == '\n' || character == '\r') && !quoted) {
        if (character == '\r' &&
            index + 1 < source.length &&
            source[index + 1] == '\n') index += 1;
        record.add(field.toString().trim());
        if (record.any((value) => value.isNotEmpty)) records.add(record);
        record = <String>[];
        field = StringBuffer();
      } else {
        field.write(character);
      }
    }
    if (quoted) {
      throw const FormatException(
          'Une cellule possède un guillemet non fermé.');
    }
    record.add(field.toString().trim());
    if (record.any((value) => value.isNotEmpty)) records.add(record);
    return records;
  }

  static String _canonicalHeader(String value) {
    final normalized = _removeAccents(value)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return const {
          'produit': 'nom',
          'nom_produit': 'nom',
          'nom_du_produit': 'nom',
          'category': 'categorie',
          'prix': 'prix_ttc',
          'prix_euros': 'prix_ttc',
          'tva': 'taux_tva',
          'stock': 'stock_actuel',
          'ratio': 'ratio_conversion',
          'duree_de_vie': 'duree_de_vie_jours',
        }[normalized] ??
        normalized;
  }

  static String _removeAccents(String value) {
    const accented = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
    var output = value.replaceFirst(RegExp('^\uFEFF'), '');
    for (var index = 0; index < accented.length; index += 1) {
      output = output.replaceAll(accented[index], plain[index]);
      output = output.replaceAll(
          accented[index].toUpperCase(), plain[index].toUpperCase());
    }
    return output;
  }
}
