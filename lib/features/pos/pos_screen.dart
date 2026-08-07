import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../models/order_receipt.dart';
import '../../services/api_exception.dart';
import '../../state/pos_controller.dart';
import 'widgets/cart_panel.dart';
import 'widgets/payment_sheet.dart';
import 'widgets/product_catalog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({required this.controller, super.key});

  final PosController controller;

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  int _mobilePage = 0;

  Future<void> _startCheckout() async {
    final paymentMethod = await PaymentSheet.show(context);
    if (paymentMethod == null || !mounted) return;

    try {
      final receipt = await widget.controller.checkout(paymentMethod);
      if (!mounted) return;
      await _showOrderSuccess(receipt);
      if (mounted) setState(() => _mobilePage = 0);
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('L’encaissement a échoué. Veuillez réessayer.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  Future<void> _showOrderSuccess(OrderReceipt receipt) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFE5F0EB),
          child: Icon(Icons.check_rounded, color: AppTheme.forest, size: 34),
        ),
        title: const Text('Vente enregistrée'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReceiptRow(label: 'Commande', value: '#${receipt.orderId}'),
              const SizedBox(height: 10),
              _ReceiptRow(
                  label: 'Total TTC', value: formatEuro(receipt.totalTtc)),
              if (receipt.status != null) ...[
                const SizedBox(height: 10),
                _ReceiptRow(label: 'Statut', value: receipt.status!),
              ],
              if (receipt.hash.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Signature de transaction',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                SelectableText(
                  receipt.hash,
                  maxLines: 3,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nouvelle vente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Scaffold(
              appBar: _buildAppBar(wide),
              body: SafeArea(
                top: false,
                child: wide ? _buildWideLayout() : _buildMobileLayout(),
              ),
              bottomNavigationBar: wide ? null : _buildNavigationBar(),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool wide) {
    return AppBar(
      toolbarHeight: 70,
      titleSpacing: 18,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandMark(),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FleurApp',
                style:
                    TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.6),
              ),
              Text(
                'CAISSE MOBILE',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Actualiser le catalogue',
          onPressed: widget.controller.catalogStatus == CatalogStatus.loading
              ? null
              : widget.controller.loadProducts,
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (!wide)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton.filledTonal(
              tooltip: 'Ouvrir le panier',
              onPressed: () => setState(() => _mobilePage = 1),
              icon: Badge(
                isLabelVisible: widget.controller.cartQuantity > 0,
                label: Text('${widget.controller.cartQuantity}'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ProductCatalog(controller: widget.controller)),
          const SizedBox(width: 20),
          SizedBox(
            width: 390,
            child: CartPanel(
              controller: widget.controller,
              onCheckout: _startCheckout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return IndexedStack(
      index: _mobilePage,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: ProductCatalog(controller: widget.controller),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: CartPanel(
            controller: widget.controller,
            onCheckout: _startCheckout,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _mobilePage,
      onDestinationSelected: (index) => setState(() => _mobilePage = index),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          selectedIcon: Icon(Icons.grid_view_rounded, color: AppTheme.forest),
          label: 'Catalogue',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: widget.controller.cartQuantity > 0,
            label: Text('${widget.controller.cartQuantity}'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: widget.controller.cartQuantity > 0,
            label: Text('${widget.controller.cartQuantity}'),
            child: const Icon(Icons.shopping_bag, color: AppTheme.forest),
          ),
          label: 'Panier',
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.forest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x30173F35), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: const Icon(Icons.local_florist_rounded, color: Colors.white),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 20),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
