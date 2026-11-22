import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivenet/hive_core.dart';
import 'package:image/image.dart' as image;

void main() {
  test(
    'compression resizes, reduces a large image, and has a stable SHA-256 ID',
    () {
      final source = image.Image(width: 3000, height: 2000);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(x, y, x % 255, y % 255, (x + y) % 255);
        }
      }
      final input = Uint8List.fromList(image.encodePng(source));
      final compressed = compressImage(input);
      expect(compressed.width, 1920);
      expect(compressed.height, 1280);
      expect(compressed.bytes, isNotEmpty);
      expect(compressed.id, hasLength(64));
      expect(matchesContentId(compressed.id, compressed.bytes), isTrue);
      expect(matchesContentId(compressed.id, [1, 2, 3]), isFalse);
    },
  );

  test('router selects two distinct online peers with capacity', () {
    final peers = [
      const PeerCandidate(
        key: 'a',
        freeBytes: 8 << 30,
        latencyMs: 5,
        online: true,
        successes: 10,
        failures: 0,
      ),
      const PeerCandidate(
        key: 'b',
        freeBytes: 6 << 30,
        latencyMs: 10,
        online: true,
        successes: 8,
        failures: 1,
      ),
      const PeerCandidate(
        key: 'c',
        freeBytes: 1,
        latencyMs: 1,
        online: true,
        successes: 20,
        failures: 0,
      ),
      const PeerCandidate(
        key: 'd',
        freeBytes: 9 << 30,
        latencyMs: 1,
        online: false,
        successes: 20,
        failures: 0,
      ),
    ];
    final selected = selectReplicaPeers(peers, (peer) => peer, 1024);
    expect(selected.map((peer) => peer.key), ['a', 'b']);
  });

  test('router reports the actual number of distinct eligible peers', () {
    const uploadBytes = 2048;
    PeerCandidate peer(
      String key, {
      required bool online,
      required int freeBytes,
    }) => PeerCandidate(
      key: key,
      online: online,
      freeBytes: freeBytes,
      latencyMs: 10,
      successes: 1,
      failures: 0,
    );

    expect(
      rankEligibleReplicaPeers<PeerCandidate>(
        const [],
        (candidate) => candidate,
        uploadBytes,
      ),
      isEmpty,
    );

    final one = [peer('one', online: true, freeBytes: 4096)];
    expect(
      rankEligibleReplicaPeers(one, (candidate) => candidate, uploadBytes),
      hasLength(1),
    );
    expect(
      selectReplicaPeers(one, (candidate) => candidate, uploadBytes),
      hasLength(1),
    );

    final two = [
      peer('one', online: true, freeBytes: 4096),
      peer('two', online: true, freeBytes: 4096),
    ];
    expect(
      selectReplicaPeers(two, (candidate) => candidate, uploadBytes),
      hasLength(2),
    );

    final manyWithDuplicatesAndUnavailable = [
      ...two,
      peer('two', online: true, freeBytes: 8192),
      peer('offline', online: false, freeBytes: 8192),
      peer('full', online: true, freeBytes: 1),
      peer('three', online: true, freeBytes: 8192),
    ];
    final eligible = rankEligibleReplicaPeers(
      manyWithDuplicatesAndUnavailable,
      (candidate) => candidate,
      uploadBytes,
    );
    expect(
      eligible.map((candidate) => candidate.key),
      containsAll(['one', 'two', 'three']),
    );
    expect(eligible.where((candidate) => candidate.key == 'two'), hasLength(1));
    expect(
      selectReplicaPeers(
        manyWithDuplicatesAndUnavailable,
        (candidate) => candidate,
        uploadBytes,
      ),
      hasLength(2),
    );
  });
}
