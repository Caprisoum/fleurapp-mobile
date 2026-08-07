import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/payment_method.dart';

class PaymentSheet extends StatelessWidget {
  const PaymentSheet({super.key});

  static Future<PaymentMethod?> show(BuildContext context) {
    return showModalBottomSheet<PaymentMethod>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PaymentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Moyen de paiement',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choisissez comment le client règle cette vente.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            _PaymentOption(
              icon: Icons.credit_card_rounded,
              title: 'Carte bancaire',
              subtitle: 'Paiement sur votre TPE actuel',
              onTap: () => Navigator.of(context).pop(PaymentMethod.card),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              icon: Icons.payments_outlined,
              title: 'Espèces',
              subtitle: 'Règlement comptant',
              onTap: () => Navigator.of(context).pop(PaymentMethod.cash),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Chèque',
              subtitle: 'Règlement par chèque',
              onTap: () => Navigator.of(context).pop(PaymentMethod.cheque),
            ),
            const SizedBox(height: 10),
            const _PaymentOption(
              icon: Icons.contactless_rounded,
              title: 'Tap to Pay',
              subtitle: 'Emplacement réservé au futur SDK Stripe Terminal',
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          enabled ? const Color(0xFFF7FAF8) : Colors.black.withOpacity(0.035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDFE7E3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: enabled,
        minVerticalPadding: 14,
        onTap: enabled ? onTap : null,
        leading: CircleAvatar(
          backgroundColor: enabled ? const Color(0xFFE5F0EB) : Colors.black12,
          child: Icon(icon, color: enabled ? AppTheme.forest : Colors.black38),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: enabled
            ? const Icon(Icons.chevron_right_rounded)
            : const Chip(label: Text('Bientôt')),
      ),
    );
  }
}
