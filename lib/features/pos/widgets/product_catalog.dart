import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/product.dart';
import '../../../state/pos_controller.dart';
import 'product_card.dart';

class ProductCatalog extends StatefulWidget {
  const ProductCatalog({
    required this.controller,
    this.onDeclareWaste,
    this.onApplyAntiWaste,
    super.key,
  });

  final PosController controller;
  final ValueChanged<Product>? onDeclareWaste;
  final ValueChanged<Product>? onApplyAntiWaste;

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
    if (widget.controller.catalogStatus == CatalogStatus.loading &&
        widget.controller.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.controller.catalogStatus == CatalogStatus.error &&
        widget.controller.products.isEmpty) {
      return _CatalogError(
        message: widget.controller.catalogError ?? 'Catalogue indisponible.',
        onRetry: widget.controller.loadProducts,
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
                    color: Colors.black54,
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
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ProductCard(
                            product: product,
                            onTap: () {
                              final added =
                                  widget.controller.addProduct(product);
                              if (!added) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Stock disponible insuffisant.'),
                                    ),
                                  );
                              }
                            },
                          ),
                        ),
                        if (widget.onDeclareWaste != null ||
                            product.canApplyAntiWaste)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: PopupMenuButton<String>(
                              tooltip: 'Actions produit',
                              onSelected: (action) {
                                if (action == 'waste') {
                                  widget.onDeclareWaste?.call(product);
                                } else {
                                  widget.onApplyAntiWaste?.call(product);
                                }
                              },
                              itemBuilder: (_) => [
                                if (widget.onDeclareWaste != null)
                                  const PopupMenuItem(
                                    value: 'waste',
                                    child: Text('Déclarer une perte'),
                                  ),
                                if (product.canApplyAntiWaste &&
                                    widget.onApplyAntiWaste != null)
                                  const PopupMenuItem(
                                    value: 'discount',
                                    child: Text('Appliquer −30 %'),
                                  ),
                              ],
                            ),
                          ),
                      ],
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.forest,
      backgroundColor: Colors.white,
      side: BorderSide(
          color: selected ? AppTheme.forest : const Color(0xFFDFE7E3)),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w700,
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: Colors.black38),
          SizedBox(height: 10),
          Text('Aucun produit ne correspond à votre recherche.'),
        ],
      ),
    );
  }
}
