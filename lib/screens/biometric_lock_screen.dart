import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/page_components.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _authenticating = false;
  String? _error;
  bool _attemptedAutomatically = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_attemptedAutomatically) return;
    _attemptedAutomatically = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_authenticating || !widget.controller.biometricLocked) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final authenticated = await widget.controller.biometricAuth.authenticate(
        'Unlock your Urban Tanker account',
      );
      if (!mounted) return;
      if (authenticated) {
        widget.controller.unlockBiometricSession();
      } else {
        setState(() => _error = 'Biometric verification was not completed.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() =>
            _error = error.message ?? 'Biometric verification is unavailable.');
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppPageInsets.status,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Unlock Urban Tanker',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verify your fingerprint or device biometric to sign in to your saved account.',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _authenticating ? null : _unlock,
                    icon: _authenticating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    label: const Text('Sign in with fingerprint or biometrics'),
                  ),
                  TextButton(
                    onPressed:
                        _authenticating ? null : controller.usePhoneOtpRecovery,
                    child: const Text('Use phone number and OTP instead'),
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
