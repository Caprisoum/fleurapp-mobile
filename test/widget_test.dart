import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleurapp_mobile/app.dart';
import 'package:fleurapp_mobile/services/admin_token_store.dart';
import 'package:fleurapp_mobile/services/fleur_api_client.dart';
import 'package:fleurapp_mobile/services/local_settings_store.dart';
import 'package:fleurapp_mobile/state/app_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('affiche le catalogue et ajoute un produit au panier',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async => http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'Bouquet champêtre',
                'price_ttc': '25.00',
                'vat_rate': '20.00',
                'category_name': 'Bouquets',
                'stock_actuel': 4,
              }
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: const _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(
      controller.pos.products,
      isNotEmpty,
      reason: controller.pos.catalogError,
    );
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Bouquet champêtre'), findsOneWidget);
    await tester.tap(find.text('Bouquet champêtre'));
    await tester.pump();
    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();

    expect(find.text('Commande en cours'), findsOneWidget);
    expect(find.text('25,00\u00a0€'), findsAtLeastNWidgets(2));
    expect(find.text('Encaisser'), findsOneWidget);
  });

  testWidgets('catalogue lisible sans actions superposées en mode sombre',
      (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async => http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'Rose rouge',
                'price_ttc': '4.00',
                'vat_rate': '20.00',
                'category_name': 'Sans catégorie',
                'stock_actuel': 4,
              },
              {
                'id': 2,
                'name': 'Bouquet surprise',
                'price_ttc': '100.00',
                'vat_rate': '20.00',
                'category_name': 'Sans catégorie',
                'stock_actuel': 2,
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: const _MemorySettingsStore(ThemeMode.dark),
      tokenStore: _MemoryTokenStore('jwt-test'),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    final productCount = tester.widget<Text>(find.text('2 produits'));
    final countContext = tester.element(find.text('2 produits'));
    expect(
      productCount.style?.color,
      Theme.of(countContext).colorScheme.onSurfaceVariant,
    );
    expect(find.byIcon(Icons.add_shopping_cart_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.more_horiz_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.add_circle_rounded), findsNothing);
    expect(
      tester.getCenter(find.byIcon(Icons.more_horiz_rounded).first).dy,
      lessThan(
        tester.getCenter(find.byIcon(Icons.add_shopping_cart_rounded).first).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sélecteur de thème compact et adaptatif en clair et sombre',
      (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async => http.Response(
            jsonEncode(<Object>[]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: const _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('theme-mode-selector')));
    await tester.pumpAndSettle();

    final systemLabel = tester.widget<Text>(find.text('Système'));
    expect(systemLabel.maxLines, 1);
    expect(systemLabel.softWrap, isFalse);

    final lightSelector = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(const Key('theme-mode-selector')),
    );
    final lightContext =
        tester.element(find.byKey(const Key('theme-mode-selector')));
    final lightColors = Theme.of(lightContext).colorScheme;
    expect(
      lightSelector.style?.backgroundColor?.resolve({WidgetState.selected}),
      lightColors.primaryContainer,
    );
    expect(
      lightSelector.style?.backgroundColor?.resolve({}),
      lightColors.surfaceContainerHighest,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    final darkSelector = tester.widget<SegmentedButton<ThemeMode>>(
      find.byKey(const Key('theme-mode-selector')),
    );
    final darkContext =
        tester.element(find.byKey(const Key('theme-mode-selector')));
    final darkTheme = Theme.of(darkContext);
    expect(controller.themeMode, ThemeMode.dark);
    expect(darkTheme.brightness, Brightness.dark);
    expect(
      darkSelector.style?.backgroundColor?.resolve({WidgetState.selected}),
      darkTheme.colorScheme.primaryContainer,
    );
    expect(
      darkSelector.style?.foregroundColor?.resolve({}),
      darkTheme.colorScheme.onSurfaceVariant,
    );
    expect(
      darkTheme.colorScheme.primaryContainer,
      isNot(lightColors.primaryContainer),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigue sans overflow sur les modules Poco F7', (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async {
        final Object payload = switch (request.url.path) {
          '/api/produits' => [
              {
                'id': 1,
                'name': 'Rose rouge',
                'price_ttc': '4.50',
                'base_price_ttc': '4.50',
                'vat_rate': '20.00',
                'category_name': 'Fleurs',
                'stock_actuel': 12,
              }
            ],
          '/api/notifications/a-venir' => {
              'generatedAt': '2026-08-08T08:00:00.000Z',
              'window': {
                'to': '2026-08-10T08:00:00.000Z',
                'timeZone': 'Europe/Paris',
              },
              'summary': {
                'total': 1,
                'arrivals': 1,
                'orders': 0,
                'bomAlerts': 0,
                'critical': 0,
              },
              'notifications': [
                {
                  'id': 'arrival:1:2026-08-09T06:00:00.000Z',
                  'type': 'arrival',
                  'severity': 'info',
                  'title': 'Arrivage à venir — Rose rouge',
                  'message': 'Arrivage prévu demain.',
                  'eventAt': '2026-08-09T06:00:00.000Z',
                  'remindAt': '2026-08-08T06:00:00.000Z',
                  'hoursUntil': 22,
                  'data': {'productId': 1},
                }
              ],
            },
          _ => <Object>[],
        };
        return http.Response(
          jsonEncode(payload),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: const _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore('jwt-test'),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.local_florist_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Gestion du catalogue'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Stocks'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.assessment_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Clôtures'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Bugs'));
    await tester.tap(find.text('Bugs'));
    await tester.pumpAndSettle();
    expect(find.text('Rapports de bugs'), findsOneWidget);
    expect(find.text('Filtrer par statut'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Serveur Render'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.notifications_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Alertes à venir'), findsOneWidget);
    expect(find.text('Arrivage à venir — Rose rouge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signale un problème depuis les réglages sur format Poco F7',
      (tester) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    http.Request? bugRequest;
    final api = RenderApiClient(
      baseUrl: '',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/bugs') {
          bugRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'bug': {
                'id': 31,
                'titre': 'Bouton panier bloqué',
                'description':
                    'Le bouton ne répond plus après plusieurs appuis.',
                'categorie': 'Autre',
                'appareil_info': {
                  'os': 'Système inconnu',
                  'modele': 'Appareil inconnu',
                },
                'version_app': 'inconnue',
                'statut': 'NOUVEAU',
                'created_at': '2026-08-08T20:00:00.000Z',
              },
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode(<Object>[]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final controller = AppController(
      apiClient: api,
      settingsStore: const _MemorySettingsStore(),
      tokenStore: _MemoryTokenStore(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(FleurApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Signaler un problème'));
    await tester.pumpAndSettle();
    expect(find.text('Signaler un problème'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ex. Impossible de valider le panier'),
      'Bouton panier bloqué',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField,
          'Étapes réalisées, résultat attendu et message affiché…'),
      'Le bouton ne répond plus après plusieurs appuis.',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Envoyer le rapport'));
    await tester.tap(find.text('Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(bugRequest?.url.path, '/api/bugs');
    expect(find.text('Rapport #31 envoyé. Merci !'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemorySettingsStore implements LocalSettingsStore {
  const _MemorySettingsStore([this.themeMode = ThemeMode.light]);

  final ThemeMode themeMode;

  @override
  Future<LocalSettings> read() async => LocalSettings(
        apiBaseUrl: 'https://fleurapp-test.onrender.com',
        themeMode: themeMode,
      );

  @override
  Future<void> writeApiBaseUrl(String value) async {}

  @override
  Future<void> writeThemeMode(ThemeMode value) async {}
}

class _MemoryTokenStore implements AdminTokenStore {
  _MemoryTokenStore([this.token]);
  String? token;

  @override
  Future<void> delete() async => token = null;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}
