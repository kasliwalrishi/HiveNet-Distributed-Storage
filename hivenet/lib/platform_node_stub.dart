class PlatformNode {
  static bool get canReceiveLanReplicas => false;
  static String get receiverDescription =>
      'Receiver unavailable on this platform';
  static Future<void> start(String nodeId) async {}
  static Future<List<Map<dynamic, dynamic>>> incomingTransfers() async =>
      const [];
  static Future<String> deviceName() async => 'This device';
  static Future<String> devicePublicKey() async => '';
  static Future<String> signDeviceProof(String payload) async => '';
  static Future<String?> localIp() async => null;
  static Future<Map<dynamic, dynamic>> startPairing(
    Map<String, dynamic> owner,
  ) async => const {};
  static Future<List<Map<dynamic, dynamic>>> pairingRequests() async =>
      const [];
  static Future<bool> approvePairing(String deviceId) async => false;
}
