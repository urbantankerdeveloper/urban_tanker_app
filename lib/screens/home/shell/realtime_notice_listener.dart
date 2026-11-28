import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_feature_flags.dart';
import '../../../app/providers.dart';
import '../../../core/design_system/widgets/app_bottom_sheet.dart';
import '../../../core/design_system/widgets/app_snack.dart';
import '../../../core/design_system/widgets/app_toast.dart';
import '../../../models/session.dart';
import '../../../models/vendor.dart';
import '../../../services/realtime_notice.dart';
import '../../../services/realtime_service.dart';
import '../../../services/friendly_error.dart';
import '../../vendor/operations/incoming_order_screen.dart';
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
  final Set<String> _closedIncomingOrderKeys = <String>{};
  final Map<String, AppToast> _toasts = <String, AppToast>{};
  final Map<String, DialogRoute<void>> _incomingRoutes =
      <String, DialogRoute<void>>{};
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
    if (closesKey != null) {
      _closedIncomingOrderKeys.add(closesKey);
      _dismissToast(closesKey);
      _dismissIncomingOrder(closesKey);
    }
    if (!_shownKeys.add(notice.key)) return;

    if (notice.isNewOrder && notice.bookingId != null) {
      unawaited(SystemSound.play(SystemSoundType.alert));
      unawaited(HapticFeedback.heavyImpact());
      if (AuthFeatureFlags.newUiEnabled) {
        unawaited(_showIncomingOrder(notice));
      } else {
        _showOffer(notice);
      }
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

  Future<void> _showIncomingOrder(RealtimeNotice notice) async {
    final bookingId = notice.bookingId!;
    VendorOrder? order;
    try {
      order = await _findOrder(bookingId);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not load the incoming order: ${friendlyError(error)}',
          variant: AppSnackVariant.error,
        );
      }
      return;
    }
    if (!mounted || _closedIncomingOrderKeys.contains(notice.key)) return;
    if (order == null) {
      showAppSnack(
        context,
        'That order is no longer available.',
        variant: AppSnackVariant.error,
      );
      return;
    }

    final navigator = Navigator.of(context);
    late final DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(
        child: IncomingOrderScreen(
          order: order!,
          onAccept: () => _acceptOffer(bookingId),
          onDecline: () => _rejectOffer(bookingId),
          onTimeout: () => _declineExpiredOffer(bookingId),
        ),
      ),
    );
    _incomingRoutes[notice.key] = route;
    try {
      await navigator.push<void>(route);
    } finally {
      if (identical(_incomingRoutes[notice.key], route)) {
        _incomingRoutes.remove(notice.key);
      }
    }
  }

  void _dismissIncomingOrder(String key) {
    final route = _incomingRoutes.remove(key);
    if (route == null || !route.isActive) return;
    Navigator.of(context).removeRoute(route);
  }

  Future<void> _acceptOffer(String bookingId) =>
      _openOrderSheet(bookingId, startWithReject: false);

  Future<void> _rejectOffer(String bookingId) =>
      _openOrderSheet(bookingId, startWithReject: true);

  Future<void> _openOrderSheet(
    String bookingId, {
    required bool startWithReject,
  }) async {
    VendorOrder? order;
    try {
      order = await _findOrder(bookingId);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not load the order: ${friendlyError(error)}',
          variant: AppSnackVariant.error,
        );
      }
      return;
    }
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
    final currentOrder = order;
    final handled = await showAppBottomSheet<bool>(
      context,
      builder: (_) => OrderActionsSheet(
        order: currentOrder,
        startWithReject: startWithReject,
      ),
    );
    if (handled == true) _dismissToast('offer:$bookingId');
  }

  Future<void> _declineExpiredOffer(String bookingId) async {
    VendorOrder? order;
    try {
      order = await _findOrder(bookingId);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'The offer expired, but could not be declined: '
          '${friendlyError(error)}',
          variant: AppSnackVariant.error,
        );
      }
      return;
    }
    if (!mounted) return;
    if (order == null || order.status != 'pending_vendor') {
      showAppSnack(
        context,
        'The order is no longer available.',
        variant: AppSnackVariant.info,
      );
      return;
    }
    final currentOrder = order;
    try {
      final api = ref.read(appControllerProvider).api;
      if (currentOrder.offerId != null) {
        await api.rejectMultiServiceOffer(currentOrder.offerId!);
      } else {
        await api.transitionVendorOrder(
          currentOrder.id,
          action: 'reject',
          reason: 'Offer expired',
        );
      }
      ref
        ..invalidate(vendorOrdersProvider)
        ..invalidate(vendorDashboardProvider);
      if (mounted) {
        showAppSnack(
          context,
          'The unanswered order was declined.',
          variant: AppSnackVariant.info,
        );
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'The offer expired, but could not be declined: '
          '${friendlyError(error)}',
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  /// Reloads the vendor orders so a brand-new order is present.
  Future<VendorOrder?> _findOrder(String bookingId) async {
    ref.invalidate(vendorOrdersProvider);
    final orders = await ref.read(vendorOrdersProvider.future);
    for (final order in orders) {
      if (order.id == bookingId) return order;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
