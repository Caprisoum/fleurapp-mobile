import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    required this.onTap,
    this.actions,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final available = product.isAvailable;
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: available ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Opacity(
            opacity: available ? 1 : 0.52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.local_florist_rounded,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const Spacer(),
                    if (product.discountBasisPoints > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4DB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '-${product.discountPercent}%',
                          style: const TextStyle(
                            color: Color(0xFFB7462E),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (product.discountBasisPoints > 0 && actions != null)
                      const SizedBox(width: 2),
                    if (actions != null) actions!,
                  ],
                ),
                const Spacer(),
                Text(
                  product.category.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        available ? formatEuro(product.priceCents) : 'Épuisé',
                        style: TextStyle(
                          color: available ? colors.primary : colors.outline,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (available)
                      Tooltip(
                        message: 'Ajouter au panier',
                        child: Icon(
                          Icons.add_shopping_cart_rounded,
                          color: colors.secondary,
                          size: 28,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
