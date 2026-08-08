import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/upcoming_alert.dart';
import '../../services/api_exception.dart';
import '../../state/app_controller.dart';
import '../../state/upcoming_alerts_controller.dart';
import '../shared/async_state_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.appController, super.key});

  final AppController appController;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.appController.adminAuthenticated &&
          widget.appController.upcomingAlerts.status ==
              UpcomingAlertsStatus.initial) {
        _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    try {
      await widget.appController.refreshUpcomingAlerts(silent: false);
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } catch (_) {
      if (mounted) {
        showApiError(
          context,
          const ApiException('Impossible d’actualiser les alertes.'),
        );
      }
    }
  }

  Future<void> _enableReminders() async {
    try {
      final enabled =
          await widget.appController.upcomingAlerts.enableReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enabled
            ? 'Rappels sonores J-1 activés.'
            : 'Autorisation refusée. Activez les notifications dans Android.'),
      ));
    } catch (_) {
      if (mounted) {
        showApiError(
          context,
          const ApiException('Impossible d’activer les rappels locaux.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Alertes à venir'),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: widget.appController.upcomingAlerts,
          builder: (context, _) {
            final controller = widget.appController.upcomingAlerts;
            if (controller.status == UpcomingAlertsStatus.loading &&
                controller.payload == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _ReminderStatusCard(
                    enabled: controller.remindersEnabled,
                    scheduledCount: controller.scheduledCount,
                    onEnable: _enableReminders,
                  ),
                  const SizedBox(height: 14),
                  if (controller.payload != null)
                    _SummaryCard(payload: controller.payload!),
                  if (controller.error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorCard(message: controller.error!, onRetry: _refresh),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Prochaines 48 heures',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (controller.alerts.isEmpty)
                    const _EmptyAlerts()
                  else
                    ...controller.alerts.map((alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AlertCard(alert: alert),
                        )),
                ],
              ),
            );
          },
        ),
      );
}

class _ReminderStatusCard extends StatelessWidget {
  const _ReminderStatusCard({
    required this.enabled,
    required this.scheduledCount,
    required this.onEnable,
  });

  final bool enabled;
  final int scheduledCount;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) => Card(
        color: enabled
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enabled ? 'Rappels J-1 actifs' : 'Rappels à activer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(enabled
                        ? '$scheduledCount rappel(s) programmé(s) avec son et vibration.'
                        : 'Autorisez FleurApp à vous prévenir un jour avant.'),
                    if (!enabled) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: onEnable,
                        icon: const Icon(Icons.notifications_rounded),
                        label: const Text('Activer les rappels'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.payload});

  final UpcomingAlertsPayload payload;

  @override
  Widget build(BuildContext context) {
    final summary = payload.summary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${summary.total} alerte(s)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(
                  icon: Icons.local_shipping_outlined,
                  label: '${summary.arrivals} arrivage(s)',
                ),
                _CountChip(
                  icon: Icons.shopping_bag_outlined,
                  label: '${summary.orders} commande(s)',
                ),
                _CountChip(
                  icon: Icons.account_tree_outlined,
                  label: '${summary.bomAlerts} BOM',
                ),
                if (summary.critical > 0)
                  _CountChip(
                    icon: Icons.error_outline_rounded,
                    label: '${summary.critical} critique(s)',
                    critical: true,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Synchronisé le ${formatDateTime(payload.generatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    this.critical = false,
  });

  final IconData icon;
  final String label;
  final bool critical;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(
          icon,
          size: 18,
          color: critical ? Theme.of(context).colorScheme.error : null,
        ),
        label: Text(label),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final UpcomingAlert alert;

  IconData get _icon => switch (alert.type) {
        UpcomingAlertType.arrival => Icons.local_shipping_rounded,
        UpcomingAlertType.order => Icons.shopping_bag_rounded,
        UpcomingAlertType.bom => Icons.account_tree_rounded,
        UpcomingAlertType.unknown => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (alert.severity) {
      UpcomingAlertSeverity.critical => colors.error,
      UpcomingAlertSeverity.warning => Colors.orange.shade700,
      UpcomingAlertSeverity.info => colors.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(alert.message),
                  const SizedBox(height: 8),
                  Text(
                    '${_relativeTime(alert.hoursUntil)} · ${formatDateTime(alert.eventAt)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
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

  String _relativeTime(int hours) {
    if (hours <= 1) return 'Dans moins d’une heure';
    if (hours < 24) return 'Dans $hours h';
    final days = (hours / 24).ceil();
    return 'Dans $days jour${days > 1 ? 's' : ''}';
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          minVerticalPadding: 12,
          leading: const Icon(Icons.cloud_off_rounded),
          title: Text(message),
          trailing: IconButton(
            tooltip: 'Réessayer',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      );
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 46,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Rien d’imminent',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Aucun arrivage, commande différée ou besoin BOM dans les prochaines 48 heures.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
