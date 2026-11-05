import 'dart:convert';

import 'package:crypto/crypto.dart';
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

/// Writes an MPIN in the unversioned format used before v2 (separate salt
/// key, 10,000-step HMAC chain) so migration can be tested.
void _seedLegacyRecord(_MemoryStore store, String pin, List<int> salt) {
  final hmac = Hmac(sha256, utf8.encode(pin));
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final output = List<int>.of(block);
  for (var i = 1; i < 10000; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < output.length; j++) {
      output[j] ^= block[j];
    }
  }
  store.values['urban_tanker_mpin_salt'] = base64Encode(salt);
  store.values['urban_tanker_mpin_hash'] = base64Encode(output);
}

Future<List<int>> _fastKdf(String pin, List<int> salt, int iterations) async =>
    sha256.convert([...salt, ...utf8.encode(pin)]).bytes;

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

  test('stores a versioned record with its iteration count', () async {
    await mpin.setPin('4821');
    expect(store.values['urban_tanker_mpin_hash'], startsWith('v2\$100000\$'));
    expect(store.values.containsKey('urban_tanker_mpin_salt'), isFalse);
  });

  test('rejects near-miss PINs of the same length', () async {
    await mpin.setPin('4821');
    for (final guess in ['4820', '4812', '3821', '4821 ']) {
      expect((await mpin.verify(guess)).isAccepted, isFalse, reason: guess);
    }
    expect((await mpin.verify('4821')).isAccepted, isTrue);
  });

  test('an unversioned record still verifies and is upgraded to v2', () async {
    final salt = List<int>.generate(16, (i) => i * 7 + 1);
    _seedLegacyRecord(store, '4821', salt);

    final wrong = await mpin.verify('0000');
    expect(wrong.isAccepted, isFalse);
    expect(store.values['urban_tanker_mpin_hash'], isNot(startsWith('v2\$')));

    expect((await mpin.verify('4821')).isAccepted, isTrue);
    expect(store.values['urban_tanker_mpin_hash'], startsWith('v2\$100000\$'));
    expect(store.values.containsKey('urban_tanker_mpin_salt'), isFalse);
    expect((await mpin.verify('4821')).isAccepted, isTrue);
  });

  test('escalates persisted cooldowns and resets escalation after success',
      () async {
    final service = MpinService(store: store, kdf: _fastKdf);
    await service.setPin('4821');
    const cooldownKey = 'urban_tanker_mpin_cooldown_until';
    const lockoutLevelKey = 'urban_tanker_mpin_lockout_level';
    const cooldowns = [30000, 60000, 300000];

    for (final cooldownMs in cooldowns) {
      if (store.values.containsKey(cooldownKey)) {
        store.values[cooldownKey] =
            '${DateTime.now().millisecondsSinceEpoch - 1}';
      }
      for (var attempt = 0; attempt < MpinService.maxAttempts; attempt++) {
        final check = await service.verify('0000');
        if (attempt < MpinService.maxAttempts - 1) {
          expect(check.isLocked, isFalse);
        } else {
          expect(check.isLocked, isTrue);
        }
      }
      final until = int.parse(store.values[cooldownKey]!);
      final remaining =
          until - DateTime.now().millisecondsSinceEpoch;
      expect(remaining, inInclusiveRange(cooldownMs - 1000, cooldownMs));
      expect((await service.verify('4821')).isLocked, isTrue);
    }

    store.values[cooldownKey] = '${DateTime.now().millisecondsSinceEpoch - 1}';
    expect((await service.verify('4821')).isAccepted, isTrue);
    expect(store.values.containsKey(lockoutLevelKey), isFalse);

    for (var attempt = 0; attempt < MpinService.maxAttempts; attempt++) {
      await service.verify('0000');
    }
    final until = int.parse(store.values[cooldownKey]!);
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    expect(remaining, inInclusiveRange(29000, 30000));
  });
}
