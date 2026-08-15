import 'package:flutter/material.dart';

import '../../models/bug_report.dart';
import '../../services/api_exception.dart';
import '../../state/app_controller.dart';

class BugReportSheet extends StatefulWidget {
  const BugReportSheet({required this.appController, super.key});

  final AppController appController;

  static Future<void> show(
    BuildContext context,
    AppController appController,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => BugReportSheet(appController: appController),
      );

  @override
  State<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<BugReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  BugCategory _category = BugCategory.other;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _validateText(
    String? value, {
    required String name,
    required int min,
  }) {
    final text = value?.trim() ?? '';
    if (text.length < min) return '$name : $min caractères minimum.';
    if (RegExp(r'[<>\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]')
        .hasMatch(text)) {
      return '$name contient un caractère non autorisé.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await widget.appController.submitBugReport(
        title: _title.text.trim(),
        description: _description.text.trim(),
        category: _category,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Rapport #${report.id} envoyé. Merci !'),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Connexion au serveur impossible. Vérifiez le réseau puis réessayez.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Signaler un problème',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Décrivez ce qui s’est passé. La version de FleurApp, le système et le modèle de l’appareil seront ajoutés automatiquement.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      _validateText(value, name: 'Titre', min: 5),
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    hintText: 'Ex. Impossible de valider le panier',
                    prefixIcon: Icon(Icons.short_text_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BugCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: BugCategory.values
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ))
                      .toList(),
                  onChanged: _sending
                      ? null
                      : (value) => setState(
                          () => _category = value ?? BugCategory.other),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 4000,
                  keyboardType: TextInputType.multiline,
                  validator: (value) =>
                      _validateText(value, name: 'Description', min: 10),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    hintText:
                        'Étapes réalisées, résultat attendu et message affiché…',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 74),
                      child: Icon(Icons.notes_rounded),
                    ),
                  ),
                ),
                const Text(
                  'Aucun identifiant unique ni donnée personnelle de l’appareil n’est collecté.',
                  style: TextStyle(fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Envoi…' : 'Envoyer le rapport'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
