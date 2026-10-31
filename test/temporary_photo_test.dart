import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/temporary_photo.dart';

void main() {
  test('deletes a photo copy inside the temporary folder', () async {
    final root = await Directory.systemTemp.createTemp('selfie_tmp');
    final file = File('${root.path}/image_picker_1.jpg')
      ..writeAsBytesSync([1, 2, 3]);

    await deleteTemporaryPhoto(file.path, temporaryRoot: root.path);

    expect(file.existsSync(), isFalse);
    await root.delete(recursive: true);
  });

  test('keeps a photo outside the temporary folder', () async {
    final root = await Directory.systemTemp.createTemp('selfie_tmp_root');
    final gallery = await Directory.systemTemp.createTemp('gallery_original');
    final original = File('${gallery.path}/IMG_0001.jpg')
      ..writeAsBytesSync([1, 2, 3]);

    await deleteTemporaryPhoto(original.path, temporaryRoot: root.path);

    expect(original.existsSync(), isTrue);
    await root.delete(recursive: true);
    await gallery.delete(recursive: true);
  });

  test('ignores a photo that is already gone or has no path', () async {
    final root = await Directory.systemTemp.createTemp('selfie_tmp_missing');
    await expectLater(
      deleteTemporaryPhoto(
        '${root.path}/missing.jpg',
        temporaryRoot: root.path,
      ),
      completes,
    );
    await expectLater(
      deleteTemporaryPhoto(null, temporaryRoot: root.path),
      completes,
    );
    await root.delete(recursive: true);
  });
}
