import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../models/admin_models.dart';
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
            .showSnackBar(SnackBar(content: Text(success)));
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
                        const _BomStatus(),
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

class _BomStatus extends StatelessWidget {
  const _BomStatus();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_tree_outlined,
                      size: 40, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Nomenclatures protégées côté serveur',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'La vente déduit déjà atomiquement les composants des bouquets. Le backend audité ne publie toutefois aucune route GET/POST/PUT/DELETE pour lire ou modifier produits_bom. Le mobile n’invente donc pas une sauvegarde locale divergente.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'API nécessaire pour activer cet écran : liste des nomenclatures, création/modification transactionnelle et suppression protégée.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
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
