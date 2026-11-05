import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' show Pbkdf2;
import 'package:flutter/foundation.dart' show compute;
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
///
/// The hash is stored as a versioned record `v2$iterations$saltB64$hashB64` under
/// [_hashKey]. Records written before versioning (a separate salt key and an
/// unversioned hash) still verify and are upgraded to v2 on the next correct
/// entry.
/// Derives the PBKDF2-HMAC-SHA256 key for [pin]. The default runs off the UI
/// isolate; tests in fake-async zones can supply an inline implementation.
typedef MpinKdf = Future<List<int>> Function(
  String pin,
  List<int> salt,
  int iterations,
);

class MpinService {
  MpinService({required MpinStore store, Random? random, MpinKdf? kdf})
      : _store = store,
        _random = random ?? Random.secure(),
        _kdf = kdf ?? _pbkdf2OffThread;

  static const minLength = 4;
  static const maxLength = 6;
  static const maxAttempts = 5;

  static const _iterations = 100000;
  static const _recordVersion = 'v2';
  static const _legacyIterations = 10000;
  static const _hashKey = 'urban_tanker_mpin_hash';
  static const _saltKey = 'urban_tanker_mpin_salt';
  static const _attemptsKey = 'urban_tanker_mpin_attempts';
  static const _cooldownUntilKey = 'urban_tanker_mpin_cooldown_until';
  static const _lockoutLevelKey = 'urban_tanker_mpin_lockout_level';
  static const _cooldowns = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];
  static final _format = RegExp('^\\d{$minLength,$maxLength}\$');

  final MpinStore _store;
  final Random _random;
  final MpinKdf _kdf;

  static bool isValid(String pin) => _format.hasMatch(pin);

  Future<bool> isSet() async => (await _store.read(_hashKey)) != null;

  /// Saves a new MPIN and clears any failed attempts.
  Future<void> setPin(String pin) async {
    if (!isValid(pin)) {
      throw ArgumentError('The MPIN must be $minLength to $maxLength digits.');
    }
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final hash = await _kdf(pin, salt, _iterations);
    await _writeRecord(salt, hash);
    await _store.delete(_attemptsKey);
    await _store.delete(_cooldownUntilKey);
    await _store.delete(_lockoutLevelKey);
  }

  Future<MpinCheck> verify(String pin) async {
    final hashText = await _store.read(_hashKey);
    if (hashText == null) {
      throw StateError('No MPIN is set.');
    }
    final cooldownUntilText = await _store.read(_cooldownUntilKey);
    if (cooldownUntilText != null) {
      final cooldownUntil = int.tryParse(cooldownUntilText);
      if (cooldownUntil == null) {
        throw StateError('Stored MPIN cooldown is malformed.');
      }
      if (cooldownUntil > DateTime.now().millisecondsSinceEpoch) {
        return MpinCheck.locked;
      }
      await _store.delete(_cooldownUntilKey);
      await _store.delete(_attemptsKey);
    }

    final attempts =
        int.tryParse(await _store.read(_attemptsKey) ?? '') ?? 0;
    if (attempts >= maxAttempts) {
      await _startCooldown();
      return MpinCheck.locked;
    }

    final matches = hashText.startsWith('$_recordVersion\$')
        ? await _matchesRecord(pin, hashText)
        : await _matchesLegacy(pin, hashText);
    if (matches) {
      await _store.delete(_attemptsKey);
      await _store.delete(_cooldownUntilKey);
      await _store.delete(_lockoutLevelKey);
      return MpinCheck.accepted;
    }
    final failed = attempts + 1;
    await _store.write(_attemptsKey, '$failed');
    final left = maxAttempts - failed;
    if (left <= 0) {
      await _startCooldown();
      return MpinCheck.locked;
    }
    return MpinCheck.rejected(left);
  }

  Future<void> clear() async {
    await _store.delete(_hashKey);
    await _store.delete(_saltKey);
    await _store.delete(_attemptsKey);
    await _store.delete(_cooldownUntilKey);
    await _store.delete(_lockoutLevelKey);
  }

  Future<void> _startCooldown() async {
    final levelText = await _store.read(_lockoutLevelKey);
    final level = levelText == null ? 0 : int.tryParse(levelText);
    if (level == null || level < 0) {
      throw StateError('Stored MPIN lockout level is malformed.');
    }
    final index = level.clamp(0, _cooldowns.length - 1);
    final until = DateTime.now().add(_cooldowns[index]).millisecondsSinceEpoch;
    await _store.write(_cooldownUntilKey, '$until');
    await _store.write(
      _lockoutLevelKey,
      '${(index + 1).clamp(0, _cooldowns.length - 1)}',
    );
  }

  Future<bool> _matchesRecord(String pin, String record) async {
    final parts = record.split('\$');
    if (parts.length != 4) throw StateError('Stored MPIN record is malformed.');
    final iterations = int.parse(parts[1]);
    final candidate = await _kdf(pin, base64Decode(parts[2]), iterations);
    return _sameBytes(candidate, base64Decode(parts[3]));
  }

  /// Checks an unversioned record and, on success, rewrites it as v2.
  Future<bool> _matchesLegacy(String pin, String hashText) async {
    final saltText = await _store.read(_saltKey);
    if (saltText == null) {
      throw StateError('Stored MPIN record is malformed.');
    }
    final salt = base64Decode(saltText);
    final candidate = await _deriveLegacyOffThread(pin, salt);
    if (!_sameBytes(candidate, base64Decode(hashText))) return false;

    final upgradedSalt = List<int>.generate(16, (_) => _random.nextInt(256));
    final upgradedHash = await _kdf(pin, upgradedSalt, _iterations);
    await _writeRecord(upgradedSalt, upgradedHash);
    return true;
  }

  Future<void> _writeRecord(List<int> salt, List<int> hash) async {
    await _store.write(
      _hashKey,
      '$_recordVersion\$$_iterations\$${base64Encode(salt)}\$'
      '${base64Encode(hash)}',
    );
    await _store.delete(_saltKey);
  }

  static Future<List<int>> _pbkdf2OffThread(
    String pin,
    List<int> salt,
    int iterations,
  ) =>
      compute(_pbkdf2, (pin, salt, iterations));

  static Future<List<int>> _deriveLegacyOffThread(
    String pin,
    List<int> salt,
  ) =>
      compute(_legacyDerive, (pin, salt, _legacyIterations));


  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

Future<List<int>> _pbkdf2((String, List<int>, int) args) async {
  final (pin, salt, iterations) = args;
  final key = await Pbkdf2.hmacSha256(iterations: iterations, bits: 256)
      .deriveKeyFromPassword(password: pin, nonce: salt);
  return key.extractBytes();
}

/// The pre-versioning HMAC chain, kept only to verify and upgrade old records.
List<int> _legacyDerive((String, List<int>, int) args) {
  final (pin, salt, iterations) = args;
  final hmac = Hmac(sha256, utf8.encode(pin));
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final output = List<int>.of(block);
  for (var i = 1; i < iterations; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < output.length; j++) {
      output[j] ^= block[j];
    }
  }
  return output;
}
