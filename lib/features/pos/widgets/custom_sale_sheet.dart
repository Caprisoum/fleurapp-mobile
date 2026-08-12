import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters.dart';
import '../../../core/money.dart';

class CustomSaleDraft {
  const CustomSaleDraft({
    required this.name,
    required this.priceCents,
    required this.vatBasisPoints,
    required this.quantity,
  });

  final String name;
  final int priceCents;
  final int vatBasisPoints;
  final int quantity;
}

class CustomSaleSheet extends StatefulWidget {
  const CustomSaleSheet({super.key});

  static Future<CustomSaleDraft?> show(BuildContext context) =>
      showModalBottomSheet<CustomSaleDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const CustomSaleSheet(),
      );

  @override
  State<CustomSaleSheet> createState() => _CustomSaleSheetState();
}

class _CustomSaleSheetState extends State<CustomSaleSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  int _vatBasisPoints = 1000;
  String? _error;

  @override
  void initState() {
    super.initState();
    _price.addListener(_refreshPreview);
    _quantity.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _price.removeListener(_refreshPreview);
    _quantity.removeListener(_refreshPreview);
    _name.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) setState(() => _error = null);
  }

  int? get _unitPriceCents {
    try {
      final cents = moneyToCents(_price.text, field: 'Prix TTC');
      return cents >= 1 && cents <= 100000000 ? cents : null;
    } on FormatException {
      return null;
    }
  }

  int? get _parsedQuantity {
    final value = int.tryParse(_quantity.text);
    return value != null && value >= 1 && value <= 999 ? value : null;
  }

  void _adjustQuantity(int delta) {
    final current = int.tryParse(_quantity.text) ?? 1;
    _quantity.text = (current + delta).clamp(1, 999).toString();
    _quantity.selection =
        TextSelection.collapsed(offset: _quantity.text.length);
  }

  void _submit() {
    final name = _name.text.trim();
    final priceCents = _unitPriceCents;
    final quantity = _parsedQuantity;
    if (name.length < 2 ||
        name.length > 120 ||
        RegExp(r'[<>\x00-\x1F\x7F]').hasMatch(name)) {
      setState(() => _error = 'Saisissez un nom de produit valide.');
      return;
    }
    if (priceCents == null) {
      setState(() => _error = 'Saisissez un prix TTC valide supérieur à 0 €.');
      return;
    }
    if (quantity == null) {
      setState(() => _error = 'La quantité doit être comprise entre 1 et 999.');
      return;
    }
    Navigator.pop(
      context,
      CustomSaleDraft(
        name: name,
        priceCents: priceCents,
        vatBasisPoints: _vatBasisPoints,
        quantity: quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final priceCents = _unitPriceCents;
    final quantity = _parsedQuantity;
    final totalCents =
        priceCents != null && quantity != null ? priceCents * quantity : null;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.edit_note_rounded,
                      color: colors.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vente sur mesure',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      Text('Nom, prix et quantité personnalisés'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('custom-sale-name'),
              controller: _name,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nom du produit',
                hintText: 'Exemple : Bouquet création client',
                prefixIcon: Icon(Icons.local_florist_outlined),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('custom-sale-price'),
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Prix TTC',
                      suffixText: '€',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _vatBasisPoints,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'TVA'),
                    items: const [
                      DropdownMenuItem(value: 550, child: Text('5,5 %')),
                      DropdownMenuItem(value: 1000, child: Text('10 %')),
                      DropdownMenuItem(value: 2000, child: Text('20 %')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _vatBasisPoints = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Quantité', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 7),
            Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: IconButton.filledTonal(
                    key: const Key('custom-sale-decrement'),
                    onPressed: () => _adjustQuantity(-1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('custom-sale-quantity'),
                    controller: _quantity,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '1',
                      helperText: 'De 1 à 999',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton.filledTonal(
                    key: const Key('custom-sale-increment'),
                    onPressed: () => _adjustQuantity(1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Total de la ligne',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    totalCents == null ? '—' : formatEuro(totalCents),
                    key: const Key('custom-sale-total'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(
                      color: colors.error, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    key: const Key('add-custom-sale-button'),
                    onPressed: _submit,
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Ajouter au panier'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
