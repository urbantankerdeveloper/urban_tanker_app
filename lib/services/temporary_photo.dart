import 'dart:io';

/// Deletes a photo copy kept in the app's temporary folder. Files elsewhere, such as the user's gallery originals, are never removed.
Future<void> deleteTemporaryPhoto(
  String? path, {
  required String temporaryRoot,
}) async {
  if (path == null ||
      !path.startsWith('$temporaryRoot${Platform.pathSeparator}')) {
    return;
  }
  try {
    await File(path).delete();
  } on FileSystemException {
    // The file was already removed, so there is nothing left to clean up.
  }
}
