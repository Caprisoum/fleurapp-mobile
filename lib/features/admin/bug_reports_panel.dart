import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/bug_report.dart';
import '../../services/api_exception.dart';
import '../../state/app_controller.dart';
import '../bugs/bug_report_sheet.dart';
import '../shared/async_state_widgets.dart';

class BugReportsPanel extends StatefulWidget {
  const BugReportsPanel({required this.appController, super.key});

  final AppController appController;

  @override
  State<BugReportsPanel> createState() => _BugReportsPanelState();
}

class _BugReportsPanelState extends State<BugReportsPanel> {
  BugReportStatus? _filter;

  Future<void> _refresh() async {
    try {
      await widget.appController.admin.refreshBugReports();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.appController.handleUnauthorized();
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _update(
    BugReport report,
    BugReportStatus status,
  ) async {
    try {
      await widget.appController.admin.updateBugReportStatus(report, status);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Rapport #${report.id} : ${status.label}.'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await widget.appController.handleUnauthorized();
      }
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.appController.admin;
    final reports = admin.bugReports
        .where((report) => _filter == null || report.status == _filter)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rapports de bugs',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Actualiser',
                onPressed: admin.busy ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Consultez les signalements Web et mobile, puis suivez leur résolution.',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<BugReportStatus?>(
            initialValue: _filter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filtrer par statut',
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            items: [
              const DropdownMenuItem<BugReportStatus?>(
                value: null,
                child: Text('Tous les statuts'),
              ),
              ...BugReportStatus.values.map(
                (status) => DropdownMenuItem<BugReportStatus?>(
                  value: status,
                  child: Text(status.label),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => BugReportSheet.show(context, widget.appController),
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Signaler un problème'),
          ),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.task_alt_rounded, size: 42),
                    SizedBox(height: 10),
                    Text('Aucun rapport pour ce filtre.'),
                  ],
                ),
              ),
            )
          else
            ...reports.map(
              (report) => _BugReportCard(
                report: report,
                busy: admin.busy,
                onStatusChanged: (status) => _update(report, status),
              ),
            ),
        ],
      ),
    );
  }
}

class _BugReportCard extends StatelessWidget {
  const _BugReportCard({
    required this.report,
    required this.busy,
    required this.onStatusChanged,
  });

  final BugReport report;
  final bool busy;
  final ValueChanged<BugReportStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (report.status) {
      BugReportStatus.newReport => colors.errorContainer,
      BugReportStatus.inProgress => colors.tertiaryContainer,
      BugReportStatus.resolved => colors.primaryContainer,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Text(
                  '${report.category} · #${report.id}',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Chip(
                  label: Text(report.status.label),
                  backgroundColor: statusColor,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              report.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            SelectableText(report.description),
            const Divider(height: 26),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Meta(icon: Icons.phone_android, value: report.deviceModel),
                _Meta(icon: Icons.memory_rounded, value: report.deviceOs),
                _Meta(
                    icon: Icons.info_outline_rounded,
                    value: 'v${report.appVersion}'),
                _Meta(
                    icon: Icons.schedule_rounded,
                    value: formatDateTime(report.createdAt.toLocal())),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<BugReportStatus>(
              key: ValueKey('${report.id}-${report.status.name}'),
              initialValue: report.status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Statut du rapport'),
              items: BugReportStatus.values
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ))
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null && value != report.status) {
                        onStatusChanged(value);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}
