class PlatformNode {
  // Browsers cannot bind a TCP port or accept unsolicited LAN connections.
  static bool get canReceiveLanReplicas => false;
  static String get receiverDescription =>
      'Browser client: uploads and retrieves via Android peers';
  static Future<void> start(String nodeId) async {}
  static Future<List<Map<dynamic, dynamic>>> incomingTransfers() async =>
      const [];
  static Future<String> deviceName() async => 'Browser client';
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
