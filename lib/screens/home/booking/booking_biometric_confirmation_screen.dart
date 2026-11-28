import 'package:flutter/material.dart';

import '../../../core/design_system/design_system.dart';
import '../../../services/friendly_error.dart';

class BookingBiometricConfirmationScreen extends StatefulWidget {
  const BookingBiometricConfirmationScreen({
    required this.serviceNames,
    required this.quoteSummary,
    required this.authorize,
    super.key,
  });

  final List<String> serviceNames;
  final String quoteSummary;
  final Future<bool> Function() authorize;

  @override
  State<BookingBiometricConfirmationScreen> createState() =>
      _BookingBiometricConfirmationScreenState();
}

class _BookingBiometricConfirmationScreenState
    extends State<BookingBiometricConfirmationScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final authorized = await widget.authorize();
      if (!mounted) return;
      if (authorized) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'Biometric confirmation was not completed.';
          _busy = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Biometric confirmation failed: ${friendlyError(error)}';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return AppScaffold(
      title: 'Confirm booking',
      body: ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          GradientCard(
            child: Column(
              children: [
                Icon(
                  Icons.fingerprint,
                  size: 72,
                  color: colors.onHero,
                  semanticLabel: 'Fingerprint confirmation',
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  'Confirm your booking',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onHero,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Use your device biometric to authorize this order.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onHero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order summary', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpace.md),
                for (final service in widget.serviceNames)
                  AppListRow(
                    leading: const Icon(Icons.water_drop_outlined),
                    title: service,
                  ),
                const Divider(height: AppSpace.xl),
                Text(widget.quoteSummary, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            ErrorState(error: _error!, message: _error),
          ],
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(
            label: _busy
                ? 'Waiting for confirmation...'
                : 'Confirm with fingerprint',
            icon: Icons.fingerprint,
            loading: _busy,
            onPressed: _busy ? null : _confirm,
          ),
          const SizedBox(height: AppSpace.sm),
          GhostButton(
            label: 'Go back',
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
