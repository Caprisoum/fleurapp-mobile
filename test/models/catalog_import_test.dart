import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/models/catalog_import.dart';

void main() {
  test('lit le modèle CSV français et conserve les virgules décimales', () {
    final bytes = Uint8List.fromList(utf8.encode(
      '\uFEFF"nom";"categorie";"prix_ttc";"taux_tva";"stock_actuel"\r\n'
      '"Rose rouge";"Fleurs coupées";"2,50";"20";"30"\r\n',
    ));
    final rows = CatalogCsvParser.parse(bytes);
    expect(rows, hasLength(1));
    expect(rows.single.values['nom'], 'Rose rouge');
    expect(rows.single.values['prix_ttc'], '2,50');
    expect(rows.single.values['categorie'], 'Fleurs coupées');
  });

  test('gère les séparateurs et guillemets dans une cellule', () {
    final rows = CatalogCsvParser.parse(Uint8List.fromList(utf8.encode(
      'nom;categorie;prix_ttc;taux_tva;stock_actuel\n'
      '"Bouquet ""Été""; premium";Bouquets;35.00;20;4\n',
    )));
    expect(rows.single.values['nom'], 'Bouquet "Été"; premium');
  });

  test('refuse une colonne inconnue et plus de 100 produits', () {
    expect(
      () => CatalogCsvParser.parse(Uint8List.fromList(utf8.encode(
        'nom;prix_ttc;taux_tva;stock_actuel;secret\nRose;2;20;1;x\n',
      ))),
      throwsFormatException,
    );
    final rows = List.generate(101, (index) => 'Rose $index;2;20;1').join('\n');
    expect(
      () => CatalogCsvParser.parse(Uint8List.fromList(utf8.encode(
        'nom;prix_ttc;taux_tva;stock_actuel\n$rows\n',
      ))),
      throwsFormatException,
    );
  });
}
