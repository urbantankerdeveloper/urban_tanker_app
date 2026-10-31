import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class AppPageInsets {
  const AppPageInsets._();

  static const EdgeInsets standard = EdgeInsets.fromLTRB(20, 16, 20, 24);
  static const EdgeInsets status = EdgeInsets.fromLTRB(24, 24, 24, 24);
}

class AppStateView extends StatelessWidget {
  const AppStateView._({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.loading = false,
  });

  const AppStateView.loading({Key? key, String message = 'Loading...'})
      : this._(
          key: key,
          icon: Icons.hourglass_empty,
          title: 'Please wait',
          message: message,
          loading: true,
        );

  factory AppStateView.error({
    Key? key,
    required Object error,
    VoidCallback? onRetry,
    String? message,
  }) {
    final isOffline = isNetworkError(error);
    return AppStateView._(
      key: key,
      icon: isOffline ? Icons.wifi_off_outlined : Icons.error_outline,
      title: isOffline ? 'No network connection' : 'Something went wrong',
      message: message ??
          (isOffline
              ? 'Check your internet connection and try again.'
              : error.toString()),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
    );
  }

  const AppStateView.empty({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.title = 'Nothing here yet',
    this.action,
  }) : loading = false;

  factory AppStateView.permission({
    Key? key,
    required String message,
    VoidCallback? onOpenSettings,
  }) =>
      AppStateView._(
        key: key,
        icon: Icons.location_disabled_outlined,
        title: 'Permission needed',
        message: message,
        action: onOpenSettings == null
            ? null
            : OutlinedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open settings'),
              ),
      );

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: AppPageInsets.status,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Icon(icon, size: 44, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  static bool isNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('timeoutexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection timed out') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('no address associated with hostname');
  }
}

class AppStateInline extends StatelessWidget {
  const AppStateInline.error({
    required Object error,
    this.onRetry,
    this.message,
    super.key,
  })  : _error = error,
        _loading = false;

  const AppStateInline.loading({super.key})
      : _error = null,
        _loading = true,
        onRetry = null,
        message = null;

  final Object? _error;
  final bool _loading;
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    final error = _error!;
    final offline = AppStateView.isNetworkError(error);
    return ListTile(
      leading: Icon(
        offline ? Icons.wifi_off_outlined : Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(offline ? 'No network connection' : 'Could not load this section'),
      subtitle: Text(message ?? error.toString()),
      trailing: onRetry == null
          ? null
          : IconButton(
              tooltip: 'Try again',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
    );
  }
}

Future<void> showAppPermissionDialog(
  BuildContext context, {
  required String message,
  required VoidCallback onOpenSettings,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Permission needed'),
      content: AppStateView.permission(
        message: message,
        onOpenSettings: () {
          Navigator.of(dialogContext).pop();
          onOpenSettings();
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Not now'),
        ),
      ],
    ),
  );
}

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({required this.child, super.key});

  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectivity,
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'connectivity',
            context: ErrorDescription('while listening for network changes'),
          ),
        );
      },
    );
    _loadConnectivity();
  }

  Future<void> _loadConnectivity() async {
    try {
      _updateConnectivity(await _connectivity.checkConnectivity());
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'connectivity',
          context: ErrorDescription('while checking network status'),
        ),
      );
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);
    if (mounted && offline != _offline) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_offline)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No network connection. Some features may be unavailable.',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
