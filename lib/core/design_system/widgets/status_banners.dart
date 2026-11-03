import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';
import 'surfaces.dart';

/// Slim glass pill shown at the top of the page while the device is offline.
/// Behavior is unchanged from the original banner: it listens to
/// connectivity and appears only when there is no network.
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
    final colors = context.colors;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.base),
          switchInCurve: AppMotion.curve,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: _offline
              ? _BannerPill(
                  key: const ValueKey('offline'),
                  icon: Icons.wifi_off_outlined,
                  tone: colors.danger,
                  message:
                      'No network connection. Some features may be unavailable.',
                )
              : const SizedBox.shrink(key: ValueKey('online')),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// Shows a notice while a request has taken longer than 3 seconds. The server
/// on the free tier can take a while to wake up.
class SlowServerBanner extends StatelessWidget {
  const SlowServerBanner({
    required this.slow,
    required this.child,
    super.key,
  });

  final ValueListenable<bool> slow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<bool>(
      valueListenable: slow,
      child: child,
      builder: (context, isSlow, child) => Column(
        children: [
          AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.base),
            switchInCurve: AppMotion.curve,
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: isSlow
                ? _BannerPill(
                    key: const ValueKey('slow'),
                    icon: null,
                    loading: true,
                    tone: colors.info,
                    message: 'Waking up the server, please wait...',
                  )
                : const SizedBox.shrink(key: ValueKey('fast')),
          ),
          Expanded(child: child!),
        ],
      ),
    );
  }
}

class _BannerPill extends StatelessWidget {
  const _BannerPill({
    required this.message,
    required this.tone,
    super.key,
    this.icon,
    this.loading = false,
  });

  final String message;
  final AppTone tone;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
        child: GlassCard(
          radius: AppRadius.pillBorder,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              if (loading)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tone.fg,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 18, color: tone.fg),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: tone.fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
