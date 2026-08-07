import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/cart_item.dart';
import '../../../state/pos_controller.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({
    required this.controller,
    required this.onCheckout,
    super.key,
  });

  final PosController controller;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F0EB),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined,
                      color: AppTheme.forest),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande en cours',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '${controller.cartQuantity} article${controller.cartQuantity > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: controller.isCartEmpty
                  ? const _EmptyCart()
                  : ListView.separated(
                      itemCount: controller.cartItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => _CartLine(
                        item: controller.cartItems[index],
                        onIncrement: () => controller
                            .increment(controller.cartItems[index].product),
                        onDecrement: () => controller
                            .decrement(controller.cartItems[index].product),
                        onRemove: () => controller
                            .remove(controller.cartItems[index].product),
                      ),
                    ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total TTC',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  formatEuro(controller.cartTotal),
                  style: const TextStyle(
                    color: AppTheme.forest,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.isCartEmpty || controller.isSubmitting
                  ? null
                  : onCheckout,
              icon: controller.isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_rounded),
              label:
                  Text(controller.isSubmitting ? 'Encaissement…' : 'Encaisser'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatEuro(item.product.priceTtc)} × ${item.quantity}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _QuantityButton(
                        icon: Icons.remove_rounded, onPressed: onDecrement),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _QuantityButton(
                        icon: Icons.add_rounded, onPressed: onIncrement),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Retirer',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
              const SizedBox(height: 4),
              Text(
                formatEuro(item.totalTtc),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.black26),
          SizedBox(height: 12),
          Text('Votre panier est vide',
              style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 5),
          Text(
            'Touchez un produit pour l’ajouter.',
            style: TextStyle(color: Colors.black45, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
