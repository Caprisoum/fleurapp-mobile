import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters.dart';
import '../../../core/money.dart';
import '../../../models/admin_models.dart';
import '../../../models/payment_method.dart';
import '../../../state/pos_controller.dart';

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    required this.totalCents,
    required this.customers,
    super.key,
  });

  final int totalCents;
  final List<Customer> customers;

  static Future<CheckoutOptions?> show(
    BuildContext context, {
    required int totalCents,
    required List<Customer> customers,
  }) =>
      showModalBottomSheet<CheckoutOptions>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => PaymentSheet(
          totalCents: totalCents,
          customers: customers,
        ),
      );

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  PaymentMethod _method = PaymentMethod.card;
  int? _customerId;
  bool _future = false;
  DateTime? _deliveryDate;
  final _depositController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      initialDate: _deliveryDate ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _deliveryDate ?? DateTime(now.year, now.month, now.day, 10),
      ),
    );
    if (time == null) return;
    setState(() {
      _deliveryDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    try {
      int? deposit;
      if (_future) {
        if (_customerId == null || _deliveryDate == null) {
          throw const MoneyFormatException(
            'Un client et une date de livraison sont requis.',
          );
        }
        deposit = _depositController.text.trim().isEmpty
            ? 0
            : moneyToCents(_depositController.text, field: 'Acompte');
        if (deposit > widget.totalCents) {
          throw const MoneyFormatException('L’acompte dépasse le total.');
        }
      }
      Navigator.of(context).pop(
        CheckoutOptions(
          paymentMethod: _method,
          customerId: _customerId,
          isFutureOrder: _future,
          deliveryDate: _deliveryDate,
          depositCents: deposit,
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Encaisser ${formatEuro(widget.totalCents)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PaymentMethod>(
              segments: PaymentMethod.values
                  .map((method) => ButtonSegment(
                        value: method,
                        label: Text(method.label),
                        icon: Icon(switch (method) {
                          PaymentMethod.card => Icons.credit_card_rounded,
                          PaymentMethod.cash => Icons.payments_outlined,
                          PaymentMethod.cheque => Icons.edit_note_rounded,
                        }),
                      ))
                  .toList(),
              selected: {_method},
              onSelectionChanged: (value) =>
                  setState(() => _method = value.single),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 18),
            if (widget.customers.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                initialValue: _customerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Client (facultatif)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Vente anonyme'),
                  ),
                  ...widget.customers.map(
                    (customer) => DropdownMenuItem<int?>(
                      value: customer.id,
                      child: Text(
                        customer.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _customerId = value),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Commande différée'),
                subtitle: const Text('Date de retrait/livraison et acompte'),
                value: _future,
                onChanged: (value) => setState(() {
                  _future = value;
                  if (!value) {
                    _deliveryDate = null;
                    _depositController.clear();
                  }
                }),
              ),
            ] else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Vente anonyme'),
                  subtitle: Text(
                    'Connectez-vous en administrateur pour sélectionner un client ou créer une commande différée.',
                  ),
                ),
              ),
            if (_future) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDeliveryDate,
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  _deliveryDate == null
                      ? 'Choisir la date de livraison'
                      : formatDateTime(_deliveryDate),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _depositController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Acompte versé',
                  suffixText: '€',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Confirmer l’encaissement'),
            ),
            const SizedBox(height: 8),
            const ListTile(
              enabled: false,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.contactless_rounded),
              title: Text('Tap to Pay'),
              subtitle: Text('Architecture prête pour Stripe Terminal'),
              trailing: Chip(label: Text('À connecter')),
            ),
          ],
        ),
      ),
    );
  }
}
