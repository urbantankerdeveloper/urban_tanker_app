import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/mpin_service.dart';

class _MemoryStore implements MpinStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late _MemoryStore store;
  late MpinService mpin;

  setUp(() {
    store = _MemoryStore();
    mpin = MpinService(store: store);
  });

  test('accepts the MPIN that was set and counts wrong tries', () async {
    await mpin.setPin('4821');
    expect(await mpin.isSet(), isTrue);
    expect((await mpin.verify('4821')).isAccepted, isTrue);

    final wrong = await mpin.verify('0000');
    expect(wrong.isAccepted, isFalse);
    expect(wrong.attemptsLeft, MpinService.maxAttempts - 1);
  });

  test('locks after five wrong tries; a correct MPIN resets the count',
      () async {
    await mpin.setPin('123456');
    for (var i = 0; i < 3; i++) {
      await mpin.verify('000000');
    }
    expect((await mpin.verify('123456')).isAccepted, isTrue);

    for (var i = 0; i < MpinService.maxAttempts - 1; i++) {
      expect((await mpin.verify('000000')).isLocked, isFalse);
    }
    expect((await mpin.verify('000000')).isLocked, isTrue);
    expect((await mpin.verify('123456')).isLocked, isTrue);
  });

  test('stores a salted hash, never the PIN itself', () async {
    await mpin.setPin('4821');
    expect(store.values.values, isNot(contains('4821')));
    expect(store.values.keys, contains('urban_tanker_mpin_hash'));
  });

  test('only 4 to 6 digits are accepted', () async {
    expect(() => mpin.setPin('123'), throwsArgumentError);
    expect(() => mpin.setPin('1234567'), throwsArgumentError);
    expect(() => mpin.setPin('12a4'), throwsArgumentError);
    expect(MpinService.isValid('1234'), isTrue);
    expect(MpinService.isValid('123456'), isTrue);
  });

  test('clear removes the MPIN and its attempts', () async {
    await mpin.setPin('4821');
    await mpin.verify('0000');
    await mpin.clear();
    expect(await mpin.isSet(), isFalse);
    expect(store.values, isEmpty);
  });
}
