# Urban Tanker mobile app

This is the native Flutter application for Urban Tanker. It is intentionally a
standalone sibling of `ut_landing`; the website remains the source of truth for
the REST and Socket.IO contracts.

## Requirements

- Flutter stable with Dart 3.4 or newer
- Android SDK with API 30 installed for the Android target
- macOS/Xcode for iOS builds (the iOS deployment target is 13.0)

Android builds and Flutter tests can be run from a Flutter-enabled development
machine. iOS builds, signing, and store validation require macOS and Xcode.

## Run

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

For a physical device, replace `10.0.2.2` with a host address reachable from
the device. The Socket.IO URL is derived from `API_BASE_URL` by removing the
`/api` suffix; override it with `--dart-define=SOCKET_URL=...` when the API and
realtime server use different origins.

The app uses the server response to determine the role. Role selection is not
available in the client. Access tokens are stored in platform secure storage;
no Supabase secret or service-role key belongs in this project.

State is coordinated with Riverpod, using the existing `ChangeNotifier`
controller as the single session/theme source. FlexColorScheme provides the
open-source Material 3 theme foundation while preserving the Urban Tanker
palette and semantic light/dark surfaces.

Native authentication uses the `/api/auth/mobile-refresh` endpoint. Access and
rotated refresh tokens are stored separately in secure platform storage. The
browser cookie refresh flow remains on `/api/auth/refresh`; the mobile endpoint
does not expose refresh tokens to browser clients.

Customer bookings are backed by `/api/customer/orders` and the booking detail
view uses the ownership-checked
`/api/customer/orders/:orderId/tracking` endpoint. Riverpod provides loading,
empty, error, refresh, and detail tracking states; the app does not fabricate
tracking data when the server has no vendor location yet.

The customer Account tab now reads the authenticated profile, saved addresses,
wallet transactions, invoices, subscriptions, and support requests from the
existing `/api/customer/*` and `/api/support/requests` endpoints. Each section
has independent Riverpod loading, empty, error, and retry states. Payment
top-up remains read-only until a native payment flow is available; account
mutations use dedicated forms, confirmation, and post-mutation provider
invalidation so the app does not claim success without a server response.

The account area now also supports:

- Profile editing through `PATCH /api/customer/profile`.
- Address creation and confirmed deletion through the customer address APIs.
- Support request creation through `POST /api/support/requests`.
- Subscription status changes through the ownership-scoped subscription API.
- Invoice detail retrieval through the authenticated invoice download endpoint.

Wallet entries remain read-only. Wallet top-up must be implemented with a native
Razorpay/OS payment flow and server verification before enabling any payment
button in the mobile app.

The native client currently uses the existing authenticated customer, vendor,
and admin notification inbox endpoints. Dispatcher notifications remain
read-only backend work until a dispatcher-scoped notification endpoint is
available. Push delivery for a terminated app is not enabled by adding an
in-app inbox alone: it requires a native FCM/APNs device-registration contract,
provider credentials, notification permission handling, and server-side
delivery. Do not add provider keys or service-account files to this project.

The vendor workspace can upload documents through the authenticated signed
upload endpoint, capture an optional delivery-proof photo, and share foreground
location while an order is en route or arrived. Location sharing stops when the
order detail screen closes; background tracking is not enabled. Android asks
for location only when sharing begins, and the platform file picker is used
without broad storage access. iOS camera and in-use location usage descriptions
are configured for these user-initiated actions. Live location requires the
deployed backend's `/api/vendor/location` route and location-update storage.
Automatic replay of saved offline mutation records is not supported by the
backend; the vendor screen continues to identify those records as server logs,
not queued actions.

## Native handoff

Run `flutter create . --platforms=android,ios` once on a Flutter-enabled
machine if the generated Runner/Gradle wrapper files are not present. Preserve
the `minSdk` and iOS deployment target from this repository when regenerating.
Then run:

```bash
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://api.example.com/api
```

iOS simulator, signing, archiving, APNs configuration, and store validation
require macOS and Xcode and have not been claimed as verified from Windows.
