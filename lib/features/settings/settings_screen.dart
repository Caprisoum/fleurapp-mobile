import 'package:flutter/material.dart';

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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Serveur Render',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                      'URL HTTPS sans suffixe /api. Elle est enregistrée uniquement sur cet appareil.'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'URL de l’API',
                      hintText: 'https://votre-service.onrender.com',
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
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Système')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Clair')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Sombre')),
                    ],
                    selected: {widget.appController.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        widget.appController.setThemeMode(value.single),
                  ),
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
