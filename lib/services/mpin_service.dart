import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value storage for the MPIN hash. The app uses secure storage; tests use
/// an in-memory map.
abstract interface class MpinStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureMpinStore implements MpinStore {
  const SecureMpinStore();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(resetOnError: true, migrateWithBackup: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Result of checking an MPIN.
class MpinCheck {
  const MpinCheck._(this._outcome, {this.attemptsLeft = 0});

  static const accepted = MpinCheck._(_Outcome.accepted);
  static const locked = MpinCheck._(_Outcome.locked);

  static MpinCheck rejected(int attemptsLeft) =>
      MpinCheck._(_Outcome.rejected, attemptsLeft: attemptsLeft);

  final _Outcome _outcome;
  final int attemptsLeft;

  bool get isAccepted => _outcome == _Outcome.accepted;
  bool get isLocked => _outcome == _Outcome.locked;
}

enum _Outcome { accepted, rejected, locked }

/// A 4 to 6 digit MPIN for unlocking the app without a password. Only a salted
/// PBKDF2-HMAC-SHA256 hash is stored.
class MpinService {
  MpinService({required MpinStore store, Random? random})
      : _store = store,
        _random = random ?? Random.secure();

  static const minLength = 4;
  static const maxLength = 6;
  static const maxAttempts = 5;

  static const _iterations = 10000;
  static const _hashKey = 'urban_tanker_mpin_hash';
  static const _saltKey = 'urban_tanker_mpin_salt';
  static const _attemptsKey = 'urban_tanker_mpin_attempts';
  static final _format = RegExp('^\\d{$minLength,$maxLength}\$');

  final MpinStore _store;
  final Random _random;

  static bool isValid(String pin) => _format.hasMatch(pin);

  Future<bool> isSet() async => (await _store.read(_hashKey)) != null;

  /// Saves a new MPIN and clears any failed attempts.
  Future<void> setPin(String pin) async {
    if (!isValid(pin)) {
      throw ArgumentError('The MPIN must be $minLength to $maxLength digits.');
    }
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    await _store.write(_saltKey, base64Encode(salt));
    await _store.write(_hashKey, base64Encode(_derive(pin, salt)));
    await _store.delete(_attemptsKey);
  }

  Future<MpinCheck> verify(String pin) async {
    final hashText = await _store.read(_hashKey);
    final saltText = await _store.read(_saltKey);
    if (hashText == null || saltText == null) {
      throw StateError('No MPIN is set.');
    }
    final attempts =
        int.tryParse(await _store.read(_attemptsKey) ?? '') ?? 0;
    if (attempts >= maxAttempts) return MpinCheck.locked;

    final candidate = _derive(pin, base64Decode(saltText));
    if (_sameBytes(candidate, base64Decode(hashText))) {
      await _store.delete(_attemptsKey);
      return MpinCheck.accepted;
    }
    final failed = attempts + 1;
    await _store.write(_attemptsKey, '$failed');
    final left = maxAttempts - failed;
    return left <= 0 ? MpinCheck.locked : MpinCheck.rejected(left);
  }

  Future<void> clear() async {
    await _store.delete(_hashKey);
    await _store.delete(_saltKey);
    await _store.delete(_attemptsKey);
  }

  /// PBKDF2-HMAC-SHA256 with a single 32-byte output block.
  List<int> _derive(String pin, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final output = List<int>.of(block);
    for (var i = 1; i < _iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < output.length; j++) {
        output[j] ^= block[j];
      }
    }
    return output;
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
