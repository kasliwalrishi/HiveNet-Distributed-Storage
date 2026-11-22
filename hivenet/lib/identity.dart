import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User identity is deliberately separate from a device identity. Sensitive
/// local state lives in encrypted platform storage, never SharedPreferences.
class HiveProfile {
  const HiveProfile({
    required this.userId,
    required this.displayName,
    required this.deviceId,
    required this.deviceNickname,
    required this.createdAt,
    required this.deviceRegisteredAt,
    this.photoBase64,
  });
  final String userId, displayName, deviceId, deviceNickname;
  final int createdAt, deviceRegisteredAt;
  final String? photoBase64;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'deviceId': deviceId,
    'deviceNickname': deviceNickname,
    'createdAt': createdAt,
    'deviceRegisteredAt': deviceRegisteredAt,
    'photoBase64': photoBase64,
  };
  factory HiveProfile.fromJson(Map<String, dynamic> json) => HiveProfile(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    deviceId: json['deviceId'] as String,
    deviceNickname: json['deviceNickname'] as String,
    createdAt: (json['createdAt'] as num).toInt(),
    deviceRegisteredAt: (json['deviceRegisteredAt'] as num).toInt(),
    photoBase64: json['photoBase64'] as String?,
  );
}

class IdentityStore {
  IdentityStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _profileKey = 'hivenet.identity.profile.v1';
  static const _pinHashKey = 'hivenet.identity.pin_hash.v1';

  Future<HiveProfile?> read() async {
    final raw = await _storage.read(key: _profileKey);
    return raw == null
        ? null
        : HiveProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
  }

  Future<void> save(HiveProfile profile) =>
      _storage.write(key: _profileKey, value: jsonEncode(profile.toJson()));
  Future<HiveProfile> create({
    required String displayName,
    required String deviceNickname,
    String? photoBase64,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final profile = HiveProfile(
      userId: _uuid(),
      displayName: displayName.trim(),
      deviceId: _uuid(),
      deviceNickname: deviceNickname.trim(),
      createdAt: now,
      deviceRegisteredAt: now,
      photoBase64: photoBase64,
    );
    await save(profile);
    return profile;
  }

  Future<void> setPin(String pin) async => _storage.write(
    key: _pinHashKey,
    value: sha256.convert(utf8.encode(pin)).toString(),
  );
  Future<bool> verifyPin(String pin) async =>
      (await _storage.read(key: _pinHashKey)) ==
      sha256.convert(utf8.encode(pin)).toString();
  Future<bool> get hasPin async =>
      await _storage.read(key: _pinHashKey) != null;
  Future<void> disablePin() => _storage.delete(key: _pinHashKey);

  String _uuid() {
    final b = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
