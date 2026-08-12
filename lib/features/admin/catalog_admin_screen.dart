import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/money.dart';
import '../../models/admin_models.dart';
import '../../models/catalog_import.dart';
import '../../models/product.dart';
import '../../services/api_exception.dart';
import '../../state/admin_controller.dart';
import '../../state/app_controller.dart';
import '../shared/async_state_widgets.dart';
import '../bugs/bug_report_sheet.dart';

class CatalogAdminScreen extends StatefulWidget {
  const CatalogAdminScreen({required this.appController, super.key});
  final AppController appController;

  @override
  State<CatalogAdminScreen> createState() => _CatalogAdminScreenState();
}

class _CatalogAdminScreenState extends State<CatalogAdminScreen> {
  String _search = '';
  int? _categoryId;
  bool _lowStockOnly = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      await widget.appController.pos.loadProducts();
      await widget.appController.refreshUpcomingAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) await widget.appController.handleUnauthorized();
      if (mounted) showApiError(context, error);
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _editProduct([Product? product]) async {
    final draft = await ProductFormDialog.show(
      context,
      categories: widget.appController.admin.categories,
      product: product,
    );
    if (draft == null || !mounted) return;
    await _run(
      () => widget.appController.admin.saveProduct(draft, existing: product),
      product == null ? 'Produit créé.' : 'Produit mis à jour.',
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer ce produit ?'),
            content: Text(
              '« ${product.name} » disparaîtra du catalogue. Le serveur refusera la suppression si un historique de vente existe.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Conserver'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) {
      await _run(
        () => widget.appController.admin.deleteProduct(product),
        'Produit supprimé.',
      );
    }
  }

  Future<void> _manageCategories() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryManager(appController: widget.appController),
    );
    if (mounted) setState(() {});
  }

  Future<void> _importCatalog() async {
    final result = await CatalogImportDialog.show(
      context,
      widget.appController.admin,
    );
    if (result == null || !mounted) return;
    await widget.appController.pos.loadProducts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        '${result.created} produit(s) créé(s), ${result.updated} mis à jour et ${result.skipped} conservé(s).',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.appController.admin;
    return AnimatedBuilder(
      animation: admin,
      builder: (context, _) {
        final query = _search.trim().toLowerCase();
        final products = admin.products.where((product) {
          final matchesSearch = query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query);
          final matchesCategory =
              _categoryId == null || product.categoryId == _categoryId;
          final matchesStock = !_lowStockOnly || (product.stock ?? 0) <= 5;
          return matchesSearch && matchesCategory && matchesStock;
        }).toList();
        return LoadingOrError(
          loading: admin.status == AdminStatus.loading,
          error: admin.status == AdminStatus.error ? admin.error : null,
          onRetry: admin.loadAll,
          onReportBug: () => BugReportSheet.show(context, widget.appController),
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: admin.refreshCatalog,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Gestion du catalogue',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    IconButton.filledTonal(
                                      onPressed:
                                          admin.busy ? null : _importCatalog,
                                      tooltip: 'Importer un catalogue CSV',
                                      icon:
                                          const Icon(Icons.upload_file_rounded),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          admin.busy ? null : _manageCategories,
                                      icon: const Icon(Icons.category_outlined),
                                      label: const Text('Catégories'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _search = value),
                              decoration: const InputDecoration(
                                hintText: 'Rechercher un produit…',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    value: _categoryId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Catégorie',
                                    ),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Toutes'),
                                      ),
                                      ...admin.categories.map(
                                        (category) => DropdownMenuItem<int?>(
                                          value: category.id,
                                          child: Text(
                                            category.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _categoryId = value),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FilterChip(
                                  label: const Text('Stock ≤ 5'),
                                  selected: _lowStockOnly,
                                  onSelected: (value) =>
                                      setState(() => _lowStockOnly = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('${products.length} résultat(s)'),
                          ],
                        ),
                      ),
                    ),
                    if (products.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('Aucun produit.')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        sliver: SliverList.separated(
                          itemCount: products.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _ProductAdminCard(
                              product: product,
                              disabled: admin.busy,
                              onEdit: () => _editProduct(product),
                              onDelete: () => _deleteProduct(product),
                              onAntiWaste: product.canApplyAntiWaste
                                  ? () => _run(
                                        () => admin.applyAntiWaste(product),
                                        'Remise anti-gaspi appliquée.',
                                      )
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: FloatingActionButton.extended(
                  onPressed: admin.busy ? null : _editProduct,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Produit'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CatalogImportDialog extends StatefulWidget {
  const CatalogImportDialog({required this.adminController, super.key});

  final AdminController adminController;

  static Future<CatalogImportResult?> show(
    BuildContext context,
    AdminController adminController,
  ) =>
      showDialog<CatalogImportResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CatalogImportDialog(adminController: adminController),
      );

  @override
  State<CatalogImportDialog> createState() => _CatalogImportDialogState();
}

class _CatalogImportDialogState extends State<CatalogImportDialog> {
  CatalogDuplicateMode _duplicateMode = CatalogDuplicateMode.skip;
  List<CatalogImportRow> _rows = const [];
  CatalogImportPreview? _preview;
  String? _fileName;
  String? _error;
  String? _idempotencyKey;
  bool _busy = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('Le téléphone n’a pas pu lire ce fichier.');
      }
      final rows = CatalogCsvParser.parse(bytes);
      setState(() {
        _rows = rows;
        _fileName = file.name;
        _preview = null;
        _error = null;
        _idempotencyKey = null;
      });
      await _loadPreview();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _loadPreview() async {
    if (_rows.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _idempotencyKey = null;
    });
    try {
      final preview = await widget.adminController
          .previewCatalogImport(_rows, _duplicateMode);
      if (mounted) setState(() => _preview = preview);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        if (mounted) Navigator.pop(context);
      } else if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Impossible de valider le fichier.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<void> _commit() async {
    if (_preview?.canImport != true) return;
    setState(() {
      _busy = true;
      _error = null;
      _idempotencyKey ??= _newIdempotencyKey();
    });
    try {
      final result = await widget.adminController.importCatalog(
        _rows,
        _duplicateMode,
        _idempotencyKey!,
      );
      if (mounted) Navigator.pop(context, result);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        if (mounted) Navigator.pop(context);
      } else if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Connexion interrompue. Vous pouvez relancer sans créer de doublon.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      title: const Text('Importer un catalogue CSV'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Utilisez le modèle téléchargé depuis l’administration Web. Prix, TVA, stocks, unités et dates seront vérifiés avant l’import.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(_fileName ?? 'Choisir un fichier CSV'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<CatalogDuplicateMode>(
                value: _duplicateMode,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Produits existants'),
                items: CatalogDuplicateMode.values
                    .map((mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(
                            mode.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(growable: false),
                onChanged: _busy
                    ? null
                    : (mode) {
                        if (mode == null || mode == _duplicateMode) return;
                        setState(() => _duplicateMode = mode);
                        _loadPreview();
                      },
              ),
              if (_busy) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (preview != null) ...[
                const SizedBox(height: 14),
                Text(
                  '${preview.created} à créer · ${preview.updated} à mettre à jour · ${preview.skipped} conservé(s) · ${preview.errors} erreur(s)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (preview.categoriesToCreate.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                      'Catégories à créer : ${preview.categoriesToCreate.join(', ')}'),
                ],
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: preview.rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = preview.rows[index];
                      final invalid = row.status == 'error';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text('${row.row}'),
                        ),
                        title: Text(row.name ?? row.error ?? 'Ligne invalide'),
                        subtitle: Text(row.category ?? 'Sans catégorie'),
                        trailing: Icon(
                          invalid
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          color: invalid
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _busy || preview?.canImport != true ? null : _commit,
          child: const Text('Confirmer l’import'),
        ),
      ],
    );
  }
}

class _ProductAdminCard extends StatelessWidget {
  const _ProductAdminCard({
    required this.product,
    required this.disabled,
    required this.onEdit,
    required this.onDelete,
    this.onAntiWaste,
  });
  final Product product;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAntiWaste;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                child: Text('${product.stock ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product.category} · ${formatEuro(product.basePriceCents ?? product.priceCents)} · TVA ${(product.vatBasisPoints / 100).toStringAsFixed(2)} %',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.hasUnitConversion)
                      Text(
                        '1 ${product.purchaseUnit} = ${product.conversionRatio} ${product.saleUnit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: !disabled,
                tooltip: 'Actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'discount') onAntiWaste?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  if (onAntiWaste != null)
                    const PopupMenuItem(
                      value: 'discount',
                      child: Text('Appliquer −30 %'),
                    ),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
        ),
      );
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({
    required this.categories,
    this.product,
    super.key,
  });
  final List<ProductCategory> categories;
  final Product? product;

  static Future<ProductDraft?> show(
    BuildContext context, {
    required List<ProductCategory> categories,
    Product? product,
  }) =>
      showDialog<ProductDraft>(
        context: context,
        builder: (_) =>
            ProductFormDialog(categories: categories, product: product),
      );

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _vat;
  late final TextEditingController _stock;
  late final TextEditingController _shelfLife;
  late final TextEditingController _purchaseUnit;
  late final TextEditingController _saleUnit;
  late final TextEditingController _ratio;
  int? _categoryId;
  DateTime? _arrivalDate;
  String? _error;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _price = TextEditingController(
      text: product == null
          ? ''
          : centsToApiDecimal(product.basePriceCents ?? product.priceCents),
    );
    _vat = TextEditingController(
      text: product == null
          ? '20.00'
          : basisPointsToApiDecimal(product.vatBasisPoints),
    );
    _stock = TextEditingController(text: '${product?.stock ?? 0}');
    _shelfLife = TextEditingController(text: '${product?.shelfLifeDays ?? ''}');
    _purchaseUnit = TextEditingController(text: product?.purchaseUnit ?? '');
    _saleUnit = TextEditingController(text: product?.saleUnit ?? '');
    _ratio = TextEditingController(text: '${product?.conversionRatio ?? ''}');
    _categoryId = product?.categoryId;
    _arrivalDate = product?.arrivalDate;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _price,
      _vat,
      _stock,
      _shelfLife,
      _purchaseUnit,
      _saleUnit,
      _ratio,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _selectedCategoryName {
    if (_categoryId == null) return 'Sans catégorie';
    for (final category in widget.categories) {
      if (category.id == _categoryId) return category.name;
    }
    return 'Sans catégorie';
  }

  Future<void> _pickCategory() async {
    final selection = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _CategoryPickerSheet(
        categories: widget.categories,
        selectedId: _categoryId,
      ),
    );
    if (selection != null && mounted) {
      setState(() => _categoryId = selection.id);
    }
  }

  Future<void> _pickArrivalDate() async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _arrivalDate ?? DateTime.now(),
    );
    if (result != null) setState(() => _arrivalDate = result);
  }

  void _submit() {
    try {
      final name = _name.text.trim();
      final stock = int.tryParse(_stock.text);
      final shelfLife =
          _shelfLife.text.isEmpty ? null : int.tryParse(_shelfLife.text);
      final ratio = _ratio.text.isEmpty ? null : int.tryParse(_ratio.text);
      final purchase = _purchaseUnit.text.trim();
      final sale = _saleUnit.text.trim();
      final hasUnit = purchase.isNotEmpty || sale.isNotEmpty || ratio != null;
      if (name.length < 2 || name.length > 120 || stock == null || stock < 0) {
        throw const FormatException('Vérifiez le nom et le stock.');
      }
      if ((_arrivalDate == null) != (shelfLife == null) ||
          (shelfLife != null && shelfLife < 1)) {
        throw const FormatException(
          'Date d’arrivage et durée de vie doivent être renseignées ensemble.',
        );
      }
      if (hasUnit &&
          (purchase.isEmpty || sale.isEmpty || ratio == null || ratio < 1)) {
        throw const FormatException(
          'Complétez les deux unités et un ratio entier positif.',
        );
      }
      Navigator.of(context).pop(
        ProductDraft(
          name: name,
          categoryId: _categoryId,
          priceCents: moneyToCents(_price.text, field: 'Prix TTC'),
          vatBasisPoints: decimalToBasisPoints(_vat.text, field: 'TVA'),
          stock: stock,
          arrivalDate: _arrivalDate,
          shelfLifeDays: shelfLife,
          purchaseUnit: hasUnit ? purchase : null,
          saleUnit: hasUnit ? sale : null,
          conversionRatio: hasUnit ? ratio : null,
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.product == null ? 'Nouveau produit' : 'Modifier le produit'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  label: 'Choisir une catégorie, $_selectedCategoryName',
                  child: InkWell(
                    key: const Key('product-category-picker'),
                    onTap: _pickCategory,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCategoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _numberField(_price, 'Prix TTC',
                            decimal: true, suffix: '€')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _numberField(_vat, 'TVA',
                            decimal: true, suffix: '%')),
                  ],
                ),
                const SizedBox(height: 10),
                _numberField(_stock, 'Stock actuel'),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Conditionnement grossiste',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: _purchaseUnit,
                            decoration: const InputDecoration(
                                labelText: 'Unité achat'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: _saleUnit,
                            decoration: const InputDecoration(
                                labelText: 'Unité vente'))),
                  ],
                ),
                const SizedBox(height: 8),
                _numberField(_ratio, 'Ratio de conversion'),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _pickArrivalDate,
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(_arrivalDate == null
                      ? 'Date d’arrivage'
                      : '${_arrivalDate!.day.toString().padLeft(2, '0')}/${_arrivalDate!.month.toString().padLeft(2, '0')}/${_arrivalDate!.year}'),
                ),
                const SizedBox(height: 8),
                _numberField(_shelfLife, 'Durée de vie (jours)'),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
        ],
      );

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
    String? suffix,
  }) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'[0-9,.]') : RegExp(r'[0-9]'),
          ),
        ],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );
}

class _CategoryChoice {
  const _CategoryChoice(this.id);

  final int? id;
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
  });

  final List<ProductCategory> categories;
  final int? selectedId;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final categories = widget.categories
        .where((category) => category.name.toLowerCase().contains(query))
        .toList(growable: false);
    final showUncategorized = query.isEmpty || 'sans catégorie'.contains(query);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.folder_copy_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choisir une catégorie',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        '${widget.categories.length} catégorie(s) disponible(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Rechercher une catégorie…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                key: const Key('product-category-list'),
                children: [
                  if (showUncategorized)
                    _CategoryOptionCard(
                      name: 'Sans catégorie',
                      detail: 'Produit non classé',
                      icon: Icons.inventory_2_outlined,
                      selected: widget.selectedId == null,
                      onTap: () => Navigator.of(context)
                          .pop(const _CategoryChoice(null)),
                    ),
                  ...categories.map(
                    (category) => _CategoryOptionCard(
                      name: category.name,
                      detail: 'Catégorie du catalogue',
                      icon: Icons.local_florist_rounded,
                      selected: widget.selectedId == category.id,
                      onTap: () => Navigator.of(context)
                          .pop(_CategoryChoice(category.id)),
                    ),
                  ),
                  if (!showUncategorized && categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 34),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 42,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          const Text('Aucune catégorie trouvée.'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryOptionCard extends StatelessWidget {
  const _CategoryOptionCard({
    required this.name,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? colors.onPrimary : colors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryManager extends StatefulWidget {
  const _CategoryManager({required this.appController});
  final AppController appController;

  @override
  State<_CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<_CategoryManager> {
  final _name = TextEditingController();
  String? _error;
  String? _success;
  bool _hasDraft = false;
  bool _allowPop = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.length < 2 || name.length > 60) {
      setState(() {
        _success = null;
        _error = 'Le nom doit contenir entre 2 et 60 caractères.';
      });
      return;
    }
    try {
      await widget.appController.admin.createCategory(name);
      _name.clear();
      if (!mounted) return;
      setState(() {
        _hasDraft = false;
        _error = null;
        _success =
            '« $name » a été créée. Vous pouvez maintenant la choisir dans une fiche produit.';
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _success = null;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _finish() async {
    if (_name.text.trim().isEmpty) {
      _closeDialog();
      return;
    }
    final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Catégorie non créée'),
            content: const Text(
              'Un nom est encore saisi. Appuyez sur « Créer la catégorie » pour l’enregistrer, ou fermez sans le conserver.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Revenir'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Fermer sans créer'),
              ),
            ],
          ),
        ) ??
        false;
    if (discard && mounted) _closeDialog();
  }

  void _closeDialog() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _delete(ProductCategory category) async {
    try {
      await widget.appController.admin.deleteCategory(category.id);
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
        canPop: _allowPop || !_hasDraft,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _hasDraft) _finish();
        },
        child: AnimatedBuilder(
          animation: widget.appController.admin,
          builder: (context, _) => AlertDialog(
            title: const Text('Gérer les catégories'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('new-category-name'),
                    controller: _name,
                    textInputAction: TextInputAction.done,
                    onSubmitted: widget.appController.admin.busy
                        ? null
                        : (_) => _create(),
                    onChanged: (value) {
                      setState(() {
                        _hasDraft = value.trim().isNotEmpty;
                        _error = null;
                        _success = null;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nom de la nouvelle catégorie',
                      hintText: 'Exemple : Fleurs d’été',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('create-category-button'),
                      onPressed:
                          widget.appController.admin.busy ? null : _create,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(widget.appController.admin.busy
                          ? 'Création en cours…'
                          : 'Créer la catégorie'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _success!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.appController.admin.categories.length,
                      itemBuilder: (context, index) {
                        final category =
                            widget.appController.admin.categories[index];
                        return ListTile(
                          title: Text(category.name),
                          trailing: IconButton(
                            onPressed: widget.appController.admin.busy
                                ? null
                                : () => _delete(category),
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                  onPressed: widget.appController.admin.busy ? null : _finish,
                  child: const Text('Terminer')),
            ],
          ),
        ),
      );
}
