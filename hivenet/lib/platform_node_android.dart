import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class PlatformNode {
  static const _channel = MethodChannel('com.hivenet.hivenet/node');
  static bool get canReceiveLanReplicas => true;
  static String get receiverDescription => 'Local receiver: port 8765';
  static Future<void> start(String nodeId) {
    // `dart.library.io` also selects this implementation for desktop and iOS.
    // Only Android has the foreground-service MethodChannel implementation.
    if (!Platform.isAndroid) return Future.value();
    return _channel.invokeMethod<void>('startNode', {'nodeId': nodeId});
  }

  /// The foreground receiver persists these events, so this remains truthful
  /// even when the Flutter activity was paused during an incoming upload.
  static Future<List<Map<dynamic, dynamic>>> incomingTransfers() async {
    if (!Platform.isAndroid) return const [];
    final events = await _channel.invokeMethod<List<dynamic>>(
      'incomingTransfers',
    );
    return events
            ?.map((item) => Map<dynamic, dynamic>.from(item as Map))
            .toList() ??
        const [];
  }

  static Future<String> deviceName() async {
    if (!Platform.isAndroid) return 'This device';
    return await _channel.invokeMethod<String>('deviceName') ?? 'This device';
  }

  static Future<String> devicePublicKey() =>
      _channel.invokeMethod<String>('devicePublicKey').then((value) => value!);
  static Future<String> signDeviceProof(String payload) => _channel
      .invokeMethod<String>('signDeviceProof', {'payload': payload})
      .then((value) => value!);
  static Future<String?> localIp() => _channel.invokeMethod<String>('localIp');
  static Future<Map<dynamic, dynamic>> startPairing(
    Map<String, dynamic> owner,
  ) => _channel
      .invokeMethod<Map<dynamic, dynamic>>('startPairing', {'owner': owner})
      .then((value) => value!);
  static Future<List<Map<dynamic, dynamic>>> pairingRequests() async =>
      (await _channel.invokeMethod<List<dynamic>>('pairingRequests'))
          ?.map((e) => Map<dynamic, dynamic>.from(e as Map))
          .toList() ??
      const [];
  static Future<bool> approvePairing(String deviceId) async =>
      await _channel.invokeMethod<bool>('approvePairing', {
        'deviceId': deviceId,
      }) ??
      false;
}
