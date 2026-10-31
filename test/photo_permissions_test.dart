import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:urban_tanker_app/services/photo_permissions.dart';

void main() {
  test('treats granted and limited photo access as usable', () {
    expect(photoAccessFor(PermissionStatus.granted), PhotoAccess.granted);
    expect(photoAccessFor(PermissionStatus.limited), PhotoAccess.granted);
  });

  test('separates a refusal from a permanent refusal', () {
    expect(photoAccessFor(PermissionStatus.denied), PhotoAccess.denied);
    expect(photoAccessFor(PermissionStatus.restricted), PhotoAccess.denied);
    expect(
      photoAccessFor(PermissionStatus.permanentlyDenied),
      PhotoAccess.permanentlyDenied,
    );
  });

  test('explains which access is needed and where to turn it on', () {
    expect(
      photoAccessMessage(camera: true, access: PhotoAccess.denied),
      contains('Camera access is needed'),
    );
    expect(
      photoAccessMessage(camera: false, access: PhotoAccess.permanentlyDenied),
      contains('Open settings'),
    );
  });
}
