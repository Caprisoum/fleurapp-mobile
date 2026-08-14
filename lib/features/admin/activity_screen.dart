import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../models/admin_models.dart';
import '../../models/order_history.dart';
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
                  if (receipt.cancellationCount > 0) ...[
                    const SizedBox(height: 8),
                    _ValueRow(
                      label: 'Annulations incluses',
                      value: '${receipt.cancellationCount}',
                    ),
                  ],
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
                        _CustomerList(admin: admin),
                        _OrderHistory(admin: admin),
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
                    subtitle: Text('${closure.transactionCount} transaction(s)'
                        '${closure.cancellationCount > 0 ? ' · ${closure.cancellationCount} annulation(s)' : ''}'
                        ' · ${formatDateTime(closure.date)}'),
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
  const _CustomerList({required this.admin});
  final AdminController admin;

  @override
  State<_CustomerList> createState() => _CustomerListState();
}

class _CustomerListState extends State<_CustomerList> {
  String _query = '';

  Future<void> _createCustomer() async {
    final draft = await showDialog<CustomerDraft>(
      context: context,
      builder: (_) => const _CustomerDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      final customer = await widget.admin.createCustomer(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${customer.displayName} a été ajouté.')),
      );
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final customers = widget.admin.customers
        .where((customer) =>
            query.isEmpty ||
            customer.displayName.toLowerCase().contains(query) ||
            (customer.phone ?? '').contains(query) ||
            (customer.email ?? '').toLowerCase().contains(query))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: widget.admin.busy ? null : _createCustomer,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Ajouter un client'),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: 'Rechercher un client…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        if (customers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: Text('Aucun client trouvé.')),
          ),
        ...customers.map(
          (customer) => Card(
            child: ExpansionTile(
              leading:
                  const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
              title: Text(customer.displayName),
              subtitle: Text(
                [customer.phone, customer.email]
                    .whereType<String>()
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (customer.allergies != null)
                  _ValueRow(label: 'Allergies', value: customer.allergies!),
                if (customer.preferences != null) ...[
                  const SizedBox(height: 8),
                  _ValueRow(label: 'Préférences', value: customer.preferences!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerDialog extends StatefulWidget {
  const _CustomerDialog();

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _allergies = TextEditingController();
  final _preferences = TextEditingController();

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _phone.dispose();
    _email.dispose();
    _allergies.dispose();
    _preferences.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      CustomerDraft(
        lastName: _lastName.text.trim(),
        firstName: _optional(_firstName),
        phone: _optional(_phone),
        email: _optional(_email),
        allergies: _optional(_allergies),
        preferences: _optional(_preferences),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nouveau client'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _lastName,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nom *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Le nom est obligatoire.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _allergies,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Allergies'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _preferences,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Préférences'),
                  ),
                ],
              ),
            ),
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

class _OrderHistory extends StatefulWidget {
  const _OrderHistory({required this.admin});
  final AdminController admin;

  @override
  State<_OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<_OrderHistory> {
  int? _loadingOrderId;
  final Map<int, ({String key, String reason})> _pendingCancellations = {};

  String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> _openOrder(OrderSummary order) async {
    setState(() => _loadingOrderId = order.id);
    try {
      final detail = await widget.admin.fetchOrderDetail(order.id);
      if (!mounted) return;
      setState(() => _loadingOrderId = null);
      final cancelRequested = await showDialog<bool>(
        context: context,
        builder: (_) => _OrderDetailDialog(detail: detail),
      );
      if (cancelRequested == true && mounted) {
        await _cancelOrder(detail.summary);
      }
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _loadingOrderId = null);
    }
  }

  Future<String?> _askCancellationReason(OrderSummary order) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _CancellationReasonDialog(orderId: order.id),
    );
  }

  Future<void> _cancelOrder(OrderSummary order) async {
    var pending = _pendingCancellations[order.id];
    if (pending == null) {
      final reason = await _askCancellationReason(order);
      if (reason == null || !mounted) return;
      pending = (key: _newIdempotencyKey(), reason: reason);
      _pendingCancellations[order.id] = pending;
    }
    setState(() => _loadingOrderId = order.id);
    try {
      final receipt = await widget.admin.cancelOrder(
        orderId: order.id,
        reason: pending.reason,
        idempotencyKey: pending.key,
      );
      _pendingCancellations.remove(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Annulation #${receipt.id} enregistrée · ${formatEuro(receipt.refundedCents)} remboursés · stock réintégré.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!error.outcomeUnknown) _pendingCancellations.remove(order.id);
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _loadingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.admin.orders;
    return RefreshIndicator(
      onRefresh: widget.admin.refreshActivity,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: Text('Aucune commande enregistrée.')),
            )
          else
            ...orders.map(
              (order) => Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: CircleAvatar(child: Text('#${order.id}')),
                  title: Text(
                    order.isCancelled
                        ? '${formatEuro(order.totalCents)} · ANNULÉE'
                        : formatEuro(order.totalCents),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: order.isCancelled
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    [
                      order.customerName ?? 'Client de passage',
                      order.status,
                      order.deliveryAt == null
                          ? formatDateTime(order.createdAt)
                          : 'Prévue ${formatDateTime(order.deliveryAt)}',
                    ].join(' · '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _loadingOrderId == order.id
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap:
                      _loadingOrderId == null ? () => _openOrder(order) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CancellationReasonDialog extends StatefulWidget {
  const _CancellationReasonDialog({required this.orderId});

  final int orderId;

  @override
  State<_CancellationReasonDialog> createState() =>
      _CancellationReasonDialogState();
}

class _CancellationReasonDialogState extends State<_CancellationReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 3) {
      setState(() => _error = 'Saisissez au moins 3 caractères.');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Annuler la commande #${widget.orderId} ?'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cette opération crée une écriture compensatoire définitive et réintègre le stock. La vente d’origine reste inchangée.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Motif obligatoire',
                    hintText: 'Ex. erreur de saisie ou vente abandonnée',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Conserver la vente'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _submit,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Créer l’annulation'),
          ),
        ],
      );
}

class _OrderDetailDialog extends StatelessWidget {
  const _OrderDetailDialog({required this.detail});
  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final order = detail.summary;
    return AlertDialog(
      title: Text('Commande #${order.id}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ValueRow(label: 'Statut', value: order.status),
              if (order.isCancelled) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Annulation #${order.cancellationId}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ValueRow(
                          label: 'Remboursement',
                          value: formatEuro(order.refundedCents ?? 0),
                        ),
                        const SizedBox(height: 6),
                        Text(order.cancellationReason ?? 'Motif non renseigné'),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _ValueRow(
                  label: 'Client',
                  value: order.customerName ?? 'Client de passage'),
              if (order.deliveryAt != null) ...[
                const SizedBox(height: 8),
                _ValueRow(
                    label: 'Préparation/livraison',
                    value: formatDateTime(order.deliveryAt)),
              ],
              const Divider(height: 28),
              ...detail.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ValueRow(
                    label: '${line.quantity} × ${line.name}',
                    value: formatEuro(line.totalCents),
                  ),
                ),
              ),
              const Divider(height: 28),
              _ValueRow(label: 'Total', value: formatEuro(order.totalCents)),
              const SizedBox(height: 8),
              _ValueRow(
                  label: 'Acompte', value: formatEuro(order.depositCents)),
              if (order.remainingCents > 0) ...[
                const SizedBox(height: 8),
                _ValueRow(
                    label: 'Reste à payer',
                    value: formatEuro(order.remainingCents)),
              ],
              const SizedBox(height: 8),
              _ValueRow(label: 'Paiement', value: order.paymentMethod),
              const SizedBox(height: 8),
              _ValueRow(
                label: 'Clôture Z',
                value: order.closureId == null
                    ? 'Non clôturée'
                    : '#${order.closureId}',
              ),
              const Divider(height: 28),
              const Text('Empreinte',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SelectableText(
                order.hash,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (order.canCancel)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Annuler la vente'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
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
