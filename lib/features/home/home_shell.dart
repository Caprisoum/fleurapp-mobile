import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_controller.dart';
import '../admin/activity_screen.dart';
import '../admin/catalog_admin_screen.dart';
import '../admin/stock_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pos/pos_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/admin_gate.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.appController, super.key});
  final AppController appController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appController.refreshUpcomingAlerts();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.appController.refreshUpcomingAlerts();
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AdminGate(
        appController: widget.appController,
        child: NotificationsScreen(appController: widget.appController),
      ),
    ));
  }

  static const _destinations = [
    _Destination(
        'Caisse', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
    _Destination(
        'Catalogue', Icons.local_florist_outlined, Icons.local_florist_rounded),
    _Destination(
        'Stocks', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    _Destination(
        'Activité', Icons.assessment_outlined, Icons.assessment_rounded),
    _Destination('Réglages', Icons.settings_outlined, Icons.settings_rounded),
  ];

  Widget _page() => switch (_index) {
        0 => PosScreen(appController: widget.appController),
        1 => AdminGate(
            appController: widget.appController,
            child: CatalogAdminScreen(appController: widget.appController),
          ),
        2 => AdminGate(
            appController: widget.appController,
            child: StockScreen(appController: widget.appController),
          ),
        3 => AdminGate(
            appController: widget.appController,
            child: ActivityScreen(appController: widget.appController),
          ),
        _ => SettingsScreen(appController: widget.appController),
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final duration = MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280);
          final content = AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(.025, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_index), child: _page()),
          );
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 68,
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BrandMark(),
                  SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FleurApp',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      Text('CAISSE MOBILE',
                          style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              actions: [
                AnimatedBuilder(
                  animation: widget.appController.upcomingAlerts,
                  builder: (context, _) {
                    final count =
                        widget.appController.upcomingAlerts.alertCount;
                    return IconButton(
                      tooltip: 'Alertes à venir',
                      onPressed: _openNotifications,
                      icon: Badge(
                        isLabelVisible: count > 0,
                        label: Text(count > 99 ? '99+' : '$count'),
                        child: const Icon(Icons.notifications_outlined),
                      ),
                    );
                  },
                ),
                Tooltip(
                  message: widget.appController.adminAuthenticated
                      ? 'Administrateur connecté'
                      : 'Mode caisse',
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      widget.appController.adminAuthenticated
                          ? Icons.verified_user_rounded
                          : Icons.lock_outline_rounded,
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: wide
                  ? Row(
                      children: [
                        NavigationRail(
                          selectedIndex: _index,
                          labelType: NavigationRailLabelType.all,
                          onDestinationSelected: (value) =>
                              setState(() => _index = value),
                          destinations: _destinations
                              .map((destination) => NavigationRailDestination(
                                    icon: Icon(destination.icon),
                                    selectedIcon:
                                        Icon(destination.selectedIcon),
                                    label: Text(destination.label),
                                  ))
                              .toList(),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: content),
                      ],
                    )
                  : content,
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    destinations: _destinations
                        .map((destination) => NavigationDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.selectedIcon),
                              label: destination.label,
                            ))
                        .toList(),
                  ),
          );
        },
      );
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.forest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.local_florist_rounded, color: Colors.white),
      );
}
