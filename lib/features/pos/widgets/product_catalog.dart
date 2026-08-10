import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../../../state/pos_controller.dart';
import 'product_card.dart';

class ProductCatalog extends StatefulWidget {
  const ProductCatalog({
    required this.controller,
    this.onDeclareWaste,
    this.onApplyAntiWaste,
    this.onReportBug,
    super.key,
  });

  final PosController controller;
  final ValueChanged<Product>? onDeclareWaste;
  final ValueChanged<Product>? onApplyAntiWaste;
  final VoidCallback? onReportBug;

  @override
  State<ProductCatalog> createState() => _ProductCatalogState();
}

class _ProductCatalogState extends State<ProductCatalog> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.controller.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (widget.controller.catalogStatus == CatalogStatus.loading &&
        widget.controller.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.controller.catalogStatus == CatalogStatus.error &&
        widget.controller.products.isEmpty) {
      return _CatalogError(
        message: widget.controller.catalogError ?? 'Catalogue indisponible.',
        onRetry: widget.controller.loadProducts,
        onReportBug: widget.onReportBug,
      );
    }

    final products = widget.controller.filteredProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Catalogue',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
            ),
            Text(
              '${products.length} produit${products.length > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: widget.controller.setSearchQuery,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher un produit…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: widget.controller.searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      _searchController.clear();
                      widget.controller.setSearchQuery('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryChip(
                label: 'Tout',
                selected: widget.controller.selectedCategory == null,
                onSelected: () => widget.controller.selectCategory(null),
              ),
              ...widget.controller.categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _CategoryChip(
                    label: category,
                    selected: widget.controller.selectedCategory == category,
                    onSelected: () =>
                        widget.controller.selectCategory(category),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (widget.controller.catalogStatus == CatalogStatus.error)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MaterialBanner(
              content: Text(widget.controller.catalogError ??
                  'Actualisation impossible.'),
              actions: [
                TextButton(
                  onPressed: widget.controller.loadProducts,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        Expanded(
          child: products.isEmpty
              ? const _EmptySearch()
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 210,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final canDeclareWaste = widget.onDeclareWaste != null;
                    final canApplyAntiWaste = product.canApplyAntiWaste &&
                        widget.onApplyAntiWaste != null;
                    return ProductCard(
                      product: product,
                      onTap: () {
                        final added = widget.controller.addProduct(product);
                        if (!added) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Stock disponible insuffisant.'),
                              ),
                            );
                        }
                      },
                      actions: canDeclareWaste || canApplyAntiWaste
                          ? PopupMenuButton<String>(
                              tooltip: 'Actions produit',
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: colors.onSurfaceVariant,
                              ),
                              onSelected: (action) {
                                if (action == 'waste') {
                                  widget.onDeclareWaste?.call(product);
                                } else if (action == 'discount') {
                                  widget.onApplyAntiWaste?.call(product);
                                }
                              },
                              itemBuilder: (_) => [
                                if (canDeclareWaste)
                                  const PopupMenuItem(
                                    value: 'waste',
                                    child: Text('Déclarer une perte'),
                                  ),
                                if (canApplyAntiWaste)
                                  const PopupMenuItem(
                                    value: 'discount',
                                    child: Text('Appliquer −30 %'),
                                  ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colors.primaryContainer,
      backgroundColor: colors.surfaceContainerHighest,
      side:
          BorderSide(color: selected ? colors.primary : colors.outlineVariant),
      labelStyle: TextStyle(
        color: selected ? colors.onPrimaryContainer : colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({
    required this.message,
    required this.onRetry,
    this.onReportBug,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onReportBug;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text(
                  'Catalogue indisponible',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
                if (onReportBug != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onReportBug,
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Signaler un problème'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 42,
            color: colors.outline,
          ),
          const SizedBox(height: 10),
          Text(
            'Aucun produit ne correspond à votre recherche.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
