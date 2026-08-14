import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'offline_database.dart';

class OfflineSession {
  const OfflineSession({
    required this.userId,
    required this.email,
    required this.deviceId,
  });

  final String userId;
  final String email;
  final String deviceId;
}

/// Keeps only secrets and the PIN verifier in Android Keystore-backed storage.
/// Transaction data is never stored in SharedPreferences.
class OfflineSessionService {
  OfflineSessionService({FlutterSecureStorage? secureStorage})
      : _storage = secureStorage ?? const FlutterSecureStorage();

  static const _sessionKey = 'offline.session';
  final FlutterSecureStorage _storage;
  final _sha256 = Sha256();

  Future<OfflineSession?> currentSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    final json = Map<String, dynamic>.from(jsonDecode(raw));
    return OfflineSession(
      userId: json['user_id'] as String,
      email: json['email'] as String? ?? '',
      deviceId: json['device_id'] as String,
    );
  }

  Future<OfflineSession> activate({
    required String userId,
    required String email,
    required String pin,
  }) async {
    _validatePin(pin);
    final deviceId = _randomToken(16);
    final dbKey = _randomToken(32);
    final salt = _randomToken(16);
    final verifier = await _pinVerifier(pin, salt);
    final session = OfflineSession(userId: userId, email: email, deviceId: deviceId);
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode({
        'user_id': userId,
        'email': email,
        'device_id': deviceId,
        'salt': salt,
        'pin_verifier': verifier,
      }),
    );
    await _storage.write(key: _dbKey(userId), value: dbKey);
    return session;
  }

  Future<bool> unlock(String pin) async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return false;
    final json = Map<String, dynamic>.from(jsonDecode(raw));
    return (await _pinVerifier(pin, json['salt'] as String)) ==
        json['pin_verifier'] as String;
  }

  Future<OfflineDatabase> openDatabase(OfflineSession session) async {
    final key = await _storage.read(key: _dbKey(session.userId));
    if (key == null) throw StateError('Kunci database offline tidak ditemukan.');
    return OfflineDatabase.open(userId: session.userId, encryptionKey: key);
  }

  Future<void> clear() async {
    final session = await currentSession();
    if (session != null) await _storage.delete(key: _dbKey(session.userId));
    await _storage.delete(key: _sessionKey);
  }

  Future<String> _pinVerifier(String pin, String salt) async {
    final hash = await _sha256.hash(utf8.encode('$salt:$pin'));
    return base64UrlEncode(hash.bytes);
  }

  String _dbKey(String userId) => 'offline.db.$userId';

  String _randomToken(int bytes) {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(bytes, (_) => random.nextInt(256)));
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError.value(pin, 'pin', 'PIN harus terdiri dari 6 digit.');
    }
  }
}
