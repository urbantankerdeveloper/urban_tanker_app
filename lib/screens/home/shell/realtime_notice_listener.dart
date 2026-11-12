import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/widgets/app_bottom_sheet.dart';
import '../../../core/design_system/widgets/app_snack.dart';
import '../../../core/design_system/widgets/app_toast.dart';
import '../../../models/session.dart';
import '../../../models/vendor.dart';
import '../../../services/realtime_notice.dart';
import '../../../services/realtime_service.dart';
import '../../vendor/operations/order_actions_sheet.dart';

/// Shows a top-right toast (plus haptic, and an alert sound for new vendor
/// orders) for each relevant realtime event. Runs only while the app is in the
/// foreground; background alerts come from push notifications.
///
/// New-order offers stay open in the bottom-right with Accept and Reject
/// buttons. Accept opens the order sheet for assigning and accepting, and
/// Reject opens its reason prompt.
class RealtimeNoticeListener extends ConsumerStatefulWidget {
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
  ConsumerState<RealtimeNoticeListener> createState() =>
      _RealtimeNoticeListenerState();
}

class _RealtimeNoticeListenerState
    extends ConsumerState<RealtimeNoticeListener> {
  StreamSubscription<RealtimeEvent>? _subscription;
  final Set<String> _shownKeys = <String>{};
  final Map<String, AppToast> _toasts = <String, AppToast>{};
  // Lifts the bottom-right offer above the floating bottom nav bar.
  static const double _navClearance = 88;

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
    final toasts = _toasts.values.toList();
    _toasts.clear();
    // Overlay entries cannot be removed while this subtree is unmounting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final toast in toasts) {
        toast.dismiss();
      }
    });
    super.dispose();
  }

  void _subscribe() {
    _subscription = widget.events?.listen(_onEvent);
  }

  void _onEvent(RealtimeEvent event) {
    if (!mounted) return;
    final notice = realtimeNoticeFor(widget.role, event);
    if (notice == null) return;
    final closesKey = notice.closesKey;
    if (closesKey != null) _dismissToast(closesKey);
    if (!_shownKeys.add(notice.key)) return;

    if (notice.isNewOrder && notice.bookingId != null) {
      unawaited(SystemSound.play(SystemSoundType.alert));
      unawaited(HapticFeedback.heavyImpact());
      _showOffer(notice);
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    _toasts[notice.key] = showAppToast(
      context,
      notice.message,
      variant: notice.variant,
      onDismissed: () => _toasts.remove(notice.key),
    );
  }

  void _showOffer(RealtimeNotice notice) {
    final bookingId = notice.bookingId!;
    _toasts[notice.key] = showAppToast(
      context,
      notice.message,
      icon: Icons.notifications_active_outlined,
      autoDismissAfter: null,
      atBottom: true,
      bottomClearance: _navClearance,
      actions: [
        AppToastAction(
          label: 'Accept',
          primary: true,
          onPressed: () => _acceptOffer(bookingId),
        ),
        AppToastAction(
          label: 'Reject',
          onPressed: () => _rejectOffer(bookingId),
        ),
      ],
      onDismissed: () => _toasts.remove(notice.key),
    );
  }

  void _dismissToast(String key) => _toasts.remove(key)?.dismiss();

  Future<void> _acceptOffer(String bookingId) =>
      _openOrderSheet(bookingId, startWithReject: false);

  Future<void> _rejectOffer(String bookingId) =>
      _openOrderSheet(bookingId, startWithReject: true);

  Future<void> _openOrderSheet(
    String bookingId, {
    required bool startWithReject,
  }) async {
    final order = await _findOrder(bookingId);
    if (!mounted) return;
    if (order == null) {
      _dismissToast('offer:$bookingId');
      showAppSnack(
        context,
        'That order is no longer available.',
        variant: AppSnackVariant.error,
      );
      return;
    }
    final handled = await showAppBottomSheet<bool>(
      context,
      builder: (_) => OrderActionsSheet(
        order: order,
        startWithReject: startWithReject,
      ),
    );
    if (handled == true) _dismissToast('offer:$bookingId');
  }

  /// Reloads the vendor orders so a brand-new order is present.
  Future<VendorOrder?> _findOrder(String bookingId) async {
    ref.invalidate(vendorOrdersProvider);
    try {
      final orders = await ref.read(vendorOrdersProvider.future);
      for (final order in orders) {
        if (order.id == bookingId) return order;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
