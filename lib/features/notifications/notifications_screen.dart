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
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

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
            ? 'Rappels J-1 et jour J activés.'
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
                    'Alertes des prochaines 48 heures',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (controller.imminentAlerts.isEmpty)
                    const _EmptyAlerts()
                  else
                    ...controller.imminentAlerts.map((alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AlertCard(alert: alert),
                        )),
                  const SizedBox(height: 14),
                  _ArrivalCalendar(
                    month: _visibleMonth,
                    selectedDay: _selectedDay,
                    arrivals: controller.arrivalAlerts,
                    windowEnd: controller.payload?.windowEnd,
                    onDaySelected: (day) => setState(() {
                      _selectedDay = day;
                    }),
                    onMonthChanged: (month) => setState(() {
                      _visibleMonth = month;
                      _selectedDay = DateTime(month.year, month.month, 1);
                    }),
                  ),
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
                      enabled
                          ? 'Rappels J-1 et jour J actifs'
                          : 'Rappels à activer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(enabled
                        ? '$scheduledCount rappel(s) programmé(s) avec son et vibration.'
                        : 'Autorisez FleurApp à vous prévenir la veille et le jour des arrivages.'),
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
              '${summary.total} événement(s) sur 42 jours',
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
                    '${_relativeTime(alert)} · ${formatDateTime(alert.eventAt)}',
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

  String _relativeTime(UpcomingAlert alert) {
    final event = alert.eventAt.toLocal();
    final now = DateTime.now();
    if (event.year == now.year &&
        event.month == now.month &&
        event.day == now.day) {
      return 'Aujourd’hui';
    }
    final hours = alert.hoursUntil;
    if (hours <= 1) return 'Dans moins d’une heure';
    if (hours < 24) return 'Dans $hours h';
    final days = (hours / 24).ceil();
    return 'Dans $days jour${days > 1 ? 's' : ''}';
  }
}

class _ArrivalCalendar extends StatelessWidget {
  const _ArrivalCalendar({
    required this.month,
    required this.selectedDay,
    required this.arrivals,
    required this.windowEnd,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<UpcomingAlert> arrivals;
  final DateTime? windowEnd;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  List<UpcomingAlert> _forDay(DateTime day) => arrivals
      .where((alert) => _sameDay(alert.eventAt.toLocal(), day))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leading = firstDay.weekday - 1;
    final cellCount = ((leading + lastDay.day + 6) ~/ 7) * 7;
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final canGoBack = month.isAfter(currentMonth);
    final canGoNext = windowEnd == null ||
        !nextMonth.isAfter(
          DateTime(windowEnd!.toLocal().year, windowEnd!.toLocal().month),
        );
    final selectedArrivals = _forDay(selectedDay);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: colors.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Calendrier des arrivages',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Touchez une date pour voir les fleurs attendues.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  onPressed: canGoBack
                      ? () => onMonthChanged(
                            DateTime(month.year, month.month - 1),
                          )
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_months[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  onPressed: canGoNext ? () => onMonthChanged(nextMonth) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              children: [
                for (final label in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: .86,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leading + 1;
                if (dayNumber < 1 || dayNumber > lastDay.day) {
                  return const SizedBox.shrink();
                }
                final day = DateTime(month.year, month.month, dayNumber);
                final count = _forDay(day).length;
                final selected = _sameDay(day, selectedDay);
                final today = _sameDay(day, DateTime.now());
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '$dayNumber ${_months[month.month - 1]}, '
                      '$count arrivage${count > 1 ? 's' : ''}',
                  child: InkWell(
                    key: ValueKey(
                      'arrival-day-${day.year}-${day.month}-${day.day}',
                    ),
                    onTap: () => onDaySelected(day),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : today
                                  ? colors.primary
                                  : colors.outlineVariant,
                          width: today && !selected ? 1.5 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: selected ? colors.onPrimary : null,
                              fontWeight: selected || today
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (count > 0)
                            Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colors.onPrimary
                                    : colors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected
                                      ? colors.primary
                                      : colors.onPrimaryContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              'Arrivages du ${selectedDay.day.toString().padLeft(2, '0')}/'
              '${selectedDay.month.toString().padLeft(2, '0')}/${selectedDay.year}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            if (selectedArrivals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Aucun arrivage prévu ce jour.'),
              )
            else
              ...selectedArrivals.map((alert) {
                final productName =
                    '${alert.data['productName'] ?? alert.title.split('—').last.trim()}';
                final stock = alert.data['stock'];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  minVerticalPadding: 10,
                  leading: CircleAvatar(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: const Icon(Icons.local_shipping_rounded),
                  ),
                  title: Text(
                    productName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(stock == null
                      ? 'Arrivage programmé'
                      : 'Stock actuel : $stock'),
                );
              }),
          ],
        ),
      ),
    );
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
