import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../services/api_exception.dart';
import '../../state/app_controller.dart';
import '../bugs/bug_report_sheet.dart';
import '../shared/async_state_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.appController, super.key});
  final AppController appController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.appController.apiBaseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await widget.appController.checkHealth(_url.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Backend joignable et base PostgreSQL disponible.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final changed = _url.text.trim().replaceAll(RegExp(r'/+$'), '') !=
        widget.appController.apiBaseUrl;
    if (changed && widget.appController.adminAuthenticated) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Changer de serveur ?'),
              content: const Text(
                'Le jeton administrateur actuel sera supprimé, car il ne doit jamais être réutilisé sur une autre API.',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Changer')),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }
    setState(() => _saving = true);
    try {
      await widget.appController.updateApiBaseUrl(_url.text);
      _url.text = widget.appController.apiBaseUrl;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse API enregistrée.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _activateCheckoutDevice() async {
    try {
      await widget.appController.activateCheckoutDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Téléphone activé pour les encaissements.'),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _deactivateCheckoutDevice() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Désactiver cette caisse ?'),
            content: const Text(
              'Ce téléphone ne pourra plus enregistrer de vente avant une nouvelle activation administrateur.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Désactiver'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await widget.appController.deactivateCheckoutDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caisse désactivée.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          Text('Réglages',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (AppConfig.allowServerConfiguration) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Serveur de recette',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text(
                        'Réglage technique réservé aux builds QA. URL HTTPS sans suffixe /api.'),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'URL de l’API',
                        hintText: 'https://backend-qa.example.com',
                        prefixIcon: Icon(Icons.cloud_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _testing ? null : _test,
                          icon: const Icon(Icons.monitor_heart_outlined),
                          label: Text(_testing ? 'Test…' : 'Tester'),
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label:
                              Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Signaler un problème'),
              subtitle: const Text(
                'Envoyez un rapport avec la version et le modèle de cet appareil.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => BugReportSheet.show(context, widget.appController),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Apparence',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _ThemeModeSelector(appController: widget.appController),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              leading: Icon(widget.appController.adminAuthenticated
                  ? Icons.verified_user_rounded
                  : Icons.admin_panel_settings_outlined),
              title: Text(widget.appController.adminAuthenticated
                  ? 'Session administrateur active'
                  : 'Session administrateur inactive'),
              subtitle: const Text(
                  'Le JWT est conservé dans le stockage sécurisé Android/iOS, jamais dans les préférences ordinaires.'),
              trailing: widget.appController.adminAuthenticated
                  ? OutlinedButton(
                      onPressed: widget.appController.logout,
                      child: const Text('Déconnexion'))
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            key: const Key('checkout-device-card'),
            child: ListTile(
              minVerticalPadding: 14,
              leading: Icon(
                widget.appController.checkoutDeviceActive
                    ? Icons.point_of_sale_rounded
                    : Icons.phonelink_lock_rounded,
              ),
              title: Text(
                widget.appController.checkoutDeviceActive
                    ? 'Caisse activée'
                    : 'Caisse à activer',
              ),
              subtitle: Text(
                widget.appController.checkoutDeviceActive
                    ? 'Ce téléphone possède une identité révocable stockée de façon sécurisée.'
                    : widget.appController.adminAuthenticated
                        ? 'Activez ce téléphone avant de rendre l’authentification des ventes obligatoire.'
                        : 'Connectez-vous d’abord comme administrateur pour autoriser ce téléphone.',
              ),
              trailing: widget.appController.checkoutDeviceBusy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : widget.appController.checkoutDeviceActive
                      ? OutlinedButton(
                          onPressed: _deactivateCheckoutDevice,
                          child: const Text('Désactiver'),
                        )
                      : FilledButton(
                          onPressed: _activateCheckoutDevice,
                          child: const Text('Activer'),
                        ),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Extensions matérielles',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.contactless_rounded),
                      title: Text('Stripe Tap to Pay / NFC'),
                      subtitle: Text(
                          'Port applicatif prêt, SDK et routes Terminal à connecter.')),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bluetooth_rounded),
                      title: Text('Imprimante / TPE Bluetooth'),
                      subtitle: Text(
                          'Découverte, connexion et impression isolées dans integrations/.')),
                ],
              ),
            ),
          ),
        ],
      );
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.appController});

  final AppController appController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SegmentedButton<ThemeMode>(
      key: const Key('theme-mode-selector'),
      expandedInsets: EdgeInsets.zero,
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_rounded, size: 18),
          label: Text('Système', maxLines: 1, softWrap: false),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 18),
          label: Text('Clair', maxLines: 1, softWrap: false),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 18),
          label: Text('Sombre', maxLines: 1, softWrap: false),
        ),
      ],
      selected: {appController.themeMode},
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimaryContainer
              : colors.onSurfaceVariant,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.outlineVariant,
          ),
        ),
      ),
      onSelectionChanged: (value) => appController.setThemeMode(value.single),
    );
  }
}
