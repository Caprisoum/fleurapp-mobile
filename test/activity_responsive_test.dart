import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/models/bug_report.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';

import '../integration_test/support/fake_fleur_backend.dart';

void main() {
  testWidgets('activité, bugs et alertes sans overflow sur le Poco F7',
      (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = FakeFleurBackend();
    final controller = AppController(
      apiClient: RenderApiClient(
        baseUrl: 'https://fleurapp-qa.invalid',
        httpClient: backend.client,
      ),
      settingsStore: MemorySettingsStore(),
      tokenStore: MemoryTokenStore('test-jwt'),
      alertScheduler: FakeAlertScheduler(),
      deviceMetadataService: const FakeDeviceMetadataService(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.assessment_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Clôturer la caisse'), findsOneWidget);

    await tester.tap(find.text('Clôturer la caisse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clôturer'));
    await tester.pumpAndSettle();
    expect(find.text('Ticket Z #8'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clients'));
    await tester.pumpAndSettle();
    expect(find.text('Martin Alice'), findsOneWidget);

    await tester.drag(find.byType(TabBar), const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FEC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Générer et consulter le FEC'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('JournalCode'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bugs'));
    await tester.pumpAndSettle();
    expect(find.text('Contraste du catalogue'), findsOneWidget);
    final bugStatus = find.byType(DropdownButtonFormField<BugReportStatus>);
    await tester.ensureVisible(bugStatus);
    await tester.tap(bugStatus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Résolu').last);
    await tester.pumpAndSettle();
    expect(backend.bugs.first['statut'], 'RESOLU');

    await tester.tap(find.byTooltip('Alertes à venir'));
    await tester.pumpAndSettle();
    expect(find.text('Arrivage à venir — Rose rouge'), findsOneWidget);
    expect(find.text('Commande Alice Martin'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(find.text('Composant BOM insuffisant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
