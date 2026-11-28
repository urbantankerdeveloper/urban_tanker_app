import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/services/api_client.dart';

void main() {
  test(
    'applies saved profile fields to the session user immediately',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final controller = AppController(
        api: ApiClient(),
        preferences: preferences,
      );
      addTearDown(controller.dispose);
      controller.user = const SessionUser(
        id: 'customer-1',
        name: 'Old name',
        username: 'customer',
        role: WorkspaceRole.customer,
        email: 'old@example.com',
        phone: '9876543210',
      );

      controller.applyProfileUpdate(
        const CustomerProfile(
          name: 'New name',
          email: 'new@example.com',
          phone: '9123456780',
          phoneVerified: true,
        ),
      );

      expect(controller.user?.name, 'New name');
      expect(controller.user?.email, 'new@example.com');
      expect(controller.user?.phone, '9123456780');
      expect(controller.user?.phoneVerified, isTrue);
    },
  );
}
