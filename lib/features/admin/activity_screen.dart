import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../models/admin_models.dart';
import '../../models/order_receipt.dart';
import '../../services/api_exception.dart';
import '../../state/admin_controller.dart';
import '../../state/app_controller.dart';
import '../shared/async_state_widgets.dart';
import '../bugs/bug_report_sheet.dart';
import 'bug_reports_panel.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({required this.appController, super.key});
  final AppController appController;

  Future<void> _closeDay(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clôturer la journée ?'),
            content: const Text(
              'Toutes les ventes non clôturées seront rattachées à un Ticket Z définitif. Cette opération est irréversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clôturer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      final receipt = await appController.admin.closeDay();
      if (context.mounted) await _showClosure(context, receipt);
    } on ApiException catch (error) {
      if (error.isUnauthorized) await appController.handleUnauthorized();
      if (context.mounted) showApiError(context, error);
    }
  }

  Future<void> _showClosure(BuildContext context, ClosureReceipt receipt) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.verified_rounded, size: 40),
          title: Text('Ticket Z #${receipt.id}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ValueRow(
                      label: 'Chiffre d’affaires TTC',
                      value: formatEuro(receipt.totalCents)),
                  const SizedBox(height: 8),
                  _ValueRow(label: 'TVA', value: formatEuro(receipt.vatCents)),
                  const SizedBox(height: 8),
                  _ValueRow(
                      label: 'Transactions',
                      value: '${receipt.transactionCount}'),
                  if (receipt.totalsByPayment.isNotEmpty) ...[
                    const Divider(height: 28),
                    ...receipt.totalsByPayment.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ValueRow(
                            label: entry.key, value: formatEuro(entry.value)),
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  const Text('Empreinte Z',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  SelectableText(receipt.hash,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: receipt.hash)),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copier le hash'),
            ),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([appController.admin, appController.pos]),
        builder: (context, _) {
          final admin = appController.admin;
          return LoadingOrError(
            loading: admin.status == AdminStatus.loading,
            error: admin.status == AdminStatus.error ? admin.error : null,
            onRetry: admin.loadAll,
            onReportBug: () => BugReportSheet.show(context, appController),
            child: DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(
                          text: 'Clôtures',
                          icon: Icon(Icons.point_of_sale_rounded)),
                      Tab(
                          text: 'Clients',
                          icon: Icon(Icons.people_outline_rounded)),
                      Tab(
                          text: 'Ventes',
                          icon: Icon(Icons.receipt_long_outlined)),
                      Tab(
                          text: 'FEC',
                          icon: Icon(Icons.file_download_outlined)),
                      Tab(text: 'Bugs', icon: Icon(Icons.bug_report_outlined)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _ClosureHistory(
                          closures: admin.closures,
                          busy: admin.busy,
                          onClose: () => _closeDay(context),
                          onRefresh: admin.refreshActivity,
                        ),
                        _CustomerList(customers: admin.customers),
                        _SessionOrders(
                            receipts: appController.pos.sessionReceipts),
                        _FecExport(admin: admin),
                        BugReportsPanel(appController: appController),
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

class _ClosureHistory extends StatelessWidget {
  const _ClosureHistory({
    required this.closures,
    required this.busy,
    required this.onClose,
    required this.onRefresh,
  });
  final List<ClosureRecord> closures;
  final bool busy;
  final VoidCallback onClose;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.lock_clock_rounded),
              label: const Text('Clôturer la caisse'),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Clôtures définitives'),
                subtitle: Text(
                    'La suppression et la dé-clôture sont interdites par l’API et PostgreSQL.'),
              ),
            ),
            const SizedBox(height: 8),
            if (closures.isEmpty)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: Text('Aucune clôture enregistrée.')),
              )
            else
              ...closures.map(
                (closure) => Card(
                  child: ExpansionTile(
                    leading: CircleAvatar(child: Text('#${closure.id}')),
                    title: Text(formatEuro(closure.totalCents),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        '${closure.transactionCount} transaction(s) · ${formatDateTime(closure.date)}'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _ValueRow(
                          label: 'TVA', value: formatEuro(closure.vatCents)),
                      const SizedBox(height: 10),
                      SelectableText(closure.hash,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

class _CustomerList extends StatefulWidget {
  const _CustomerList({required this.customers});
  final List<Customer> customers;

  @override
  State<_CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends State<_CustomerList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final customers = widget.customers
        .where((customer) =>
            query.isEmpty ||
            customer.displayName.toLowerCase().contains(query) ||
            (customer.phone ?? '').contains(query))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Rechercher un client…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Création client non exposée par l’API'),
            subtitle: Text(
                'GET /api/clients permet la consultation et la sélection en caisse. Aucune route POST n’existe dans le backend audité.'),
          ),
        ),
        ...customers.map(
          (customer) => Card(
            child: ListTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
              title: Text(customer.displayName),
              subtitle: customer.phone == null ? null : Text(customer.phone!),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionOrders extends StatelessWidget {
  const _SessionOrders({required this.receipts});
  final List<OrderReceipt> receipts;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Ventes de cette session mobile'),
              subtitle: Text(
                'Le backend ne publie pas encore GET /api/commandes ni une route d’annulation compensatoire. Une vente clôturée ne doit jamais être modifiée ou supprimée.',
              ),
            ),
          ),
          if (receipts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: Text('Aucune vente dans cette session.')),
            )
          else
            ...receipts.map(
              (receipt) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('Commande #${receipt.orderId}'),
                  subtitle: Text(
                      '${formatEuro(receipt.totalCents)} · ${receipt.status ?? 'Enregistrée'}'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ...receipt.lines.map(
                      (line) => _ValueRow(
                        label: '${line.quantity} × ${line.name}',
                        value: formatEuro(line.totalCents),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(receipt.hash,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 10)),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _FecExport extends StatefulWidget {
  const _FecExport({required this.admin});
  final AdminController admin;

  @override
  State<_FecExport> createState() => _FecExportState();
}

class _FecExportState extends State<_FecExport> {
  late final TextEditingController _year;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _year = TextEditingController(text: '${DateTime.now().year}');
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final year = int.tryParse(_year.text);
    if (year == null || year < 2000 || year > DateTime.now().year + 1) {
      showApiError(context, const ApiException('Année FEC invalide.'));
      return;
    }
    setState(() => _loading = true);
    try {
      final content = await widget.admin.exportFec(year);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Export FEC $year'),
          content: SizedBox(
            width: 700,
            height: 420,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: SelectableText(content,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FEC copié.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copier'),
            ),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer')),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Conformité & comptabilité',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text(
              'Le fichier contient uniquement les ventes clôturées. Faites-le valider par votre expert-comptable.'),
          const SizedBox(height: 16),
          TextField(
            controller: _year,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'Exercice',
                prefixIcon: Icon(Icons.calendar_month_rounded)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _export,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
            label: const Text('Générer et consulter le FEC'),
          ),
        ],
      );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      );
}
