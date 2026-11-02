import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/services/api_client.dart';

Booking _booking(int index) => Booking.fromJson({
      'id': 'b$index',
      'reference': 'UT-$index',
      'status': 'pending',
      'location': '12 Main Street',
      'capacity_litres': 5000,
      'created_at': '2026-10-21T09:00:00Z',
    });

class _PagedApi extends ApiClient {
  final List<int> requestedOffsets = [];
  final int total;

  _PagedApi({required this.total});

  @override
  Future<BookingPage> bookingsPage({int offset = 0, int pageSize = 100}) async {
    requestedOffsets.add(offset);
    final end = (offset + pageSize).clamp(0, total);
    return BookingPage(
      rows: [for (var i = offset; i < end; i++) _booking(i)],
      nextOffset: end < total ? end : null,
    );
  }
}

void main() {
  test('bookings load one page first and append pages on demand', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _PagedApi(total: 70);
    final controller = AppController(api: api, preferences: preferences);
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith((ref) => controller)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(bookingsProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(bookingsProvider.future);
    expect(api.requestedOffsets, [0]);
    expect(container.read(bookingsProvider).requireValue.items, hasLength(30));

    final notifier = container.read(bookingsProvider.notifier);
    await notifier.loadMore();
    await notifier.loadMore();
    await notifier.loadMore();

    final state = container.read(bookingsProvider).requireValue;
    expect(api.requestedOffsets, [0, 30, 60]);
    expect(state.items, hasLength(70));
    expect(state.hasMore, isFalse);
  });
}
