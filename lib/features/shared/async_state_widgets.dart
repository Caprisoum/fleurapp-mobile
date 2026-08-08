import 'package:flutter/material.dart';

import '../../services/api_exception.dart';

void showApiError(BuildContext context, Object error) {
  final exception = error is ApiException ? error : null;
  var message = exception?.message ?? 'Une erreur inattendue est survenue.';
  if (exception?.statusCode == 409) {
    message = '$message Aucune modification partielle n’a été conservée.';
  }
  if (exception?.requestId != null) {
    message = '$message\nRéférence : ${exception!.requestId}';
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
    );
}

class LoadingOrError extends StatelessWidget {
  const LoadingOrError({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.child,
    super.key,
  });

  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error == null) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 46, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 14),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
