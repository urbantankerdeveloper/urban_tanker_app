import '../../models/dispatcher.dart';

/// How pressing an order is on the dispatch queue. Most urgent first.
enum DispatchUrgency { urgent, needsVendor, inProgress, scheduled, done }

/// Orders due within this window with no vendor are urgent.
const urgentWindow = Duration(hours: 2);

DispatchUrgency dispatchUrgency(DispatcherOrder order, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final status = order.status.toLowerCase();
  if (status == 'delivered' || status == 'cancelled') {
    return DispatchUrgency.done;
  }
  if (status == 'pending_vendor' && !order.isAssigned) {
    final due = order.scheduledFor;
    final dueSoon = due != null && due.difference(current) <= urgentWindow;
    return dueSoon ? DispatchUrgency.urgent : DispatchUrgency.needsVendor;
  }
  const active = ['vendor_assigned', 'accepted', 'en_route', 'arrived'];
  if (active.contains(status)) return DispatchUrgency.inProgress;
  return DispatchUrgency.scheduled;
}

/// Sorts most urgent first, then soonest scheduled. Orders with no date go last.
List<DispatcherOrder> sortByPriority(
  List<DispatcherOrder> orders, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  return [...orders]..sort((a, b) => compareByPriority(a, b, current));
}

/// Comparison used for the queue: urgency first, then soonest scheduled.
int compareByPriority(DispatcherOrder a, DispatcherOrder b, DateTime now) {
  final rank = dispatchUrgency(a, now: now)
      .index
      .compareTo(dispatchUrgency(b, now: now).index);
  if (rank != 0) return rank;
  final left = a.scheduledFor;
  final right = b.scheduledFor;
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}
