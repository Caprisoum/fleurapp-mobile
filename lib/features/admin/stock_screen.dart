import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../models/admin_models.dart';
import '../../models/bom_recipe.dart';
import '../../models/product.dart';
import '../../services/api_exception.dart';
import '../../state/admin_controller.dart';
import '../../state/app_controller.dart';
import '../shared/async_state_widgets.dart';
import '../bugs/bug_report_sheet.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({required this.appController, super.key});
  final AppController appController;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      await appController.pos.loadProducts();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(success)));
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) await appController.handleUnauthorized();
      if (context.mounted) showApiError(context, error);
    } catch (error) {
      if (context.mounted) showApiError(context, error);
    }
  }

  Future<void> _receive(BuildContext context, Product product) async {
    final quantity = await _IntegerDialog.show(
      context,
      title: 'Réception — ${product.name}',
      label: 'Nombre de ${product.purchaseUnit}',
      helper:
          '1 ${product.purchaseUnit} = ${product.conversionRatio} ${product.saleUnit}',
    );
    if (quantity == null || !context.mounted) return;
    await _run(
      context,
      () => appController.admin.receiveStock(product, quantity),
      'Réception enregistrée.',
    );
  }

  Future<void> _waste(BuildContext context, Product product) async {
    final result = await _WasteStockDialog.show(context, product);
    if (result == null || !context.mounted) return;
    await _run(
      context,
      () => appController.admin
          .declareWaste(product, result.quantity, result.reason),
      'Perte enregistrée.',
    );
  }

  Future<void> _saveBom(BuildContext context, [BomRecipe? existing]) async {
    final draft = await _BomEditorDialog.show(
      context,
      products: appController.admin.products,
      existing: existing,
    );
    if (draft == null || !context.mounted) return;
    await _run(
      context,
      () => appController.admin.saveBomRecipe(draft),
      existing == null ? 'Nomenclature créée.' : 'Nomenclature actualisée.',
    );
  }

  Future<void> _deleteBom(BuildContext context, BomRecipe recipe) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer cette nomenclature ?'),
            content: Text(
              'La composition de « ${recipe.parentName} » sera supprimée. Les produits et leurs stocks seront conservés.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      () => appController.admin.deleteBomRecipe(recipe),
      'Nomenclature supprimée.',
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: appController.admin,
        builder: (context, _) {
          final admin = appController.admin;
          return LoadingOrError(
            loading: admin.status == AdminStatus.loading,
            error: admin.status == AdminStatus.error ? admin.error : null,
            onRetry: admin.loadAll,
            onReportBug: () => BugReportSheet.show(context, appController),
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(
                          text: 'Stocks',
                          icon: Icon(Icons.inventory_2_outlined)),
                      Tab(
                          text: 'Réceptions',
                          icon: Icon(Icons.add_business_rounded)),
                      Tab(text: 'Pertes', icon: Icon(Icons.compost_outlined)),
                      Tab(text: 'BOM', icon: Icon(Icons.account_tree_outlined)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _StockList(
                          products: admin.products,
                          busy: admin.busy,
                          onReceive: (product) => _receive(context, product),
                          onWaste: (product) => _waste(context, product),
                          onRefresh: admin.refreshCatalog,
                        ),
                        _ReceptionList(
                          receptions: admin.receptions,
                          onRefresh: admin.refreshStock,
                        ),
                        _WasteList(
                          records: admin.wasteRecords,
                          onRefresh: admin.refreshActivity,
                        ),
                        _BomList(
                          recipes: admin.bomRecipes,
                          busy: admin.busy,
                          onCreate: () => _saveBom(context),
                          onEdit: (recipe) => _saveBom(context, recipe),
                          onDelete: (recipe) => _deleteBom(context, recipe),
                          onRefresh: admin.refreshBom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _StockList extends StatelessWidget {
  const _StockList({
    required this.products,
    required this.busy,
    required this.onReceive,
    required this.onWaste,
    required this.onRefresh,
  });
  final List<Product> products;
  final bool busy;
  final ValueChanged<Product> onReceive;
  final ValueChanged<Product> onWaste;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final product = products[index];
            final stock = product.stock ?? 0;
            final color = stock == 0
                ? Theme.of(context).colorScheme.error
                : stock <= 5
                    ? Colors.orange.shade800
                    : Theme.of(context).colorScheme.primary;
            return Card(
              child: ListTile(
                minVerticalPadding: 12,
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(.12),
                  child: Text('$stock',
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.w900)),
                ),
                title: Text(product.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text([
                  product.category,
                  if (product.hasUnitConversion)
                    '1 ${product.purchaseUnit} = ${product.conversionRatio} ${product.saleUnit}',
                ].join('\n')),
                trailing: PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (value) => value == 'receive'
                      ? onReceive(product)
                      : onWaste(product),
                  itemBuilder: (_) => [
                    if (product.hasUnitConversion)
                      const PopupMenuItem(
                          value: 'receive', child: Text('Réceptionner')),
                    const PopupMenuItem(
                        value: 'waste', child: Text('Déclarer une perte')),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _ReceptionList extends StatelessWidget {
  const _ReceptionList({required this.receptions, required this.onRefresh});
  final List<StockReception> receptions;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: receptions.isEmpty
            ? ListView(children: const [
                SizedBox(height: 180),
                Center(child: Text('Aucune réception récente.'))
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: receptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final reception = receptions[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(reception.productName),
                      subtitle: Text(
                        '${reception.receivedQuantity} ${reception.purchaseUnit} × '
                        '${reception.addedQuantity ~/ reception.receivedQuantity} → '
                        '+${reception.addedQuantity} ${reception.saleUnit}\n'
                        'Stock : ${reception.stockBefore} → ${reception.stockAfter} · '
                        '${formatDateTime(reception.receivedAt)}',
                      ),
                    ),
                  );
                },
              ),
      );
}

class _WasteList extends StatelessWidget {
  const _WasteList({required this.records, required this.onRefresh});
  final List<WasteRecord> records;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: records.isEmpty
            ? ListView(children: const [
                SizedBox(height: 180),
                Center(child: Text('Aucune perte aujourd’hui.'))
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.compost_outlined),
                      title: Text('${record.quantity} × ${record.productName}'),
                      subtitle: Text(
                          '${record.reason} · ${formatDateTime(record.date)}'),
                    ),
                  );
                },
              ),
      );
}

class _BomList extends StatelessWidget {
  const _BomList({
    required this.recipes,
    required this.busy,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<BomRecipe> recipes;
  final bool busy;
  final VoidCallback onCreate;
  final ValueChanged<BomRecipe> onEdit;
  final ValueChanged<BomRecipe> onDelete;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            FilledButton.icon(
              key: const Key('create-bom-button'),
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle nomenclature'),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Stock vendable sécurisé'),
                subtitle: Text(
                  'Une vente déduit le stock du bouquet et les quantités de chaque composant dans une seule transaction.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (recipes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 72),
                child: Center(
                  child: Text(
                    'Aucune composition enregistrée.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...recipes.map((recipe) {
                final color = recipe.availableQuantity == 0
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary;
                return Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(.12),
                      child: Text(
                        '${recipe.availableQuantity}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      recipe.parentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${recipe.components.length} composant(s) · '
                      '${recipe.availableQuantity} disponible(s)',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      ...recipe.components.map(
                        (component) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.subdirectory_arrow_right),
                          title: Text(
                            '${component.quantity} × ${component.productName}',
                          ),
                          subtitle: Text(
                            'Stock ${component.stock} · permet ${component.possibleQuantity} bouquet(s)',
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: busy ? null : () => onEdit(recipe),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Modifier'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Supprimer la nomenclature',
                            onPressed: busy ? null : () => onDelete(recipe),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
}

class _BomEditorDialog extends StatefulWidget {
  const _BomEditorDialog({required this.products, this.existing});

  final List<Product> products;
  final BomRecipe? existing;

  static Future<BomRecipeDraft?> show(
    BuildContext context, {
    required List<Product> products,
    BomRecipe? existing,
  }) =>
      showDialog<BomRecipeDraft>(
        context: context,
        builder: (_) => _BomEditorDialog(
          products: products,
          existing: existing,
        ),
      );

  @override
  State<_BomEditorDialog> createState() => _BomEditorDialogState();
}

class _BomEditorDialogState extends State<_BomEditorDialog> {
  late int? _parentId;
  late final Map<int, int> _quantities;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _parentId = widget.existing?.parentId;
    _quantities = {
      for (final component in widget.existing?.components ?? const [])
        component.productId: component.quantity,
    };
  }

  void _submit() {
    if (_parentId == null) {
      setState(() => _error = 'Choisissez le bouquet à composer.');
      return;
    }
    if (_quantities.isEmpty) {
      setState(() => _error = 'Ajoutez au moins un composant.');
      return;
    }
    final components = _quantities.entries
        .map((entry) => BomComponentDraft(
              productId: entry.key,
              quantity: entry.value,
            ))
        .toList()
      ..sort((a, b) => a.productId.compareTo(b.productId));
    Navigator.pop(
      context,
      BomRecipeDraft(parentId: _parentId!, components: components),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedSearch = _search.trim().toLowerCase();
    final components = widget.products
        .where((product) => product.id != _parentId)
        .where((product) =>
            normalizedSearch.isEmpty ||
            product.name.toLowerCase().contains(normalizedSearch))
        .toList(growable: false);
    final existingParent = widget.existing == null
        ? null
        : widget.products
            .where((product) => product.id == widget.existing!.parentId)
            .firstOrNull;

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Nouvelle nomenclature'
            : 'Modifier la composition',
      ),
      content: SizedBox(
        width: 540,
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.existing == null)
              DropdownButtonFormField<int>(
                value: _parentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Bouquet ou produit composé',
                  prefixIcon: Icon(Icons.local_florist_outlined),
                ),
                items: widget.products
                    .map((product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(
                            product.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(growable: false),
                onChanged: (value) => setState(() {
                  _parentId = value;
                  if (value != null) _quantities.remove(value);
                  _error = null;
                }),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_florist_outlined),
                title: const Text('Produit composé'),
                subtitle:
                    Text(existingParent?.name ?? widget.existing!.parentName),
              ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Rechercher un composant',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: components.isEmpty
                  ? const Center(child: Text('Aucun produit disponible.'))
                  : ListView.builder(
                      itemCount: components.length,
                      itemBuilder: (context, index) {
                        final product = components[index];
                        final quantity = _quantities[product.id];
                        return Card(
                          child: Column(
                            children: [
                              CheckboxListTile(
                                value: quantity != null,
                                title: Text(product.name),
                                subtitle: Text(
                                  'Stock actuel : ${product.stock ?? 0}',
                                ),
                                onChanged: (selected) => setState(() {
                                  if (selected == true) {
                                    _quantities[product.id] = 1;
                                  } else {
                                    _quantities.remove(product.id);
                                  }
                                  _error = null;
                                }),
                              ),
                              if (quantity != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 8, 8),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Text('Quantité par bouquet'),
                                      ),
                                      IconButton(
                                        tooltip: 'Diminuer',
                                        onPressed: quantity <= 1
                                            ? null
                                            : () => setState(() =>
                                                _quantities[product.id] =
                                                    quantity - 1),
                                        icon: const Icon(Icons.remove_rounded),
                                      ),
                                      SizedBox(
                                        width: 42,
                                        child: Text(
                                          '$quantity',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Augmenter',
                                        onPressed: quantity >= 1000000
                                            ? null
                                            : () => setState(() =>
                                                _quantities[product.id] =
                                                    quantity + 1),
                                        icon: const Icon(Icons.add_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _IntegerDialog extends StatefulWidget {
  const _IntegerDialog({required this.title, required this.label, this.helper});
  final String title;
  final String label;
  final String? helper;

  static Future<int?> show(
    BuildContext context, {
    required String title,
    required String label,
    String? helper,
  }) =>
      showDialog<int>(
        context: context,
        builder: (_) =>
            _IntegerDialog(title: title, label: label, helper: helper),
      );

  @override
  State<_IntegerDialog> createState() => _IntegerDialogState();
}

class _IntegerDialogState extends State<_IntegerDialog> {
  final _controller = TextEditingController(text: '1');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helper,
            errorText: _error,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(_controller.text);
              if (value == null || value < 1 || value > 1000000) {
                setState(() => _error = 'Quantité invalide.');
              } else {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
}

class _WasteValue {
  const _WasteValue(this.quantity, this.reason);
  final int quantity;
  final String reason;
}

class _WasteStockDialog extends StatefulWidget {
  const _WasteStockDialog(this.product);
  final Product product;

  static Future<_WasteValue?> show(BuildContext context, Product product) =>
      showDialog<_WasteValue>(
        context: context,
        builder: (_) => _WasteStockDialog(product),
      );

  @override
  State<_WasteStockDialog> createState() => _WasteStockDialogState();
}

class _WasteStockDialogState extends State<_WasteStockDialog> {
  final _quantity = TextEditingController(text: '1');
  final _reason = TextEditingController(text: 'Fané');
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Perte — ${widget.product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantité',
                helperText: 'Stock : ${widget.product.stock ?? 0}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Motif'),
            ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final quantity = int.tryParse(_quantity.text);
              final stock = widget.product.stock ?? 0;
              final reason = _reason.text.trim();
              if (quantity == null ||
                  quantity < 1 ||
                  quantity > stock ||
                  reason.isEmpty) {
                setState(() => _error = 'Vérifiez la quantité et le motif.');
              } else {
                Navigator.pop(context, _WasteValue(quantity, reason));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      );
}
