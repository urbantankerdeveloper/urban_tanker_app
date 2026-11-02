import 'dart:io';

import 'package:path_provider/path_provider.dart';

final _savedInvoiceName = RegExp(r'^invoice-[^/]+\.json$');

/// Removes invoice files saved by the invoice screen. Called on sign-out.
Future<void> deleteSavedInvoiceFiles() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (_savedInvoiceName.hasMatch(name)) {
        await entity.delete();
      }
    }
  } catch (_) {
    // Cleanup is best effort; the sign-out itself must not fail.
  }
}
