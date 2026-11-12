import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/widgets/app_snack.dart';
import '../../../models/session.dart';
import '../../../services/realtime_notice.dart';
import '../../../services/realtime_service.dart';

/// Shows a visible snackbar (plus haptic, and an alert sound for new vendor
/// orders) for each relevant realtime event. Runs only while the app is in the
/// foreground; background alerts come from push notifications.
class RealtimeNoticeListener extends StatefulWidget {
  const RealtimeNoticeListener({
    required this.events,
    required this.role,
    required this.child,
    super.key,
  });

  final Stream<RealtimeEvent>? events;
  final WorkspaceRole role;
  final Widget child;

  @override
  State<RealtimeNoticeListener> createState() => _RealtimeNoticeListenerState();
}

class _RealtimeNoticeListenerState extends State<RealtimeNoticeListener> {
  StreamSubscription<RealtimeEvent>? _subscription;
  final Set<String> _shownKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(RealtimeNoticeListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events || oldWidget.role != widget.role) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _subscription = widget.events?.listen(_onEvent);
  }

  void _onEvent(RealtimeEvent event) {
    if (!mounted) return;
    final notice = realtimeNoticeFor(widget.role, event);
    if (notice == null || !_shownKeys.add(notice.key)) return;

    if (notice.isNewOrder) {
      unawaited(SystemSound.play(SystemSoundType.alert));
      unawaited(HapticFeedback.heavyImpact());
      showAppSnack(
        context,
        notice.message,
        icon: Icons.notifications_active_outlined,
      );
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    showAppSnack(context, notice.message, variant: notice.variant);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
