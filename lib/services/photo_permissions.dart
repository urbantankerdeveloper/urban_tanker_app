import 'package:permission_handler/permission_handler.dart';

enum PhotoAccess { granted, denied, permanentlyDenied }

PhotoAccess photoAccessFor(PermissionStatus status) => switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional =>
        PhotoAccess.granted,
      PermissionStatus.permanentlyDenied => PhotoAccess.permanentlyDenied,
      _ => PhotoAccess.denied,
    };

Future<PhotoAccess> requestCameraAccess() async =>
    photoAccessFor(await Permission.camera.request());

Future<PhotoAccess> requestPhotoAccess() async =>
    photoAccessFor(await Permission.photos.request());

String photoAccessMessage({required bool camera, required PhotoAccess access}) {
  if (access == PhotoAccess.permanentlyDenied) {
    return camera
        ? 'Camera access is turned off for Urban Tanker. Open settings to allow it.'
        : 'Photo access is turned off for Urban Tanker. Open settings to allow it.';
  }
  return camera
      ? 'Camera access is needed to take your selfie. Allow it when asked, or choose a photo from the gallery.'
      : 'Photo access is needed to choose a photo. Allow it when asked, or take a selfie with the camera.';
}
