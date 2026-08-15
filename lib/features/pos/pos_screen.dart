import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../models/order_receipt.dart';
import '../../models/product.dart';
import '../../services/api_exception.dart';
import '../../state/app_controller.dart';
import '../bugs/bug_report_sheet.dart';
import 'widgets/cart_panel.dart';
import 'widgets/custom_sale_sheet.dart';
import 'widgets/payment_sheet.dart';
import 'widgets/product_catalog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({required this.appController, super.key});

  final AppController appController;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  int _mobilePage = 0;

  Future<void> _addCustomSale() async {
    final draft = await CustomSaleSheet.show(context);
    if (draft == null || !mounted) return;
    widget.appController.pos.addCustomSale(
      name: draft.name,
      priceCents: draft.priceCents,
      vatBasisPoints: draft.vatBasisPoints,
      quantity: draft.quantity,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('« ${draft.name} » ajouté au panier.'),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () {
              if (mounted) setState(() => _mobilePage = 1);
            },
          ),
        ),
      );
  }

  Future<void> _startCheckout() async {
    final pos = widget.appController.pos;
    final options = await PaymentSheet.show(
      context,
      totalCents: pos.cartTotalCents,
      customers: widget.appController.adminAuthenticated
          ? widget.appController.admin.customers
          : const [],
    );
    if (options == null || !mounted) return;

    try {
      final receipt = await pos.checkout(options);
      await pos.loadProducts();
      if (widget.appController.adminAuthenticated) {
        try {
          await Future.wait([
            widget.appController.admin.refreshCatalog(),
            widget.appController.admin.refreshActivity(),
          ]);
        } catch (_) {
          // La vente est acquise ; les données de gestion pourront être
          // actualisées manuellement si le réseau coupe juste après.
        }
      }
      if (!mounted) return;
      await _showReceipt(receipt);
      if (mounted) setState(() => _mobilePage = 0);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isUnauthorized) {
        await widget.appController.handleUnauthorized();
      }
      _showCheckoutError(error);
    } catch (_) {
      if (mounted) {
        _showCheckoutError(const ApiException('L’encaissement a échoué.'));
      }
    }
  }

  void _showCheckoutError(ApiException error) {
    var message = error.message;
    if (error.statusCode == 409) {
      message =
          '$message Le panier a été conservé : actualisez les stocks avant de réessayer.';
    }
    if (error.requestId != null) {
      message = '$message\nRéférence : ${error.requestId}';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error.outcomeUnknown
              ? Colors.orange.shade800
              : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
        ),
      );
  }

  Future<void> _showReceipt(OrderReceipt receipt) {
    final ticket = _receiptText(receipt);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer le ticket',
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        title: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Ticket #${receipt.orderId}')),
            IconButton(
              key: const Key('close-receipt-button'),
              tooltip: 'Fermer le ticket',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470, maxHeight: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...receipt.lines.map(
                  (line) => _ReceiptLineCard(line: line),
                ),
                const SizedBox(height: 8),
                _ReceiptSummary(receipt: receipt),
                if (receipt.hash.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Empreinte d’intégrité',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          receipt.hash,
                          maxLines: 4,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: ticket));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ticket copié.')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copier'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nouvelle vente'),
          ),
        ],
      ),
    );
  }

  String _receiptText(OrderReceipt receipt) => [
        'FLEURAPP — TICKET #${receipt.orderId}',
        ...receipt.lines.map(
          (line) =>
              '${line.quantity} x ${line.name}  ${formatEuro(line.totalCents)}',
        ),
        'TOTAL TTC  ${formatEuro(receipt.totalCents)}',
        if (receipt.depositCents != null)
          'ACOMPTE  ${formatEuro(receipt.depositCents!)}',
        if ((receipt.remainingCents ?? 0) > 0)
          'RESTE  ${formatEuro(receipt.remainingCents!)}',
        if (receipt.hash.isNotEmpty) 'EMPREINTE ${receipt.hash}',
      ].join('\n');

  Future<void> _declareWaste(Product product) async {
    if (!widget.appController.adminAuthenticated) {
      _showCheckoutError(const ApiException(
        'Connectez-vous dans un module de gestion pour déclarer une perte.',
        statusCode: 401,
      ));
      return;
    }
    final result = await _WasteDialog.show(context, product);
    if (result == null || !mounted) return;
    try {
      await widget.appController.admin
          .declareWaste(product, result.quantity, result.reason);
      await widget.appController.pos.loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Perte enregistrée et stock actualisé.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) _showCheckoutError(error);
    }
  }

  Future<void> _applyAntiWaste(Product product) async {
    if (!widget.appController.adminAuthenticated) {
      _showCheckoutError(const ApiException(
        'Connexion administrateur requise pour appliquer une remise.',
        statusCode: 401,
      ));
      return;
    }
    try {
      await widget.appController.admin.applyAntiWaste(product);
      await widget.appController.pos.loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remise anti-gaspi de 30 % appliquée.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) _showCheckoutError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.appController.pos;
    return AnimatedBuilder(
      animation: Listenable.merge([controller, widget.appController.admin]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Padding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 8, wide ? 24 : 14, 14),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _catalog()),
                      const SizedBox(width: 20),
                      SizedBox(width: 390, child: _cart()),
                    ],
                  )
                : Column(
                    children: [
                      SegmentedButton<int>(
                        segments: [
                          const ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.grid_view_rounded),
                            label: Text('Catalogue'),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: Badge(
                              isLabelVisible: controller.cartQuantity > 0,
                              label: Text('${controller.cartQuantity}'),
                              child: const Icon(Icons.shopping_bag_outlined),
                            ),
                            label: const Text('Panier'),
                          ),
                        ],
                        selected: {_mobilePage},
                        onSelectionChanged: (value) =>
                            setState(() => _mobilePage = value.single),
                        showSelectedIcon: false,
                      ),
                      if (controller.hasUncertainCheckout) ...[
                        const SizedBox(height: 8),
                        const MaterialBanner(
                          content: Text(
                            'Résultat du dernier encaissement inconnu : ne modifiez pas le panier avant de réessayer.',
                          ),
                          actions: [SizedBox.shrink()],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 260),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: _mobilePage == 0
                              ? KeyedSubtree(
                                  key: const ValueKey('catalog'),
                                  child: _catalog())
                              : KeyedSubtree(
                                  key: const ValueKey('cart'), child: _cart()),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _catalog() => ProductCatalog(
        controller: widget.appController.pos,
        onAddCustomSale: _addCustomSale,
        onDeclareWaste: _declareWaste,
        onApplyAntiWaste: _applyAntiWaste,
        onReportBug: () => BugReportSheet.show(context, widget.appController),
      );

  Widget _cart() => CartPanel(
        controller: widget.appController.pos,
        onCheckout: _startCheckout,
      );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasized
                  ? const TextStyle(fontWeight: FontWeight.w900)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w800,
                fontSize: emphasized ? 16 : null,
              ),
            ),
          ),
        ],
      );
}

class _ReceiptLineCard extends StatelessWidget {
  const _ReceiptLineCard({required this.line});

  final ReceiptLine line;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '${line.quantity} ×',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              line.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatEuro(line.totalCents),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSummary extends StatelessWidget {
  const _ReceiptSummary({required this.receipt});

  final OrderReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: .22)),
      ),
      child: Column(
        children: [
          _ReceiptRow(
            label: 'Total TTC',
            value: formatEuro(receipt.totalCents),
            emphasized: true,
          ),
          if (receipt.depositCents != null) ...[
            const Divider(height: 18),
            _ReceiptRow(
              label: 'Acompte',
              value: formatEuro(receipt.depositCents!),
            ),
          ],
          if ((receipt.remainingCents ?? 0) > 0) ...[
            const Divider(height: 18),
            _ReceiptRow(
              label: 'Reste à payer',
              value: formatEuro(receipt.remainingCents!),
            ),
          ],
          if (receipt.status != null) ...[
            const Divider(height: 18),
            _ReceiptRow(label: 'Statut', value: receipt.status!),
          ],
        ],
      ),
    );
  }
}

class _WasteResult {
  const _WasteResult(this.quantity, this.reason);
  final int quantity;
  final String reason;
}

class _WasteDialog extends StatefulWidget {
  const _WasteDialog(this.product);
  final Product product;

  static Future<_WasteResult?> show(BuildContext context, Product product) =>
      showDialog<_WasteResult>(
        context: context,
        builder: (_) => _WasteDialog(product),
      );

  @override
  State<_WasteDialog> createState() => _WasteDialogState();
}

class _WasteDialogState extends State<_WasteDialog> {
  final _quantity = TextEditingController(text: '1');
  final _customReason = TextEditingController();
  String _reason = 'Fané';
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _customReason.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_quantity.text);
    final reason = _reason == 'Autre' ? _customReason.text.trim() : _reason;
    if (quantity == null ||
        quantity < 1 ||
        (widget.product.stock != null && quantity > widget.product.stock!) ||
        reason.isEmpty ||
        reason.length > 100) {
      setState(() => _error = 'Vérifiez la quantité disponible et le motif.');
      return;
    }
    Navigator.of(context).pop(_WasteResult(quantity, reason));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Perte — ${widget.product.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Quantité',
                  helperText: widget.product.stock == null
                      ? null
                      : 'Stock actuel : ${widget.product.stock}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Motif'),
                items: const ['Fané', 'Cassé', 'Invendable', 'Autre']
                    .map((reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _reason = value ?? 'Fané'),
              ),
              if (_reason == 'Autre') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customReason,
                  maxLength: 100,
                  decoration:
                      const InputDecoration(labelText: 'Précisez le motif'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
        ],
      );
}
