import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_exception.dart';
import '../../state/admin_controller.dart';
import '../../state/app_controller.dart';
import '../bugs/bug_report_sheet.dart';

class AdminGate extends StatefulWidget {
  const AdminGate(
      {required this.appController, required this.child, super.key});

  final AppController appController;
  final Widget child;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _pinController = TextEditingController();
  String? _error;
  bool _requestedLoad = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _error = null);
    try {
      await widget.appController.login(_pinController.text);
      _pinController.clear();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connexion administrateur impossible.');
      }
    }
  }

  void _loadRestoredSession() {
    if (_requestedLoad ||
        widget.appController.admin.status != AdminStatus.initial) {
      return;
    }
    _requestedLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.appController.admin.loadAll();
      } on ApiException catch (error) {
        if (error.isUnauthorized) {
          await widget.appController.handleUnauthorized();
        }
      } catch (_) {
        // L’écran d’erreur de l’AdminController propose une nouvelle tentative.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.appController.adminAuthenticated) {
      _loadRestoredSession();
      return widget.child;
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        size: 34),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Accès administrateur',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le catalogue, les stocks et les clôtures nécessitent le PIN sécurisé par le serveur.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pinController,
                    autofocus: true,
                    obscureText: true,
                    obscuringCharacter: '●',
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 12),
                    onSubmitted: (_) => _login(),
                    decoration: const InputDecoration(
                      labelText: 'Code PIN à 4 chiffres',
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.appController.authBusy ? null : _login,
                    icon: widget.appController.authBusy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: const Text('Se connecter'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => BugReportSheet.show(
                      context,
                      widget.appController,
                    ),
                    icon: const Icon(Icons.bug_report_outlined),
                    label: const Text('Signaler un problème'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
