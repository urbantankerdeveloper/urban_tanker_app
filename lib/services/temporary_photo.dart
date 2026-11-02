import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Deletes a photo copy kept in the app's temporary folder. Files elsewhere, such as the user's gallery originals, are never removed.
Future<void> deleteTemporaryPhoto(
  String? path, {
  required String temporaryRoot,
}) async {
  if (path == null ||
      !(path.startsWith('$temporaryRoot${Platform.pathSeparator}') ||
          path.startsWith('$temporaryRoot/'))) {
    return;
  }
  try {
    await File(path).delete();
  } on FileSystemException {
    // The file was already removed, so there is nothing left to clean up.
  }
}

/// Like [deleteTemporaryPhoto], using the app's own temporary folder. Never throws.
Future<void> discardTemporaryPhotoFile(String? path) async {
  try {
    final temporaryRoot = (await getTemporaryDirectory()).path;
    await deleteTemporaryPhoto(path, temporaryRoot: temporaryRoot);
  } catch (_) {
    // Cleanup is best effort.
  }
}
